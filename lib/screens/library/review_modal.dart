import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:corpus/globals.dart';
import 'package:corpus/utils/format_utils.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../repositories/review_repository.dart';
import '../../models/models.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/corpus_network_image.dart';

/// Callback invocado cuando el usuario pulsa "Guardar/Publicar Reseña".
/// Firma idéntica a [_GameDetailsScreenState._saveReview].
typedef OnSaveReview =
    Future<void> Function({
      String? reviewId,
      required double rating,
      required double ratingGameplay,
      required double ratingNarrative,
      required double ratingSoundtrack,
      required double ratingVisuals,
      required String comment,
      required String status,
      required String completionType,
      required bool isReplay,
      required int? replayNumber,
      required String? platform,
      required double? playTimeHours,
      required DateTime? playedFrom,
      required DateTime? playedUntil,
      required int? progressPercent,
      required DateTime? reviewDate,
      required List<XFile> newImages,
      required List<String> existingImages,
      required List<String> partnerIds,
    });

/// Modal bottom sheet de creación/edición de reseña.
///
/// Extraído de [_GameDetailsScreenState._showReviewModal] para reducir el
/// tamaño de game_details_screen.dart y facilitar el testing independiente.
///
/// Uso:
/// ```dart
/// ReviewModal.show(
///   context: context,
///   gameData: widget.gameData,
///   enrichedData: _enrichedData,
///   existingReview: _reviews.isNotEmpty ? _reviews.first : null,
///   isSaving: _isSaving,
///   currentRating: _rating,
///   currentStatus: _status,
///   commentController: _commentController,
///   onSave: _saveReview,
/// );
/// ```
class ReviewModal {
  ReviewModal._();

  /// Delega en [ReviewRepository.fetchFriendsForCoopPicker] para obtener
  /// los amigos del usuario actual. La lógica (v_friend_pairs + fallback)
  /// vive en el repositorio — no la duplicamos aquí.
  static Future<List<UserProfile>> _fetchFriends() =>
      ReviewRepository().fetchFriendsForCoopPicker();

  static void show({
    required BuildContext context,
    required Map<String, dynamic> gameData,
    required Map<String, dynamic> enrichedData,
    Review? existingReview,
    List<String>? currentPartnerIds,
    required bool isSaving,
    required double currentRating,
    required double currentRatingGameplay,
    required double currentRatingNarrative,
    required double currentRatingSoundtrack,
    required double currentRatingVisuals,
    required String currentStatus,
    required TextEditingController commentController,
    required OnSaveReview onSave,
    bool inLibrary = false,
  }) {
    final hasReview = existingReview != null;
    final r = existingReview;

    // Inicializar estado del formulario desde la reseña existente o el estado actual
    double reviewRating = hasReview ? (r!.rating ?? 0) : currentRating;
    double reviewRatingGameplay = hasReview
        ? (r!.ratingGameplay ?? 0)
        : currentRatingGameplay;
    double reviewRatingNarrative = hasReview
        ? (r!.ratingNarrative ?? 0)
        : currentRatingNarrative;
    double reviewRatingSoundtrack = hasReview
        ? (r!.ratingSoundtrack ?? 0)
        : currentRatingSoundtrack;
    double reviewRatingVisuals = hasReview
        ? (r!.ratingVisuals ?? 0)
        : currentRatingVisuals;
    String reviewStatus = hasReview ? r!.status.dbValue : currentStatus;
    String reviewCompletionType = hasReview
        ? (r!.completionType ?? 'story')
        : 'story';
    bool reviewIsReplay = hasReview && r!.isReplay;
    // TODO: replayNumber is not in Review model currently? Let's assume it's omitted or 1
    int reviewReplayNumber = 1;
    String? reviewPlatform = hasReview ? r!.platform : null;
    String playTimeText = hasReview && r!.playTimeHours != null
        ? r.playTimeHours.toString()
        : '';
    // Review model does not have played_from/played_until/progress_percent yet.
    // They might be in user_games or they might be missing. We'll leave them as null/0 for now.
    DateTime? reviewPlayedFrom = hasReview ? r!.playedFrom : null;
    DateTime? reviewPlayedUntil = hasReview ? r!.playedUntil : null;
    int reviewProgressPercent = hasReview ? (r!.progressPercent ?? 0) : 0;
    // Fecha de publicación de la reseña (editable solo al editar)
    DateTime? reviewDate = hasReview ? r!.createdAt : null;
    // Snapshot inmutable de la fecha original, para restaurarla si el usuario
    // cambia de estado por error durante la edición (ver applyStatusChange).
    final DateTime? initialReviewDate = reviewDate;

    /// Aplica un cambio de estado desde los chips de "Estado".
    /// Si pasa de un estado no finalizado (quiero/jugando) a uno finalizado
    /// (terminado/abandonado), autorellena la fecha con hoy. Si se revierte a
    /// un estado no finalizado antes de guardar, restaura la fecha original
    /// (por si ha sido un misclick).
    void applyStatusChange(String v) {
      final wasFinished = GameStatus.fromString(reviewStatus).isFinished;
      final willBeFinished = GameStatus.fromString(v).isFinished;
      if (!wasFinished && willBeFinished) {
        reviewDate = DateTime.now();
      } else if (wasFinished && !willBeFinished) {
        reviewDate = initialReviewDate;
      }
      reviewStatus = v;
      reviewCompletionType = 'none';
    }

    // El controller de comentario vive dentro del modal (con texto inicial)
    final reviewCommentController = TextEditingController(
      text: hasReview ? (r!.comment ?? '') : commentController.text,
    );
    final String? reviewId = hasReview ? r!.id : null;
    final TextEditingController partnerSearchController =
        TextEditingController();
    List<String> reviewPartnerIds = List<String>.from(currentPartnerIds ?? []);
    final Future<List<UserProfile>> friendsFuture = _fetchFriends();

    List<XFile> newImages = [];
    List<String> existingImages = hasReview
        ? List<String>.from(r!.imageUrls)
        : [];

    final List<dynamic> platforms =
        (gameData['platforms'] as List?)?.isNotEmpty == true
        ? gameData['platforms']
        : (enrichedData['platforms'] as List? ?? []);

    // Paso 1: elegir estado. Paso 2: rellenar datos.
    bool statusStepConfirmed = hasReview || inLibrary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            // ── helpers locales ───────────────────────────────────────────
            Widget chip(
              String value,
              String label,
              IconData icon,
              String current,
              Color color,
              Function(String) onSelect,
            ) {
              final sel = current == value;
              final tc = sel
                  ? (color == Theme.of(modalContext).colorScheme.secondary
                        ? Theme.of(modalContext).scaffoldBackgroundColor
                        : Colors.white)
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7);
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: sel
                          ? tc
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(label),
                  ],
                ),
                selected: sel,
                onSelected: (_) => setModalState(() => onSelect(value)),
                selectedColor: color,
                backgroundColor: Theme.of(modalContext).colorScheme.surface,
                labelStyle: TextStyle(
                  color: tc,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      Theme.of(
                        context,
                      ).extension<CorpusThemeExtension>()?.radiusLarge ??
                      BorderRadius.circular(20),
                ),
                side: BorderSide(
                  color: sel
                      ? color
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                showCheckmark: false,
              );
            }

            Widget statusButton(
              String value,
              String label,
              IconData icon,
              String current,
              Color color,
              Function(String) onSelect,
            ) {
              final sel = current == value;
              final radius =
                  Theme.of(
                    context,
                  ).extension<CorpusThemeExtension>()?.radiusLarge ??
                  BorderRadius.circular(12);
              final onSurface = Theme.of(context).colorScheme.onSurface;
              final onSurfaceVariant = Theme.of(
                context,
              ).colorScheme.onSurfaceVariant;
              final labelColor = sel
                  ? (color.computeLuminance() > 0.5 ? onSurface : Colors.white)
                  : onSurface;

              return SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setModalState(() => onSelect(value)),
                    borderRadius: radius,
                    child: Ink(
                      decoration: BoxDecoration(
                        color: sel
                            ? color
                            : Theme.of(
                                modalContext,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: radius,
                        border: Border.all(
                          color: sel
                              ? color
                              : onSurfaceVariant.withValues(alpha: 0.45),
                          width: sel ? 2 : 1,
                        ),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, size: 22, color: labelColor),
                            const SizedBox(width: 10),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: sel
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: labelColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            Widget buildRemovableImage({
              required Widget imageWidget,
              required VoidCallback onRemove,
            }) {
              return Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 8, top: 8),
                    decoration: BoxDecoration(
                      borderRadius:
                          Theme.of(
                            context,
                          ).extension<CorpusThemeExtension>()?.radiusSmall ??
                          BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: imageWidget,
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            Widget buildSubRatingSlider(
              String label,
              IconData icon,
              double value,
              Function(double) onChange,
            ) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: value,
                          min: 0,
                          max: 10,
                          divisions: 100,
                          activeColor: Theme.of(context).colorScheme.primary,
                          label: value > 0 ? formatRating(value) : '-',
                          onChanged: onChange,
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Text(
                          value > 0 ? formatRating(value) : '-',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            String monthAbbr(int m) {
              const months = [
                'ene',
                'feb',
                'mar',
                'abr',
                'may',
                'jun',
                'jul',
                'ago',
                'sep',
                'oct',
                'nov',
                'dic',
              ];
              return months[m - 1];
            }

            Widget buildExtraInfoFields() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Rejugada',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: reviewIsReplay,
                        onChanged: (val) =>
                            setModalState(() => reviewIsReplay = val),
                        activeThumbColor: Theme.of(
                          modalContext,
                        ).colorScheme.primary,
                      ),
                    ],
                  ),
                  if (reviewIsReplay)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Text(
                            'Nº de rejugada',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 60,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              controller: TextEditingController(
                                text: reviewReplayNumber.toString(),
                              ),
                              onChanged: (val) {
                                final n = int.tryParse(val);
                                if (n != null) {
                                  setModalState(() => reviewReplayNumber = n);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  FutureBuilder<List<UserProfile>>(
                    future: friendsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final friends = snapshot.data ?? [];
                      if (friends.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Compañero (Cooperativo)',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final availableFriends = friends
                                  .where(
                                    (f) => !reviewPartnerIds.contains(f.id),
                                  )
                                  .toList();
                              return DropdownMenu<String>(
                                controller: partnerSearchController,
                                hintText: 'Buscar y añadir amigo...',
                                enableSearch: true,
                                enableFilter: true,
                                width: constraints.maxWidth,
                                dropdownMenuEntries: availableFriends
                                    .map<DropdownMenuEntry<String>>(
                                      (f) => DropdownMenuEntry<String>(
                                        value: f.id,
                                        label: f.effectiveName,
                                        leadingIcon: CircleAvatar(
                                          radius: 12,
                                          backgroundImage: f.avatarUrl != null
                                              ? NetworkImage(f.avatarUrl!)
                                              : null,
                                          child: f.avatarUrl == null
                                              ? const Icon(
                                                  Icons.person,
                                                  size: 16,
                                                )
                                              : null,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onSelected: (selectedId) {
                                  if (selectedId != null) {
                                    setModalState(() {
                                      reviewPartnerIds.add(selectedId);
                                      partnerSearchController.clear();
                                    });
                                  }
                                },
                              );
                            },
                          ),
                          if (reviewPartnerIds.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).dividerColor.withValues(alpha: 0.1),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: reviewPartnerIds.map<Widget>((id) {
                                  final friend = friends.firstWhere(
                                    (f) => f.id == id,
                                    orElse: () => UserProfile(
                                      id: id,
                                      username: 'Desconocido',
                                    ),
                                  );
                                  return ListTile(
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundImage: friend.avatarUrl != null
                                          ? NetworkImage(friend.avatarUrl!)
                                          : null,
                                      child: friend.avatarUrl == null
                                          ? const Icon(Icons.person, size: 16)
                                          : null,
                                    ),
                                    title: Text(friend.effectiveName),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () {
                                        setModalState(() {
                                          reviewPartnerIds.remove(id);
                                        });
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                  if (platforms.isNotEmpty) ...[
                    Text(
                      'Plataforma',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: reviewPlatform,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      dropdownColor: Theme.of(
                        modalContext,
                      ).colorScheme.surfaceContainerHighest,
                      items: platforms
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.toString(),
                              child: Text(
                                p.toString(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setModalState(() => reviewPlatform = val),
                      hint: const Text('Seleccionar plataforma'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Tiempo de juego (horas)',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Ej: 45.5',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (val) => setModalState(() => playTimeText = val),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Fecha de juego',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            reviewPlayedFrom != null
                                ? '${reviewPlayedFrom!.day} ${monthAbbr(reviewPlayedFrom!.month)} ${reviewPlayedFrom!.year}'
                                : 'Desde',
                            style: const TextStyle(fontSize: 13),
                          ),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: modalContext,
                              initialDate: reviewPlayedFrom ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (d != null) {
                              setModalState(() => reviewPlayedFrom = d);
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '-',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            reviewPlayedUntil != null
                                ? '${reviewPlayedUntil!.day} ${monthAbbr(reviewPlayedUntil!.month)} ${reviewPlayedUntil!.year}'
                                : 'Hasta',
                            style: const TextStyle(fontSize: 13),
                          ),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: modalContext,
                              initialDate: reviewPlayedUntil ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (d != null) {
                              setModalState(() => reviewPlayedUntil = d);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Progreso',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: reviewProgressPercent.toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 100,
                          activeColor: Theme.of(
                            modalContext,
                          ).colorScheme.primary,
                          label: '$reviewProgressPercent%',
                          onChanged: (val) => setModalState(
                            () => reviewProgressPercent = val.round(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '$reviewProgressPercent%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Theme.of(modalContext).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            Color statusColor(String s) =>
                GameStatus.colorForString(context, s);

            // ── cuerpo del modal ──────────────────────────────────────────
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Header: título + (si edición) botón de fecha ──
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      hasReview
                                          ? 'Editar Reseña'
                                          : 'Añadir Reseña',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(
                                      Icons.edit_calendar,
                                      size: 16,
                                    ),
                                    label: Text(() {
                                      final displayDate =
                                          reviewDate ?? initialReviewDate;
                                      return displayDate != null
                                          ? '${displayDate.day} ${monthAbbr(displayDate.month)} ${displayDate.year}'
                                          : 'Fecha';
                                    }(), style: const TextStyle(fontSize: 12)),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                    ),
                                    onPressed: () async {
                                      final d = await showDatePicker(
                                        context: modalContext,
                                        initialDate:
                                            reviewDate ??
                                            initialReviewDate ??
                                            DateTime.now(),
                                        firstDate: DateTime(1970),
                                        lastDate: DateTime.now().add(
                                          const Duration(days: 1),
                                        ),
                                      );
                                      if (d != null) {
                                        setModalState(() => reviewDate = d);
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // ── Estado ──────────────────────────────────────────
                              if (!statusStepConfirmed) ...[
                                Text(
                                  'Estado',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                statusButton(
                                  'wishlist',
                                  'Quiero',
                                  Icons.favorite,
                                  '',
                                  statusColor('wishlist'),
                                  (v) {
                                    applyStatusChange(v);
                                    statusStepConfirmed = true;
                                  },
                                ),
                                const SizedBox(height: 8),
                                statusButton(
                                  'playing',
                                  'Jugando',
                                  Icons.videogame_asset,
                                  '',
                                  statusColor('playing'),
                                  (v) {
                                    applyStatusChange(v);
                                    statusStepConfirmed = true;
                                  },
                                ),
                                const SizedBox(height: 8),
                                statusButton(
                                  'beaten',
                                  'Terminado',
                                  Icons.check_circle,
                                  '',
                                  statusColor('beaten'),
                                  (v) {
                                    applyStatusChange(v);
                                    statusStepConfirmed = true;
                                  },
                                ),
                                const SizedBox(height: 8),
                                statusButton(
                                  'abandoned',
                                  'Abandonado',
                                  Icons.cancel_outlined,
                                  '',
                                  statusColor('abandoned'),
                                  (v) {
                                    applyStatusChange(v);
                                    statusStepConfirmed = true;
                                  },
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.arrow_back),
                                      tooltip: 'Cambiar estado',
                                      onPressed: () => setModalState(
                                        () => statusStepConfirmed = false,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                    ),
                                    Icon(
                                      GameStatus.iconForString(reviewStatus),
                                      size: 20,
                                      color: statusColor(reviewStatus),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      GameStatus.labelForString(reviewStatus),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor(reviewStatus),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (statusStepConfirmed) ...[
                                const SizedBox(height: 16),

                                // ── Tipo de completado / Modo de juego ──────────────
                                if (reviewStatus == 'beaten') ...[
                                  Text(
                                    'Tipo de completado',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      chip(
                                        'none',
                                        'Nada',
                                        Icons.do_not_disturb_alt,
                                        reviewCompletionType,
                                        Theme.of(
                                          modalContext,
                                        ).colorScheme.primary,
                                        (v) => reviewCompletionType = v,
                                      ),
                                      chip(
                                        'story',
                                        'Historia',
                                        Icons.auto_stories,
                                        reviewCompletionType,
                                        Theme.of(
                                          modalContext,
                                        ).colorScheme.primary,
                                        (v) => reviewCompletionType = v,
                                      ),
                                      chip(
                                        'story_extras',
                                        'Historia + Extras',
                                        Icons.extension,
                                        reviewCompletionType,
                                        Theme.of(
                                          modalContext,
                                        ).colorScheme.primary,
                                        (v) => reviewCompletionType = v,
                                      ),
                                      chip(
                                        '100_percent',
                                        'Platino',
                                        Icons.emoji_events,
                                        reviewCompletionType,
                                        Theme.of(
                                          modalContext,
                                        ).colorScheme.primary,
                                        (v) => reviewCompletionType = v,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                ] else if (reviewStatus == 'playing') ...[
                                  Text(
                                    'Modo de juego',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      chip(
                                        'none',
                                        'Nada',
                                        Icons.do_not_disturb_alt,
                                        reviewCompletionType,
                                        Theme.of(
                                          modalContext,
                                        ).colorScheme.primary,
                                        (v) => reviewCompletionType = v,
                                      ),
                                      chip(
                                        'endless',
                                        'Sin Fin',
                                        Icons.all_inclusive,
                                        reviewCompletionType,
                                        Theme.of(
                                          modalContext,
                                        ).colorScheme.primary,
                                        (v) => reviewCompletionType = v,
                                      ),
                                      chip(
                                        'on_hold',
                                        'En Pausa',
                                        Icons.pause,
                                        reviewCompletionType,
                                        Theme.of(
                                          modalContext,
                                        ).colorScheme.primary,
                                        (v) => reviewCompletionType = v,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                ],

                                // ── Nota y sub-ratings ──────────────────────────────
                                if (reviewStatus == 'beaten' ||
                                    reviewStatus == 'abandoned') ...[
                                  Text(
                                    'Nota',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Slider(
                                          value: reviewRating,
                                          min: 0,
                                          max: 10,
                                          divisions: 100,
                                          activeColor: Theme.of(
                                            modalContext,
                                          ).colorScheme.secondary,
                                          label: reviewRating > 0
                                              ? formatRating(reviewRating)
                                              : '-',
                                          onChanged: (val) => setModalState(
                                            () => reviewRating = val,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 40,
                                        child: Text(
                                          reviewRating > 0
                                              ? formatRating(reviewRating)
                                              : '-',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Theme.of(
                                              modalContext,
                                            ).colorScheme.secondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  Theme(
                                    data: Theme.of(modalContext).copyWith(
                                      dividerColor: Colors.transparent,
                                    ),
                                    child: ExpansionTile(
                                      tilePadding: EdgeInsets.zero,
                                      title: const Text(
                                        'Desglosar nota',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      children: [
                                        buildSubRatingSlider(
                                          'Gameplay',
                                          Icons.sports_esports,
                                          reviewRatingGameplay,
                                          (val) => setModalState(
                                            () => reviewRatingGameplay = val,
                                          ),
                                        ),
                                        buildSubRatingSlider(
                                          'Narrativa',
                                          Icons.auto_stories,
                                          reviewRatingNarrative,
                                          (val) => setModalState(
                                            () => reviewRatingNarrative = val,
                                          ),
                                        ),
                                        buildSubRatingSlider(
                                          'Banda Sonora',
                                          Icons.music_note,
                                          reviewRatingSoundtrack,
                                          (val) => setModalState(
                                            () => reviewRatingSoundtrack = val,
                                          ),
                                        ),
                                        buildSubRatingSlider(
                                          'Gráficos',
                                          Icons.brush,
                                          reviewRatingVisuals,
                                          (val) => setModalState(
                                            () => reviewRatingVisuals = val,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // ── Reseña (comentario) ───────────────────────────
                                  Text(
                                    'Reseña',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: reviewCommentController,
                                    maxLines: 4,
                                    minLines: 2,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: const InputDecoration(
                                      hintText: '¿Qué te pareció el juego?',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // ── Imágenes adjuntas ─────────────────────────────
                                  if (existingImages.isNotEmpty ||
                                      newImages.isNotEmpty) ...[
                                    SizedBox(
                                      height: 90,
                                      child: ListView(
                                        scrollDirection: Axis.horizontal,
                                        children: [
                                          ...existingImages.map(
                                            (url) => buildRemovableImage(
                                              imageWidget: CorpusNetworkImage(
                                                url: url,
                                                fit: BoxFit.cover,
                                                width: 80,
                                                height: 80,
                                              ),
                                              onRemove: () => setModalState(
                                                () =>
                                                    existingImages.remove(url),
                                              ),
                                            ),
                                          ),
                                          ...newImages.map(
                                            (file) => buildRemovableImage(
                                              imageWidget: kIsWeb
                                                  ? CorpusNetworkImage(
                                                      url: file.path,
                                                      fit: BoxFit.cover,
                                                      width: 80,
                                                      height: 80,
                                                    )
                                                  : Image.file(
                                                      File(file.path),
                                                      fit: BoxFit.cover,
                                                      width: 80,
                                                      height: 80,
                                                    ),
                                              onRemove: () => setModalState(
                                                () => newImages.remove(file),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  if (existingImages.length + newImages.length <
                                      3)
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.add_photo_alternate,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Adjuntar imagen (máx 3)',
                                      ),
                                      onPressed: () async {
                                        final picker = ImagePicker();
                                        final pickedFiles = await picker
                                            .pickMultiImage(
                                              imageQuality: 70,
                                              maxWidth: 1080,
                                            );
                                        if (pickedFiles.isNotEmpty) {
                                          setModalState(() {
                                            final remaining =
                                                3 -
                                                existingImages.length -
                                                newImages.length;
                                            newImages.addAll(
                                              pickedFiles.take(remaining),
                                            );
                                          });
                                        }
                                      },
                                    ),
                                  const SizedBox(height: 12),
                                ],

                                // ── Información extra (plataforma, tiempo, fechas) ─
                                if (reviewStatus != 'wishlist') ...[
                                  if (reviewStatus == 'playing') ...[
                                    Text(
                                      'Información Extra',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  Theme(
                                    data: Theme.of(modalContext).copyWith(
                                      dividerColor: Colors.transparent,
                                    ),
                                    child: reviewStatus == 'playing'
                                        ? buildExtraInfoFields()
                                        : ExpansionTile(
                                            tilePadding: EdgeInsets.zero,
                                            title: const Text(
                                              'Información Extra',
                                              style: TextStyle(fontSize: 14),
                                            ),
                                            children: [buildExtraInfoFields()],
                                          ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (statusStepConfirmed) ...[
                    // ── Botón guardar ─────────────────────────────────────
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () => onSave(
                                  reviewId: reviewId,
                                  rating: reviewRating,
                                  ratingGameplay: reviewRatingGameplay,
                                  ratingNarrative: reviewRatingNarrative,
                                  ratingSoundtrack: reviewRatingSoundtrack,
                                  ratingVisuals: reviewRatingVisuals,
                                  comment: reviewCommentController.text,
                                  status: reviewStatus,
                                  completionType: reviewStatus == 'wishlist'
                                      ? 'none'
                                      : reviewCompletionType,
                                  isReplay:
                                      !(reviewStatus == 'wishlist') &&
                                      reviewIsReplay,
                                  replayNumber: reviewIsReplay
                                      ? reviewReplayNumber
                                      : null,
                                  platform: reviewPlatform,
                                  playTimeHours: double.tryParse(playTimeText),
                                  playedFrom: reviewPlayedFrom,
                                  playedUntil: reviewPlayedUntil,
                                  progressPercent: reviewProgressPercent > 0
                                      ? reviewProgressPercent
                                      : null,
                                  reviewDate: reviewDate,
                                  newImages: newImages,
                                  existingImages: existingImages,
                                  partnerIds: reviewPartnerIds,
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              modalContext,
                            ).colorScheme.secondary,
                            foregroundColor: Theme.of(
                              modalContext,
                            ).scaffoldBackgroundColor,
                          ),
                          child: isSaving
                              ? CircularProgressIndicator(
                                  color: Theme.of(
                                    modalContext,
                                  ).scaffoldBackgroundColor,
                                )
                              : Text(
                                  reviewStatus == 'wishlist' ||
                                          reviewStatus == 'playing'
                                      ? 'Guardar'
                                      : 'Guardar Reseña',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: getBottomSpacer(modalContext)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

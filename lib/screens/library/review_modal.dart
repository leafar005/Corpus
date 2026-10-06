import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:corpus/globals.dart';
import 'package:corpus/utils/format_utils.dart';
import 'package:corpus/routes/app_navigation_controller.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../repositories/review_repository.dart';
import '../../models/models.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/corpus_network_image.dart';
import 'review_modal_widgets.dart';

/// Callback invocado cuando el usuario pulsa "Guardar/Publicar Reseña".
/// Firma idéntica a [_GameDetailsScreenState._saveReview].
typedef OnSaveReview =
    Future<bool> Function({
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
///   initialComment: _commentController.text,
///   onSave: _saveReview,
/// );
/// ```
class ReviewModal {
  ReviewModal._();

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
    String initialComment = '',
    required OnSaveReview onSave,
    bool inLibrary = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width > kDesktopBreakpoint
            ? 880
            : 640,
      ),
      builder: (_) => _ReviewModalContent(
        gameData: gameData,
        enrichedData: enrichedData,
        existingReview: existingReview,
        currentPartnerIds: currentPartnerIds,
        isSaving: isSaving,
        currentRating: currentRating,
        currentRatingGameplay: currentRatingGameplay,
        currentRatingNarrative: currentRatingNarrative,
        currentRatingSoundtrack: currentRatingSoundtrack,
        currentRatingVisuals: currentRatingVisuals,
        currentStatus: currentStatus,
        initialComment: initialComment,
        onSave: onSave,
        inLibrary: inLibrary,
      ),
    );
  }
}

class _ReviewModalContent extends StatefulWidget {
  final Map<String, dynamic> gameData;
  final Map<String, dynamic> enrichedData;
  final Review? existingReview;
  final List<String>? currentPartnerIds;
  final bool isSaving;
  final double currentRating;
  final double currentRatingGameplay;
  final double currentRatingNarrative;
  final double currentRatingSoundtrack;
  final double currentRatingVisuals;
  final String currentStatus;
  final String initialComment;
  final OnSaveReview onSave;
  final bool inLibrary;

  const _ReviewModalContent({
    required this.gameData,
    required this.enrichedData,
    this.existingReview,
    this.currentPartnerIds,
    required this.isSaving,
    required this.currentRating,
    required this.currentRatingGameplay,
    required this.currentRatingNarrative,
    required this.currentRatingSoundtrack,
    required this.currentRatingVisuals,
    required this.currentStatus,
    this.initialComment = '',
    required this.onSave,
    this.inLibrary = false,
  });

  @override
  State<_ReviewModalContent> createState() => _ReviewModalContentState();
}

class _ReviewModalContentState extends State<_ReviewModalContent> {
  /// Delega en [ReviewRepository.fetchFriendsForCoopPicker] para obtener
  /// los amigos del usuario actual.
  Future<List<UserProfile>> _fetchFriends() =>
      ReviewRepository().fetchFriendsForCoopPicker();

  // ── Estado del formulario ─────────────────────────────────────────────
  late double reviewRating;
  late double reviewRatingGameplay;
  late double reviewRatingNarrative;
  late double reviewRatingSoundtrack;
  late double reviewRatingVisuals;
  late String reviewStatus;
  late String reviewCompletionType;
  late bool reviewIsReplay;
  late int reviewReplayNumber;
  String? reviewPlatform;
  late String playTimeText;
  DateTime? reviewPlayedFrom;
  DateTime? reviewPlayedUntil;
  late int reviewProgressPercent;
  DateTime? reviewDate;
  late final DateTime? initialReviewDate;
  late final String initialReviewStatus;

  late final TextEditingController reviewCommentController;
  late final TextEditingController partnerSearchController;
  late final ScrollController scrollController;
  late List<String> reviewPartnerIds;
  late final Future<List<UserProfile>> friendsFuture;
  late List<XFile> newImages;
  late List<String> existingImages;
  late final List<dynamic> platforms;
  late bool statusStepConfirmed;
  bool isLocalSaving = false;
  late final String? reviewId;

  @override
  void initState() {
    super.initState();
    final hasReview = widget.existingReview != null;
    final r = widget.existingReview;

    reviewRating = hasReview ? (r!.rating ?? 0) : widget.currentRating;
    reviewRatingGameplay = hasReview
        ? (r!.ratingGameplay ?? 0)
        : widget.currentRatingGameplay;
    reviewRatingNarrative = hasReview
        ? (r!.ratingNarrative ?? 0)
        : widget.currentRatingNarrative;
    reviewRatingSoundtrack = hasReview
        ? (r!.ratingSoundtrack ?? 0)
        : widget.currentRatingSoundtrack;
    reviewRatingVisuals = hasReview
        ? (r!.ratingVisuals ?? 0)
        : widget.currentRatingVisuals;
    reviewStatus = hasReview ? r!.status.dbValue : widget.currentStatus;
    reviewCompletionType = hasReview
        ? (r!.completionType ?? 'story')
        : 'story';
    reviewIsReplay = hasReview && r!.isReplay;
    reviewReplayNumber = (hasReview ? r!.replayNumber : null) ?? 1;
    reviewPlatform = hasReview ? r!.platform : null;
    playTimeText = hasReview && r!.playTimeHours != null
        ? r.playTimeHours.toString()
        : '';
    reviewPlayedFrom = hasReview ? r!.playedFrom : null;
    reviewPlayedUntil = hasReview ? r!.playedUntil : null;
    reviewProgressPercent = hasReview ? (r!.progressPercent ?? 0) : 0;
    reviewDate = hasReview ? r!.createdAt : null;
    initialReviewDate = reviewDate;
    initialReviewStatus = reviewStatus;

    reviewCommentController = TextEditingController(
      text: hasReview ? (r!.comment ?? '') : widget.initialComment,
    );
    reviewId = hasReview ? r!.id : null;
    partnerSearchController = TextEditingController();
    reviewPartnerIds = List<String>.from(widget.currentPartnerIds ?? []);
    friendsFuture = _fetchFriends();

    newImages = [];
    existingImages = hasReview
        ? List<String>.from(r!.imageUrls)
        : [];

    platforms =
        (widget.gameData['platforms'] as List?)?.isNotEmpty == true
        ? widget.gameData['platforms']
        : (widget.enrichedData['platforms'] as List? ?? []);

    statusStepConfirmed = hasReview || widget.inLibrary;
    scrollController = ScrollController();
  }

  @override
  void dispose() {
    reviewCommentController.dispose();
    partnerSearchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  /// Aplica un cambio de estado desde los chips de "Estado".
  bool isCollectionOnlyStatus(String s) =>
      s == GameStatus.wishlist.dbValue || s == GameStatus.toPlay.dbValue;

  void applyStatusChange(String v) {
    if (v == initialReviewStatus) {
      reviewDate = initialReviewDate;
    } else if (reviewStatus != v) {
      reviewDate = DateTime.now();
    }
    reviewStatus = v;
    reviewCompletionType = 'none';
  }

  @override
  Widget build(BuildContext context) {
    final hasReview = widget.existingReview != null;
    // Determina si el modal debe usar el layout de escritorio
    // (columnas) o el móvil (apilado), reevaluado en cada rebuild.
    final bool isDesktop =
        MediaQuery.of(context).size.width > kDesktopBreakpoint;
    // ── helpers locales ───────────────────────────────────────────
            Widget chip(
              String value,
              String label,
              CorpusIconKind icon,
              String current,
              Color color,
              Function(String) onSelect,
            ) {
              final sel = current == value;
              final tc = sel
                  ? (color == Theme.of(context).colorScheme.secondary
                        ? Theme.of(context).scaffoldBackgroundColor
                        : Colors.white)
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7);
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CorpusTablerIcon(icon,
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
                onSelected: (_) => setState(() => onSelect(value)),
                selectedColor: color,
                backgroundColor: Theme.of(context).colorScheme.surface,
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
              CorpusIconKind icon,
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
                    onTap: () => setState(() => onSelect(value)),
                    borderRadius: radius,
                    child: Ink(
                      decoration: BoxDecoration(
                        color: sel
                            ? color
                            : Theme.of(
                                context,
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
                            CorpusTablerIcon(icon, size: 22, color: labelColor),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: sel
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: labelColor,
                                ),
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
                            setState(() => reviewIsReplay = val),
                        activeThumbColor: Theme.of(
                          context,
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
                                  setState(() => reviewReplayNumber = n);
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
                                              ? const CorpusTablerIcon(
                                                  CorpusIconKind.Person,
                                                  size: 16,
                                                )
                                              : null,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onSelected: (selectedId) {
                                  if (selectedId != null) {
                                    setState(() {
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
                                          ? const CorpusTablerIcon(CorpusIconKind.Person, size: 16)
                                          : null,
                                    ),
                                    title: Text(friend.effectiveName),
                                    trailing: IconButton(
                                      icon: const CorpusTablerIcon(
                                        CorpusIconKind.RemoveCircleOutline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () {
                                        setState(() {
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
                        context,
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
                          setState(() => reviewPlatform = val),
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
                    onChanged: (val) => setState(() => playTimeText = val),
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
                          icon: const CorpusTablerIcon(CorpusIconKind.CalendarToday, size: 16),
                          label: Text(
                            reviewPlayedFrom != null
                                ? '${reviewPlayedFrom!.day} ${monthAbbr(reviewPlayedFrom!.month)} ${reviewPlayedFrom!.year}'
                                : 'Desde',
                            style: const TextStyle(fontSize: 13),
                          ),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: reviewPlayedFrom ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (d != null) {
                              setState(() => reviewPlayedFrom = d);
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
                          icon: const CorpusTablerIcon(CorpusIconKind.CalendarToday, size: 16),
                          label: Text(
                            reviewPlayedUntil != null
                                ? '${reviewPlayedUntil!.day} ${monthAbbr(reviewPlayedUntil!.month)} ${reviewPlayedUntil!.year}'
                                : 'Hasta',
                            style: const TextStyle(fontSize: 13),
                          ),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: reviewPlayedUntil ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (d != null) {
                              setState(() => reviewPlayedUntil = d);
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
                            context,
                          ).colorScheme.primary,
                          label: '$reviewProgressPercent%',
                          onChanged: (val) => setState(
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
                            color: Theme.of(context).colorScheme.primary,
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

            /// Los 4 botones de selección de estado (Paso 1). Se extraen a una
            /// función para poder mostrarlos apilados en móvil o en fila en
            /// escritorio sin duplicar la lógica de cada botón.
            List<Widget> buildStatusButtons() {
              return [
                statusButton(
                  'wishlist',
                  GameStatus.wishlist.shortLabel,
                  CorpusIconKind.Favorite,
                  '',
                  statusColor('wishlist'),
                  (v) {
                    applyStatusChange(v);
                    statusStepConfirmed = true;
                  },
                ),
                statusButton(
                  'to_play',
                  GameStatus.toPlay.shortLabel,
                  CorpusIconKind.Bookmark,
                  '',
                  statusColor('to_play'),
                  (v) {
                    applyStatusChange(v);
                    statusStepConfirmed = true;
                  },
                ),
                statusButton(
                  'playing',
                  GameStatus.playing.shortLabel,
                  CorpusIconKind.VideogameAsset,
                  '',
                  statusColor('playing'),
                  (v) {
                    applyStatusChange(v);
                    statusStepConfirmed = true;
                  },
                ),
                statusButton(
                  'beaten',
                  GameStatus.beaten.shortLabel,
                  CorpusIconKind.CheckCircle,
                  '',
                  statusColor('beaten'),
                  (v) {
                    applyStatusChange(v);
                    statusStepConfirmed = true;
                  },
                ),
                statusButton(
                  'abandoned',
                  GameStatus.abandoned.shortLabel,
                  CorpusIconKind.CancelOutlined,
                  '',
                  statusColor('abandoned'),
                  (v) {
                    applyStatusChange(v);
                    statusStepConfirmed = true;
                  },
                ),
              ];
            }

            /// "Tipo de completado" (terminado) / "Modo de juego" (jugando).
            /// Usado tanto en el layout móvil como en la columna izquierda
            /// del layout de escritorio.
            Widget buildTipoCompletadoSection() {
              if (reviewStatus == 'beaten') {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tipo de completado',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                          CorpusIconKind.DoNotDisturbAlt,
                          reviewCompletionType,
                          Theme.of(context).colorScheme.primary,
                          (v) => reviewCompletionType = v,
                        ),
                        chip(
                          'story',
                          'Historia',
                          CorpusIconKind.AutoStories,
                          reviewCompletionType,
                          Theme.of(context).colorScheme.primary,
                          (v) => reviewCompletionType = v,
                        ),
                        chip(
                          'story_extras',
                          'Historia + Extras',
                          CorpusIconKind.Extension,
                          reviewCompletionType,
                          Theme.of(context).colorScheme.primary,
                          (v) => reviewCompletionType = v,
                        ),
                        chip(
                          '100_percent',
                          'Platino',
                          CorpusIconKind.EmojiEvents,
                          reviewCompletionType,
                          Theme.of(context).colorScheme.primary,
                          (v) => reviewCompletionType = v,
                        ),
                      ],
                    ),
                  ],
                );
              } else if (reviewStatus == 'playing') {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modo de juego',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                          CorpusIconKind.DoNotDisturbAlt,
                          reviewCompletionType,
                          Theme.of(context).colorScheme.primary,
                          (v) => reviewCompletionType = v,
                        ),
                        chip(
                          'endless',
                          'Sin Fin',
                          CorpusIconKind.AllInclusive,
                          reviewCompletionType,
                          Theme.of(context).colorScheme.primary,
                          (v) => reviewCompletionType = v,
                        ),
                        chip(
                          'on_hold',
                          'En Pausa',
                          CorpusIconKind.Pause,
                          reviewCompletionType,
                          Theme.of(context).colorScheme.primary,
                          (v) => reviewCompletionType = v,
                        ),
                      ],
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            }

            /// Slider de "Nota" + desglose por categorías. Solo aplica a
            /// reseñas de juegos terminados o abandonados.
            Widget buildNotaSection() {
              if (reviewStatus != 'beaten' && reviewStatus != 'abandoned') {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nota',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                            context,
                          ).colorScheme.secondary,
                          label: reviewRating > 0
                              ? formatRating(reviewRating)
                              : '-',
                          onChanged: (val) =>
                              setState(() => reviewRating = val),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          reviewRating > 0 ? formatRating(reviewRating) : '-',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text(
                        'Desglosar nota',
                        style: TextStyle(fontSize: 14),
                      ),
                      children: [
                        ReviewSubRatingSlider(
                          label: 'Gameplay',
                          icon: CorpusIconKind.SportsEsports,
                          value: reviewRatingGameplay,
                          formatRating: formatRating,
                          onChanged: (val) =>
                              setState(() => reviewRatingGameplay = val),
                        ),
                        ReviewSubRatingSlider(
                          label: 'Narrativa',
                          icon: CorpusIconKind.AutoStories,
                          value: reviewRatingNarrative,
                          formatRating: formatRating,
                          onChanged: (val) =>
                              setState(() => reviewRatingNarrative = val),
                        ),
                        ReviewSubRatingSlider(
                          label: 'Banda Sonora',
                          icon: CorpusIconKind.MusicNote,
                          value: reviewRatingSoundtrack,
                          formatRating: formatRating,
                          onChanged: (val) =>
                              setState(() => reviewRatingSoundtrack = val),
                        ),
                        ReviewSubRatingSlider(
                          label: 'Gráficos',
                          icon: CorpusIconKind.Brush,
                          value: reviewRatingVisuals,
                          formatRating: formatRating,
                          onChanged: (val) =>
                              setState(() => reviewRatingVisuals = val),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            /// Campo de texto de la reseña + imágenes adjuntas. En escritorio
            /// se muestra en una columna propia, más alta, junto a la nota.
            Widget buildReseniaSection() {
              if (reviewStatus != 'beaten' && reviewStatus != 'abandoned') {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reseña',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reviewCommentController,
                    maxLines: isDesktop ? 12 : 4,
                    minLines: isDesktop ? 9 : 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: '¿Qué te pareció el juego?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (existingImages.isNotEmpty || newImages.isNotEmpty) ...[
                    SizedBox(
                      height: 90,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ...existingImages.map(
                            (url) => RemovableImageCard(
                              imageWidget: CorpusNetworkImage(
                                url: url,
                                fit: BoxFit.cover,
                                width: 80,
                                height: 80,
                              ),
                              onRemove: () => setState(
                                () => existingImages.remove(url),
                              ),
                            ),
                          ),
                          ...newImages.map(
                            (file) => RemovableImageCard(
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
                              onRemove: () =>
                                  setState(() => newImages.remove(file)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (existingImages.length + newImages.length < 4)
                    OutlinedButton.icon(
                      icon: const CorpusTablerIcon(CorpusIconKind.AddPhotoAlternate, size: 18),
                      label: const Text('Adjuntar imagen (máx 4)'),
                      onPressed: () async {
                        final picker = ImagePicker();
                        final pickedFiles = await picker.pickMultiImage(
                          imageQuality: 70,
                          maxWidth: 1080,
                        );
                        if (pickedFiles.isNotEmpty) {
                          setState(() {
                            final remaining =
                                4 - existingImages.length - newImages.length;
                            newImages.addAll(pickedFiles.take(remaining));
                          });
                        }
                      },
                    ),
                ],
              );
            }

            /// Sección "Información Extra" (plataforma, tiempo jugado,
            /// fechas, progreso, rejugada, compañero de cooperativo).
            Widget buildInfoExtraSection() {
              if (isCollectionOnlyStatus(reviewStatus)) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (reviewStatus == 'playing') ...[
                    Text(
                      'Información Extra',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
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
              );
            }

            // Más aire lateral en escritorio, ahora que el modal es más
            // ancho — evita que el contenido quede pegado a los bordes.
            final double horizontalPadding = isDesktop ? 40.0 : 24.0;

            // ── cuerpo del modal ──────────────────────────────────────────
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: isDesktop ? 32 : 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header: título + (si edición) botón de fecha ──
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            hasReview ? 'Editar Reseña' : 'Añadir Reseña',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          icon: const CorpusTablerIcon(CorpusIconKind.EditCalendar, size: 16),
                          label: Text(() {
                            final displayDate = reviewDate ?? initialReviewDate;
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
                              context: context,
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
                              setState(() => reviewDate = d);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Flexible(
                    child: PrimaryScrollController(
                      controller: scrollController,
                      child: Scrollbar(
                        controller: scrollController,
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                  // Hay 5 botones de estado; en escritorio
                                  // usamos Wrap para que ajusten si no caben
                                  // en una sola fila. En móvil, apilados.
                                  if (isDesktop)
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 8,
                                      children: buildStatusButtons(),
                                    )
                                  else
                                    Column(
                                      children: [
                                        for (final entry
                                            in buildStatusButtons()
                                                .asMap()
                                                .entries) ...[
                                          if (entry.key > 0)
                                            const SizedBox(height: 8),
                                          entry.value,
                                        ],
                                        // Espacio extra para que el último botón
                                        // no quede tapado por la barra de navegación
                                        const SizedBox(height: 64),
                                      ],
                                    ),
                                ] else ...[
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const CorpusTablerIcon(CorpusIconKind.ArrowBack),
                                        tooltip: 'Cambiar estado',
                                        onPressed: () => setState(
                                          () => statusStepConfirmed = false,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 36,
                                          minHeight: 36,
                                        ),
                                      ),
                                      CorpusTablerIcon(
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
                                  if (!isDesktop) ...[
                                    // ── Layout móvil (sin cambios) ──────────────────────
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
                                            CorpusIconKind.DoNotDisturbAlt,
                                            reviewCompletionType,
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            (v) => reviewCompletionType = v,
                                          ),
                                          chip(
                                            'story',
                                            'Historia',
                                            CorpusIconKind.AutoStories,
                                            reviewCompletionType,
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            (v) => reviewCompletionType = v,
                                          ),
                                          chip(
                                            'story_extras',
                                            'Historia + Extras',
                                            CorpusIconKind.Extension,
                                            reviewCompletionType,
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            (v) => reviewCompletionType = v,
                                          ),
                                          chip(
                                            '100_percent',
                                            'Platino',
                                            CorpusIconKind.EmojiEvents,
                                            reviewCompletionType,
                                            Theme.of(
                                              context,
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
                                            CorpusIconKind.DoNotDisturbAlt,
                                            reviewCompletionType,
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            (v) => reviewCompletionType = v,
                                          ),
                                          chip(
                                            'endless',
                                            'Sin Fin',
                                            CorpusIconKind.AllInclusive,
                                            reviewCompletionType,
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            (v) => reviewCompletionType = v,
                                          ),
                                          chip(
                                            'on_hold',
                                            'En Pausa',
                                            CorpusIconKind.Pause,
                                            reviewCompletionType,
                                            Theme.of(
                                              context,
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
                                                context,
                                              ).colorScheme.secondary,
                                              label: reviewRating > 0
                                                  ? formatRating(reviewRating)
                                                  : '-',
                                              onChanged: (val) => setState(
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
                                                  context,
                                                ).colorScheme.secondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      Theme(
                                        data: Theme.of(context).copyWith(
                                          dividerColor: Colors.transparent,
                                        ),
                                        child: ExpansionTile(
                                          tilePadding: EdgeInsets.zero,
                                          title: const Text(
                                            'Desglosar nota',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          children: [
                                            ReviewSubRatingSlider(
                                              label: 'Gameplay',
                                              icon: CorpusIconKind.SportsEsports,
                                              value: reviewRatingGameplay,
                                              formatRating: formatRating,
                                              onChanged: (val) => setState(
                                                () =>
                                                    reviewRatingGameplay = val,
                                              ),
                                            ),
                                            ReviewSubRatingSlider(
                                              label: 'Narrativa',
                                              icon: CorpusIconKind.AutoStories,
                                              value: reviewRatingNarrative,
                                              formatRating: formatRating,
                                              onChanged: (val) => setState(
                                                () =>
                                                    reviewRatingNarrative = val,
                                              ),
                                            ),
                                            ReviewSubRatingSlider(
                                              label: 'Banda Sonora',
                                              icon: CorpusIconKind.MusicNote,
                                              value: reviewRatingSoundtrack,
                                              formatRating: formatRating,
                                              onChanged: (val) => setState(
                                                () => reviewRatingSoundtrack =
                                                    val,
                                              ),
                                            ),
                                            ReviewSubRatingSlider(
                                              label: 'Gráficos',
                                              icon: CorpusIconKind.Brush,
                                              value: reviewRatingVisuals,
                                              formatRating: formatRating,
                                              onChanged: (val) => setState(
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
                                        GridView.count(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          crossAxisCount: 2,
                                          mainAxisSpacing: 0,
                                          crossAxisSpacing: 0,
                                          childAspectRatio: 16 / 9,
                                          children: [
                                            ...existingImages.map(
                                              (url) => RemovableImageCard(
                                                imageWidget: CorpusNetworkImage(
                                                  url: url,
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                ),
                                                onRemove: () => setState(
                                                  () => existingImages.remove(url),
                                                ),
                                              ),
                                            ),
                                            ...newImages.map(
                                              (file) => RemovableImageCard(
                                                imageWidget: kIsWeb
                                                    ? CorpusNetworkImage(
                                                        url: file.path,
                                                        fit: BoxFit.cover,
                                                        width: double.infinity,
                                                        height: double.infinity,
                                                      )
                                                    : Image.file(
                                                        File(file.path),
                                                        fit: BoxFit.cover,
                                                        width: double.infinity,
                                                        height: double.infinity,
                                                      ),
                                                onRemove: () => setState(
                                                  () => newImages.remove(file),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      if (existingImages.length +
                                              newImages.length <
                                          4)
                                        OutlinedButton.icon(
                                          icon: const CorpusTablerIcon(
                                            CorpusIconKind.AddPhotoAlternate,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'Adjuntar imagen (máx 4)',
                                          ),
                                          onPressed: () async {
                                            final picker = ImagePicker();
                                            final pickedFiles = await picker
                                                .pickMultiImage(
                                                  imageQuality: 70,
                                                  maxWidth: 1080,
                                                );
                                            if (pickedFiles.isNotEmpty) {
                                              setState(() {
                                                final remaining =
                                                    4 -
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
                                    if (!isCollectionOnlyStatus(reviewStatus)) ...[
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
                                        data: Theme.of(context).copyWith(
                                          dividerColor: Colors.transparent,
                                        ),
                                        child: reviewStatus == 'playing'
                                            ? buildExtraInfoFields()
                                            : ExpansionTile(
                                                tilePadding: EdgeInsets.zero,
                                                title: const Text(
                                                  'Información Extra',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                children: [
                                                  buildExtraInfoFields(),
                                                ],
                                              ),
                                      ),
                                    ], // Cierra if (reviewStatus != 'wishlist')
                                  ] else ...[
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 320,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              buildTipoCompletadoSection(),
                                              const SizedBox(height: 16),
                                              buildNotaSection(),
                                              if (reviewStatus !=
                                                  'playing') ...[
                                                const SizedBox(height: 16),
                                                buildInfoExtraSection(),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 32),
                                        Expanded(
                                          child: reviewStatus == 'playing'
                                              ? buildInfoExtraSection()
                                              : buildReseniaSection(),
                                        ),
                                      ],
                                    ),
                                  ], // Cierra else
                                ], // Cierra if (statusStepConfirmed)
                              ], // Cierra children
                            ), // Cierra Column
                          ), // Cierra Padding
                        ), // Cierra SingleChildScrollView
                      ), // Cierra Scrollbar
                    ), // Cierra PrimaryScrollController
                  ), // Cierra Flexible
                  if (statusStepConfirmed) ...[
                    // ── Botón guardar ─────────────────────────────────────
                    const SizedBox(height: 24),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLocalSaving
                              ? null
                              : () async {
                                  setState(() => isLocalSaving = true);
                                  final success = await widget.onSave(
                                    reviewId: reviewId,
                                    rating: reviewRating,
                                    ratingGameplay: reviewRatingGameplay,
                                    ratingNarrative: reviewRatingNarrative,
                                    ratingSoundtrack: reviewRatingSoundtrack,
                                    ratingVisuals: reviewRatingVisuals,
                                    comment: reviewCommentController.text,
                                    status: reviewStatus,
                                    completionType: isCollectionOnlyStatus(reviewStatus)
                                        ? 'none'
                                        : reviewCompletionType,
                                    isReplay:
                                        !isCollectionOnlyStatus(reviewStatus) &&
                                        reviewIsReplay,
                                    replayNumber: reviewIsReplay
                                        ? reviewReplayNumber
                                        : null,
                                    platform: reviewPlatform,
                                    playTimeHours: double.tryParse(
                                      playTimeText,
                                    ),
                                    playedFrom: reviewPlayedFrom,
                                    playedUntil: reviewPlayedUntil,
                                    progressPercent: reviewProgressPercent > 0
                                        ? reviewProgressPercent
                                        : null,
                                    reviewDate: reviewDate,
                                    newImages: newImages,
                                    existingImages: existingImages,
                                    partnerIds: reviewPartnerIds,
                                  );
                                  if (context.mounted) {
                                    if (success) {
                                      final route = ModalRoute.of(context);
                                      if (route != null && route.isCurrent) {
                                        Navigator.of(context).pop();
                                        AppNavigationController.instance
                                            .syncBrowserHistoryAfterProgrammaticPop();
                                      }
                                    } else {
                                      setState(
                                        () => isLocalSaving = false,
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.secondary,
                            foregroundColor: Theme.of(
                              context,
                            ).scaffoldBackgroundColor,
                          ),
                          child: isLocalSaving
                              ? CircularProgressIndicator(
                                  color: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                )
                              : Text(
                                  isCollectionOnlyStatus(reviewStatus) ||
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
                  const SizedBox(height: 16),
                ],
              ),
            );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:image_picker/image_picker.dart';

/// Callback invocado cuando el usuario pulsa "Guardar/Publicar Reseña".
/// Firma idéntica a [_GameDetailsScreenState._saveReview].
typedef OnSaveReview = Future<void> Function({
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
  required List<XFile> newImages,
  required List<String> existingImages,
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

  static void show({
    required BuildContext context,
    required Map<String, dynamic> gameData,
    required Map<String, dynamic> enrichedData,
    Map<String, dynamic>? existingReview,
    required bool isSaving,
    required double currentRating,
    required double currentRatingGameplay,
    required double currentRatingNarrative,
    required double currentRatingSoundtrack,
    required double currentRatingVisuals,
    required String currentStatus,
    required TextEditingController commentController,
    required OnSaveReview onSave,
  }) {
    final hasReview = existingReview != null;
    final r = existingReview;

    // Inicializar estado del formulario desde la reseña existente o el estado actual
    double reviewRating = hasReview ? (r!['rating'] ?? 0).toDouble() : currentRating;
    double reviewRatingGameplay = hasReview ? (r!['rating_gameplay'] ?? 0).toDouble() : currentRatingGameplay;
    double reviewRatingNarrative = hasReview ? (r!['rating_narrative'] ?? 0).toDouble() : currentRatingNarrative;
    double reviewRatingSoundtrack = hasReview ? (r!['rating_soundtrack'] ?? 0).toDouble() : currentRatingSoundtrack;
    double reviewRatingVisuals = hasReview ? (r!['rating_visuals'] ?? 0).toDouble() : currentRatingVisuals;
    String reviewStatus = hasReview ? (r!['status'] ?? currentStatus) : currentStatus;
    String reviewCompletionType = hasReview ? (r!['completion_type'] ?? 'story') : 'story';
    bool reviewIsReplay = hasReview ? (r!['is_replay'] ?? false) : false;
    int reviewReplayNumber = hasReview ? (r!['replay_number'] ?? 1) : 1;
    String? reviewPlatform = hasReview ? r!['platform'] : null;
    String playTimeText = hasReview && r!['play_time_hours'] != null ? r['play_time_hours'].toString() : '';
    DateTime? reviewPlayedFrom = hasReview && r!['played_from'] != null ? DateTime.parse(r['played_from']) : null;
    DateTime? reviewPlayedUntil = hasReview && r!['played_until'] != null ? DateTime.parse(r['played_until']) : null;
    int reviewProgressPercent = hasReview ? (r!['progress_percent'] ?? 0) : 0;

    // El controller de comentario vive dentro del modal (con texto inicial)
    final reviewCommentController = TextEditingController(
      text: hasReview ? (r!['comment'] ?? '') : commentController.text,
    );
    final String? reviewId = hasReview ? r!['id'] : null;

    List<XFile> newImages = [];
    List<String> existingImages = hasReview ? List<String>.from(r!['image_urls'] ?? []) : [];

    final List<dynamic> platforms = (gameData['platforms'] as List?)?.isNotEmpty == true
        ? gameData['platforms']
        : (enrichedData['platforms'] as List? ?? []);

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
            Widget chip(String value, String label, IconData icon, String current,
                Color color, Function(String) onSelect) {
              final sel = current == value;
              final tc = sel
                  ? (color == Theme.of(modalContext).colorScheme.secondary
                      ? Theme.of(modalContext).scaffoldBackgroundColor
                      : Colors.white)
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
              return ChoiceChip(
                label: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 18, color: sel ? tc : Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(label),
                ]),
                selected: sel,
                onSelected: (_) => setModalState(() => onSelect(value)),
                selectedColor: color,
                backgroundColor: Theme.of(modalContext).colorScheme.surfaceContainerHighest,
                labelStyle: TextStyle(color: tc, fontWeight: sel ? FontWeight.bold : FontWeight.normal),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                side: BorderSide(color: sel ? color : Theme.of(context).colorScheme.onSurfaceVariant),
                showCheckmark: false,
              );
            }

            Widget buildRemovableImage({required Widget imageWidget, required VoidCallback onRemove}) {
              return Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 8, top: 8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                    clipBehavior: Clip.hardEdge,
                    child: imageWidget,
                  ),
                  Positioned(
                    top: 0, right: 0,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }

            Widget buildSubRatingSlider(String label, IconData icon, double value, Function(double) onChange) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const Spacer(),
                    Text(value > 0 ? value.toStringAsFixed(1) : '-',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.primary)),
                  ]),
                  Slider(
                    value: value, min: 0, max: 10, divisions: 100,
                    activeColor: Theme.of(context).colorScheme.primary,
                    label: value > 0 ? value.toStringAsFixed(1) : '-',
                    onChanged: onChange,
                  ),
                ],
              );
            }

            Color statusColor(String s) {
              switch (s) {
                case 'beaten': return Theme.of(context).colorScheme.secondary;
                case 'playing': return Colors.blueAccent;
                case 'wishlist': return Theme.of(context).colorScheme.primary;
                default: return Theme.of(context).colorScheme.onSurfaceVariant;
              }
            }

            String monthAbbr(int m) {
              const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
              return months[m - 1];
            }

            // ── cuerpo del modal ──────────────────────────────────────────
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
                top: 24, left: 24, right: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasReview ? 'Editar Reseña' : 'Añadir Reseña',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),

                    // ── Estado ──────────────────────────────────────────
                    Text('Estado', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      chip('wishlist', 'Quiero', Icons.favorite, reviewStatus, statusColor('wishlist'),
                          (v) { reviewStatus = v; reviewCompletionType = 'none'; }),
                      chip('playing', 'Jugando', Icons.videogame_asset, reviewStatus, statusColor('playing'),
                          (v) { reviewStatus = v; reviewCompletionType = 'none'; }),
                      chip('beaten', 'Terminado', Icons.emoji_events, reviewStatus, statusColor('beaten'),
                          (v) { reviewStatus = v; reviewCompletionType = 'none'; }),
                      chip('abandoned', 'Abandonado', Icons.cancel_outlined, reviewStatus, statusColor('abandoned'),
                          (v) { reviewStatus = v; reviewCompletionType = 'none'; }),
                    ]),
                    const SizedBox(height: 24),

                    // ── Tipo de completado / Modo de juego ──────────────
                    if (reviewStatus == 'beaten') ...[
                      Text('Tipo de completado', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        chip('none', 'Nada', Icons.do_not_disturb_alt, reviewCompletionType, Theme.of(modalContext).colorScheme.primary, (v) => reviewCompletionType = v),
                        chip('story', 'Historia', Icons.auto_stories, reviewCompletionType, Theme.of(modalContext).colorScheme.primary, (v) => reviewCompletionType = v),
                        chip('story_extras', 'Historia + Extras', Icons.extension, reviewCompletionType, Theme.of(modalContext).colorScheme.primary, (v) => reviewCompletionType = v),
                        chip('100_percent', '100%', Icons.stars, reviewCompletionType, Theme.of(modalContext).colorScheme.primary, (v) => reviewCompletionType = v),
                      ]),
                      const SizedBox(height: 24),
                    ] else if (reviewStatus == 'playing') ...[
                      Text('Modo de juego', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        chip('none', 'Nada', Icons.do_not_disturb_alt, reviewCompletionType, Theme.of(modalContext).colorScheme.primary, (v) => reviewCompletionType = v),
                        chip('endless', 'Sin Fin', Icons.all_inclusive, reviewCompletionType, Theme.of(modalContext).colorScheme.primary, (v) => reviewCompletionType = v),
                        chip('on_hold', 'En Pausa', Icons.pause, reviewCompletionType, Theme.of(modalContext).colorScheme.primary, (v) => reviewCompletionType = v),
                      ]),
                      const SizedBox(height: 24),
                    ],

                    // ── Nota y sub-ratings ──────────────────────────────
                    if (reviewStatus != 'wishlist') ...[
                      Row(children: [
                        Text('Nota', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        const Spacer(),
                        Text(
                          reviewRating > 0 ? reviewRating.toStringAsFixed(1) : '-',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18,
                              color: Theme.of(modalContext).colorScheme.secondary),
                        ),
                      ]),
                      Slider(
                        value: reviewRating, min: 0, max: 10, divisions: 100,
                        activeColor: Theme.of(modalContext).colorScheme.secondary,
                        label: reviewRating > 0 ? reviewRating.toStringAsFixed(1) : '-',
                        onChanged: (val) => setModalState(() => reviewRating = val),
                      ),

                      Theme(
                        data: Theme.of(modalContext).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Desglosar nota', style: TextStyle(fontSize: 14)),
                          children: [
                            buildSubRatingSlider('Gameplay', Icons.sports_esports, reviewRatingGameplay,
                                (val) => setModalState(() => reviewRatingGameplay = val)),
                            buildSubRatingSlider('Narrativa', Icons.auto_stories, reviewRatingNarrative,
                                (val) => setModalState(() => reviewRatingNarrative = val)),
                            buildSubRatingSlider('Banda Sonora', Icons.music_note, reviewRatingSoundtrack,
                                (val) => setModalState(() => reviewRatingSoundtrack = val)),
                            buildSubRatingSlider('Gráficos', Icons.brush, reviewRatingVisuals,
                                (val) => setModalState(() => reviewRatingVisuals = val)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Rejugada ──────────────────────────────────────
                      Row(children: [
                        Text('Rejugada', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        const Spacer(),
                        Switch(
                          value: reviewIsReplay,
                          onChanged: (val) => setModalState(() => reviewIsReplay = val),
                          activeThumbColor: Theme.of(modalContext).colorScheme.primary,
                        ),
                      ]),
                      if (reviewIsReplay)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            Text('Nº de rejugada',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 60,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(vertical: 8)),
                                controller: TextEditingController(text: reviewReplayNumber.toString()),
                                onChanged: (val) {
                                  final n = int.tryParse(val);
                                  if (n != null) setModalState(() => reviewReplayNumber = n);
                                },
                              ),
                            ),
                          ]),
                        ),

                      const SizedBox(height: 16),

                      // ── Reseña (comentario) ───────────────────────────
                      Text('Reseña', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: reviewCommentController,
                        maxLines: 4, minLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                            hintText: '¿Qué te pareció el juego?', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),

                      // ── Imágenes adjuntas ─────────────────────────────
                      if (existingImages.isNotEmpty || newImages.isNotEmpty) ...[
                        SizedBox(
                          height: 90,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ...existingImages.map((url) => buildRemovableImage(
                                    imageWidget: Image.network(url, fit: BoxFit.cover, width: 80, height: 80),
                                    onRemove: () => setModalState(() => existingImages.remove(url)),
                                  )),
                              ...newImages.map((file) => buildRemovableImage(
                                    imageWidget: kIsWeb
                                        ? Image.network(file.path, fit: BoxFit.cover, width: 80, height: 80)
                                        : Image.file(File(file.path), fit: BoxFit.cover, width: 80, height: 80),
                                    onRemove: () => setModalState(() => newImages.remove(file)),
                                  )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (existingImages.length + newImages.length < 3)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add_photo_alternate, size: 18),
                          label: const Text('Adjuntar imagen (máx 3)'),
                          onPressed: () async {
                            final picker = ImagePicker();
                            final pickedFiles = await picker.pickMultiImage(imageQuality: 70, maxWidth: 1080);
                            if (pickedFiles.isNotEmpty) {
                              setModalState(() {
                                final remaining = 3 - existingImages.length - newImages.length;
                                newImages.addAll(pickedFiles.take(remaining));
                              });
                            }
                          },
                        ),
                      const SizedBox(height: 12),

                      // ── Información extra (plataforma, tiempo, fechas) ─
                      Theme(
                        data: Theme.of(modalContext).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Información Extra', style: TextStyle(fontSize: 14)),
                          children: [
                            if (platforms.isNotEmpty) ...[
                              Text('Plataforma',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: reviewPlatform,
                                decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                dropdownColor: Theme.of(modalContext).colorScheme.surfaceContainerHighest,
                                items: platforms
                                    .map((p) => DropdownMenuItem(
                                        value: p.toString(), child: Text(p.toString(), style: const TextStyle(fontSize: 14))))
                                    .toList(),
                                onChanged: (val) => setModalState(() => reviewPlatform = val),
                                hint: const Text('Seleccionar plataforma'),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Text('Tiempo de juego (horas)',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                            const SizedBox(height: 8),
                            TextField(
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Ej: 45.5',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                              onChanged: (val) => setModalState(() => playTimeText = val),
                            ),
                            const SizedBox(height: 16),
                            Text('Fecha de juego',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                            const SizedBox(height: 8),
                            Row(children: [
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
                                        lastDate: DateTime.now().add(const Duration(days: 365)));
                                    if (d != null) setModalState(() => reviewPlayedFrom = d);
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text('-', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                                        lastDate: DateTime.now().add(const Duration(days: 365)));
                                    if (d != null) setModalState(() => reviewPlayedUntil = d);
                                  },
                                ),
                              ),
                            ]),
                            const SizedBox(height: 16),
                            Row(children: [
                              Text('Progreso',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                              const Spacer(),
                              Text('$reviewProgressPercent%',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Theme.of(modalContext).colorScheme.primary)),
                            ]),
                            Slider(
                              value: reviewProgressPercent.toDouble(), min: 0, max: 100, divisions: 100,
                              activeColor: Theme.of(modalContext).colorScheme.primary,
                              label: '$reviewProgressPercent%',
                              onChanged: (val) => setModalState(() => reviewProgressPercent = val.round()),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Botón guardar ─────────────────────────────────────
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity, height: 50,
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
                                  completionType: reviewStatus == 'wishlist' ? 'none' : reviewCompletionType,
                                  isReplay: reviewStatus == 'wishlist' ? false : reviewIsReplay,
                                  replayNumber: reviewIsReplay ? reviewReplayNumber : null,
                                  platform: reviewPlatform,
                                  playTimeHours: double.tryParse(playTimeText),
                                  playedFrom: reviewPlayedFrom,
                                  playedUntil: reviewPlayedUntil,
                                  progressPercent: reviewProgressPercent > 0 ? reviewProgressPercent : null,
                                  newImages: newImages,
                                  existingImages: existingImages,
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(modalContext).colorScheme.secondary,
                          foregroundColor: Theme.of(modalContext).scaffoldBackgroundColor,
                        ),
                        child: isSaving
                            ? CircularProgressIndicator(color: Theme.of(modalContext).scaffoldBackgroundColor)
                            : Text(
                                reviewStatus == 'wishlist' ? 'Guardar' : 'Guardar Reseña',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

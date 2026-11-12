import 'dart:io';

import 'package:corpus/models/models.dart';
import 'package:corpus/routes/corpus_router.dart';
import 'package:corpus/services/igdb_service.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/corpus_network_image.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Barra inferior reutilizable para redactar comentarios, responder en hilo,
/// adjuntar una imagen o citar un juego (con chips rápidos opcionales para
/// publicaciones agrupadas).
class CommentComposer extends StatelessWidget {
  const CommentComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.onSubmit,
    this.replyToCommentId,
    this.replyToUsername,
    this.onClearReply,
    this.selectedImage,
    required this.onImageChanged,
    this.selectedGame,
    required this.onGameChanged,
    this.suggestedGames = const [],
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final String? replyToCommentId;
  final String? replyToUsername;
  final VoidCallback? onClearReply;
  final XFile? selectedImage;
  final ValueChanged<XFile?> onImageChanged;
  final Map<String, dynamic>? selectedGame;
  final ValueChanged<Map<String, dynamic>?> onGameChanged;
  final List<Map<String, dynamic>> suggestedGames;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file != null) {
      onImageChanged(file);
    }
  }

  Map<String, dynamic>? _normalizePickedGame(Object? picked) {
    if (picked is Game) return picked.toMap();
    if (picked is Map<String, dynamic>) return picked;
    if (picked is Map) return Map<String, dynamic>.from(picked);
    return null;
  }

  Future<void> _pickGame(BuildContext context) async {
    if (suggestedGames.isEmpty) {
      final game = await context.pushSearch(isSelectionMode: true);
      final normalized = _normalizePickedGame(game);
      if (normalized != null) {
        onGameChanged(normalized);
      }
      return;
    }

    final choice = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Citar un juego',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ...suggestedGames.map(
                    (game) => ListTile(
                      leading: const CorpusTablerIcon(
                        CorpusIconKind.VideogameAsset,
                      ),
                      title: Text(game['name']?.toString() ?? 'Juego'),
                      onTap: () => Navigator.pop(sheetContext, game),
                    ),
                  ),
                  ListTile(
                    leading: const CorpusTablerIcon(CorpusIconKind.Search),
                    title: const Text('Buscar otro juego...'),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      const <String, dynamic>{'_open_search': true},
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice['_open_search'] == true) {
      final searched = await context.pushSearch(isSelectionMode: true);
      final normalized = _normalizePickedGame(searched);
      if (normalized != null) {
        onGameChanged(normalized);
      }
      return;
    }
    onGameChanged(choice);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyToCommentId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Respondiendo a @${replyToUsername ?? ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const CorpusTablerIcon(
                      CorpusIconKind.Close,
                      size: 18,
                    ),
                    onPressed: onClearReply,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          if (selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: theme
                          .extension<CorpusThemeExtension>()!
                          .radiusSmall,
                      child: kIsWeb
                          ? CorpusNetworkImage(
                              url: selectedImage!.path,
                              height: 80,
                              width: 80,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(selectedImage!.path),
                              height: 80,
                              width: 80,
                              fit: BoxFit.cover,
                            ),
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: GestureDetector(
                        onTap: () => onImageChanged(null),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const CorpusTablerIcon(
                            CorpusIconKind.Close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (selectedGame != null)
            _SelectedGameChipPreview(
              gameData: selectedGame!,
              onRemove: () => onGameChanged(null),
            ),
          Row(
            children: [
              IconButton(
                onPressed: isSubmitting ? null : _pickImage,
                icon: CorpusTablerIcon(
                  CorpusIconKind.AddPhotoAlternate,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                tooltip: 'Adjuntar imagen',
              ),
              IconButton(
                onPressed: isSubmitting ? null : () => _pickGame(context),
                icon: CorpusTablerIcon(
                  CorpusIconKind.VideogameAsset,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                tooltip: 'Citar juego',
              ),
              Expanded(
                child: Focus(
                  onKeyEvent: (_, event) {
                    if (isDesktop &&
                        event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter &&
                        !HardwareKeyboard.instance.isShiftPressed) {
                      onSubmit();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Escribe un comentario...',
                      counterText: '',
                      isDense: true,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: isSubmitting ? null : onSubmit,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : CorpusTablerIcon(
                        CorpusIconKind.Send,
                        color: theme.colorScheme.primary,
                      ),
                tooltip: 'Enviar',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectedGameChipPreview extends StatelessWidget {
  const _SelectedGameChipPreview({
    required this.gameData,
    required this.onRemove,
  });

  final Map<String, dynamic> gameData;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverUrl =
        gameData['cover_url'] as String? ??
        (gameData['cover']?['image_id'] != null
            ? IGDBService.getCoverUrl(gameData['cover']['image_id'])
            : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 80,
              height: 110,
              decoration: BoxDecoration(
                borderRadius: theme
                    .extension<CorpusThemeExtension>()!
                    .radiusSmall,
                color: theme.colorScheme.surfaceContainerHighest,
                image: coverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(coverUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: coverUrl == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          gameData['name']?.toString() ?? '',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    )
                  : null,
            ),
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const CorpusTablerIcon(
                    CorpusIconKind.Close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

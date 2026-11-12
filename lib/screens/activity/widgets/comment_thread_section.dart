import 'package:corpus/models/models.dart';
import 'package:corpus/routes/corpus_router.dart';
import 'package:corpus/services/igdb_service.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:corpus/utils/comment_thread_utils.dart';
import 'package:corpus/utils/format_utils.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/corpus_network_image.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/full_screen_gallery.dart';
import 'package:corpus/widgets/mention_text.dart';
import 'package:flutter/material.dart';

/// Sección reutilizable que renderiza la lista anidada de comentarios de un
/// post (reseña individual o publicación agrupada), con respuestas, imágenes,
/// juegos adjuntos y acciones de responder/eliminar.
class CommentThreadSection extends StatelessWidget {
  const CommentThreadSection({
    super.key,
    required this.comments,
    required this.currentUserId,
    required this.onReply,
    required this.onDeleteComment,
    this.authorId,
    this.emptyState,
  });

  final List<Map<String, dynamic>> comments;
  final String? currentUserId;
  final String? authorId;
  final ValueChanged<Map<String, dynamic>> onReply;
  final Future<void> Function(String commentId, String? imageUrl)
  onDeleteComment;
  final Widget? emptyState;

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return emptyState ?? const SizedBox.shrink();
    }

    final ordered = orderCommentsThreaded(comments);
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comentarios',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ordered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _CommentCard(
            comment: ordered[index],
            currentUserId: currentUserId,
            authorId: authorId,
            isDesktop: isDesktop,
            onReply: onReply,
            onDeleteComment: onDeleteComment,
          ),
        ),
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.comment,
    required this.currentUserId,
    required this.authorId,
    required this.isDesktop,
    required this.onReply,
    required this.onDeleteComment,
  });

  final Map<String, dynamic> comment;
  final String? currentUserId;
  final String? authorId;
  final bool isDesktop;
  final ValueChanged<Map<String, dynamic>> onReply;
  final Future<void> Function(String commentId, String? imageUrl)
  onDeleteComment;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar comentario'),
        content: const Text(
          '¿Seguro que quieres eliminar este comentario? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await onDeleteComment(
        comment['id'] as String,
        comment['image_url'] as String?,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = comment['users'] as Map<String, dynamic>?;
    final commentUserId = comment['user_id'] as String?;
    final isMine = currentUserId != null && commentUserId == currentUserId;
    final isAuthor = authorId != null && commentUserId == authorId;
    final depth = (comment['_thread_depth'] as int?) ?? 0;
    final visualDepth = depth > 1 ? 1 : depth;
    final isReply = visualDepth > 0;
    final leftIndent = isReply ? (isDesktop ? 48.0 : 36.0) : 0.0;
    final replyToUsername = comment['_reply_to_username'] as String?;
    final content = comment['content'] as String?;
    final imageUrl = comment['image_url'] as String?;
    final attachedGame = comment['attached_game'] as Map<String, dynamic>?;
    final avatarUrl = user?['avatar_url'] as String?;
    final username = user?['username']?.toString() ?? 'Usuario';
    final displayName =
        (user?['display_name']?.toString().trim().isNotEmpty ?? false)
        ? user!['display_name'].toString().trim()
        : username;

    final cardContent = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: theme.extension<CorpusThemeExtension>()!.radiusMedium,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: commentUserId == null
                      ? null
                      : () => context.pushProfile(userId: commentUserId),
                  child: CircleAvatar(
                    radius: isReply ? 15 : 18,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: (avatarUrl == null || avatarUrl.isEmpty)
                        ? Text(
                            displayName[0].toUpperCase(),
                            style: theme.textTheme.labelMedium,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Padding a la derecha para no solapar con los iconos fijados arriba.
                      Padding(
                        padding: EdgeInsets.only(right: isMine ? 64.0 : 36.0),
                        child: Row(
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: commentUserId == null
                                    ? null
                                    : () => context.pushProfile(
                                        userId: commentUserId,
                                      ),
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            if (isAuthor) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Autor',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Text(
                              formatDateRelative(
                                comment['created_at'] as String?,
                              ),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isReply && replyToUsername != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'En respuesta a @$replyToUsername',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                      if (content != null && content.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        MentionText(text: content),
                      ],
                      if (imageUrl != null && imageUrl.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () =>
                              showFullScreenGallery(context, [imageUrl], 0),
                          child: ClipRRect(
                            borderRadius: theme
                                .extension<CorpusThemeExtension>()!
                                .radiusSmall,
                            child: CorpusNetworkImage(
                              url: imageUrl,
                              height: isDesktop ? 260 : 150,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                      if (attachedGame != null) ...[
                        const SizedBox(height: 10),
                        _AttachedGamePreview(
                          gameData: attachedGame,
                          isDesktop: isDesktop,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Botones fijados en la esquina superior derecha
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: CorpusTablerIcon(
                    CorpusIconKind.Reply,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Responder',
                  onPressed: () => onReply(comment),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: CorpusTablerIcon(
                      CorpusIconKind.DeleteOutline,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    tooltip: 'Eliminar',
                    onPressed: () => _confirmDelete(context),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (leftIndent <= 0) return cardContent;

    return Padding(
      padding: EdgeInsets.only(left: leftIndent),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.35),
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 10),
        child: cardContent,
      ),
    );
  }
}

class _AttachedGamePreview extends StatelessWidget {
  const _AttachedGamePreview({required this.gameData, required this.isDesktop});

  final Map<String, dynamic> gameData;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = gameData['name']?.toString() ?? 'Juego';
    final coverUrl =
        gameData['cover_url'] as String? ??
        (gameData['cover']?['image_id'] != null
            ? IGDBService.getCoverUrl(gameData['cover']['image_id'])
            : null);

    return GestureDetector(
      onTap: () => context.pushGameDetails(Game.fromMap(gameData)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isDesktop ? 140 : 110,
            height: isDesktop ? 196 : 154,
            decoration: BoxDecoration(
              borderRadius: theme
                  .extension<CorpusThemeExtension>()!
                  .radiusSmall,
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            clipBehavior: Clip.antiAlias,
            child: coverUrl != null
                ? CorpusNetworkImage(url: coverUrl, fit: BoxFit.cover)
                : const Center(
                    child: CorpusTablerIcon(CorpusIconKind.VideogameAsset),
                  ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: isDesktop ? 140 : 110,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:flutter/material.dart';

/// Barra reutilizable de interacciones (like y comentarios) para un post del feed,
/// tanto individual como agrupado.
class PostActionBar extends StatelessWidget {
  const PostActionBar({
    super.key,
    required this.likesCount,
    required this.commentsCount,
    required this.likedByMe,
    required this.onLikeTap,
    required this.onCommentTap,
    this.trailing,
  });

  final int likesCount;
  final int commentsCount;
  final bool likedByMe;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final likeColor = likedByMe
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final commentColor = theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        InkWell(
          onTap: onLikeTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CorpusTablerIcon(
                  likedByMe
                      ? CorpusIconKind.ThumbUp
                      : CorpusIconKind.ThumbUpAltOutlined,
                  size: 18,
                  color: likeColor,
                ),
                const SizedBox(width: 6),
                Text(
                  '$likesCount',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: likeColor,
                    fontWeight: likedByMe ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onCommentTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CorpusTablerIcon(
                  CorpusIconKind.ChatBubbleOutline,
                  size: 18,
                  color: commentColor,
                ),
                const SizedBox(width: 6),
                Text(
                  '$commentsCount',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: commentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (trailing != null) ...[const Spacer(), Flexible(child: trailing!)],
      ],
    );
  }
}

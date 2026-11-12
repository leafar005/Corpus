import 'package:corpus/models/models.dart';
import 'package:corpus/repositories/activity_repository.dart';
import 'package:corpus/routes/app_navigation_controller.dart';
import 'package:corpus/routes/corpus_router.dart';
import 'package:corpus/screens/activity/activity_formatters.dart';
import 'package:corpus/screens/activity/widgets/comment_composer.dart';
import 'package:corpus/screens/activity/widgets/comment_thread_section.dart';
import 'package:corpus/screens/activity/widgets/post_thread_controller.dart';
import 'package:corpus/screens/library/game_details_screen.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:corpus/utils/format_utils.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/corpus_network_image.dart';
import 'package:corpus/widgets/corpus_section_title.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pantalla de detalle para publicaciones agrupadas (varios juegos en un
/// mismo `feed_post`), con cuadrícula de juegos e hilo propio de likes y
/// comentarios.
class GroupedPostDetailsScreen extends StatefulWidget {
  const GroupedPostDetailsScreen({
    super.key,
    required this.postId,
    this.actorData,
    this.status,
    this.createdAt,
    this.initialGames,
    this.initialStats,
    this.focusComment = false,
  });

  final String postId;
  final Map<String, dynamic>? actorData;
  final String? status;
  final String? createdAt;
  final List<Map<String, dynamic>>? initialGames;
  final PostStats? initialStats;
  final bool focusComment;

  @override
  State<GroupedPostDetailsScreen> createState() =>
      _GroupedPostDetailsScreenState();
}

class _GroupedPostDetailsScreenState extends State<GroupedPostDetailsScreen> {
  final ActivityRepository _repo = ActivityRepository();
  late final PostThreadController _threadController;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  Map<String, dynamic>? _actorData;
  String? _status;
  String? _createdAt;
  List<Map<String, dynamic>> _games = [];
  bool _isLoadingItems = false;

  XFile? _commentImage;
  Map<String, dynamic>? _selectedGameForComment;
  String? _replyToCommentId;
  String? _replyToUsername;

  @override
  void initState() {
    super.initState();
    _actorData = widget.actorData;
    _status = widget.status;
    _createdAt = widget.createdAt;
    _games = widget.initialGames != null
        ? List<Map<String, dynamic>>.from(widget.initialGames!)
        : <Map<String, dynamic>>[];

    _threadController = PostThreadController(
      initialPostId: widget.postId,
      initialStats: widget.initialStats,
      repo: _repo,
    );
    _threadController.fetchInteractions();

    if (_games.isEmpty || _actorData == null || _status == null) {
      _loadPostItems();
    }

    if (widget.focusComment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _commentFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _threadController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPostItems() async {
    setState(() => _isLoadingItems = true);
    try {
      final items = await _repo.fetchPostItems(widget.postId);
      if (!mounted) return;
      if (items.isNotEmpty) {
        final first = items.first;
        final meta = first['metadata'] as Map<String, dynamic>? ?? {};
        final loadedGames = items
            .map((item) => item['games'])
            .whereType<Map<String, dynamic>>()
            .toList();
        setState(() {
          _actorData ??= first['users'] as Map<String, dynamic>?;
          _status ??= meta['status'] as String?;
          _createdAt ??= first['created_at'] as String?;
          if (loadedGames.isNotEmpty) {
            _games = loadedGames;
          }
        });
      }
    } catch (e) {
      debugPrint('[GroupedPostDetailsScreen] fetchPostItems failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingItems = false);
      }
    }
  }

  Future<void> _toggleLike() async {
    try {
      await _threadController.toggleLike();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el like: $e')),
      );
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty &&
        _commentImage == null &&
        _selectedGameForComment == null) {
      return;
    }

    try {
      final sent = await _threadController.submitComment(
        content: content,
        commentImage: _commentImage,
        attachedGame: _selectedGameForComment,
        parentCommentId: _replyToCommentId,
      );
      if (!mounted || !sent) return;
      setState(() {
        _commentController.clear();
        _commentImage = null;
        _selectedGameForComment = null;
        _replyToCommentId = null;
        _replyToUsername = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al enviar comentario: $e')));
    }
  }

  Future<void> _deleteComment(String commentId, String? imageUrl) async {
    try {
      await _threadController.deleteComment(commentId, imageUrl: imageUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Comentario eliminado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar comentario: $e')),
      );
    }
  }

  void _startReply(Map<String, dynamic> comment) {
    final user = comment['users'] as Map<String, dynamic>?;
    final targetUsername = user?['username']?.toString() ?? 'Usuario';
    final prefix = '@$targetUsername ';
    final withoutOldPrefix = _commentController.text.replaceFirst(
      RegExp(r'^@\w+\s*'),
      '',
    );

    setState(() {
      _replyToCommentId = comment['id'] as String?;
      _replyToUsername = targetUsername;
      _commentController.text = prefix + withoutOldPrefix;
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentController.text.length),
      );
    });
    _commentFocusNode.requestFocus();
  }

  void _clearReplyTarget() {
    if (_replyToCommentId == null) return;
    setState(() {
      _replyToCommentId = null;
      _replyToUsername = null;
      _commentController.text = _commentController.text.replaceFirst(
        RegExp(r'^@\w+\s*'),
        '',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final actor = _actorData;
    final actorName = actor != null
        ? ActivityFormatters.displayName(actor)
        : 'Actividad';
    final username = (actor?['username'] as String?)?.trim();
    final avatarUrl = actor?['avatar_url'] as String?;
    final status = _status;
    final statusText = status != null && status.isNotEmpty
        ? GameStatus.labelForString(status)
        : '';
    final Widget? statusWidget = statusText.isEmpty
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CorpusTablerIcon(
                GameStatus.iconForString(status ?? ''),
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
    final dateStr = _createdAt != null ? formatDateLong(_createdAt) : '';

    return ListenableBuilder(
      listenable: _threadController,
      builder: (context, _) {
        final isLoading = _isLoadingItems || _threadController.isLoading;
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            leading: IconButton(
              icon: const CorpusTablerIcon(CorpusIconKind.ArrowBack),
              onPressed: () =>
                  AppNavigationController.instance.requestBack(context),
            ),
            title: const CorpusScreenTitle(
              'Publicación',
              abbreviateIfLong: true,
              trailingBalanceWidth:
                  CorpusVisuallyBalancedTitle.defaultLeadingWidth,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: isLoading && _games.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // User Info
                              GestureDetector(
                                onTap: actor?['id'] == null
                                    ? null
                                    : () => context.pushProfile(
                                        userId: actor!['id'] as String,
                                      ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      backgroundImage:
                                          avatarUrl != null &&
                                              avatarUrl.isNotEmpty
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                      child:
                                          (avatarUrl == null ||
                                              avatarUrl.isEmpty)
                                          ? const CorpusTablerIcon(
                                              CorpusIconKind.Person,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            actorName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (username != null &&
                                              username.isNotEmpty)
                                            Text(
                                              '@$username',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (statusWidget != null) ...[
                                const SizedBox(height: 16),
                                statusWidget,
                              ],
                              const SizedBox(height: 16),

                              // Game covers (100x140)
                              if (_games.isNotEmpty)
                                Wrap(
                                  spacing: 14,
                                  runSpacing: 16,
                                  children: [
                                    for (final game in _games)
                                      _GroupedGameTile(gameData: game),
                                  ],
                                )
                              else
                                Text(
                                  'No se pudieron cargar los juegos de esta publicación.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),

                              const SizedBox(height: 32),

                              // Date
                              if (dateStr.isNotEmpty)
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),

                              const SizedBox(height: 16),
                              Divider(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.24,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Like and Comment Buttons
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _toggleLike,
                                    icon: CorpusTablerIcon(
                                      _threadController.hasLiked
                                          ? CorpusIconKind.ThumbUp
                                          : CorpusIconKind.ThumbUpAltOutlined,
                                      size: 18,
                                      color: _threadController.hasLiked
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface,
                                    ),
                                    label: Text(
                                      _threadController.likesCount.toString(),
                                      style: TextStyle(
                                        color: _threadController.hasLiked
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          theme.colorScheme.onSurface,
                                      side: BorderSide(
                                        color: _threadController.hasLiked
                                            ? theme.colorScheme.primary
                                            : theme
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                      ),
                                      backgroundColor:
                                          _threadController.hasLiked
                                          ? theme.colorScheme.primary
                                                .withValues(alpha: 0.1)
                                          : null,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: theme
                                            .extension<CorpusThemeExtension>()!
                                            .radiusLarge,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _commentFocusNode.requestFocus(),
                                    icon: const CorpusTablerIcon(
                                      CorpusIconKind.ChatBubbleOutline,
                                      size: 18,
                                    ),
                                    label: Text(
                                      _threadController.comments.length
                                          .toString(),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          theme.colorScheme.onSurface,
                                      side: BorderSide(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: theme
                                            .extension<CorpusThemeExtension>()!
                                            .radiusLarge,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Comments List
                              if (_threadController.comments.isNotEmpty) ...[
                                CommentThreadSection(
                                  comments: _threadController.comments,
                                  currentUserId: currentUserId,
                                  authorId: actor?['id'] as String?,
                                  onReply: _startReply,
                                  onDeleteComment: _deleteComment,
                                ),
                                const SizedBox(height: 24),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!isLoading)
                      CommentComposer(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        isSubmitting: _threadController.isSubmitting,
                        onSubmit: _submitComment,
                        replyToCommentId: _replyToCommentId,
                        replyToUsername: _replyToUsername,
                        onClearReply: _clearReplyTarget,
                        selectedImage: _commentImage,
                        onImageChanged: (img) =>
                            setState(() => _commentImage = img),
                        selectedGame: _selectedGameForComment,
                        onGameChanged: (game) =>
                            setState(() => _selectedGameForComment = game),
                        suggestedGames: _games,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _GroupedGameTile extends StatelessWidget {
  const _GroupedGameTile({required this.gameData});

  final Map<String, dynamic> gameData;

  void _openGame(BuildContext context, Game game) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    if (isDesktop) {
      context.pushGameDetails(game);
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        enableDrag: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 1.0,
          minChildSize: 0.5,
          maxChildSize: 1.0,
          expand: false,
          snap: true,
          builder: (context, scrollController) => GameDetailsScreen(
            gameData: game,
            scrollController: scrollController,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final game = Game.fromMap(gameData);
    final title =
        (gameData['title'] ?? gameData['name'])?.toString() ?? 'Juego';
    final coverUrl = gameData['cover_url'] as String?;

    return SizedBox(
      width: 100,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _openGame(context, game),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: theme
                    .extension<CorpusThemeExtension>()!
                    .radiusSmall,
                child: SizedBox(
                  width: 100,
                  height: 140,
                  child: coverUrl != null && coverUrl.isNotEmpty
                      ? CorpusNetworkImage(
                          url: coverUrl,
                          width: 100,
                          height: 140,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: theme.primaryColorDark,
                          child: Center(
                            child: CorpusTablerIcon(
                              CorpusIconKind.VideogameAsset,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.54,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

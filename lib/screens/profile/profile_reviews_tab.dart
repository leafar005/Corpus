import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../activity/review_details_screen.dart';
import '../../widgets/paginated_scroll_mixin.dart';

/// Pestaña "Reseñas" del perfil: feed de reseñas con comentario escrito,
/// más recientes primero, con scroll infinito.
///
/// Sustituye a `_buildReviewsTab()` / `_buildReviewCard()` de
/// `profile_screen.dart`, que pintaban todas las reseñas de golpe en un
/// `Column` dentro del scroll general de la pantalla (por eso petaba con
/// bibliotecas grandes). Aquí cada página se pide directamente a Supabase.
///
/// Uso:
/// ```dart
/// ProfileReviewsTab(userId: profileUserId, userData: _userProfile)
/// ```
class ProfileReviewsTab extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? userData;
  final ScrollController scrollController;

  const ProfileReviewsTab({
    super.key,
    required this.userId,
    required this.userData,
    required this.scrollController,
  });

  @override
  State<ProfileReviewsTab> createState() => _ProfileReviewsTabState();
}

class _ProfileReviewsTabState extends State<ProfileReviewsTab>
    with PaginatedScrollMixin {
  static const int _pageSize = 15;

  final List<Map<String, dynamic>> _reviews = [];
  int _page = 0;
  bool _isInitialLoading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    initPagination(externalController: widget.scrollController);
    loadMore();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    disposePagination();
    super.dispose();
  }

  @override
  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore) return;
    setState(() => isLoadingMore = true);

    try {
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;

      var query = Supabase.instance.client
          .from('reviews')
          .select(
            '*, games!inner(*), review_likes(user_id), review_comments(id)',
          )
          .eq('user_id', widget.userId)
          .not('comment', 'is', null)
          .neq('comment', '');

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('games.title', '%$_searchQuery%');
      }

      final res = await query
          .order('created_at', ascending: false)
          .range(from, to);

      final newItems = List<Map<String, dynamic>>.from(
        res,
      ).where((r) => r['games'] != null).toList();

      if (mounted) {
        setState(() {
          _reviews.addAll(newItems);
          _page++;
          hasMore = newItems.length == _pageSize;
          isLoadingMore = false;
          _isInitialLoading = false;
        });
        if (hasMore) {
          triggerScrollCheck();
        }
      }
    } catch (e) {
      debugPrint('[CORPUS] Error cargando reseñas: $e');
      if (mounted) {
        setState(() {
          _error = 'No se pudieron cargar las reseñas.';
          isLoadingMore = false;
          _isInitialLoading = false;
          hasMore = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _reviews.clear();
      _page = 0;
      hasMore = true;
      _isInitialLoading = true;
      _error = null;
    });
    await loadMore();
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '';
    try {
      final date = DateTime.parse(isoString).toLocal();
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
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return '';
    }
  }

  void _openReview(Map<String, dynamic> review) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewDetailsScreen(
          gameData: review['games'],
          userData: widget.userData,
          reviewData: review,
        ),
      ),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _buildSearchBar(),
          ),
        ),
        _buildListSliver(),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Buscar reseña por juego...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                  _refresh();
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      onChanged: (value) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () {
          setState(() => _searchQuery = value.trim());
          _refresh();
        });
      },
    );
  }

  Widget _buildListSliver() {
    if (_isInitialLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_reviews.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              _error ?? 'Todavía no hay reseñas escritas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= _reviews.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _buildReviewCard(_reviews[index]);
        }, childCount: _reviews.length + (hasMore ? 1 : 0)),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final gameData = review['games'] as Map<String, dynamic>?;
    if (gameData == null) return const SizedBox.shrink();

    final title = gameData['title'] ?? 'Desconocido';
    final coverUrl = gameData['cover_url'] ?? '';
    final rating = (review['rating'] ?? 0).toDouble();
    final comment = review['comment'] ?? '';
    final likesCount = (review['review_likes'] as List?)?.length ?? 0;
    final commentsCount = (review['review_comments'] as List?)?.length ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _openReview(review),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 78,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Theme.of(context).primaryColorDark,
                  image: coverUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(coverUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: coverUrl.isEmpty
                    ? Icon(
                        Icons.videogame_asset,
                        size: 18,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (rating > 0) ...[
                          Icon(
                            Icons.star,
                            size: 14,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(review['created_at']),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.thumb_up_alt_outlined,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$likesCount',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$commentsCount',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

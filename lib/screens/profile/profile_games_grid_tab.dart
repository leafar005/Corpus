import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/game_card.dart';
import '../../widgets/paginated_scroll_mixin.dart';

/// Pestaña "Juegos" del perfil: feed de juegos del usuario
/// con scroll infinito y carga paginada.
///
/// Uso:
/// ```dart
/// ProfileGamesGridTab(userId: profileUserId, filters: _filters, status: 'beaten')
/// ```
class ProfileGamesGridTab extends StatefulWidget {
  final String userId;
  final String? status; // null para todos, o 'beaten', 'playing', 'wishlist'
  final VoidCallback onReturn;

  const ProfileGamesGridTab({
    super.key,
    required this.userId,
    this.status,
    required this.onReturn,
  });

  @override
  State<ProfileGamesGridTab> createState() => _ProfileGamesGridTabState();
}

class _ProfileGamesGridTabState extends State<ProfileGamesGridTab>
    with PaginatedScrollMixin {
  static const int _pageSize = 30;

  final List<Map<String, dynamic>> _games = [];
  int _page = 0;
  bool _isInitialLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    initPagination();
    loadMore();
  }

  @override
  void dispose() {
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
          .from('user_games')
          .select('*, games(*)')
          .eq('user_id', widget.userId);

      if (widget.status != null) {
        query = query.eq('status', widget.status!);
      }

      // Ordenar por fecha de actualización
      final res = await query.order('updated_at', ascending: false).range(from, to);

      final newItems = List<Map<String, dynamic>>.from(res)
          .where((r) => r['games'] != null)
          .toList();

      if (mounted) {
        setState(() {
          _games.addAll(newItems);
          _page++;
          hasMore = res.length == _pageSize; // Comparar con los devueltos originalmente
          isLoadingMore = false;
          _isInitialLoading = false;
        });
        if (hasMore) {
          triggerScrollCheck();
        }
      }
    } catch (e) {
      debugPrint('[CORPUS] Error cargando juegos: $e');
      if (mounted) {
        setState(() {
          _error = 'No se pudieron cargar los juegos.';
          isLoadingMore = false;
          _isInitialLoading = false;
          hasMore = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _games.clear();
      _page = 0;
      hasMore = true;
      _isInitialLoading = true;
      _error = null;
    });
    await loadMore();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const Padding(
        padding: EdgeInsets.all(48.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_games.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            _error ?? 'No hay juegos para mostrar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: GridView.builder(
        controller: scrollController,
        // Scroll real: nada de shrinkWrap.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 120,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _games.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _games.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final item = _games[index];
          final gameData = item['games'] as Map<String, dynamic>;
          final rating = (item['rating'] ?? 0).toDouble();
          gameData['user_rating'] = rating;

          return GameCard(
            game: gameData,
            isInLibrary: true,
            userRating: rating,
            onReturn: () {
              widget.onReturn();
              _refresh();
            },
          );
        },
      ),
    );
  }
}

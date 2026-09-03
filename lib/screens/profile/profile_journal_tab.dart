import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import 'package:corpus/utils/format_utils.dart';
import 'package:corpus/routes/corpus_router.dart';
import '../../widgets/paginated_scroll_mixin.dart';
import '../../utils/igdb_constants.dart';
import '../../theme/corpus_theme_extension.dart';

/// Pestaña "Diario" del perfil: timeline cronológico de las reseñas del
/// usuario, agrupadas por mes, con scroll infinito.
///
/// A diferencia de la v1, este widget NO recibe la lista de reseñas ya
/// cargada por [ProfileScreen] — hace sus propias queries paginadas a
/// Supabase, así que nunca carga en memoria más de lo que el usuario ha
/// llegado a ver en pantalla.
///
/// Requiere que exista la columna generada `effective_date` en `reviews`
/// (ver `journal_tab_integration.md` para el SQL). Si no quieres tocar la
/// BD todavía, cambia `_orderColumn` por `'created_at'` — funciona igual,
/// solo que la agrupación por mes puede no ser 100% exacta si registras
/// reseñas mucho después de haber jugado.
///
/// Uso:
/// ```dart
/// ProfileJournalTab(userId: profileUserId, userData: _userProfile)
/// ```
class ProfileJournalTab extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? userData;
  final ScrollController scrollController;

  const ProfileJournalTab({
    super.key,
    required this.userId,
    required this.userData,
    required this.scrollController,
  });

  @override
  State<ProfileJournalTab> createState() => _ProfileJournalTabState();
}

class _ProfileJournalTabState extends State<ProfileJournalTab>
    with PaginatedScrollMixin {
  static const int _pageSize = 25;
  static const String _orderColumn =
      'created_at'; // Changed from effective_date as it requires SQL updates

  final List<Map<String, dynamic>> _reviews = [];
  int _page = 0;
  bool _isInitialLoading = true;
  String? _error;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int? _selectedYear;
  List<int> _availableYears = [];

  static const List<String> _monthNames = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    initPagination(externalController: widget.scrollController);
    _fetchAvailableYears();
    loadMore();
  }

  Future<void> _fetchAvailableYears() async {
    try {
      final res = await Supabase.instance.client
          .from('reviews')
          .select(_orderColumn)
          .eq('user_id', widget.userId)
          .inFilter('status', ['playing', 'beaten', 'completed']);

      final Set<int> years = {};
      for (final r in res) {
        final dateStr = r[_orderColumn];
        if (dateStr != null) {
          try {
            final date = DateTime.parse(dateStr.toString());
            years.add(date.year);
          } catch (_) {}
        }
      }

      final sortedYears = years.toList()..sort((a, b) => b.compareTo(a));
      if (mounted) {
        setState(() {
          _availableYears = sortedYears;
        });
      }
    } catch (e) {
      debugPrint('[CORPUS] Error cargando años: $e');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    disposePagination();
    super.dispose();
  }

  DateTime? _effectiveDate(Map<String, dynamic> r) {
    final raw =
        r['effective_date'] ??
        r['played_until'] ??
        r['played_from'] ??
        r['created_at'];
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _buildQuery() {
    var query = Supabase.instance.client
        .from('reviews')
        .select('*, games!inner(*)')
        .eq('user_id', widget.userId)
        .inFilter('status', ['playing', 'beaten', 'completed']);

    if (_searchQuery.isNotEmpty) {
      query = query.ilike('games.title', '%$_searchQuery%');
    }

    if (_selectedYear != null) {
      query = query
          .gte(_orderColumn, '$_selectedYear-01-01T00:00:00.000Z')
          .lte(_orderColumn, '$_selectedYear-12-31T23:59:59.999Z');
    }
    return query;
  }

  @override
  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore) return;
    setState(() => isLoadingMore = true);

    try {
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;

      final res = await _buildQuery()
          .order(_orderColumn, ascending: false)
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
      debugPrint('[CORPUS] Error cargando diario: $e');
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar el diario.';
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

  Future<void> _refreshInPlace() async {
    if (_reviews.isEmpty) {
      await _refresh();
      return;
    }
    try {
      final res = await _buildQuery()
          .order(_orderColumn, ascending: false)
          .range(0, _reviews.length - 1);
      final newItems = List<Map<String, dynamic>>.from(
        res,
      ).where((r) => r['games'] != null).toList();
      if (mounted && newItems.isNotEmpty) {
        setState(() {
          _reviews
            ..clear()
            ..addAll(newItems);
        });
      }
    } catch (e) {
      debugPrint('[CORPUS] Error en refreshInPlace (diario): $e');
    }
  }

  String _getStatusText(String status) => GameStatus.labelForString(status);

  Widget _buildStarRow(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star,
          color: Theme.of(context).colorScheme.secondary,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          formatRating(rating),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  void _openReview(Map<String, dynamic> review) {
    context
        .pushReviewDetails(
          Game.fromMap(review['games']),
          widget.userData,
          review,
        )
        .then((_) => _refreshInPlace());
  }

  void _openGame(Map<String, dynamic> review) {
    context
        .pushGameDetails(Game.fromMap(review['games']))
        .then((_) => _refreshInPlace());
  }

  /// Aplana [_reviews] en una lista de "filas" (cabecera de mes o entrada)
  /// para poder pintarlo todo con un único ListView.builder.
  List<_JournalRow> _flatten() {
    final rows = <_JournalRow>[];
    String? lastKey;
    for (final r in _reviews) {
      final d = _effectiveDate(r);
      final key = d == null ? 'sin-fecha' : '${d.year}-${d.month}';
      if (key != lastKey) {
        final label = d == null
            ? 'Sin fecha'
            : '${_monthNames[d.month - 1]}, ${d.year}';
        rows.add(_JournalRow.header(label));
        lastKey = key;
      }
      rows.add(_JournalRow.entry(r));
    }
    return rows;
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar juego...',
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
                borderRadius: Theme.of(
                  context,
                ).extension<CorpusThemeExtension>()!.radiusMedium,
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
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 1,
          child: DropdownButtonFormField<int?>(
            initialValue: _selectedYear,
            hint: const Text('Año'),
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: Theme.of(
                  context,
                ).extension<CorpusThemeExtension>()!.radiusMedium,
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Todos')),
              ..._availableYears.map(
                (year) => DropdownMenuItem<int?>(
                  value: year,
                  child: Text(year.toString()),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() => _selectedYear = value);
              _refresh();
            },
          ),
        ),
      ],
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
              _error ??
                  'Aún no hay nada en tu diario. En cuanto marques una fecha\n'
                      'de juego en una reseña, aparecerá aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    final rows = _flatten();

    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= rows.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final row = rows[index];
          return row.isHeader
              ? _buildMonthHeader(row.label!)
              : _buildJournalRow(row.review!);
        }, childCount: rows.length + (hasMore ? 1 : 0)),
      ),
    );
  }

  Widget _buildMonthHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) => GameStatus.iconForString(status);

  Widget _buildJournalRow(Map<String, dynamic> review) {
    final gameData = review['games'] as Map<String, dynamic>?;
    if (gameData == null) return const SizedBox.shrink();

    final title = gameData['title'] ?? 'Desconocido';
    final coverUrl = gameData['cover_url'] ?? '';
    final date = _effectiveDate(review);
    final rating = (review['rating'] ?? 0).toDouble();
    final status = review['status'] ?? 'beaten';
    final platform = review['platform'] as String?;
    final isReplay = review['is_replay'] == true;
    final completionType = review['completion_type'] as String?;
    final isPlatinado =
        status == 'completed' || completionType == '100_percent';

    return InkWell(
      onTap: () => _openReview(review),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              child: Text(
                date != null ? date.day.toString().padLeft(2, '0') : '--',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Container(
              width: 1,
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.12),
            ),
            GestureDetector(
              onTap: () => _openGame(review),
              child: Container(
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
                        size: 20,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isReplay) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.replay,
                          size: 16,
                          color: Colors.orangeAccent.shade200,
                        ),
                      ],
                    ],
                  ),
                  if (rating > 0 || isPlatinado) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (rating > 0) _buildStarRow(rating),
                        if (rating > 0 && isPlatinado) const SizedBox(width: 8),
                        if (isPlatinado)
                          const Icon(
                            Icons.emoji_events,
                            size: 16,
                            color: Colors.amber,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (MediaQuery.of(context).size.width > 600) ...[
              SizedBox(
                width: 60,
                child: Row(
                  children: [
                    if (platform != null)
                      Builder(
                        builder: (context) {
                          final style = IgdbConstants.getPlatformStyle(
                            platform,
                          );
                          final color =
                              style['color'] as Color? ??
                              Theme.of(context).colorScheme.primary;
                          final iconPath = style['icon'] as String?;
                          final iconData = style['materialIcon'] as IconData?;
                          return Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: iconPath != null
                                  ? Image.asset(
                                      iconPath,
                                      width: 16,
                                      height: 16,
                                      color: Colors.white,
                                    )
                                  : (iconData != null
                                        ? Icon(
                                            iconData,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : const SizedBox.shrink()),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 110,
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(status),
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _getStatusText(status),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(width: 12),
              Icon(
                _getStatusIcon(status),
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _JournalRow {
  final bool isHeader;
  final String? label;
  final Map<String, dynamic>? review;

  _JournalRow.header(this.label) : isHeader = true, review = null;
  _JournalRow.entry(this.review) : isHeader = false, label = null;
}

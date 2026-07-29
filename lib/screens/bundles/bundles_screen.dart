import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/game_card.dart';
import '../../services/bundle_service.dart';
import '../../widgets/paginated_scroll_mixin.dart';

class _ListRow {
  final bool isHeader;
  final String? storeName;
  final Map<String, dynamic>? bundle;
  _ListRow.header(this.storeName) : isHeader = true, bundle = null;
  _ListRow.bundle(this.storeName, this.bundle) : isHeader = false;
}

class BundlesScreen extends StatefulWidget {
  const BundlesScreen({super.key});

  @override
  State<BundlesScreen> createState() => _BundlesScreenState();
}

class _BundlesScreenState extends State<BundlesScreen> with PaginatedScrollMixin {
  final List<Map<String, dynamic>> _bundles = [];
  bool _isInitialLoading = true;
  String? _error;
  int _page = 0;
  static const int _pageSize = 10;

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

  Future<void> _refresh() async {
    setState(() {
      _bundles.clear();
      _page = 0;
      hasMore = true;
      _isInitialLoading = true;
      _error = null;
    });
    await loadMore();
  }

  @override
  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore) return;
    setState(() => isLoadingMore = true);

    try {
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;

      final response = await Supabase.instance.client
          .from('active_bundles')
          .select()
          .order('end_date', ascending: true)
          .range(from, to);

      final newBundles = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          _bundles.addAll(newBundles);
          _page++;
          hasMore = newBundles.length == _pageSize;
          isLoadingMore = false;
          _isInitialLoading = false;
        });
        if (hasMore) {
          triggerScrollCheck();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudieron cargar los bundles.\n$e';
          isLoadingMore = false;
          _isInitialLoading = false;
          hasMore = false;
        });
      }
    }
  }

  List<_ListRow> _buildFlatRows() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final b in _bundles) {
      final storeName = b['store_name'] ?? 'Desconocido';
      grouped.putIfAbsent(storeName, () => []).add(b);
    }
    final orderedStores = grouped.keys.toList()
      ..sort((a, b) => BundleService.storeRankPublic(a).compareTo(BundleService.storeRankPublic(b)));

    final rows = <_ListRow>[];
    for (final store in orderedStores) {
      rows.add(_ListRow.header(store));
      for (final bundle in grouped[store]!) {
        rows.add(_ListRow.bundle(store, bundle));
      }
    }
    return rows;
  }

  Widget _buildStoreHeader(String storeName) {
    final isHumble = storeName == 'Humble Bundle';
    final badgeColor = isHumble ? Colors.redAccent : Colors.orangeAccent;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Icon(
            isHumble ? Icons.local_fire_department : Icons.storefront,
            color: badgeColor,
          ),
          const SizedBox(width: 8),
          Text(
            storeName.toUpperCase(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: badgeColor,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bundles Activos'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _bundles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              const Text(
                'No se pudieron cargar los bundles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_bundles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.local_offer_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text('No hay bundles activos en este momento.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _refresh,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final rows = _buildFlatRows();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: rows.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= rows.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final row = rows[index];
          if (row.isHeader) {
            return _buildStoreHeader(row.storeName!);
          }
          final isHumble = row.storeName == 'Humble Bundle';
          final badgeColor = isHumble ? Colors.redAccent : Colors.orangeAccent;
          
          return _BundleCard(
            bundle: row.bundle!,
            storeName: row.storeName!,
            badgeColor: badgeColor,
          );
        },
      ),
    );
  }
}

class _BundleCard extends StatefulWidget {
  final Map<String, dynamic> bundle;
  final String storeName;
  final Color badgeColor;

  const _BundleCard({
    required this.bundle,
    required this.storeName,
    required this.badgeColor,
  });

  @override
  State<_BundleCard> createState() => _BundleCardState();
}

class _BundleCardState extends State<_BundleCard> {
  final Map<int, int> _tierLimits = {};
  static const int _initialLimit = 12;

  Widget _buildTierHeader(
    BuildContext context,
    Map<String, dynamic> tier,
    String bundleTitle,
    Color badgeColor,
  ) {
    final String tierName = tier['name'] ?? '';
    final double? price = tier['price'] != null
        ? (tier['price'] as num).toDouble()
        : null;
    final List games = tier['games'] ?? [];

    String priceText = '';
    String perGameText = '';

    if (price != null && price > 0) {
      final String formattedPrice = price == price.truncateToDouble()
          ? price.toInt().toString()
          : price.toStringAsFixed(2);
      priceText = '$formattedPrice €/\$';

      final RegExp pickRegex = RegExp(
        r'pick\s+(\d+)|any\s+(\d+)|elige\s+(\d+)',
        caseSensitive: false,
      );
      final match = pickRegex.firstMatch(tierName);
      if (match != null) {
        final int? count = int.tryParse(
          match.group(1) ?? match.group(2) ?? match.group(3) ?? '',
        );
        if (count != null && count > 0) {
          final double perGame = price / count;
          perGameText = ' (~${perGame.toStringAsFixed(2)} €/juego)';
        }
      } else if (games.isNotEmpty &&
          !bundleTitle.toLowerCase().contains('build your bundle') &&
          !tierName.toLowerCase().contains('pick')) {
        final double perGame = price / games.length;
        if (games.length > 1) {
          perGameText = ' (~${perGame.toStringAsFixed(2)} €/juego)';
        }
      }
    }

    return Row(
      children: [
        Text(
          tierName.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            fontSize: 14,
          ),
        ),
        if (priceText.isNotEmpty) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sell_outlined, size: 14, color: badgeColor),
                const SizedBox(width: 4),
                Text(
                  priceText + perGameText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.bundle['title'] ?? 'Bundle';
    final url = widget.bundle['url'] ?? '';
    final endDateStr = widget.bundle['end_date'];

    String timeRemaining = '';
    Color timeColor = Colors.grey;
    IconData timeIcon = Icons.schedule;

    if (endDateStr != null) {
      final endDate = DateTime.parse(endDateStr);
      final diff = endDate.difference(DateTime.now().toUtc());
      if (diff.isNegative) {
        timeRemaining = 'Caducado';
        timeColor = Colors.red;
        timeIcon = Icons.timer_off;
      } else if (diff.inDays <= 10) {
        timeRemaining = diff.inDays == 0
            ? '¡Termina hoy!'
            : 'Quedan ${diff.inDays} días';
        timeColor = Colors.amber;
        timeIcon = Icons.warning_amber_rounded;
      } else {
        timeRemaining = 'Quedan ${diff.inDays} días';
        timeColor = Colors.green;
        timeIcon = Icons.calendar_today;
      }
    }

    final List tiers = widget.bundle['tiers'] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Tienda'),
                  onPressed: () {
                    if (url.isNotEmpty) {
                      launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ],
            ),
            if (timeRemaining.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(
                  top: 4,
                  bottom: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: timeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: timeColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        timeIcon,
                        size: 14,
                        color: timeColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeRemaining,
                        style: TextStyle(
                          color: timeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(height: 24),

            ...tiers.asMap().entries.map((entry) {
              final tIndex = entry.key;
              final tierMap = entry.value;
              final tier = tierMap as Map<String, dynamic>;
              final List validGames = tier['games'] ?? [];

              if (validGames.isEmpty) {
                return const SizedBox.shrink();
              }

              final limit = _tierLimits[tIndex] ?? _initialLimit;
              final showMoreButton = validGames.length > limit;
              final displayedGames = validGames.take(limit).toList();

              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTierHeader(
                      context,
                      tier,
                      title,
                      widget.badgeColor,
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 140,
                        childAspectRatio: 0.68,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: displayedGames.length,
                      itemBuilder: (context, gIndex) {
                        final gameData = displayedGames[gIndex] as Map<String, dynamic>;
                        return GameCard(
                          key: ValueKey(gameData['steamAppId'] ?? gameData['title'] ?? gIndex),
                          game: gameData,
                          onReturn: () {},
                        );
                      },
                    ),
                    if (showMoreButton)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _tierLimits[tIndex] = limit + 12;
                              });
                            },
                            icon: const Icon(Icons.expand_more),
                            label: Text('Ver más (${validGames.length - limit} restantes)'),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

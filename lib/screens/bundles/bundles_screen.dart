import 'dart:async';
import '../../models/models.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/game_card.dart';
import '../../services/bundle_service.dart';

class _ListRow {
  final bool isHeader;
  final String? storeName;
  final Map<String, dynamic>? bundle;
  _ListRow.header(this.storeName) : isHeader = true, bundle = null;
  _ListRow.bundle(this.storeName, this.bundle) : isHeader = false;
}

class BundlesNavigation {
  static final targetQuery = ValueNotifier<String?>(null);
}

class BundlesScreen extends StatefulWidget {
  const BundlesScreen({super.key});

  @override
  State<BundlesScreen> createState() => _BundlesScreenState();
}

class _BundlesScreenState extends State<BundlesScreen> {
  final List<Map<String, dynamic>> _bundles = [];
  bool _isInitialLoading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();
  final Set<String> _collapsedStores = {};

  @override
  void initState() {
    super.initState();
    
    final initialQuery = BundlesNavigation.targetQuery.value;
    if (initialQuery != null && initialQuery.isNotEmpty) {
      _searchController.text = initialQuery;
      _searchQuery = initialQuery;
      // We don't clear targetQuery.value here because _onExternalSearch might be triggered 
      // immediately if we add the listener after, but actually it's fine to clear it.
      BundlesNavigation.targetQuery.value = null;
    }
    
    _fetchBundles();
    BundlesNavigation.targetQuery.addListener(_onExternalSearch);
  }

  void _onExternalSearch() {
    final query = BundlesNavigation.targetQuery.value;
    if (query != null && query.isNotEmpty) {
      _searchController.text = query;
      _searchQuery = query;
      BundlesNavigation.targetQuery.value = null;
      _refresh();
    }
  }

  @override
  void dispose() {
    BundlesNavigation.targetQuery.removeListener(_onExternalSearch);
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _bundles.clear();
      _isInitialLoading = true;
      _error = null;
    });
    await _fetchBundles();
  }

  Future<void> _fetchBundles() async {
    try {
      List<dynamic> response;
      if (_searchQuery.isEmpty) {
        response = await Supabase.instance.client
            .from('active_bundles')
            .select()
            .order('end_date', ascending: true);
      } else {
        response = await Supabase.instance.client.rpc(
          'search_active_bundles',
          params: {'search_term': _searchQuery},
        );
      }

      final newBundles = List<Map<String, dynamic>>.from(response);
      final now = DateTime.now();
      newBundles.retainWhere((b) {
        if (b['end_date'] == null) return true;
        final endDate = DateTime.parse(b['end_date']);
        return endDate.isAfter(now);
      });

      if (mounted) {
        setState(() {
          _bundles.addAll(newBundles);
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudieron cargar los bundles.\n$e';
          _isInitialLoading = false;
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
      ..sort(
        (a, b) => BundleService.storeRankPublic(
          a,
        ).compareTo(BundleService.storeRankPublic(b)),
      );

    final rows = <_ListRow>[];
    for (final store in orderedStores) {
      rows.add(_ListRow.header(store));
      if (!_collapsedStores.contains(store)) {
        for (final bundle in grouped[store]!) {
          rows.add(_ListRow.bundle(store, bundle));
        }
      }
    }
    return rows;
  }

  Widget _buildStoreHeader(String storeName) {
    final isHumble = storeName.toLowerCase().contains('humble');
    final isFanatical = storeName.toLowerCase().contains('fanatical');
    final badgeColor = isHumble ? Colors.redAccent : Colors.orangeAccent;
    final isCollapsed = _collapsedStores.contains(storeName);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isCollapsed) {
              _collapsedStores.remove(storeName);
            } else {
              _collapsedStores.add(storeName);
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              if (isHumble)
                Image.asset('assets/images/humble_logo_full.png', height: 32, fit: BoxFit.contain)
              else if (isFanatical)
                Image.asset('assets/images/fanatical_logo_full.png', height: 32, fit: BoxFit.contain)
              else ...[
                Icon(Icons.storefront, color: badgeColor, size: 24),
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
              const Spacer(),
              Icon(
                isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _searchQuery.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                  _refresh();
                },
              )
            : null,
        title: const Text('Bundles Activos'),
        actions: [
          IconButton(
            icon: const Padding(
              padding: EdgeInsets.only(top: 2.0),
              child: Icon(Icons.refresh),
            ),
            onPressed: _refresh,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar bundle o juego...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                          _refresh();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
              onChanged: (value) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                  _refresh();
                });
              },
            ),
          ),
        ),
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
        controller: _scrollController,
        cacheExtent: 5000,
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        itemBuilder: (context, index) {
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: timeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: timeColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(timeIcon, size: 14, color: timeColor),
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
              final tierMap = entry.value;
              final tier = tierMap as Map<String, dynamic>;
              final List validGames = tier['games'] ?? [];

              if (validGames.isEmpty) {
                return const SizedBox.shrink();
              }

              final displayedGames = validGames;

              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTierHeader(context, tier, title, widget.badgeColor),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 140,
                            childAspectRatio: 0.68,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: displayedGames.length,
                      itemBuilder: (context, gIndex) {
                        final gameData =
                            displayedGames[gIndex] as Map<String, dynamic>;
                        return GameCard(
                          key: ValueKey(
                            gameData['steamAppId'] ??
                                gameData['title'] ??
                                gIndex,
                          ),
                          game: Game.fromMap(gameData),
                          onReturn: () {},
                        );
                      },
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

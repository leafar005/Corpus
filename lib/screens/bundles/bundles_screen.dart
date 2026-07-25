import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/bundle_service.dart';
import '../../services/igdb_service.dart';
import '../library/game_details_screen.dart';
import '../../widgets/game_card.dart';

class _BundlesData {
  final List<GameBundle> bundles;
  final Map<String, Map<String, dynamic>> resolvedGames;
  _BundlesData(this.bundles, this.resolvedGames);

  Map<String, dynamic> toJson() => {
    'bundles': bundles.map((b) => b.toJson()).toList(),
    'resolvedGames': resolvedGames,
  };

  factory _BundlesData.fromJson(Map<String, dynamic> json) {
    final bList = (json['bundles'] as List).map((e) => GameBundle.fromJson(e)).toList();
    final Map<String, dynamic> rRaw = json['resolvedGames'] ?? {};
    final rMap = rRaw.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v)));
    return _BundlesData(bList, rMap);
  }
}

class BundlesScreen extends StatefulWidget {
  const BundlesScreen({super.key});

  @override
  State<BundlesScreen> createState() => _BundlesScreenState();
}

class _BundlesScreenState extends State<BundlesScreen> {
  late Future<_BundlesData> _dataFuture;
  bool _isBackgroundRefreshing = false;
  
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<String> _statusNotifier = ValueNotifier<String>('Conectando con Humble Bundle y Fanatical...');

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    _dataFuture = _loadDataFromCache().then((cached) {
      if (cached != null) {
        _checkAndRevalidate();
        return cached;
      }
      return _loadData();
    });
  }

  void _checkAndRevalidate() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheTime = prefs.getInt('bundles_full_cache_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Si la caché tiene menos de 8 horas, no recargamos de fondo
    final eightHours = 8 * 60 * 60 * 1000;
    if (now - cacheTime < eightHours) {
      return; 
    }

    if (mounted) setState(() => _isBackgroundRefreshing = true);
    
    _loadData().then((freshData) {
      if (mounted) {
        setState(() {
          _dataFuture = Future.value(freshData);
          _isBackgroundRefreshing = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _isBackgroundRefreshing = false);
    });
  }

  Future<_BundlesData?> _loadDataFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('bundles_full_cache');
      if (str != null) {
        return _BundlesData.fromJson(json.decode(str));
      }
    } catch (e) {
      debugPrint('Error loading cache: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _progressNotifier.dispose();
    _statusNotifier.dispose();
    super.dispose();
  }

  Future<_BundlesData> _loadData() async {
    _progressNotifier.value = 0.05;
    _statusNotifier.value = 'Descargando catálogo de ofertas...';

    final bundles = await BundleService.getActiveBundles();
    
    final Set<int> steamIds = {};
    final List<BundleGame> allBundleGames = [];
    
    for (final b in bundles) {
      for (final t in b.tiers) {
        for (final g in t.games) {
          allBundleGames.add(g);
          if (g.steamAppId != null && g.steamAppId! > 0) {
            steamIds.add(g.steamAppId!);
          }
        }
      }
    }

    _progressNotifier.value = 0.15;
    _statusNotifier.value = 'Procesando ${steamIds.length} juegos de Steam...';

    final Map<String, Map<String, dynamic>> resolved = steamIds.isEmpty
        ? {}
        : await IGDBService.getGamesBySteamIds(
            steamIds.toList(),
            onProgress: (processed, total, step) {
              _progressNotifier.value = 0.15 + (processed / total) * 0.60;
              _statusNotifier.value = step;
            },
          );

    final List<BundleGame> unresolvedGames = allBundleGames.where((g) {
      if (g.steamAppId != null && g.steamAppId! > 0) {
        return !resolved.containsKey('steam:${g.steamAppId}');
      }
      return !resolved.containsKey('title:${g.title}');
    }).toList();

    final Set<String> titlesToSearch = unresolvedGames.map((g) => g.title).toSet();
    final List<String> titleList = titlesToSearch.toList();

    if (titleList.isNotEmpty) {
      _statusNotifier.value = 'Rescatando indies y expansiones...';
      const batchSize = 5;
      for (var i = 0; i < titleList.length; i += batchSize) {
        final chunk = titleList.skip(i).take(batchSize).toList();
        final results = await Future.wait(chunk.map((title) async {
          try {
            final r = await IGDBService.searchGameLenient(title);
            return r.isNotEmpty ? r.first as Map<String, dynamic> : null;
          } catch (_) {
            return null;
          }
        }));
        
        for (var j = 0; j < chunk.length; j++) {
          final data = results[j];
          if (data != null) {
            resolved['title:${chunk[j]}'] = data;
          }
        }

        final currentTitleIdx = (i + chunk.length < titleList.length) ? i + chunk.length : titleList.length;
        _progressNotifier.value = 0.75 + (currentTitleIdx / titleList.length) * 0.25;
        _statusNotifier.value = 'Rescatando por título ($currentTitleIdx de ${titleList.length})...';
      }
    }

    _progressNotifier.value = 1.0;
    _statusNotifier.value = 'Completado.';

    final newData = _BundlesData(bundles, resolved);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bundles_full_cache', json.encode(newData.toJson()));
      await prefs.setInt('bundles_full_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error saving cache: $e');
    }

    return newData;
  }

  Map<String, dynamic>? _lookup(BundleGame bg, Map<String, Map<String, dynamic>> resolved) {
    if (bg.steamAppId != null && bg.steamAppId! > 0) {
      final bySteam = resolved['steam:${bg.steamAppId}'];
      if (bySteam != null) return bySteam;
    }
    return resolved['title:${bg.title}'];
  }

  // --- CABECERA DE TIER CON PRECIO TOTAL Y DESGLOSE POR JUEGO ---
  Widget _buildTierHeader(BuildContext context, BundleTier tier, String bundleTitle, Color badgeColor) {
    final String tierName = tier.name;
    final double? price = tier.price;
    
    String priceText = '';
    String perGameText = '';

    if (price != null && price > 0) {
      final String formattedPrice = price == price.truncateToDouble() 
          ? price.toInt().toString() 
          : price.toStringAsFixed(2);
      priceText = '$formattedPrice €/\$';

      final RegExp pickRegex = RegExp(r'pick\s+(\d+)|any\s+(\d+)|elige\s+(\d+)', caseSensitive: false);
      final match = pickRegex.firstMatch(tierName);
      if (match != null) {
        final int? count = int.tryParse(match.group(1) ?? match.group(2) ?? match.group(3) ?? '');
        if (count != null && count > 0) {
          final double perGame = price / count;
          perGameText = ' (~${perGame.toStringAsFixed(2)} €/juego)';
        }
      } else if (tier.games.isNotEmpty && !bundleTitle.toLowerCase().contains('build your bundle') && !tierName.toLowerCase().contains('pick')) {
        final double perGame = price / tier.games.length;
        if (tier.games.length > 1) {
          perGameText = ' (~${perGame.toStringAsFixed(2)} €/juego)';
        }
      }
    }

    return Row(
      children: [
        Text(
          tierName.toUpperCase(),
          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: 14),
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
                  style: TextStyle(fontWeight: FontWeight.bold, color: badgeColor, fontSize: 12),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bundles Activos'),
        bottom: _isBackgroundRefreshing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2.0),
                child: LinearProgressIndicator(minHeight: 2.0),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _progressNotifier.value = 0.0;
                _statusNotifier.value = 'Conectando con Humble Bundle y Fanatical...';
                _dataFuture = _loadData();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<_BundlesData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            // --- BARRA DE PROGRESO COMPACTA Y CENTRADA ---
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_offer, size: 56, color: Colors.orangeAccent),
                      const SizedBox(height: 24),
                      const Text('Actualizando Bundles Activos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      ValueListenableBuilder<double>(
                        valueListenable: _progressNotifier,
                        builder: (context, progress, child) {
                          return Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: progress > 0 ? progress : null,
                                  minHeight: 10,
                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<String>(
                        valueListenable: _statusNotifier,
                        builder: (context, status, child) {
                          return Text(
                            status,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    const Text('No se pudieron cargar los bundles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _dataFuture = _loadData();
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final bundles = snapshot.data!.bundles;
          final resolved = snapshot.data!.resolvedGames;

          if (bundles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No hay bundles activos en este momento.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _dataFuture = _loadData();
                      });
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final Map<String, List<GameBundle>> grouped = {};
          for (final b in bundles) {
            grouped.putIfAbsent(b.storeName, () => []).add(b);
          }
          final orderedStores = grouped.keys.toList()
            ..sort((a, b) => BundleService.storeRankPublic(a).compareTo(BundleService.storeRankPublic(b)));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: orderedStores.map((storeName) {
              final storeBundles = grouped[storeName]!;
              final isHumble = storeName == 'Humble Bundle';
              final badgeColor = isHumble ? Colors.redAccent : Colors.orangeAccent;

              return Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  tilePadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Icon(isHumble ? Icons.local_fire_department : Icons.storefront, color: badgeColor),
                      const SizedBox(width: 8),
                      Text(storeName.toUpperCase(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: badgeColor, letterSpacing: 1.2)),
                    ],
                  ),
                  children: storeBundles.map((bundle) {
                    String timeRemaining = '';
                    Color timeColor = Colors.grey;
                    IconData timeIcon = Icons.schedule;
                    if (bundle.endDate != null) {
                      final diff = bundle.endDate!.difference(DateTime.now().toUtc());
                      if (diff.isNegative) {
                        timeRemaining = 'Caducado';
                        timeColor = Colors.red;
                        timeIcon = Icons.timer_off;
                      } else if (diff.inDays <= 10) {
                        timeRemaining = diff.inDays == 0 ? '¡Termina hoy!' : 'Quedan ${diff.inDays} días';
                        timeColor = Colors.amber;
                        timeIcon = Icons.warning_amber_rounded;
                      } else {
                        timeRemaining = 'Quedan ${diff.inDays} días';
                        timeColor = Colors.green;
                        timeIcon = Icons.calendar_today;
                      }
                    }

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
                                  child: Text(bundle.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.open_in_new, size: 16),
                                  label: const Text('Tienda'),
                                  onPressed: () => launchUrl(Uri.parse(bundle.url), mode: LaunchMode.externalApplication),
                                )
                              ],
                            ),
                            if (timeRemaining.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                      Text(timeRemaining, style: TextStyle(color: timeColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            const Divider(height: 24),
                            
                            ...bundle.tiers.map((tier) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTierHeader(context, tier, bundle.title, badgeColor),
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
                                      itemCount: tier.games.length,
                                      itemBuilder: (context, gIndex) {
                                        final bg = tier.games[gIndex];
                                        final gameData = _lookup(bg, resolved);
                                        if (gameData == null) {
                                          return _buildUnresolvedCard(context, bg.title);
                                        }
                                        return GameCard(game: gameData, onReturn: () {});
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
                  }).toList(),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildUnresolvedCard(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videogame_asset_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 28),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

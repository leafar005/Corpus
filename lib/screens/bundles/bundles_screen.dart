import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
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
  static const int _cacheSchemaVersion = 2;
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
      final version = prefs.getInt('bundles_full_cache_version');
      if (str != null && version == _cacheSchemaVersion) {
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

  /// Filtro inteligente: descarta cupones, suscripciones de IGN/DC, bandas sonoras y archivos 3D
  /// (Hemos eliminado 'juego desconocido' de aquí para no destruir los ítems antes de que IGDB resuelva su Steam ID)
  bool _isRealGame(String title) {
    final lower = title.toLowerCase().trim();
    if (lower.isEmpty || lower == 'null' || lower == 'bundle sin título') return false;
    
    // Lista negra de ítems comerciales de Barter.vg que no son juegos
    if (lower.contains('coupon') ||
        lower.contains('voucher') ||
        lower.contains('discount') ||
        lower.contains('ign plus') ||
        lower.contains('dc universe') ||
        lower.contains('1-month') ||
        lower.contains('3-month') ||
        lower.contains('membership') ||
        lower.contains('subscription') ||
        lower.contains('soundtrack') ||
        lower.contains('artbook') ||
        lower.contains('audio_only') ||
        lower.contains('stl') ||
        lower.contains('3d print')) {
      return false;
    }
    return true;
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
    _statusNotifier.value = 'Procesando ${steamIds.length} juegos en IGDB...';

    // 1. PRIMERO: Intentamos resolver todo por Steam ID en IGDB
    final Map<String, Map<String, dynamic>> resolved = steamIds.isEmpty
        ? {}
        : await IGDBService.getGamesBySteamIds(
            steamIds.toList(),
            onProgress: (processed, total, step) {
              _progressNotifier.value = 0.15 + (processed / total) * 0.40;
              _statusNotifier.value = step;
            },
          );

    // 2. SEGUNDO: Rescate por título en IGDB para indies y juegos sin Steam ID
    final List<BundleGame> unresolvedGames = allBundleGames.where((g) {
      if (g.steamAppId != null && g.steamAppId! > 0) {
        return !resolved.containsKey('steam:${g.steamAppId}');
      }
      return !resolved.containsKey('title:${g.title}');
    }).toList();

    final Set<String> titlesToSearch = unresolvedGames
        .map((g) => g.title)
        .where((t) => t.isNotEmpty && t != 'Juego Desconocido' && t != 'null')
        .toSet();
    final List<String> titleList = titlesToSearch.toList();

    if (titleList.isNotEmpty) {
      _statusNotifier.value = 'Rescatando títulos en IGDB...';
      const batchSize = 5;
      for (var i = 0; i < titleList.length; i += batchSize) {
        final chunk = titleList.skip(i).take(batchSize).toList();
        final results = await Future.wait(chunk.map((title) async {
          try {
            final cleanedTitle = title
                .replaceAll(RegExp(r'\s*-?\s*(Digital\s+)?Deluxe\s+Edition.*$', caseSensitive: false), '')
                .replaceAll(RegExp(r'\s*-?\s*Game\s+of\s+the\s+Year\s+Edition.*$', caseSensitive: false), '')
                .replaceAll(RegExp(r"\s*-?\s*Collector(')?s\s+Edition.*$", caseSensitive: false), '')
                .replaceAll(RegExp(r'\s*-?\s*Expansion\s+Standalone.*$', caseSensitive: false), '')
                .replaceAll(RegExp(r'\s*-?\s*Premium\s+Edition.*$', caseSensitive: false), '')
                .replaceAll(RegExp(r'\s*-?\s*Ultimate\s+Edition.*$', caseSensitive: false), '')
                .replaceAll(RegExp(r'\s*-?\s*Complete\s+Edition.*$', caseSensitive: false), '')
                .replaceAll(RegExp(r'\s*\(.*?\)', caseSensitive: false), '')
                .replaceAll(RegExp(r'\s*\[.*?\]', caseSensitive: false), '')
                .trim();
            final r = await IGDBService.searchGameLenient(cleanedTitle);
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
        _progressNotifier.value = 0.55 + (currentTitleIdx / titleList.length) * 0.20;
      }
    }

    // 3. TERCERO (EL COMODÍN INFALIBLE): Rescate final usando la API de Steam
    // Si IGDB no conoció el juego pero tenemos un Steam ID, le preguntamos a Steam.
    final List<int> stillUnresolvedSteamIds = steamIds
        .where((id) => !resolved.containsKey('steam:$id'))
        .toList();

    if (stillUnresolvedSteamIds.isNotEmpty) {
      _statusNotifier.value = 'Consultando servidores de Steam...';
      for (var i = 0; i < stillUnresolvedSteamIds.length; i++) {
        final appId = stillUnresolvedSteamIds[i];
        try {
          final response = await http.get(Uri.parse('https://store.steampowered.com/api/appdetails?appids=$appId&l=spanish'));
          if (response.statusCode == 200) {
            final jsonResp = json.decode(response.body);
            final appData = jsonResp[appId.toString()];
            
            // Si la API de Steam nos dice que existe y ES UN JUEGO (descarta cupones, música o DLCs)
            if (appData != null && appData['success'] == true) {
              final data = appData['data'];
              final String type = (data['type'] ?? '').toString().toLowerCase();
              
              if (type == 'game') {
                // Creamos un mapa idéntico a los de IGDB para que GameCard y GameDetailsScreen funcionen transparentemente
                final String name = data['name'] ?? 'Juego de Steam';
                final String cover = data['header_image'] ?? data['capsule_image'] ?? '';
                final List developers = data['developers'] ?? [];
                final String devName = developers.isNotEmpty ? developers.first.toString() : 'Desconocido';
                final List genres = data['genres'] ?? [];
                final List<String> genreNames = genres.map((g) => g['description'].toString()).toList();

                resolved['steam:$appId'] = {
                  'id': appId, // Usamos el ID de Steam como fallback numérico
                  'igdb_id': null,
                  'name': name,
                  'title': name,
                  'cover_url': cover,
                  'developer': devName,
                  'summary': data['short_description'] ?? data['detailed_description'] ?? 'Sin descripción disponible.',
                  'platforms': ['PC (Steam)'],
                  'genres': genreNames,
                  'release_date': data['release_date']?['date'],
                  'steam_app_id': appId,
                };
              }
            }
          }
        } catch (e) {
          debugPrint('Error en rescate de Steam API para appId $appId: $e');
        }
        _progressNotifier.value = 0.75 + ((i + 1) / stillUnresolvedSteamIds.length) * 0.25;
      }
    }

    _progressNotifier.value = 1.0;
    _statusNotifier.value = 'Completado.';

    final newData = _BundlesData(bundles, resolved);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bundles_full_cache', json.encode(newData.toJson()));
      await prefs.setInt('bundles_full_cache_time', DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt('bundles_full_cache_version', _cacheSchemaVersion);
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
                              // FILTRO DE DESTRUCCIÓN: Si no existe en 'resolved' (ni por IGDB ni por Steam), se elimina de la lista.
                              // Esto destruye instantáneamente el 9º ítem fantasma de Humble Choice y los cupones.
                              final validGames = tier.games.where((bg) {
                                final gameData = _lookup(bg, resolved);
                                return gameData != null; 
                              }).toList();

                              // Si después de filtrar la basura el tier se queda vacío, no dibujamos nada
                              if (validGames.isEmpty) return const SizedBox.shrink();

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
                                      itemCount: validGames.length,
                                      itemBuilder: (context, gIndex) {
                                        final bg = validGames[gIndex];
                                        final gameData = _lookup(bg, resolved)!; // Ya sabemos que no es null
                                        
                                        // Dibujamos el GameCard estándar. Al hacer clic, te llevará a GameDetailsScreen
                                        // con todos los metadatos perfectamente estructurados, venga de IGDB o de Steam.
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
}

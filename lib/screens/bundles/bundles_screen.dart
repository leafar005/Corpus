import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/game_card.dart';
import '../../services/bundle_service.dart';

class BundlesScreen extends StatefulWidget {
  const BundlesScreen({super.key});

  @override
  State<BundlesScreen> createState() => _BundlesScreenState();
}

class _BundlesScreenState extends State<BundlesScreen> {
  late Future<List<Map<String, dynamic>>> _bundlesFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _bundlesFuture = _fetchBundles();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchBundles() async {
    final response = await Supabase.instance.client
        .from('active_bundles')
        .select()
        .order('end_date', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bundles Activos'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _bundlesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
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
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final bundles = snapshot.data ?? [];

          if (bundles.isEmpty) {
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
                    onPressed: _loadData,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final Map<String, List<Map<String, dynamic>>> grouped = {};
          for (final b in bundles) {
            final storeName = b['store_name'] ?? 'Desconocido';
            grouped.putIfAbsent(storeName, () => []).add(b);
          }
          final orderedStores = grouped.keys.toList()
            ..sort(
              (a, b) => BundleService.storeRankPublic(
                a,
              ).compareTo(BundleService.storeRankPublic(b)),
            );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: orderedStores.map((storeName) {
              final storeBundles = grouped[storeName]!;
              final isHumble = storeName == 'Humble Bundle';
              final badgeColor = isHumble
                  ? Colors.redAccent
                  : Colors.orangeAccent;

              return Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  tilePadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Icon(
                        isHumble
                            ? Icons.local_fire_department
                            : Icons.storefront,
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
                  children: storeBundles.map((bundle) {
                    final title = bundle['title'] ?? 'Bundle';
                    final url = bundle['url'] ?? '';
                    final endDateStr = bundle['end_date'];

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

                    final List tiers = bundle['tiers'] ?? [];

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

                            ...tiers.map((tierMap) {
                              final tier = tierMap as Map<String, dynamic>;
                              final List validGames = tier['games'] ?? [];

                              if (validGames.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTierHeader(
                                      context,
                                      tier,
                                      title,
                                      badgeColor,
                                    ),
                                    const SizedBox(height: 10),
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          const SliverGridDelegateWithMaxCrossAxisExtent(
                                            maxCrossAxisExtent: 140,
                                            childAspectRatio: 0.68,
                                            crossAxisSpacing: 10,
                                            mainAxisSpacing: 10,
                                          ),
                                      itemCount: validGames.length,
                                      itemBuilder: (context, gIndex) {
                                        final gameData =
                                            validGames[gIndex]
                                                as Map<String, dynamic>;
                                        return GameCard(
                                          game: gameData,
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

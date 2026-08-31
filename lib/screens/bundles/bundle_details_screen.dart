import 'package:flutter/material.dart';
import 'package:corpus/widgets/game_card.dart';
import 'package:corpus/models/models.dart';
import 'package:corpus/utils/url_utils.dart';
import 'package:corpus/widgets/corpus_section_title.dart';
import 'package:corpus/routes/app_navigation_controller.dart';
import 'package:corpus/globals.dart';

class BundleDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> bundleData;

  const BundleDetailsScreen({super.key, required this.bundleData});

  @override
  State<BundleDetailsScreen> createState() => _BundleDetailsScreenState();
}

class _BundleDetailsScreenState extends State<BundleDetailsScreen> {
  late final ScrollController _scrollController;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted) return;
    final offset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    if ((offset - _scrollOffset).abs() > 2.0) {
      setState(() {
        _scrollOffset = offset;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.bundleData['title'] ?? 'Bundle';
    final url = widget.bundleData['url'] as String?;
    final endDateStr = widget.bundleData['end_date'] as String?;
    final tiers = widget.bundleData['tiers'] as List<dynamic>? ?? [];

    String? daysRemaining;
    if (endDateStr != null) {
      final endDate = DateTime.tryParse(endDateStr);
      if (endDate != null) {
        final diff = endDate.difference(DateTime.now());
        if (diff.inDays >= 0) {
          daysRemaining = 'Quedan ${diff.inDays} días';
        } else {
          daysRemaining = 'Terminado';
        }
      }
    }

    final canPopSystem = !Navigator.of(context).canPop();
    return PopScope(
      canPop: canPopSystem,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          AppNavigationController.instance.requestBack(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: AnimatedOpacity(
            opacity: _scrollOffset > 50 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Text(title),
          ),
          actions: [
            if (url != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Tienda'),
                  onPressed: () => openUrl(url),
                ),
              ),
          ],
        ),
        body: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título principal en el body
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (daysRemaining != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.amber),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        daysRemaining,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // Lógica para decidir si aplanamos los tiers o no
              Builder(
                builder: (context) {
                  final isFanatical =
                      (widget.bundleData['store_name'] as String?)
                          ?.toLowerCase() ==
                      'fanatical';
                  final isHumbleChoice = title.toLowerCase().contains(
                    'humble choice',
                  );
                  final flattenTiers = isFanatical || isHumbleChoice;

                  if (flattenTiers) {
                    // Aplanar todos los juegos
                    final allGames = <dynamic>[];
                    for (final tier in tiers) {
                      final gamesList =
                          (tier as Map<String, dynamic>)['games']
                              as List<dynamic>? ??
                          [];
                      allGames.addAll(gamesList);
                    }

                    if (allGames.isEmpty) return const SizedBox.shrink();

                    return ValueListenableBuilder<int>(
                      valueListenable: mobileGridColumnsNotifier,
                      builder: (context, columns, child) {
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: getCorpusGridDelegate(
                            context,
                            columns,
                            desktopMaxExtent: 140,
                            spacing: 16,
                          ),
                          itemCount: allGames.length,
                          itemBuilder: (context, index) {
                            final gameData = allGames[index];
                            if (gameData is! Map<String, dynamic>) {
                              return const SizedBox.shrink();
                            }
                            return GameCard(
                              game: Game.fromMap(gameData),
                              onReturn: () {},
                            );
                          },
                        );
                      },
                    );
                  }

                  // Render normal por Tiers
                  return ValueListenableBuilder<int>(
                    valueListenable: mobileGridColumnsNotifier,
                    builder: (context, columns, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: tiers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final tier = entry.value as Map<String, dynamic>;
                          final gamesList =
                              tier['games'] as List<dynamic>? ?? [];

                          if (gamesList.isEmpty) return const SizedBox.shrink();

                          // Si tiene nombre o precio, se puede poner, si no TIER N
                          final tierName = tier['name'] ?? 'TIER ${index + 1}';

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CorpusSectionTitle(
                                tierName.toString().toUpperCase(),
                              ),
                              const SizedBox(height: 16),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: getCorpusGridDelegate(
                                  context,
                                  columns,
                                  desktopMaxExtent: 140,
                                  spacing: 16,
                                ),
                                itemCount: gamesList.length,
                                itemBuilder: (context, gIndex) {
                                  final gameData = gamesList[gIndex];
                                  if (gameData is! Map<String, dynamic>) {
                                    return const SizedBox.shrink();
                                  }
                                  return GameCard(
                                    game: Game.fromMap(gameData),
                                    onReturn: () {},
                                  );
                                },
                              ),
                              const SizedBox(height: 32),
                            ],
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

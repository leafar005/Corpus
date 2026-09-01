import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/igdb_service.dart';
import 'package:corpus/routes/corpus_router.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/corpus_section_title.dart';
import '../../widgets/p5r_styled_panel.dart';
import '../../widgets/p5r_dynamic_frame.dart';
import '../../widgets/corpus_network_image.dart';

class AnticipatedGamesSection extends StatefulWidget {
  final List<dynamic> games;
  final String countdownStyle;
  final String title;

  const AnticipatedGamesSection({
    super.key,
    required this.games,
    this.countdownStyle = 'full',
    this.title = 'Juegos más anticipados',
  });

  @override
  State<AnticipatedGamesSection> createState() =>
      _AnticipatedGamesSectionState();
}

class _AnticipatedGamesSectionState extends State<AnticipatedGamesSection> {
  Timer? _timer;
  late DateTime _now;
  final PageController _pageController = PageController();
  final ValueNotifier<int> _currentPage = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _currentPage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.games.isEmpty) return const SizedBox.shrink();

    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CorpusSectionTitle(widget.title),
          const SizedBox(height: 8),
          if (isDesktop)
            GridView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: widget.games.length,
              itemBuilder: (context, index) {
                return _buildGameCard(widget.games[index]);
              },
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 240,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.games.length,
                    onPageChanged: (index) {
                      _currentPage.value = index;
                    },
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: _buildGameCard(widget.games[index]),
                      );
                    },
                  ),
                ),
                if (widget.games.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Center(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _currentPage,
                        builder: (context, currentPage, child) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              widget.games.length,
                              (index) => Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: currentPage == index
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface
                                            .withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildGameCard(dynamic game) {
    final title = game['name'] ?? 'Desconocido';
    final releaseTimestamp = game['first_release_date'] as int?;
    String dateStr = 'Fecha por confirmar';

    String days = '00';
    String hours = '00';
    String minutes = '00';

    if (releaseTimestamp != null) {
      final releaseDate = DateTime.fromMillisecondsSinceEpoch(
        releaseTimestamp * 1000,
      );
      dateStr =
          '${releaseDate.day.toString().padLeft(2, '0')}/${releaseDate.month.toString().padLeft(2, '0')}/${releaseDate.year}';

      final difference = releaseDate.difference(_now);
      if (difference.isNegative) {
        days = '00';
        hours = '00';
        minutes = '00';
      } else {
        days = difference.inDays.toString().padLeft(2, '0');
        hours = (difference.inHours % 24).toString().padLeft(2, '0');
        minutes = (difference.inMinutes % 60).toString().padLeft(2, '0');
      }
    }

    String backgroundUrl = '';
    if (game['artworks'] != null && game['artworks'].isNotEmpty) {
      backgroundUrl = IGDBService.getScreenshotUrl(
        game['artworks'][0]['image_id'],
      );
    } else if (game['cover'] != null) {
      backgroundUrl = IGDBService.getCoverUrl(game['cover']['image_id']);
    }

    bool isHovered = false;
    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          cursor: SystemMouseCursors.click,
          child: AnimatedScale(
            scale: isHovered ? 1.03 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: GestureDetector(
              onTap: () {
                if (game['id'] != null) {
                  context.pushGameDetails({'igdb_id': game['id'], 'title': title});
                }
              },
              child: CorpusStyledPanel(
                padding: EdgeInsets.zero,
                backgroundColor: const Color(0xFF0A0A0A),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (backgroundUrl.isNotEmpty)
                      Positioned.fill(
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.55),
                            BlendMode.srcOver,
                          ),
                          child: CorpusNetworkImage(
                            url: backgroundUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          if (widget.countdownStyle == 'days_only')
                            Row(
                              children: [
                                _buildCountdownSection(days, 'DÍAS RESTANTES'),
                              ],
                            )
                          else
                            Row(
                              children: [
                                _buildCountdownSection(days, 'DAYS'),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '|',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ),
                                _buildCountdownSection(hours, 'HOURS'),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '|',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ),
                                _buildCountdownSection(minutes, 'MINUTES'),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCountdownSection(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: value
              .split('')
              .map((char) => _buildDigitBox(char))
              .toList(),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDigitBox(String digit) {
    final isP5r = Theme.of(
      context,
    ).extension<CorpusThemeExtension>()!.useDynamicFrames;

    if (isP5r) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: P5rDynamicFrame(
          backgroundColor: Colors.black,
          borderColor: Colors.white,
          borderWidth: 1,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 22,
              height: 1.0,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(
        digit,
        style: const TextStyle(
          fontSize: 24,
          height: 1.0,
          fontWeight: FontWeight.w300,
          color: Colors.white,
        ),
      ),
    );
  }
}

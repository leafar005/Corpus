// Fase 3 del refactor B-C2.
// Origen: _buildMediaTab -> líneas 3465-3644.

import 'package:flutter/material.dart';
import '../../../services/igdb_service.dart';
import '../../../utils/url_utils.dart';
import '../../../widgets/full_screen_gallery.dart';
import '../../../theme/corpus_theme_extension.dart';
import '../../../widgets/corpus_network_image.dart';

class GameMediaTab extends StatefulWidget {
  const GameMediaTab({
    super.key,
    required this.screenshotsList,
    required this.artworksList,
    required this.videosList,
  });

  final List screenshotsList;
  final List artworksList;
  final List videosList;

  @override
  State<GameMediaTab> createState() => _GameMediaTabState();
}

class _GameMediaTabState extends State<GameMediaTab> {
  // Origen: _selectedMediaTabIndex (campo del State original). Es puramente
  // local a esta pestaña: qué sub-tab (Capturas/Videos/Artworks) se ve.
  int _selectedMediaTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> availableTabs = [];
    if (widget.screenshotsList.isNotEmpty) {
      availableTabs.add({
        'id': 0,
        'label': 'Capturas',
        'icon': Icons.screenshot_monitor,
      });
    }
    if (widget.videosList.isNotEmpty) {
      availableTabs.add({
        'id': 1,
        'label': 'Tráilers',
        'icon': Icons.video_library,
      });
    }
    if (widget.artworksList.isNotEmpty) {
      availableTabs.add({'id': 2, 'label': 'Artworks', 'icon': Icons.brush});
    }

    if (availableTabs.isEmpty) return const SizedBox.shrink();

    final int activeTabId =
        availableTabs.any((t) => t['id'] == _selectedMediaTabIndex)
        ? _selectedMediaTabIndex
        : availableTabs.first['id'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (availableTabs.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: availableTabs.map((tab) {
                final isSelected = tab['id'] == activeTabId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(tab['label']),
                    showCheckmark: false,
                    avatar: Icon(
                      tab['icon'],
                      size: 18,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() => _selectedMediaTabIndex = tab['id']);
                      }
                    },
                    selectedColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.4),
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (activeTabId == 0)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              childAspectRatio: 16 / 9,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: widget.screenshotsList.length,
            itemBuilder: (context, index) {
              final url = IGDBService.getScreenshotUrl(
                widget.screenshotsList[index].toString(),
              );
              return InkWell(
                onTap: () {
                  final List<String> urls = widget.screenshotsList
                      .map((id) => IGDBService.getScreenshotUrl(id.toString()))
                      .toList();
                  showFullScreenGallery(context, urls, index);
                },
                borderRadius: Theme.of(
                  context,
                ).extension<CorpusThemeExtension>()!.radiusMedium,
                child: ClipRRect(
                  borderRadius: Theme.of(
                    context,
                  ).extension<CorpusThemeExtension>()!.radiusMedium,
                  child: CorpusNetworkImage(url: url, fit: BoxFit.cover),
                ),
              );
            },
          ),
        if (activeTabId == 1)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              childAspectRatio: 16 / 9,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: widget.videosList.length,
            itemBuilder: (context, index) {
              final videoId = widget.videosList[index].toString();
              final thumbUrl = IGDBService.getVideoThumbnailUrl(videoId);
              final videoUrl = IGDBService.getVideoUrl(videoId);
              return InkWell(
                onTap: () => openUrl(videoUrl),
                borderRadius: Theme.of(
                  context,
                ).extension<CorpusThemeExtension>()!.radiusMedium,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: Theme.of(
                        context,
                      ).extension<CorpusThemeExtension>()!.radiusMedium,
                      child: CorpusNetworkImage(
                        url: thumbUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: Theme.of(
                          context,
                        ).extension<CorpusThemeExtension>()!.radiusMedium,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        if (activeTabId == 2)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: widget.artworksList.length,
            itemBuilder: (context, index) {
              final url = IGDBService.getArtworkUrl(
                widget.artworksList[index].toString(),
              );
              return InkWell(
                onTap: () {
                  final List<String> urls = widget.artworksList
                      .map((id) => IGDBService.getArtworkUrl(id.toString()))
                      .toList();
                  showFullScreenGallery(context, urls, index);
                },
                borderRadius: Theme.of(
                  context,
                ).extension<CorpusThemeExtension>()!.radiusMedium,
                child: ClipRRect(
                  borderRadius: Theme.of(
                    context,
                  ).extension<CorpusThemeExtension>()!.radiusMedium,
                  child: CorpusNetworkImage(url: url, fit: BoxFit.cover),
                ),
              );
            },
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../../../routes/corpus_router.dart';
import '../../../utils/shelf_platforms.dart';

/// Utilidades de layout para lomos en la estantería.
abstract final class ShelfSpineLayout {
  static const double gap = 4;

  static double uiWidthForPlatform(String platformName) =>
      ShelfPlatforms.caseDimensionsFor(platformName).uiWidth;

  static double uiHeightForPlatform(String platformName) =>
      ShelfPlatforms.caseDimensionsFor(platformName).uiHeight;

  /// Agrupa cajas en filas según el ancho disponible (lomos de distinto grosor).
  static List<List<T>> chunkIntoRows<T>(
    List<T> items,
    double totalWidth, {
    required double Function(T item) itemWidth,
    double horizontalPadding = 40,
    double gap = gap,
  }) {
    final contentWidth = totalWidth - horizontalPadding;
    final rows = <List<T>>[];
    var currentRow = <T>[];
    var usedWidth = 0.0;

    for (final item in items) {
      final w = itemWidth(item);
      final extra = currentRow.isEmpty ? w : gap + w;

      if (usedWidth + extra > contentWidth && currentRow.isNotEmpty) {
        rows.add(currentRow);
        currentRow = [item];
        usedWidth = w;
      } else {
        currentRow.add(item);
        usedWidth += extra;
      }
    }

    if (currentRow.isNotEmpty) rows.add(currentRow);
    return rows;
  }
}

/// Caja de juego vista de lado (lomo), como en una estantería física.
class ShelfGameBox extends StatefulWidget {
  const ShelfGameBox({
    super.key,
    required this.game,
    required this.platformName,
    this.onLongPress,
  });

  final Game game;
  final String platformName;
  final VoidCallback? onLongPress;

  @override
  State<ShelfGameBox> createState() => _ShelfGameBoxState();
}

class _ShelfGameBoxState extends State<ShelfGameBox> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final platform = ShelfPlatforms.resolve(widget.platformName);
    final caseSize = ShelfPlatforms.caseDimensionsFor(widget.platformName);
    final spineWidth = caseSize.uiWidth;
    final spineHeight = caseSize.uiHeight;
    final title = _spineTitle(widget.game.title, platform);
    final footer = _spineFooter(widget.game);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.game.title,
        waitDuration: const Duration(milliseconds: 400),
        child: AnimatedScale(
          scale: _hovered ? 1.06 : 1.0,
          alignment: Alignment.bottomCenter,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: GestureDetector(
            onTap: () => context.pushGameDetails(widget.game),
            onLongPress: widget.onLongPress,
            child: SizedBox(
              width: spineWidth,
              height: spineHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color.lerp(platform.color, Colors.white, 0.14)!,
                      platform.color,
                      Color.lerp(platform.color, Colors.black, 0.22)!,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: _hovered ? 0.55 : 0.38,
                      ),
                      blurRadius: _hovered ? 10 : 6,
                      offset: Offset(_hovered ? 3 : 2, _hovered ? 5 : 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 2,
                        child: ColoredBox(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: spineWidth < 20 ? 2 : 4,
                          vertical: 8,
                        ),
                        child: Column(
                          children: [
                            _SpinePlatformMark(
                              platform: platform,
                              size: spineWidth < 18 ? 16 : spineWidth < 26 ? 20 : 24,
                            ),
                            SizedBox(height: spineWidth < 18 ? 5 : 7),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final fontSize = spineWidth < 18
                                      ? 9.0
                                      : spineWidth < 26
                                      ? 10.5
                                      : 12.0;
                                  return Center(
                                    child: RotatedBox(
                                      quarterTurns: 3,
                                      child: SizedBox(
                                        width: constraints.maxHeight,
                                        height: constraints.maxWidth,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.center,
                                          child: Text(
                                            title,
                                            maxLines: 6,
                                            overflow: TextOverflow.fade,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: platform.textColor,
                                              fontSize: fontSize,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                              height: 1.05,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (footer != null) ...[
                              const SizedBox(height: 4),
                              _SpineFooter(
                                label: footer,
                                color: platform.textColor,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _spineTitle(String raw, ShelfPlatform platform) {
    final normalized = raw.trim();
    if (platform.group == 'Nintendo' ||
        platform.id == 'Steam' ||
        platform.id == 'Epic Games') {
      return normalized.toUpperCase();
    }
    return normalized;
  }

  String? _spineFooter(Game game) {
    final label = game.publisher?.trim().isNotEmpty == true
        ? game.publisher!.trim()
        : game.developer?.trim();
    if (label == null || label.isEmpty) return null;
    if (label.length > 18) return '${label.substring(0, 16)}…';
    return label.toUpperCase();
  }
}

class _SpinePlatformMark extends StatelessWidget {
  const _SpinePlatformMark({required this.platform, required this.size});

  final ShelfPlatform platform;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: platform.textColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: platform.textColor.withValues(alpha: 0.25),
        ),
      ),
      alignment: Alignment.center,
      child: _PlatformGlyph(
        platform: platform,
        size: size * 0.58,
      ),
    );
  }
}

class _SpineFooter extends StatelessWidget {
  const _SpineFooter({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Center(
        child: RotatedBox(
          quarterTurns: 3,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color.withValues(alpha: 0.75),
              fontSize: 8,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformGlyph extends StatelessWidget {
  const _PlatformGlyph({required this.platform, required this.size});

  final ShelfPlatform platform;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (platform.iconAsset != null) {
      return Image.asset(
        platform.iconAsset!,
        width: size,
        height: size,
        color: platform.textColor,
        errorBuilder: (_, _, _) => Icon(
          platform.materialIcon ?? Icons.sports_esports,
          size: size,
          color: platform.textColor,
        ),
      );
    }
    return Icon(
      platform.materialIcon ?? Icons.sports_esports,
      size: size,
      color: platform.textColor,
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/corpus_theme_extension.dart';

class AchievementToast {
  /// Muestra el banner emergente estilo Xbox en la parte superior de la pantalla.
  static void show(
    BuildContext context, {
    required String title,
    String subtitle = 'Logro desbloqueado',
    int? xpReward,
    IconData icon = Icons.emoji_events,
    Color color = const Color(0xFFFFD700), // Dorado por defecto
  }) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _AnimatedAchievementToast(
        title: title,
        subtitle: subtitle,
        xpReward: xpReward,
        icon: icon,
        color: color,
        onDismissed: () {
          overlayEntry.remove();
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }
}

class _AnimatedAchievementToast extends StatefulWidget {
  final String title;
  final String subtitle;
  final int? xpReward;
  final IconData icon;
  final Color color;
  final VoidCallback onDismissed;

  const _AnimatedAchievementToast({
    required this.title,
    required this.subtitle,
    this.xpReward,
    required this.icon,
    required this.color,
    required this.onDismissed,
  });

  @override
  State<_AnimatedAchievementToast> createState() =>
      _AnimatedAchievementToastState();
}

class _AnimatedAchievementToastState extends State<_AnimatedAchievementToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Animación de deslizamiento desde arriba con un ligero rebote (elasticOut)
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    // Mantener en pantalla 3.5 segundos y luego retirar suavemente
    _timer = Timer(const Duration(milliseconds: 3500), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 450),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24), // Fondo gris oscuro consola
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                    boxShadow: [
                      // Brillo exterior estilo neón/Xbox
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                      const BoxShadow(
                        color: Colors.black54,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icono con fondo circular iluminado
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.color.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Icon(widget.icon, color: widget.color, size: 24),
                      ),
                      const SizedBox(width: 14),
                      // Textos del logro
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.subtitle.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: widget.color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Etiqueta de XP opcional
                      if (widget.xpReward != null && widget.xpReward! > 0) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: widget.color.withValues(alpha: 0.2),
                            borderRadius: Theme.of(
                              context,
                            ).extension<CorpusThemeExtension>()!.radiusLarge,
                          ),
                          child: Text(
                            '+${widget.xpReward} XP',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: widget.color,
                            ),
                          ),
                        ),
                      ],
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
}

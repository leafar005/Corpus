import 'dart:async';
import 'package:flutter/material.dart';
import '../routes/deep_route_resolver.dart';
import '../routes/tab_deep_route.dart';
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
    VoidCallback? onTap,
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
        onTap: onTap,
        onDismissed: () {
          overlayEntry.remove();
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }

  /// Muestra de forma escalonada los toasts de logros recién desbloqueados.
  ///
  /// [achievements] proviene de `SaveReviewResult.newAchievementDetails`.
  /// [isMounted] debe ser una función que devuelva `mounted` del [State] caller
  /// para evitar mostrar toasts sobre widgets ya destruidos.
  static void showFromList(
    BuildContext context,
    List<Map<String, dynamic>> achievements, {
    required bool Function() isMounted,
  }) {
    int toastDelay = 300;
    for (final ach in achievements) {
      final String aId = ach['id'] as String;
      final String title = ach['name'] as String? ?? 'Logro desbloqueado';
      final String rarity =
          (ach['rarity'] as String?)?.toLowerCase() ?? 'comun';
      final int xpReward = ach['xp_reward'] as int? ?? 0;

      String subtitle = 'Logro desbloqueado';
      Color color = const Color(0xFFFFD700);

      if (title.contains('(Maestro)') ||
          title.contains('(Nivel 3)') ||
          aId.endsWith('_all')) {
        subtitle = 'Maestro de saga';
        color = const Color(0xFFFFD700);
      } else if (title.contains('(Nivel 2)')) {
        subtitle = 'Hito alcanzado';
        color = const Color(0xFFC0C0C0);
      } else if (title.contains('(Nivel 1)')) {
        subtitle = 'Logro desbloqueado';
        color = const Color(0xFFCD7F32);
      } else {
        if (rarity == 'legendario' ||
            rarity == 'platino' ||
            rarity == 'épico' ||
            rarity == 'epico') {
          subtitle = 'Hazaña legendaria';
          color = Colors.cyanAccent;
        } else if (rarity == 'difícil' ||
            rarity == 'dificil' ||
            rarity == 'medio') {
          subtitle = 'Logro desbloqueado';
          color = Colors.blueAccent;
        } else {
          subtitle = 'Logro desbloqueado';
          color = Colors.green;
        }
      }

      Future.delayed(Duration(milliseconds: toastDelay), () {
        if (!context.mounted) return;
        if (isMounted()) {
          AchievementToast.show(
            context,
            title: title,
            subtitle: subtitle,
            xpReward: xpReward,
            icon: Icons.workspace_premium,
            color: color,
            onTap: () async {
              final groupId = aId.split('_').first;
              final route = await DeepRouteResolver.buildRoute(
                AchievementGamesDeepRoute(achievementId: groupId),
              );
              if (!context.mounted) return;
              if (route != null && isMounted()) {
                Navigator.push(context, route);
              }
            },
          );
        }
      });
      toastDelay += 3700;
    }
  }
}

class _AnimatedAchievementToast extends StatefulWidget {
  final String title;
  final String subtitle;
  final int? xpReward;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback onDismissed;

  const _AnimatedAchievementToast({
    required this.title,
    required this.subtitle,
    this.xpReward,
    required this.icon,
    required this.color,
    this.onTap,
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
                child: GestureDetector(
                  onTap: () {
                    widget.onTap?.call();
                    if (mounted) {
                      _timer?.cancel();
                      _controller.reverse().then((_) {
                        widget.onDismissed();
                      });
                    }
                  },
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 450),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF1E1E24,
                      ), // Fondo gris oscuro consola
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
                          child: Icon(
                            widget.icon,
                            color: widget.color,
                            size: 24,
                          ),
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
                        if (widget.xpReward != null &&
                            widget.xpReward! > 0) ...[
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
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../routes/app_navigation_controller.dart';

/// Un widget que simula el gesto de retroceso en iOS (Edge Swipe).
/// Dado que `PopScope` con `canPop: false` desactiva el gesto nativo de retroceso
/// interactivo en iOS, necesitamos capturarlo manualmente.
class EdgeSwipeBackDetector extends StatelessWidget {
  final Widget child;

  const EdgeSwipeBackDetector({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Si estamos en Web o no estamos en iOS/macOS, no necesitamos esto,
    // devolvemos el child tal cual.
    if (kIsWeb || !(Platform.isIOS || Platform.isMacOS)) {
      return child;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        // Si el usuario arrastra desde el borde izquierdo (menos de 20px)
        // hacia la derecha de manera suficientemente rápida o larga
        if (details.globalPosition.dx < 20 &&
            details.primaryDelta != null &&
            details.primaryDelta! > 10) {
          // Triggeamos el back
          AppNavigationController.instance.requestBack(context);
        }
      },
      child: child,
    );
  }
}

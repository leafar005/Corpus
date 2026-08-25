import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../routes/corpus_router.dart';
import 'corpus_primary_button.dart';

/// Aviso reutilizable para zonas de la app en "modo invitado":
/// icono + mensaje + botón que abre la pantalla de login.
///
/// Úsalo tanto a pantalla completa (Perfil, Actividad) como en línea,
/// dentro de otro layout (p.ej. en vez del botón "Añadir a biblioteca").
class GuestLoginPrompt extends StatelessWidget {
  final String message;
  final IconData icon;
  final String buttonLabel;
  final EdgeInsetsGeometry padding;

  const GuestLoginPrompt({
    super.key,
    required this.message,
    this.icon = Icons.lock_outline,
    this.buttonLabel = 'Iniciar sesión',
    this.padding = const EdgeInsets.all(32),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 56,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          CorpusPrimaryButton(
            onPressed: () => openLoginScreen(context),
            icon: Icons.login,
            label: buttonLabel,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          ),
        ],
      ),
    );
  }
}

/// Abre la pantalla de login por encima de todo (rootNavigator), para que
/// funcione igual sin importar desde qué pestaña/tab-navigator se llame.
void openLoginScreen(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    CorpusRouter.route(const RouteSettings(name: AppRoutes.login)),
  );
}

/// Botón compacto en línea (para sustituir "Añadir a biblioteca" en la
/// ficha de juego). Mismo destino, distinta presentación visual.
class GuestLoginButton extends StatelessWidget {
  final String label;
  const GuestLoginButton({
    super.key,
    this.label = 'Iniciar sesión para registrar',
  });

  @override
  Widget build(BuildContext context) {
    return CorpusPrimaryButton(
      onPressed: () => openLoginScreen(context),
      icon: Icons.login,
      label: label,
      expand: true,
      height: 50,
    );
  }
}

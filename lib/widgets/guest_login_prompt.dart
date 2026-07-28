import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';

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
          ElevatedButton.icon(
            onPressed: () => openLoginScreen(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontSize: 18),
            ),
            icon: const Icon(Icons.login),
            label: Text(buttonLabel),
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
    MaterialPageRoute(builder: (_) => const LoginScreen()),
  );
}

/// Botón compacto en línea (para sustituir "Añadir a biblioteca" en la
/// ficha de juego). Mismo destino, distinta presentación visual.
class GuestLoginButton extends StatelessWidget {
  final String label;
  const GuestLoginButton({super.key, this.label = 'Iniciar sesión para registrar'});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => openLoginScreen(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(fontSize: 18),
      ),
      icon: const Icon(Icons.login),
      label: Text(
        label,
        textAlign: TextAlign.center,
      ),
    );
  }
}

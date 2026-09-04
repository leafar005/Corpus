import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:flutter/material.dart';
import 'package:corpus/routes/app_routes.dart';
import 'package:corpus/routes/corpus_router.dart';
import 'corpus_primary_button.dart';
import 'corpus_tabler_icon.dart';

/// Aviso reutilizable para zonas de la app en "modo invitado":
/// icono + mensaje + botón que abre la pantalla de login.
///
/// Úsalo tanto a pantalla completa (Perfil, Actividad) como en línea,
/// dentro de otro layout (p.ej. en vez del botón "Añadir a biblioteca").
class GuestLoginPrompt extends StatelessWidget {
  final String message;
  final CorpusIconKind? icon;
  final Widget? iconWidget;
  final String buttonLabel;
  final EdgeInsetsGeometry padding;

  const GuestLoginPrompt({
    super.key,
    required this.message,
    this.icon,
    this.iconWidget,
    this.buttonLabel = 'Iniciar sesión',
    this.padding = const EdgeInsets.all(32),
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).colorScheme.primary.withValues(
      alpha: 0.6,
    );
    final leading =
        iconWidget ??
        (icon != null
            ? CorpusTablerIcon(icon!, size: 56, color: iconColor)
            : CorpusTablerIcon.lock(size: 56, color: iconColor));

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
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
            icon: CorpusIconKind.Login,
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
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(CorpusRouter.route(const RouteSettings(name: AppRoutes.login)));
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
      icon: CorpusIconKind.Login,
      label: label,
      expand: true,
      height: 50,
    );
  }
}

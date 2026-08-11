// lib/utils/url_utils.dart
//
// Helper para abrir URLs de forma fiable en todas las plataformas.
//
// En web, launchUrl() llama a window.open() de forma async, lo que hace
// que Firefox (y otros navegadores con popup blocker estricto) lo bloquee
// porque considera que no viene de un gesto de usuario síncrono.
//
// Solución: en web creamos un elemento <a> programático y lo clickamos
// directamente — todos los navegadores aceptan esto sin bloqueo porque
// es equivalente a que el usuario haga clic en un enlace.
//
// En plataformas nativas se usa launchUrl con LaunchMode.externalApplication.

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

// ignore: avoid_web_libraries_in_flutter
import 'url_utils_stub.dart' if (dart.library.html) 'dart:html' as html;

/// Abre [url] en el navegador del sistema de forma compatible con todos los
/// navegadores web (Chrome, Firefox, Safari) y plataformas nativas.
///
/// Devuelve `true` si el enlace se pudo abrir, `false` en caso de error.
Future<bool> openUrl(String url) async {
  if (url.isEmpty) return false;

  if (kIsWeb) {
    try {
      // Crear un <a> y clickarlo — no activa popup blocker en ningún navegador
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..target = '_blank'
        ..rel = 'noopener noreferrer';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      return true;
    } catch (e) {
      // Fallback a launchUrl si el DOM no está disponible por algún motivo
      try {
        return await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.platformDefault,
        );
      } catch (_) {
        return false;
      }
    }
  }

  // Nativo (Android, iOS, Windows, macOS, Linux)
  try {
    final uri = Uri.parse(url);
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

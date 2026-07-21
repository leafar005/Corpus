import 'package:flutter/foundation.dart';
import 'theme/app_theme.dart';

// Notificador global. Lo incrementaremos cada vez que el usuario añada/edite un juego en su biblioteca.
// Cualquier pantalla que necesite refrescarse (como ProfileScreen o HomeScreen) puede escuchar este notificador.
final ValueNotifier<int> libraryUpdateNotifier = ValueNotifier<int>(0);

// Notificador global para el tema claro/oscuro
final ThemeNotifier themeNotifier = ThemeNotifier();

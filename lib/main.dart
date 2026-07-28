import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/main_screen.dart';
import 'env.dart';
import 'theme/app_theme.dart';

import 'globals.dart';

void main() async {
  // 1. Asegura que los motores de Flutter están listos
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializa la conexión con Supabase
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  // 3. Arranca la interfaz gráfica
  runApp(const CorpusApp());
}

class CorpusApp extends StatelessWidget {
  const CorpusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, child) {
        return MaterialApp(
          title: 'Corpus',
          // Aplicamos nuestros temas y el modo seleccionado
          theme: AppTheme.getLightTheme(themeNotifier.seedColor),
          darkTheme: AppTheme.getDarkTheme(themeNotifier.seedColor),
          themeMode: themeNotifier.currentMode,
          home: kIsWeb
              ? const SelectionArea(child: AuthGate())
              : const AuthGate(),
        );
      },
    );
  }
}

// El AuthGate es un "vigilante". Comprueba en tiempo real si estás logueado o no.
class AuthGate extends StatelessWidget {
  final Stream<AuthState>? authStream;
  const AuthGate({super.key, this.authStream});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder escucha los cambios de estado de Supabase continuamente
    return StreamBuilder<AuthState>(
      stream: authStream ?? Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Mientras comprueba si hay sesión guardada, muestra un circulito de carga
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Con sesión o sin ella, entramos siempre a MainScreen.
        // Las pantallas que necesitan cuenta (Perfil, Actividad, añadir a
        // biblioteca...) detectan el modo invitado por su cuenta y
        // muestran un aviso con botón de "Iniciar sesión" en su lugar.
        return MainScreen(
          key: ValueKey(snapshot.data?.session?.user.id),
        );
      },
    );
  }
}

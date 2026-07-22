import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/main_screen.dart';
import 'env.dart';
import 'screens/auth/login_screen.dart';
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
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
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
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder escucha los cambios de estado de Supabase continuamente
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Mientras comprueba si hay sesión guardada, muestra un circulito de carga
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final session = snapshot.hasData ? snapshot.data!.session : null;
        
        if (session != null) {
          // Si hay sesión, dejamos pasar al usuario a la app principal.
          return const MainScreen();
        }
        
        // Si no hay sesión, al Login de cabeza
        return const LoginScreen();
      },
    );
  }
}

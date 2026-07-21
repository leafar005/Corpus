import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';
import 'screens/auth/login_screen.dart';
import 'screens/library/library_screen.dart';

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
    return MaterialApp(
      title: 'Corpus',
      // ¡Configuramos un tema oscuro y elegante con toques morados!
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const SelectionArea(
        child: AuthGate(),
      ),
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
          return const LibraryScreen();
        }
        
        // Si no hay sesión, al Login de cabeza
        return const LoginScreen();
      },
    );
  }
}

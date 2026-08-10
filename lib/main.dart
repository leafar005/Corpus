import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/main_screen.dart';
import 'env.dart';
import 'theme/app_theme.dart';
import 'theme/style_pack_registry.dart';
import 'services/notification_service.dart';
import 'services/style_pack_music_service.dart';

import 'globals.dart';

void main() async {
  // 1. Asegura que los motores de Flutter están listos
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Valida que todas las variables de entorno necesarias fueron inyectadas.
  //    Falla rápido con un mensaje claro si falta alguna.
  //    Ejecutar con: flutter run --dart-define-from-file=.env.json
  Env.assertConfigured();

  // 3. Inicializa Firebase
  if (kIsWeb) {
    // En web: la configuración viene de variables de entorno (Env.*)
    // ya que google-services.json no aplica en web.
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        authDomain: Env.firebaseAuthDomain,
        projectId: Env.firebaseProjectId,
        storageBucket: Env.firebaseStorageBucket,
        messagingSenderId: Env.firebaseMessagingSenderId,
        appId: Env.firebaseAppId,
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  // 4. Inicializa la conexión con Supabase
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  // 5. Carga packs importados por el usuario
  await StylePackRegistry.loadImported();
  await themeNotifier.initialize();
  await StylePackMusicService.instance.init(themeNotifier);

  // 6. Inicializa el servicio de notificaciones (Android + Windows + Web)
  await NotificationService().init();

  // 7. Arranca la interfaz gráfica
  runApp(const CorpusApp());
}

class CorpusApp extends StatefulWidget {
  const CorpusApp({super.key});

  @override
  State<CorpusApp> createState() => _CorpusAppState();
}

class _CorpusAppState extends State<CorpusApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StylePackMusicService.instance.syncWithCurrentPack(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, child) {
        return MaterialApp(
          title: 'Corpus',
          // Aplicamos nuestros temas y el modo seleccionado
          theme: AppTheme.getLightTheme(themeNotifier.seedColor, themeNotifier.currentPack),
          darkTheme: AppTheme.getDarkTheme(themeNotifier.seedColor, themeNotifier.currentPack),
          themeMode: themeNotifier.currentMode,
          scrollBehavior: const AlwaysScrollbarBehavior(),
          home: const AuthGate(),
        );
      },
    );
  }
}

// El AuthGate es un "vigilante". Comprueba en tiempo real si estás logueado o no.
class AuthGate extends StatefulWidget {
  final Stream<AuthState>? authStream;
  const AuthGate({super.key, this.authStream});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  RealtimeChannel? _presenceChannel;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Registramos el observador del ciclo de vida de la app
    WidgetsBinding.instance.addObserver(this);

    // Escuchamos el estado de autenticación para rastrear o limpiar la presencia
    _authSub =
        (widget.authStream ?? Supabase.instance.client.auth.onAuthStateChange)
            .listen((data) {
              if (data.session?.user != null) {
                _setupPresence();
              } else {
                _cleanupPresence();
              }
            });
  }

  void _setupPresence() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    // Si no hay usuario o el canal ya está configurado, salimos temprano
    if (userId == null || _presenceChannel != null) return;

    // Pedir permisos de notificación y guardar token FCM (solo la primera vez)
    final notifService = NotificationService();
    await notifService.requestPermissions();
    await notifService.saveFcmToken();

    // Inicializamos el canal de presencia en tiempo real
    _presenceChannel = Supabase.instance.client.channel('online-users');

    _presenceChannel!
        .onPresenceSync((_) {
          final state = _presenceChannel!.presenceState();
          final onlineIds = <String>{};

          for (final presenceState in state) {
            for (final presence in presenceState.presences) {
              if (presence.payload['user_id'] != null) {
                onlineIds.add(presence.payload['user_id'] as String);
              }
            }
          }

          // Actualizamos el notificador global con los amigos conectados
          onlineUsersNotifier.value = onlineIds;
        })
        .subscribe((status, [error]) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await _presenceChannel!.track({'user_id': userId});
          }
        });
  }

  void _cleanupPresence() {
    _presenceChannel?.untrack();
    _presenceChannel?.unsubscribe();
    _presenceChannel = null;
    onlineUsersNotifier.value = {};
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si la app se vuelve a abrir, reconectamos. Si se minimiza o cierra, nos desconectamos.
    if (state == AppLifecycleState.resumed) {
      _setupPresence();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _presenceChannel?.untrack();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupPresence();
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mantenemos tu UI original mientras verifica la sesión
    return StreamBuilder<AuthState>(
      stream:
          widget.authStream ?? Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final session = snapshot.hasData ? snapshot.data!.session : null;
        if (session != null) {
          return MainScreen(key: ValueKey(session.user.id));
        } else {
          return const MainScreen(key: ValueKey('guest'));
        }
      },
    );
  }
}

/// Fuerzas a que la app pinte barras de scroll en cualquier plataforma,
/// incluyendo iOS y Android (ya sea nativo o web en móvil), en los listados
/// que lo permitan.
class AlwaysScrollbarBehavior extends MaterialScrollBehavior {
  const AlwaysScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (axisDirectionToAxis(details.direction) == Axis.horizontal) {
      return child;
    }

    final controller = details.controller;
    if (controller != null) {
      try {
        if (controller.positions.length > 1) {
          return child;
        }
      } catch (_) {}
    }

    return Scrollbar(controller: controller, child: child);
  }
}

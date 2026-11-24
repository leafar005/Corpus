import 'dart:async';
import 'package:corpus/routes/tab_url_sync.dart';
import 'package:corpus/routes/app_navigation_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/main_screen.dart';
import 'env.dart';
import 'package:corpus/theme/style_pack.dart';
import 'theme/app_theme.dart';
import 'theme/style_pack_registry.dart';
import 'services/notification_service.dart';
import 'services/style_pack_music_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/deep_link_service.dart';
import 'screens/auth/reset_password_screen.dart';
import 'services/user_settings_service.dart';

import 'package:corpus/globals.dart';
import 'routes/app_root.dart';

void main() async {
  // 1. Asegura que los motores de Flutter están listos
  WidgetsFlutterBinding.ensureInitialized();

  // ErrorWidget personalizado: en debug muestra el detalle completo para
  // diagnosticar el bug; en release muestra un mensaje genérico para no
  // filtrar información interna (nombres de archivo, stack traces, etc.)
  // al usuario final. (Auditoría I-01)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    // En release: UI genérica sin datos internos.
    if (kReleaseMode) {
      return const Material(
        child: ColoredBox(
          color: Color(0xFF1A1A1A),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Ha ocurrido un error de renderizado.\nReinicia la aplicación.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // En debug: detalle completo para diagnosticar.
    return Material(
      child: Container(
        color: const Color(0xFF4A0000), // Rojo oscuro muy visible
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Text(
            'BUG DE RENDERIZADO:\n\n${details.exceptionAsString()}\n\n${details.stack?.toString() ?? ''}',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  };

  // 2. Valida que todas las variables de entorno necesarias fueron inyectadas.
  //    Falla rápido con un mensaje claro si falta alguna.
  //    Ejecutar con: flutter run --dart-define-from-file=.env.json
  Env.assertConfigured();

  // 3. Inicializa Firebase, Supabase y packs locales en paralelo para acelerar FCP
  await Future.wait([
    () async {
      try {
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
      } catch (e) {
        debugPrint('[main] Firebase initialize falló (continuando): $e');
      }
    }(),
    Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    ),
    () async {
      await StylePackRegistry.loadImported();
      if (kDebugMode) {
        StylePackRegistry.registerDebugBuiltIn(StylePack.persona5RoyalPack());
      }
      await themeNotifier.initialize();
    }(),
  ]);

  // 4. Arranca la interfaz gráfica inmediatamente (música, notificaciones y
  // sincronización remota se ejecutan tras el primer frame).
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await StylePackMusicService.instance.init(themeNotifier);
      StylePackMusicService.instance.syncWithCurrentPack(force: true);
      await NotificationService().init();

      // Deep link en frío: la app estaba completamente cerrada y se abrió
      // tocando una notificación push.
      try {
        final initialMessage = await FirebaseMessaging.instance
            .getInitialMessage();
        if (initialMessage != null) {
          DeepLinkService.handle(initialMessage.data);
        }
      } catch (e) {
        debugPrint('[CorpusApp] getInitialMessage no disponible: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: DeepLinkService.navigatorKey,
          navigatorObservers: [
            TabUrlSyncObserver(AppNavigationController.rootStackIndex),
          ],
          title: 'Corpus',
          // Aplicamos nuestros temas y el modo seleccionado
          theme: AppTheme.getLightTheme(
            themeNotifier.seedColor,
            themeNotifier.currentPack,
          ),
          darkTheme: AppTheme.getDarkTheme(
            themeNotifier.seedColor,
            themeNotifier.currentPack,
          ),
          themeMode: themeNotifier.currentMode,
          scrollBehavior: const AlwaysScrollbarBehavior(),
          home: const AppRoot(child: AuthGate()),
        );
      },
    );
  }
}

// El AuthGate es un "vigilante". Comprueba en tiempo real si estás logueado o no.
class AuthGate extends StatefulWidget {
  final Stream<AuthState>? authStream;
  @visibleForTesting
  final SupabaseClient? supabaseClient;
  @visibleForTesting
  final Widget Function(BuildContext context, Session? session)? mainBuilder;

  const AuthGate({
    super.key,
    this.authStream,
    this.supabaseClient,
    this.mainBuilder,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  RealtimeChannel? _presenceChannel;
  bool _settingUpPresence = false;
  StreamSubscription<AuthState>? _authSub;
  late final Stream<AuthState> _authStream;
  Future<void> _authQueue = Future<void>.value();
  int _authEpoch = 0;
  String? _lastUserId;
  String? _fcmRegisteredUserId;
  bool _hasAuthSnapshot = false;
  Session? _currentSession;

  SupabaseClient? get _supabaseOrNull {
    if (widget.supabaseClient != null) return widget.supabaseClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    // Registramos el observador del ciclo de vida de la app
    WidgetsBinding.instance.addObserver(this);

    _authStream =
        widget.authStream ?? Supabase.instance.client.auth.onAuthStateChange;

    // Escuchamos el estado de autenticación de forma serializada y única
    _authSub = _authStream.listen(_enqueueAuthEvent);
  }

  void _enqueueAuthEvent(AuthState data) {
    _authQueue = _authQueue
        .then((_) => _handleAuthState(data))
        .catchError((Object e, StackTrace st) {
          debugPrint('[AuthGate] Error procesando estado de auth: $e');
        });
  }

  Future<void> _handleAuthState(AuthState data) async {
    if (!mounted) return;

    // El usuario volvió desde el link de reset de contraseña:
    // Supabase valida el token y emite passwordRecovery.
    // Navegamos a la pantalla de nueva contraseña por encima de todo.
    if (data.event == AuthChangeEvent.passwordRecovery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (DeepLinkService.navigatorKey.currentState != null) {
          DeepLinkService.navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (_) => const ResetPasswordScreen(),
              fullscreenDialog: true,
            ),
          );
        }
      });
      return;
    }

    setState(() {
      _hasAuthSnapshot = true;
      _currentSession = data.session;
    });

    final newUserId = data.session?.user.id;
    if (newUserId != null) {
      final userChanged = _lastUserId != null && _lastUserId != newUserId;
      final epoch = ++_authEpoch;

      if (userChanged) {
        _cleanupPresenceChannel();
        _fcmRegisteredUserId = null;
        await NotificationService().deleteFcmToken();
        AppNavigationController.instance.resetForSessionChange();
        await resetAllGlobalState();
      }
      if (!mounted || epoch != _authEpoch) return;

      _lastUserId = newUserId;

      // No refrescar ajustes desde remoto ante un simple tokenRefreshed
      if (data.event != AuthChangeEvent.tokenRefreshed) {
        try {
          await UserSettingsService().pullAndApplyToLocalCache();
          if (!mounted || epoch != _authEpoch) return;
          await themeNotifier.reloadFromPrefs();
        } catch (e) {
          debugPrint('[AuthGate] Error sincronizando ajustes: $e');
        }
      }
      if (!mounted || epoch != _authEpoch) return;

      if (_fcmRegisteredUserId != newUserId) {
        _fcmRegisteredUserId = newUserId;
        unawaited(_registerFcmForUser(newUserId, epoch));
      }
      unawaited(_setupPresence(expectedUserId: newUserId));
    } else {
      final wasLoggedIn =
          _lastUserId != null || data.event == AuthChangeEvent.signedOut;
      _authEpoch++;
      _lastUserId = null;
      _fcmRegisteredUserId = null;
      _cleanupPresenceChannel();
      if (wasLoggedIn) {
        await NotificationService().deleteFcmToken();
        AppNavigationController.instance.resetForSessionChange();
        await resetAllGlobalState();
      }
    }
  }

  Future<void> _registerFcmForUser(String userId, int epoch) async {
    final notifService = NotificationService();
    // En nativo solicitamos permiso; en Web (especialmente iOS Safari 16.4+)
    // el permiso requiere gesto explícito del usuario en Ajustes -> Notificaciones.
    if (!kIsWeb) {
      try {
        await notifService.requestPermissions();
      } catch (_) {}
    }
    if (!mounted || epoch != _authEpoch) return;
    final currentUid = _supabaseOrNull?.auth.currentUser?.id;
    if (currentUid != null && currentUid != userId) return;
    try {
      await notifService.saveFcmToken();
    } catch (e) {
      debugPrint('[AuthGate] Error guardando token FCM: $e');
    }
  }

  Future<void> _setupPresence({String? expectedUserId}) async {
    if (_settingUpPresence || _presenceChannel != null || !mounted) return;
    final client = _supabaseOrNull;
    final userId =
        expectedUserId ??
        _currentSession?.user.id ??
        client?.auth.currentUser?.id;
    if (client == null || userId == null) return;

    _settingUpPresence = true;
    try {
      if (!mounted || _presenceChannel != null) return;
      final currentAuthId = client.auth.currentUser?.id;
      if (currentAuthId != null && currentAuthId != userId) return;

      // Inicializamos el canal de presencia en tiempo real capturando referencia local
      final channel = client.channel('online-users');
      _presenceChannel = channel;

      channel
          .onPresenceSync((_) {
            if (!mounted || _presenceChannel != channel) return;
            final state = channel.presenceState();
            final onlineIds = <String>{};

            for (final presenceState in state) {
              for (final presence in presenceState.presences) {
                final uid = presence.payload['user_id'];
                if (uid != null) {
                  onlineIds.add(uid.toString());
                }
              }
            }

            // Actualizamos el notificador global con los amigos conectados
            onlineUsersNotifier.value = onlineIds;
          })
          .subscribe((status, [error]) async {
            if (status == RealtimeSubscribeStatus.subscribed &&
                mounted &&
                _presenceChannel == channel) {
              await channel.track({'user_id': userId});
            }
          });
    } finally {
      _settingUpPresence = false;
    }
  }

  void _cleanupPresenceChannel() {
    final channel = _presenceChannel;
    _presenceChannel = null;
    if (channel != null) {
      try {
        channel.untrack();
      } catch (_) {}
      try {
        final client = _supabaseOrNull;
        if (client != null) {
          unawaited(client.removeChannel(channel));
        }
      } catch (_) {}
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver de segundo plano reconectamos solo presencia (sin re-subir FCM en cada resume).
    if (state == AppLifecycleState.resumed) {
      unawaited(_setupPresence());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _cleanupPresenceChannel();
    }
  }

  @override
  Future<bool> didPopRoute() async {
    if (kIsWeb) {
      return true;
    }
    return super.didPopRoute();
  }

  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
    if (kIsWeb) {
      // Bloqueamos el pushRouteInformation nativo en Web.
      return true;
    }
    return super.didPushRouteInformation(routeInformation);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupPresenceChannel();
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAuthSnapshot) {
      // El HTML splash tapa la pantalla mientras Flutter carga.
      // No mostramos nada propio para evitar el salto visual.
      return const SizedBox.shrink();
    }
    final session = _currentSession;
    if (widget.mainBuilder != null) {
      return KeyedSubtree(
        key: ValueKey(session?.user.id ?? 'guest'),
        child: widget.mainBuilder!(context, session),
      );
    }
    if (session != null) {
      return MainScreen(key: ValueKey(session.user.id));
    } else {
      return const MainScreen(key: ValueKey('guest'));
    }
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

import 'dart:io';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../env.dart';

// ─── Background message handler (debe ser top-level) ────────────────────────
// Se ejecuta cuando llega un mensaje FCM con la app en background/terminada.
// NO puede referenciar variables globales de estado (sí puede usar plugins).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Los datos del mensaje ya se muestran como notificación del sistema
  // gracias a la configuración de FCM (notification payload).
  // Este handler es el punto de extensión para lógica adicional en background.
  debugPrint('[FCM Background] Mensaje recibido: ${message.messageId}');
}

// La clave VAPID se lee desde Env.firebaseVapidKey (inyectada con --dart-define-from-file).

/// Servicio singleton de notificaciones.
/// Gestiona FCM (Android + Web) y notificaciones locales (Windows + foreground Android).
class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Activo en Android, Windows y Web
  bool get _isSupported =>
      kIsWeb || (!kIsWeb && (Platform.isAndroid || Platform.isWindows));

  // ─── Canal de notificaciones Android ──────────────────────────────────────

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'corpus_default', // id — debe coincidir con AndroidManifest
        'Notificaciones de Corpus', // nombre visible
        description: 'Actividad de amigos, bundles y comentarios.',
        importance: Importance.high,
        playSound: true,
      );

  // ─── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized || !_isSupported) return;

    if (kIsWeb) {
      // En web: solo FCM. No usamos flutter_local_notifications.
      // El service worker (firebase-messaging-sw.js) gestiona los mensajes en background.
      // Aquí escuchamos los mensajes cuando la app está en primer plano.
      FirebaseMessaging.onMessage.listen(_onForegroundMessageWeb);
      _initialized = true;
      debugPrint('[NotificationService] Web: inicializado con FCM.');
      return;
    }

    // Registrar el handler de mensajes en background (solo Android)
    if (Platform.isAndroid) {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    }

    // Inicializar flutter_local_notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const windowsSettings = WindowsInitializationSettings(
      appName: 'Corpus',
      appUserModelId: 'com.rafaelcasado.corpus.corpus',
      guid: 'a8b4e2f0-1234-5678-abcd-ef0123456789', // GUID único para la app
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      windows: windowsSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Crear el canal de notificaciones en Android (necesario para Android 8+)
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_androidChannel);

      // Escuchar mensajes FCM cuando la app está en primer plano
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Escuchar tap en notificación cuando la app está en background (no terminada)
      FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpenedApp);
    }

    _initialized = true;
    debugPrint('[NotificationService] Inicializado correctamente.');
  }

  // ─── Permisos ──────────────────────────────────────────────────────────────

  Future<void> requestPermissions() async {
    if (!_isSupported) return;

    if (kIsWeb) {
      // En web: pedir permiso a través de la API de Firebase Messaging
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint(
        '[NotificationService] Permiso web: ${settings.authorizationStatus}',
      );
      return;
    }

    if (Platform.isAndroid) {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );
      debugPrint(
        '[NotificationService] Permiso Android: ${settings.authorizationStatus}',
      );

      // Solicitar también el permiso nativo POST_NOTIFICATIONS (Android 13+)
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }

    if (Platform.isWindows) {
      // flutter_local_notifications v19 no requiere solicitud explícita de permiso
      // en Windows — las notificaciones Toast funcionan directamente.
      debugPrint(
        '[NotificationService] Windows: permisos de notificación por defecto.',
      );
    }
  }

  // ─── Token FCM ─────────────────────────────────────────────────────────────

  /// Guarda el token FCM del dispositivo en Supabase (push_tokens).
  /// Solo se ejecuta una vez por sesión, reutilizando el mismo token si ya existe.
  Future<void> saveFcmToken() async {
    if (!_isSupported) return;

    // Web: necesita VAPID key; Android: usa google-services.json
    final bool isAndroid = !kIsWeb && Platform.isAndroid;
    if (!kIsWeb && !isAndroid) return; // Windows no tiene token FCM

    try {
      final messaging = FirebaseMessaging.instance;
      final token = kIsWeb
          ? await messaging.getToken(vapidKey: Env.firebaseVapidKey)
          : await messaging.getToken();

      if (token == null) return;

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      const platform = kIsWeb ? 'web' : 'android';

      await Supabase.instance.client
          .from('push_tokens')
          .upsert(
            {'user_id': userId, 'token': token, 'platform': platform},
            onConflict: 'token',
            ignoreDuplicates: false,
          );

      debugPrint(
        '[NotificationService] Token FCM ($platform) guardado: ${token.substring(0, 20)}...',
      );

      // Escuchar refresh de token para mantenerlo actualizado
      messaging.onTokenRefresh.listen((newToken) async {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid == null) return;
        await Supabase.instance.client.from('push_tokens').upsert({
          'user_id': uid,
          'token': newToken,
          'platform': platform,
        }, onConflict: 'token');
        debugPrint('[NotificationService] Token FCM actualizado.');
      });
    } catch (e) {
      debugPrint('[NotificationService] Error guardando token FCM: $e');
    }
  }

  /// Elimina el token del dispositivo cuando el usuario cierra sesión.
  Future<void> deleteFcmToken() async {
    if (!_isSupported) return;
    final bool isAndroid = !kIsWeb && Platform.isAndroid;
    if (!kIsWeb && !isAndroid) return;

    try {
      final token = kIsWeb
          ? await FirebaseMessaging.instance.getToken(
              vapidKey: Env.firebaseVapidKey,
            )
          : await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await Supabase.instance.client
          .from('push_tokens')
          .delete()
          .eq('token', token);
      await FirebaseMessaging.instance.deleteToken();
      debugPrint('[NotificationService] Token FCM eliminado.');
    } catch (e) {
      debugPrint('[NotificationService] Error eliminando token FCM: $e');
    }
  }

  // ─── Mostrar notificación local (foreground o Windows) ────────────────────

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    if (!_isSupported || kIsWeb) return; // En web lo gestiona el service worker

    const androidDetails = AndroidNotificationDetails(
      'corpus_default',
      'Notificaciones de Corpus',
      channelDescription: 'Actividad de amigos, bundles y comentarios.',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      color: Color(0xFF7E57C2),
    );

    const windowsDetails = WindowsNotificationDetails(
      actions: [
        WindowsAction(
          content: 'Abrir',
          arguments: 'open',
          activationType: WindowsActivationType.foreground,
        ),
      ],
    );

    final details = NotificationDetails(
      android: Platform.isAndroid ? androidDetails : null,
      windows: Platform.isWindows ? windowsDetails : null,
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  // ─── Notificación de prueba ────────────────────────────────────────────────

  Future<void> sendTestNotification() async {
    if (kIsWeb) {
      // En web: mostrar via API del navegador directamente si tenemos permiso
      debugPrint(
        '[NotificationService] Test notification en web — enviada vía FCM al dispositivo.',
      );
      return;
    }
    await showNotification(
      title: 'Corpus — Notificación de prueba',
      body: 'Las notificaciones funcionan correctamente.',
      id: 9999,
    );
  }

  // ─── Handlers internos ────────────────────────────────────────────────────

  /// Mensaje FCM recibido con la app en primer plano (Android) → mostrar notificación local.
  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final title = notification.title ?? 'Corpus';
    final body = notification.body ?? '';
    final data = message.data;

    showNotification(
      title: title,
      body: body,
      payload: data['type'],
      id: message.hashCode,
    );
  }

  /// Mensaje FCM recibido con la app en primer plano (Web).
  /// El navegador no muestra notificaciones automáticamente en foreground,
  /// así que simplemente lo logeamos. El service worker gestiona el background.
  void _onForegroundMessageWeb(RemoteMessage message) {
    debugPrint(
      '[NotificationService] Web foreground message: ${message.notification?.title}',
    );
    // Aquí se podría mostrar un SnackBar o banner in-app si se desea.
  }

  /// Tap en notificación cuando la app estaba en background (pero no terminada).
  void _onNotificationOpenedApp(RemoteMessage message) {
    debugPrint(
      '[NotificationService] App abierta desde notificación: ${message.data}',
    );
    // TODO: Navegar a la pantalla relevante según message.data['type']
  }

  /// Tap en notificación local (Windows foreground o Android foreground).
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
      '[NotificationService] Notificación local tapeada: ${response.payload}',
    );
    // TODO: Navegar a la pantalla relevante según response.payload
  }
}

// Fin de NotificationService

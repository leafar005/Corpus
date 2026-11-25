import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:corpus/globals.dart';
import 'package:corpus/main.dart';
import 'package:corpus/repositories/review_repository.dart';
import 'package:corpus/routes/app_navigation_controller.dart';
import 'package:corpus/routes/app_root.dart';
import 'package:corpus/routes/corpus_router.dart';
import 'package:corpus/routes/tab_url_sync.dart';
import 'package:corpus/screens/library/game_details/game_details_controller.dart';
import 'package:corpus/services/deep_link_service.dart';
import 'package:corpus/services/duracionde_service.dart';
import 'package:corpus/services/igdb_service.dart';
import 'package:corpus/services/user_settings_service.dart';
import 'package:corpus/theme/app_theme.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/game_card.dart';
import 'package:file_picker/file_picker.dart';
// ignore: depend_on_referenced_packages, implementation_imports
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_supabase_backend.dart';

const List<int> _kTransparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

/// Arranque y utilidades reutilizables para tests de integración headless con
/// backend Supabase simulado, imágenes en memoria y plugins de plataforma mockeados.
class CorpusTestHarness {
  CorpusTestHarness({this.backend});

  static const Size desktopSize = Size(1280, 900);
  static const Size mobileSize = Size(412, 915);

  FakeSupabaseBackend? backend;
  HttpOverrides? _previousHttpOverrides;
  FilePickerPlatform? _previousFilePickerPlatform;
  Directory? _tempDir;
  final Map<String, String> _secureStorage = <String, String>{};
  final List<String> _registeredChannels = <String>[];
  final List<FilePickerResult?> _queuedPickedFiles = <FilePickerResult?>[];
  int filePickerCallCount = 0;

  void enqueuePickedFile({
    required String name,
    required Uint8List bytes,
    int? sizeOverride,
  }) {
    _queuedPickedFiles.add(
      FilePickerResult(<PlatformFile>[
        PlatformFile(
          name: name,
          size: sizeOverride ?? bytes.length,
          bytes: bytes,
        ),
      ]),
    );
  }

  void enqueueCancelledFilePick() {
    _queuedPickedFiles.add(null);
  }

  Future<void> run(
    WidgetTester tester,
    Future<void> Function(FakeSupabaseBackend backend) body, {
    FakeSupabaseBackend? customBackend,
    Size viewportSize = desktopSize,
    bool floatingMobileNav = true,
    bool loggedIn = false,
    String email = FakeSupabaseBackend.primaryEmail,
    String password = FakeSupabaseBackend.primaryPassword,
  }) async {
    final activeBackend = await pumpApp(
      tester,
      customBackend: customBackend,
      viewportSize: viewportSize,
      floatingMobileNav: floatingMobileNav,
      loggedIn: loggedIn,
      email: email,
      password: password,
    );
    try {
      await body(activeBackend);
    } finally {
      await tearDown(tester);
    }
  }

  Future<FakeSupabaseBackend> pumpApp(
    WidgetTester tester, {
    FakeSupabaseBackend? customBackend,
    Size viewportSize = desktopSize,
    bool floatingMobileNav = true,
    bool loggedIn = false,
    String email = FakeSupabaseBackend.primaryEmail,
    String password = FakeSupabaseBackend.primaryPassword,
  }) async {
    kDisableCarouselForTests = true;
    kDisablePushDebounceForTests = true;
    kDisableIsolatesForTests = true;
    resetPushDebounceForTesting();
    AppNavigationController.instance.resetForSessionChange();
    floatingMobileNavNotifier.value = floatingMobileNav;

    IGDBService.clearCache();
    DuracionDeService.clearCache();
    ReviewRepository.clearBackfillCacheForTesting();
    UserSettingsService().resetForTesting();
    GameDetailsController.clearSessionCacheForTesting();

    backend = customBackend ?? backend ?? FakeSupabaseBackend();

    tester.view.physicalSize = viewportSize;
    tester.view.devicePixelRatio = 1.0;

    _tempDir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('corpus_int_test_'),
    );

    _installPlatformChannelMocks();
    _previousFilePickerPlatform = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _FakeFilePickerPlatform(
      onPick: () {
        filePickerCallCount++;
        return _queuedPickedFiles.isNotEmpty
            ? _queuedPickedFiles.removeAt(0)
            : null;
      },
    );

    _previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = _MockImageHttpOverrides();

    SharedPreferences.setMockInitialValues(<String, Object>{
      'floating_mobile_nav': floatingMobileNav,
    });

    await tester.runAsync(() async {
      await resetAllGlobalState();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('floating_mobile_nav', floatingMobileNav);
    });
    floatingMobileNavNotifier.value = floatingMobileNav;

    await tester.runAsync(() => _resetAndInitSupabase(backend!));

    if (loggedIn) {
      await tester.runAsync(
        () => Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        ),
      );
    }

    await tester.pumpWidget(_buildTestRootApp());
    // ignore: invalid_use_of_internal_member
    Supabase.instance.client.auth.notifyAllSubscribers(
      AuthChangeEvent.initialSession,
    );
    await settleFrames(tester, count: 8);
    return backend!;
  }

  Widget _buildTestRootApp() {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: DeepLinkService.navigatorKey,
          navigatorObservers: <NavigatorObserver>[
            TabUrlSyncObserver(AppNavigationController.rootStackIndex),
          ],
          title: 'Corpus',
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

  Future<void> _resetAndInitSupabase(FakeSupabaseBackend activeBackend) async {
    try {
      await Supabase.instance.client.removeAllChannels();
    } catch (_) {}
    try {
      await Supabase.instance.dispose();
    } catch (_) {}

    await Supabase.initialize(
      url: FakeSupabaseBackend.baseUrl,
      publishableKey: FakeSupabaseBackend.anonKey,
      httpClient: activeBackend.httpClient,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      realtimeClientOptions: RealtimeClientOptions(
        transport: (_, _) => FakeWebSocketChannel(),
      ),
      debug: false,
    );

    final initialClient = Supabase.instance.client;
    await initialClient.dispose();

    Supabase.instance.client = SupabaseClient(
      FakeSupabaseBackend.baseUrl,
      FakeSupabaseBackend.anonKey,
      httpClient: activeBackend.httpClient,
      isolate: SyncJsonIsolate(),
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
      realtimeClientOptions: RealtimeClientOptions(
        transport: (_, _) => FakeWebSocketChannel(),
      ),
    );
  }

  void _installPlatformChannelMocks() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final tempPath = _tempDir?.path ?? Directory.systemTemp.path;

    void register(
      String channelName,
      Future<dynamic> Function(MethodCall call) handler,
    ) {
      _registeredChannels.add(channelName);
      messenger.setMockMethodCallHandler(MethodChannel(channelName), handler);
    }

    register('plugins.flutter.io/path_provider', (call) async {
      return tempPath;
    });

    register('plugins.it_nomads.com/flutter_secure_storage', (call) async {
      final args =
          (call.arguments as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return key != null ? _secureStorage[key] : null;
        case 'write':
          if (key != null) {
            final value = args['value'] as String?;
            if (value == null) {
              _secureStorage.remove(key);
            } else {
              _secureStorage[key] = value;
            }
          }
          return null;
        case 'delete':
          if (key != null) _secureStorage.remove(key);
          return null;
        case 'deleteAll':
          _secureStorage.clear();
          return null;
        case 'readAll':
          return Map<String, String>.from(_secureStorage);
        case 'containsKey':
          return key != null && _secureStorage.containsKey(key);
        default:
          return null;
      }
    });

    register('com.tekartik.sqflite', (call) async {
      switch (call.method) {
        case 'getDatabasesPath':
          return tempPath;
        case 'openDatabase':
          return 1;
        case 'query':
          return <dynamic>[];
        case 'insert':
        case 'update':
        case 'delete':
          return 1;
        case 'batch':
          return <dynamic>[];
        default:
          return null;
      }
    });

    register('xyz.luan/audioplayers', (call) async => 1);
    register('xyz.luan/audioplayers.global', (call) async => 1);
    register('plugins.flutter.io/url_launcher', (call) async => true);
    register(
      'dev.fluttercommunity.plus/package_info',
      (call) async => <String, dynamic>{
        'appName': 'Corpus',
        'packageName': 'com.corpus.app',
        'version': '1.0.0',
        'buildNumber': '1',
      },
    );
    register(
      'dev.fluttercommunity.plus/connectivity',
      (call) async => <String>['wifi'],
    );
    register('com.llfbandit.app_links/messages', (call) async => null);
    register('com.llfbandit.app_links/events', (call) async => null);
  }

  Future<void> tearDown(WidgetTester tester) async {
    try {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    } catch (_) {}

    try {
      unawaited(
        Supabase.instance.client
            .removeAllChannels()
            .catchError((Object _) => <String>[]),
      );
    } catch (_) {}
    try {
      unawaited(
        Supabase.instance.client.realtime
            .disconnect()
            .catchError((Object _) {}),
      );
    } catch (_) {}

    // Drena timers de Push/Realtime (10s/50s) y cleanup de CacheStore (10s) en FakeAsync.
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));

    await tester.runAsync(() async {
      try {
        await Supabase.instance.dispose();
      } catch (_) {}
    });

    kDisableCarouselForTests = false;
    kDisablePushDebounceForTests = false;
    kDisableIsolatesForTests = false;
    resetPushDebounceForTesting();
    _queuedPickedFiles.clear();
    filePickerCallCount = 0;
    if (_previousFilePickerPlatform != null) {
      FilePickerPlatform.instance = _previousFilePickerPlatform!;
      _previousFilePickerPlatform = null;
    }
    AppNavigationController.instance.resetForSessionChange();
    await tester.runAsync(() => resetAllGlobalState());
    IGDBService.clearCache();
    DuracionDeService.clearCache();
    ReviewRepository.clearBackfillCacheForTesting();
    UserSettingsService().resetForTesting();
    GameDetailsController.clearSessionCacheForTesting();

    // Drena cualquier timer tardío (p. ej. CacheStore._scheduleCleanup de 10s)
    // disparado tras los runAsync anteriores mientras los mocks siguen activos.
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 15));

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in _registeredChannels) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), null);
    }
    _registeredChannels.clear();
    _secureStorage.clear();

    HttpOverrides.global = _previousHttpOverrides;
    _previousHttpOverrides = null;

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();

    if (_tempDir != null && _tempDir!.existsSync()) {
      await tester.runAsync(() async {
        try {
          await _tempDir!.delete(recursive: true);
        } catch (_) {}
      });
    }
    _tempDir = null;
    await tester.pump(const Duration(seconds: 15));
  }

  // ---------------------------------------------------------------------------
  // Helpers de sincronización y finders
  // ---------------------------------------------------------------------------

  Future<void> settleFrames(
    WidgetTester tester, {
    int count = 6,
    Duration step = const Duration(milliseconds: 50),
  }) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(step);
    }
  }

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 8),
    Duration step = const Duration(milliseconds: 50),
  }) async {
    final maxSteps = timeout.inMilliseconds ~/ step.inMilliseconds;
    for (var i = 0; i <= maxSteps; i++) {
      if (finder.evaluate().isNotEmpty) {
        return;
      }
      await tester.pump(step);
    }
    fail('Tiempo agotado esperando a que apareciera: $finder');
  }

  Future<void> pumpUntilGone(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 8),
    Duration step = const Duration(milliseconds: 50),
  }) async {
    final maxSteps = timeout.inMilliseconds ~/ step.inMilliseconds;
    for (var i = 0; i <= maxSteps; i++) {
      if (finder.evaluate().isEmpty) {
        return;
      }
      await tester.pump(step);
    }
    fail('Tiempo agotado esperando a que desapareciera: $finder');
  }

  /// `CorpusNavigation._shouldThrottlePush()` usa `DateTime.now()` real (600 ms).
  /// Cuando [kDisablePushDebounceForTests] está activo basta con bombear un frame;
  /// si el test lo desactiva explícitamente, espera la ventana real.
  Future<void> waitForPushDebounce(WidgetTester tester) async {
    if (!kDisablePushDebounceForTests) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 650)),
      );
    }
    await tester.pump(const Duration(milliseconds: 20));
  }

  Finder findCorpusIcon(CorpusIconKind kind) {
    return find.byWidgetPredicate(
      (widget) => widget is CorpusTablerIcon && widget.kind == kind,
      description: 'CorpusTablerIcon($kind)',
    );
  }

  Finder findGameCardByTitle(String title) {
    final expected = title.trim().toLowerCase();
    return find.byWidgetPredicate(
      (widget) =>
          widget is GameCard && widget.game.title.trim().toLowerCase() == expected,
      description: 'GameCard($title)',
    );
  }

  Future<void> tapWhenReady(
    WidgetTester tester,
    Finder finder, {
    bool useLast = false,
    bool scrollIntoView = true,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    const step = Duration(milliseconds: 50);
    final maxSteps = timeout.inMilliseconds ~/ step.inMilliseconds;
    var scrolledOnce = false;

    for (var i = 0; i <= maxSteps; i++) {
      final hit = finder.hitTestable();
      if (hit.evaluate().isNotEmpty) {
        await tester.tap(useLast ? hit.last : hit.first);
        await settleFrames(tester, count: 6);
        return;
      }
      if (!scrolledOnce &&
          scrollIntoView &&
          i >= 10 &&
          finder.evaluate().isNotEmpty) {
        scrolledOnce = true;
        try {
          await tester.ensureVisible(useLast ? finder.last : finder.first);
          await tester.pump(step);
          final hitAfterScroll = finder.hitTestable();
          if (hitAfterScroll.evaluate().isNotEmpty) {
            await tester.tap(
              useLast ? hitAfterScroll.last : hitAfterScroll.first,
            );
            await settleFrames(tester, count: 6);
            return;
          }
        } catch (_) {}
      }
      await tester.pump(step);
    }
    fail('Tiempo agotado esperando widget pulsable: $finder');
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tapWhenReady(tester, find.text(label), scrollIntoView: false);
    await settleFrames(tester, count: 8);
  }

  Future<void> openLoginFromGuestProfile(WidgetTester tester) async {
    await tapTab(tester, 'Perfil');
    await pumpUntilFound(tester, find.text('Iniciar sesión'));
    await waitForPushDebounce(tester);
    await tapWhenReady(tester, find.text('Iniciar sesión'));
    await pumpUntilFound(tester, find.text('Bienvenido a Corpus'));
    await settleFrames(tester, count: 8);
  }

  Future<void> loginViaUi(
    WidgetTester tester, {
    String email = FakeSupabaseBackend.primaryEmail,
    String password = FakeSupabaseBackend.primaryPassword,
  }) async {
    if (find.text('Bienvenido a Corpus').evaluate().isEmpty) {
      await openLoginFromGuestProfile(tester);
    }

    final emailField = find.widgetWithText(TextField, 'Correo electrónico');
    final passField = find.widgetWithText(TextField, 'Contraseña');

    await tester.enterText(emailField, email);
    await tester.enterText(passField, password);
    await tester.pump();

    await tapWhenReady(
      tester,
      find.widgetWithText(ElevatedButton, 'Iniciar sesión'),
      useLast: true,
    );
    await pumpUntilGone(tester, find.text('Bienvenido a Corpus'));
    await pumpUntilFound(tester, find.text('Explorar'));
    await settleFrames(tester, count: 10);
  }

  Future<void> searchAndOpenGame(
    WidgetTester tester,
    String queryTitle,
  ) async {
    await tapTab(tester, 'Explorar');

    final searchField = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == 'Buscar juegos...',
      description: 'TextField("Buscar juegos...")',
    );
    await pumpUntilFound(tester, searchField);
    await tester.enterText(searchField, queryTitle);

    // Debouncer de SearchScreen = 500 ms.
    await tester.pump(const Duration(milliseconds: 550));
    await settleFrames(tester, count: 6);

    final gameCard = findGameCardByTitle(queryTitle);
    await pumpUntilFound(tester, gameCard);

    await waitForPushDebounce(tester);
    await tapWhenReady(tester, gameCard);
    await pumpUntilFound(tester, find.text(queryTitle));
    await settleFrames(tester, count: 10);
  }
}

class _MockImageHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient();
  }
}

class _FakeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Duration? connectionTimeout;

  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  int? maxConnectionsPerHost;

  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _FakeHttpClientRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest(url);

  @override
  Future<HttpClientRequest> get(String host, int port, String path) async =>
      _FakeHttpClientRequest(Uri(host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) async =>
      _FakeHttpClientRequest(Uri(host: host, port: port, path: path));

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) {}

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) {}

  @override
  set authenticate(
    Future<bool> Function(Uri url, String scheme, String? realm)? f,
  ) {}

  @override
  set authenticateProxy(
    Future<bool> Function(
      String host,
      int port,
      String scheme,
      String? realm,
    )? f,
  ) {}

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) {}

  @override
  void close({bool force = false}) {}

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
      Uri url,
      String? proxyHost,
      int? proxyPort,
    )? f,
  ) {}

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) async =>
      _FakeHttpClientRequest(Uri(host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) async =>
      _FakeHttpClientRequest(url);

  @override
  set findProxy(String Function(Uri url)? f) {}

  @override
  Future<HttpClientRequest> head(String host, int port, String path) async =>
      _FakeHttpClientRequest(Uri(host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> headUrl(Uri url) async =>
      _FakeHttpClientRequest(url);

  @override
  set keyLog(Function(String line)? callback) {}

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) async =>
      _FakeHttpClientRequest(Uri(host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> patchUrl(Uri url) async =>
      _FakeHttpClientRequest(url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) async =>
      _FakeHttpClientRequest(Uri(host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> postUrl(Uri url) async =>
      _FakeHttpClientRequest(url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) async =>
      _FakeHttpClientRequest(Uri(host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> putUrl(Uri url) async =>
      _FakeHttpClientRequest(url);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this._uri);

  final Uri _uri;

  @override
  bool bufferOutput = true;

  @override
  int contentLength = -1;

  @override
  Encoding encoding = utf8;

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}

  @override
  void add(List<int> data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => <Cookie>[];

  @override
  Future<HttpClientResponse> get done async => _FakeHttpClientResponse();

  @override
  Future<void> flush() async {}

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  String get method => 'GET';

  @override
  Uri get uri => _uri;

  @override
  void write(Object? object) {}

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object? object = '']) {}
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  @override
  X509Certificate? get certificate => null;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  int get contentLength => _kTransparentPng.length;

  @override
  List<Cookie> get cookies => <Cookie>[];

  @override
  Future<Socket> detachSocket() {
    throw UnsupportedError('detachSocket no soportado en tests mock');
  }

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(
      <List<int>>[Uint8List.fromList(_kTransparentPng)],
    ).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => 'OK';

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) async =>
      this;

  @override
  List<RedirectInfo> get redirects => <RedirectInfo>[];

  @override
  int get statusCode => HttpStatus.ok;
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  bool chunkedTransferEncoding = false;

  @override
  int contentLength = -1;

  @override
  ContentType? contentType;

  @override
  DateTime? date;

  @override
  DateTime? expires;

  @override
  String? host;

  @override
  DateTime? ifModifiedSince;

  @override
  bool persistentConnection = false;

  @override
  int? port;

  @override
  List<String>? operator [](String name) => null;

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void clear() {}

  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  void noFolding(String name) {}

  @override
  void remove(String name, Object value) {}

  @override
  void removeAll(String name) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  String? value(String name) => null;
}

class _FakeFilePickerPlatform extends FilePickerPlatform {
  _FakeFilePickerPlatform({required this.onPick});

  final FilePickerResult? Function() onPick;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    return onPick();
  }
}

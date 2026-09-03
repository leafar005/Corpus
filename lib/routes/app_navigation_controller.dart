import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:corpus/globals.dart';
import 'package:corpus/routes/app_routes.dart';
import 'package:corpus/routes/nav_history_frame.dart';
import 'package:corpus/routes/tab_deep_route.dart';
import 'package:corpus/routes/tab_url_sync.dart';
import 'package:corpus/routes/deep_route_resolver.dart';
import 'package:corpus/utils/web_js.dart';

class AppNavigationController {
  AppNavigationController._();
  static final AppNavigationController instance = AppNavigationController._();

  /// Índice reservado para la pila del Navigator raíz de MaterialApp (la
  /// que usa DeepLinkService para pantallas abiertas desde notificaciones).
  static const int rootStackIndex = -1;

  int _nextToken = 1;

  final Map<int, List<NavHistoryFrame>> _stacks = {
    0: [],
    1: [],
    2: [],
    3: [],
    4: [],
    rootStackIndex: [],
  };

  /// true mientras se está reproduciendo un popstate: evita que los propios
  /// pop()/push() que generamos nosotros se interpreten como una acción del
  /// usuario y disparen otra vuelta de sincronización (reentrada infinita).
  bool _replaying = false;

  /// Controla si el retroceso que desencadena el popstate fue provocado por
  /// el botón "atrás" de nuestra propia UI, en lugar de por un gesto nativo
  /// o botón de atrás del propio navegador.
  bool _isProgrammaticBack = false;

  /// Registradas una sola vez al arrancar la app.
  List<GlobalKey<NavigatorState>>?
  _tabNavigatorKeys; // longitud 5, índice = pestaña
  GlobalKey<NavigatorState>? _rootNavigatorKey;

  void Function(int newTab)? onTabSwitchedByBrowser;

  void registerTabNavigatorKeys(List<GlobalKey<NavigatorState>> keys) {
    assert(keys.length == 5);
    _tabNavigatorKeys = keys;
  }

  void registerRootNavigatorKey(GlobalKey<NavigatorState> key) {
    _rootNavigatorKey = key;
  }

  NavigatorState? _navigatorFor(int stackIndex) {
    if (stackIndex == rootStackIndex) return _rootNavigatorKey?.currentState;
    final keys = _tabNavigatorKeys;
    if (keys == null || stackIndex < 0 || stackIndex >= keys.length) {
      return null;
    }
    return keys[stackIndex].currentState;
  }

  List<NavHistoryFrame> framesFor(int stackIndex) {
    return _stacks[stackIndex] ?? const [];
  }

  void truncateStack(int stackIndex, {required bool keepFirst}) {
    final frames = _stacks[stackIndex] ?? const [];
    if (frames.isEmpty) return;
    if (keepFirst) {
      _stacks[stackIndex] = [frames.first];
    } else {
      _stacks[stackIndex] = [];
    }
  }

  void replaceCurrentUrlWithRoot(int stackIndex) {
    final frames = _stacks[stackIndex] ?? const [];
    if (frames.isEmpty) return;
    final rootFrame = frames.first;
    setWebPath(
      publicPathForTabRoute(stackIndex, null),
      replace: true,
      state: {'tab': stackIndex, 'depth': 0, 'token': rootFrame.token},
    );
  }

  void onNavigatorPush(int stackIndex, Route<dynamic> route) {
    final token = _nextToken++;
    _stacks[stackIndex] = [
      ...(_stacks[stackIndex] ?? []),
      NavHistoryFrame(token: token, settings: route.settings, route: route),
    ];

    if (_replaying) return; // eco de un popstate que ya estamos procesando

    // Pestaña en segundo plano (Offstage): se contabiliza, pero no se toca
    // la URL visible hasta que el usuario vuelva a esa pestaña.
    if (stackIndex != rootStackIndex &&
        stackIndex != currentTabIndexNotifier.value) {
      return;
    }

    final depth = _stacks[stackIndex]!.length - 1;
    final subRoute = deepRouteFromRouteSettings(
      route.settings,
    ); // puede ser null

    final String path;
    if (stackIndex == rootStackIndex) {
      // Pantallas de DeepLinkService: no tienen "tab", se sincronizan sobre
      // el path visible actual sin cambiar su texto.
      path = getWebPathname() ?? '/';
    } else if (subRoute != null) {
      path = publicPathForTabRoute(stackIndex, subRoute);
    } else {
      // Ruta sin sub-URL propia (modal, bottom sheet…): no cambiamos el
      // texto visible, pero SÍ añadimos una entrada de historial nueva con
      // su propio token — así un solo atrás la deshace igual que a
      // cualquier otra (arregla el Bug D).
      path = getWebPathname() ?? publicPathForTabRoute(stackIndex, null);
    }

    // depth == 0 → ruta raíz de la pestaña: usamos replaceState para
    // sustituir la entrada inicial (p. ej. '/') por la URL canónica
    // (p. ej. '/inicio'), evitando que quede una entrada «huérfana» en
    // el historial que un «atrás» pudiera retomar.
    setWebPath(
      path,
      replace: depth == 0,
      state: {'tab': stackIndex, 'depth': depth, 'token': token},
    );
  }

  void onNavigatorPop(int stackIndex) {
    final frames = _stacks[stackIndex];
    if (frames == null || frames.isEmpty) return; // defensivo
    _stacks[stackIndex] = frames.sublist(0, frames.length - 1);
  }

  void onNavigatorReplace(int stackIndex, {required Route<dynamic> newRoute}) {
    final frames = _stacks[stackIndex];
    if (frames == null || frames.isEmpty) {
      onNavigatorPush(stackIndex, newRoute);
      return;
    }
    final last = frames.last;
    _stacks[stackIndex] = [
      ...frames.sublist(0, frames.length - 1),
      NavHistoryFrame(
        token: last.token,
        settings: newRoute.settings,
        route: newRoute,
      ),
    ];
  }

  /// Único método que cualquier control de la UI debe llamar para "ir
  /// atrás" (AppBar, PopScope, gesto de borde). Nunca se debe llamar a
  /// Navigator.pop(context) directamente para cerrar una pantalla que
  /// pertenece a una de las 5 pestañas o a la pila raíz.
  ///
  /// [forStack]: opcional. Si quien llama no tiene un BuildContext dentro
  /// del Navigator relevante (p. ej. el gesto de borde, que vive por
  /// encima de las 5 pestañas), debe indicar explícitamente qué pila
  /// quiere deshacer.
  ///
  /// Devuelve `true` si se iniciará una navegación hacia atrás (el
  /// resultado real, en web, llega de forma asíncrona vía popstate).
  /// Devuelve `false` si no hay nada que deshacer en esa pila (ya está en
  /// su raíz) — quien llama decide qué hacer en ese caso (p. ej. MainScreen
  /// cambia a la pestaña Inicio, o cierra la app).
  bool requestBack(BuildContext context, {int? forStack}) {
    if (!kIsWeb) {
      // Nativo: no hay historial de navegador, no hay nada que sincronizar.
      final nav = forStack != null
          ? _navigatorFor(forStack)
          : Navigator.of(context);
      if (nav != null && nav.canPop()) {
        nav.pop();
        return true;
      }
      return false;
    }

    final stackIndex = forStack ?? _stackIndexOf(context);
    final frames = _stacks[stackIndex] ?? const [];
    if (frames.length <= 1) return false; // ya en la raíz de esta pila

    _isProgrammaticBack = true;
    goBackInBrowserHistory(); // dispara un popstate real
    return true;
  }

  /// Deduce a qué pila pertenece un BuildContext dado, comparando su
  /// Navigator más cercano con las claves registradas. Se usa cuando
  /// [requestBack] se llama sin `forStack` (caso normal: un botón "atrás"
  /// dentro de una pantalla ya sabe en qué pestaña vive porque su propio
  /// contexto está dentro del Navigator de esa pestaña).
  int _stackIndexOf(BuildContext context) {
    final nav = Navigator.of(context);
    final keys = _tabNavigatorKeys ?? const [];
    for (var i = 0; i < keys.length; i++) {
      if (keys[i].currentState == nav) return i;
    }
    return rootStackIndex;
  }

  Future<void> handleBrowserPopState(
    Map<String, Object?>? state,
    String pathname,
  ) async {
    final isNativeBrowserBack = !_isProgrammaticBack;
    _isProgrammaticBack = false;

    try {
      final tokenObj = state?['token'];
      final tabObj = state?['tab'];
      final depthObj = state?['depth'];

      if (tokenObj != null && tabObj != null && depthObj != null) {
        final tabInt = tabObj is num ? tabObj.toInt() : int.tryParse(tabObj.toString());
        final depthInt = depthObj is num ? depthObj.toInt() : int.tryParse(depthObj.toString());
        final tokenInt = tokenObj is num ? tokenObj.toInt() : int.tryParse(tokenObj.toString());

        if (tabInt != null && depthInt != null && tokenInt != null) {
          await _handleTypedPopState(
            tab: tabInt,
            depth: depthInt,
            token: tokenInt,
            pathname: pathname,
            isNativeBrowserBack: isNativeBrowserBack,
          );
          return;
        }
      }
      
      await _handleLegacyPopState(pathname);
    } catch (e, st) {
      debugPrint('[AppNavigationController] Error parsing popstate: $e\n$st');
      // Fallback a reconstruir desde URL pura si todo lo demás falla
      try {
        final tab = AppRoutes.tabIndexFromPublicPath(pathname) ?? 0;
        await _rebuildStackFromUrl(tab, pathname);
      } catch (_) {
        // En caso catastrófico, no hacer nada y esperar nueva interacción.
      }
    }
  }

  Future<void> _handleTypedPopState({
    required int tab,
    required int depth,
    required int token,
    required String pathname,
    required bool isNativeBrowserBack,
  }) async {
    _replaying = true;
    try {
      if (tab != rootStackIndex && tab != currentTabIndexNotifier.value) {
        onTabSwitchedByBrowser?.call(tab);
      }

      final frames = _stacks[tab] ?? const [];
      final currentDepth = frames.length - 1;

      final targetFrameStillAlive =
          depth >= 0 && depth < frames.length && frames[depth].token == token;

      if (depth < currentDepth && targetFrameStillAlive) {
        // ── CAMINO RÁPIDO ────────────────────────────────────────────
        // Vamos hacia atrás y el destino sigue vivo en memoria: solo hace
        // falta desapilar. Cero peticiones de red, cero spinners.
        final navigator = _navigatorFor(tab);
        final steps = currentDepth - depth;
        for (var i = 0; i < steps; i++) {
          final topFrame = frames[currentDepth - i];
          if (isNativeBrowserBack && topFrame.route != null) {
            navigator?.removeRoute(topFrame.route!);
          } else {
            navigator?.pop();
          }
        }
      } else if (depth == currentDepth && targetFrameStillAlive) {
        // Nada que hacer (p. ej. el usuario pulsó atrás y adelante muy
        // rápido y los eventos se superpusieron): ya estamos donde toca.
      } else if (depth > currentDepth) {
        // ── CASO: HISTORIAL HUÉRFANO ─────────────────────────────────
        // El historial del navegador pide una ruta hacia adelante que ya
        // no existe en nuestra pila (típico al hacer truncateStack tras pulsar
        // el icono de un tab). Reemplazamos la URL por la que corresponde
        // al tope actual de la pila y abortamos.
        final last = frames.isNotEmpty ? frames.last : null;
        final subRoute = last != null
            ? deepRouteFromRouteSettings(last.settings)
            : null;
        setWebPath(
          publicPathForTabRoute(tab, subRoute),
          replace: true,
          state: {
            'tab': tab,
            'depth': currentDepth,
            'token': last?.token ?? -1,
          },
        );
      } else {
        // ── CAMINO LENTO ─────────────────────────────────────────────
        // O vamos hacia atrás a un frame que ya no existe en memoria
        // (por limpieza), o el token no coincide. Reconstruimos desde la URL.
        await _rebuildStackFromUrl(tab, pathname);
      }
    } finally {
      _replaying = false;
    }
  }

  Future<void> _rebuildStackFromUrl(int tab, String pathname) async {
    final navigator = _navigatorFor(tab);
    navigator?.popUntil((route) => route.isFirst);

    final rootFrame = (_stacks[tab] ?? const []).isNotEmpty
        ? _stacks[tab]!.first
        : null;
    _stacks[tab] = rootFrame == null ? [] : [rootFrame];

    final subRoute = parseTabDeepRoute(
      AppRoutes.subSegmentsFromPublicPath(pathname),
    );

    if (subRoute == null) {
      if (rootFrame != null) {
        setWebPath(
          publicPathForTabRoute(tab, null),
          replace: true,
          state: {'tab': tab, 'depth': 0, 'token': rootFrame.token},
        );
      }
      return;
    }

    final route = await DeepRouteResolver.buildRoute(subRoute);
    if (route == null) {
      // El recurso ya no existe (id inventado, o se borró entre tanto):
      // igual que hoy, nos quedamos en la raíz y corregimos la URL.
      setWebPath(
        publicPathForTabRoute(tab, null),
        replace: true,
        state: rootFrame == null
            ? null
            : {'tab': tab, 'depth': 0, 'token': rootFrame.token},
      );
      return;
    }

    // El push que sigue pasará por onNavigatorPush (porque el observer
    // sigue enganchado); como _replaying sigue en true durante toda esta
    // llamada, ese push NO tocará window.history por sí mismo — así que lo
    // hacemos explícitamente aquí, con un token nuevo, y con replace:true
    // porque YA estamos en esta entrada del historial (la trajo el propio
    // popstate): no queremos añadir una entrada más, solo corregirla.
    navigator?.push(route);
    final newToken = _nextToken++;
    _stacks[tab] = [
      ...(_stacks[tab] ?? const []),
      // Guardamos el objeto Route para que removeRoute() funcione
      // correctamente si el usuario pulsa atrás desde aquí.
      NavHistoryFrame(token: newToken, settings: route.settings, route: route),
    ];
    setWebPath(
      publicPathForTabRoute(tab, subRoute),
      replace: true,
      state: {
        'tab': tab,
        'depth': (_stacks[tab]!.length - 1),
        'token': newToken,
      },
    );
  }

  Future<void> _handleLegacyPopState(String pathname) async {
    final tab = AppRoutes.tabIndexFromPublicPath(pathname) ?? 0;
    if (tab != currentTabIndexNotifier.value) {
      onTabSwitchedByBrowser?.call(tab);
    }
    _replaying = true;
    try {
      await _rebuildStackFromUrl(tab, pathname);
    } finally {
      _replaying = false;
    }
  }

  void recordTabSwitch(int toTab, {int retries = 0}) {
    final frames = _stacks[toTab] ?? const [];
    if (frames.isEmpty) {
      if (retries >= 5) {
        debugPrint(
          '[Nav] recordTabSwitch: frames de tab $toTab siguen vacíos tras $retries reintentos',
        );
        return;
      }
      // Primera visita a esta pestaña en la sesión: su Navigator todavía
      // no ha construido ni empujado su ruta raíz (eso ocurre en el
      // siguiente frame). Diferimos un frame — mismo patrón que ya usaba
      // el código actual para este caso (`addPostFrameCallback`).
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => recordTabSwitch(toTab, retries: retries + 1),
      );
      return;
    }
    final last = frames.last;
    final depth = frames.length - 1;
    final subRoute = deepRouteFromRouteSettings(last.settings);
    setWebPath(
      publicPathForTabRoute(toTab, subRoute),
      replace: false, // cambiar de pestaña SÍ consume un nivel de "atrás"
      state: {'tab': toTab, 'depth': depth, 'token': last.token},
    );
  }

  // (Eliminado bootstrapStack por ser código muerto)
}

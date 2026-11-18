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

  // Contador para ignorar pops nativos que ya hemos procesado sincrónicamente
  // para evitar double-truncating de la pila en clics rápidos.
  int _ignorePopSyncCount = 0;

  /// Registradas una sola vez al arrancar la app.
  List<GlobalKey<NavigatorState>>?
  _tabNavigatorKeys; // longitud 5, índice = pestaña
  GlobalKey<NavigatorState>? _rootNavigatorKey;

  final Set<int> _pendingTabSwitches = <int>{};

  void Function(int newTab)? onTabSwitchedByBrowser;

  /// Limpia el historial en memoria al cambiar o cerrar sesión sin tocar
  /// [rootStackIndex], cuyo Navigator permanece montado bajo [MaterialApp].
  void resetForSessionChange() {
    for (var i = 0; i < 5; i++) {
      _stacks[i] = [];
    }
    _pendingTabSwitches.clear();
    _ignorePopSyncCount = 0;
    _isProgrammaticBack = false;
  }

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
    if (kIsWeb && route.settings.name == 'loading_dialog') return;

    final token = _nextToken++;
    _stacks[stackIndex] = [
      ...(_stacks[stackIndex] ?? []),
      NavHistoryFrame(token: token, settings: route.settings, route: route),
    ];

    if (_replaying) return; // eco de un popstate que ya estamos procesando

    // La ruta raíz de MaterialApp (MainScreen) no debe pisar la URL de la pestaña.
    if (stackIndex == rootStackIndex &&
        (_stacks[rootStackIndex]!.length - 1) == 0) {
      return;
    }

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
    // sustituir la entrada inicial salvo si llega desde recordTabSwitch.
    final isPendingTabSwitch =
        depth == 0 && _pendingTabSwitches.remove(stackIndex);
    setWebPath(
      path,
      replace: depth == 0 && !isPendingTabSwitch,
      state: {'tab': stackIndex, 'depth': depth, 'token': token},
    );
  }

  void onNavigatorPop(int stackIndex, [Route<dynamic>? route]) {
    if (route != null && route.settings.name == 'loading_dialog') return;

    if (_ignorePopSyncCount > 0) {
      _ignorePopSyncCount--;
      return;
    }
    if (_replaying) return;
    final frames = _stacks[stackIndex];
    if (frames == null || frames.isEmpty) return; // defensivo

    _stacks[stackIndex] = frames.sublist(0, frames.length - 1);

    if (!kIsWeb) return;

    // [OPCIÓN 1]: Sincronizar la URL actual del navegador para que refleje el pop visual.
    // Esto desvincula el botón volver interno de la app (que ahora usa nav.pop())
    // del historial del navegador (que mantendrá su longitud, pero actualizará su URL activa).
    if (stackIndex == rootStackIndex ||
        stackIndex == currentTabIndexNotifier.value) {
      final rootFrames = _stacks[rootStackIndex] ?? const [];
      if (rootFrames.length > 1) {
        // Si todavía hay modales sobre la ruta raíz, actualizamos el path al último modal.
        final last = rootFrames.last;
        setWebPath(
          getWebPathname() ?? '/',
          replace: true,
          state: {
            'tab': rootStackIndex,
            'depth': rootFrames.length - 1,
            'token': last.token,
          },
        );
      } else {
        // No quedan modales (o el pop fue directamente de la pestaña).
        // Restauramos la URL de la pestaña activa subyacente.
        final activeTab = currentTabIndexNotifier.value;
        final activeFrames = _stacks[activeTab] ?? const [];
        if (activeFrames.isNotEmpty) {
          final last = activeFrames.last;
          final subRoute = deepRouteFromRouteSettings(last.settings);
          setWebPath(
            publicPathForTabRoute(activeTab, subRoute),
            replace: true,
            state: {
              'tab': activeTab,
              'depth': activeFrames.length - 1,
              'token': last.token,
            },
          );
        }
      }
    }
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
    if (kIsWeb &&
        !_replaying &&
        (stackIndex == rootStackIndex ||
            stackIndex == currentTabIndexNotifier.value)) {
      final subRoute = deepRouteFromRouteSettings(newRoute.settings);
      final path = stackIndex == rootStackIndex
          ? (getWebPathname() ?? '/')
          : publicPathForTabRoute(stackIndex, subRoute);
      setWebPath(
        path,
        replace: true,
        state: {
          'tab': stackIndex,
          'depth': _stacks[stackIndex]!.length - 1,
          'token': last.token,
        },
      );
    }
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

    // Si estamos dentro de una pestaña (no un modal global) y estamos en su raíz,
    // devolvemos false para que MainScreen cambie a Inicio o cierre la app.
    if (stackIndex != rootStackIndex) {
      final frames = _stacks[stackIndex] ?? const [];
      if (frames.length <= 1) return false;
    }

    final nav = forStack != null
        ? _navigatorFor(forStack)
        : Navigator.of(context);

    if (nav != null && nav.canPop()) {
      nav.pop();
      return true;
    }
    return false;
  }

  /// Debe llamarse Inmediatamente después de hacer un `Navigator.pop(context, result)`
  /// programático (por ejemplo, al guardar un formulario en un modal) para
  /// asegurar que la entrada en el historial del navegador que correspondía a ese
  /// modal también se elimine, evitando un "click muerto" en el botón de volver.
  void syncBrowserHistoryAfterProgrammaticPop() {
    if (kIsWeb) {
      _isProgrammaticBack = true;
      goBackInBrowserHistory();
    }
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
        final tabInt = tabObj is num
            ? tabObj.toInt()
            : int.tryParse(tabObj.toString());
        final depthInt = depthObj is num
            ? depthObj.toInt()
            : int.tryParse(depthObj.toString());
        final tokenInt = tokenObj is num
            ? tokenObj.toInt()
            : int.tryParse(tokenObj.toString());

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
        _replaying = true;
        try {
          await _rebuildStackFromUrl(tab, pathname);
        } finally {
          _replaying = false;
        }
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

      // Relajamos el token check para no destruir la pila de Flutter solo porque
      // el navegador haya modificado el history.state. Si vamos hacia atrás (depth < currentDepth),
      // nos basta con que el depth exista en nuestra pila.
      final targetFrameStillAlive =
          depth >= 0 &&
          depth < frames.length &&
          (depth < currentDepth || frames[depth].token == token);

      if (depth < currentDepth && targetFrameStillAlive) {
        // ── CAMINO RÁPIDO ────────────────────────────────────────────
        // Vamos hacia atrás y el destino sigue vivo en memoria: solo hace
        // falta desapilar. Cero peticiones de red, cero spinners.
        final navigator = _navigatorFor(tab);
        if (navigator == null) {
          await _rebuildStackFromUrl(tab, pathname);
          return;
        }
        final steps = currentDepth - depth;

        // Actualizamos sincrónicamente para evitar condiciones de carrera en
        // clics rápidos donde didPop/didRemove tardan en actualizar el estado.
        _stacks[tab] = frames.sublist(0, frames.length - steps);

        for (var i = 0; i < steps; i++) {
          if (!navigator.canPop()) break;
          final topFrame = frames[currentDepth - i];
          final targetRoute = topFrame.route;
          _ignorePopSyncCount++;
          if (isNativeBrowserBack &&
              targetRoute != null &&
              targetRoute.isActive &&
              !targetRoute.isFirst &&
              targetRoute.navigator == navigator) {
            navigator.removeRoute(targetRoute);
          } else {
            navigator.pop();
          }
        }
      } else if (depth == currentDepth && targetFrameStillAlive) {
        // Nada que hacer visualmente (ya estamos en esta pantalla).
        // SIN EMBARGO, si esto ha sido provocado por el botón atrás/swipe del navegador,
        // significa que el usuario ha tropezado con un "click muerto" (una entrada duplicada
        // generada por el replaceState de onNavigatorPop).
        // Para que la UI no parezca atascada, ejecutamos el siguiente back automáticamente.
        if (isNativeBrowserBack) {
          goBackInBrowserHistory();
        }
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

    // El push que sigue pasa por onNavigatorPush (via TabUrlSyncObserver),
    // que ya añade el NavHistoryFrame a `_stacks[tab]`. Como `_replaying` es
    // true, onNavigatorPush no modifica `window.history`, así que sincronizamos
    // la entrada actual aquí con `replace: true` reutilizando ese token.
    if (navigator == null) return;
    navigator.push(route);
    final tabFrames = _stacks[tab] ?? const [];
    final frameToken = tabFrames.isNotEmpty
        ? tabFrames.last.token
        : _nextToken++;
    if (tabFrames.isEmpty) {
      _stacks[tab] = [
        NavHistoryFrame(
          token: frameToken,
          settings: route.settings,
          route: route,
        ),
      ];
    }
    setWebPath(
      publicPathForTabRoute(tab, subRoute),
      replace: true,
      state: {
        'tab': tab,
        'depth': (_stacks[tab]!.length - 1),
        'token': frameToken,
      },
    );
  }

  Future<void> _handleLegacyPopState(String pathname) async {
    final tab = AppRoutes.tabIndexFromPublicPath(pathname) ?? 0;
    if (tab != currentTabIndexNotifier.value) {
      onTabSwitchedByBrowser?.call(tab);
    }

    final frames = _stacks[tab] ?? const [];
    if (frames.isNotEmpty) {
      // 1. Verificamos si la ruta actual en Flutter ya coincide con la URL
      final last = frames.last;
      final subRoute = deepRouteFromRouteSettings(last.settings);
      final currentPath = publicPathForTabRoute(tab, subRoute);
      if (currentPath == pathname) {
        setWebPath(
          pathname,
          replace: true,
          state: {'tab': tab, 'depth': frames.length - 1, 'token': last.token},
        );
        return;
      }

      // 2. Buscamos si la URL destino está más abajo en nuestra pila
      // Esto pasa si el navegador pierde el state pero Flutter sigue intacto.
      for (int i = frames.length - 2; i >= 0; i--) {
        final frameRoute = deepRouteFromRouteSettings(frames[i].settings);
        final framePath = publicPathForTabRoute(tab, frameRoute);
        if (framePath == pathname) {
          final navigator = _navigatorFor(tab);
          final stepsToPop = frames.length - 1 - i;

          _stacks[tab] = frames.sublist(0, frames.length - stepsToPop);

          // Pops visuales nativos sin recargar toda la jerarquía
          if (navigator != null) {
            for (int j = 0; j < stepsToPop; j++) {
              if (!navigator.canPop()) break;
              _ignorePopSyncCount++;
              navigator.pop();
            }
          }

          setWebPath(
            pathname,
            replace: true,
            state: {'tab': tab, 'depth': i, 'token': frames[i].token},
          );
          return;
        }
      }
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
        _pendingTabSwitches.remove(toTab);
        debugPrint(
          '[Nav] recordTabSwitch: frames de tab $toTab siguen vacíos tras $retries reintentos',
        );
        return;
      }
      _pendingTabSwitches.add(toTab);
      // Primera visita a esta pestaña en la sesión: su Navigator todavía
      // no ha construido ni empujado su ruta raíz (eso ocurre en el
      // siguiente frame). Diferimos un frame — mismo patrón que ya usaba
      // el código actual para este caso (`addPostFrameCallback`).
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => recordTabSwitch(toTab, retries: retries + 1),
      );
      return;
    }
    if (retries > 0 && !_pendingTabSwitches.remove(toTab)) {
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

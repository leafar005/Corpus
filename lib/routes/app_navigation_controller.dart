import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:corpus/globals.dart';
import 'package:corpus/routes/app_routes.dart';
import 'package:corpus/routes/deep_route_resolver.dart';
import 'package:corpus/routes/nav_history_frame.dart';
import 'package:corpus/routes/tab_deep_route.dart';
import 'package:corpus/routes/tab_url_sync.dart';
import 'package:corpus/utils/corpus_logger.dart';
import 'package:corpus/utils/web_js.dart';

class AppNavigationController {
  AppNavigationController._();
  static final AppNavigationController instance = AppNavigationController._();

  static final _log = CorpusLogger('AppNavigationController');

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

  /// `true` mientras se está reproduciendo un `popstate`: evita que los
  /// `pop()`/`push()` generados por el replay re-sincronicen `window.history`.
  bool _replaying = false;

  /// Cola secuencial para serializar eventos `popstate` y generación para
  /// descartar reconstrucciones de red obsoletas tras múltiples pulsaciones.
  Future<void> _popStateQueue = Future<void>.value();
  int _popStateGeneration = 0;
  int _programmaticBackPending = 0;
  Timer? _programmaticBackTimer;

  List<GlobalKey<NavigatorState>>? _tabNavigatorKeys;
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
    _popStateGeneration++;
    _replaying = false;
    _programmaticBackPending = 0;
    _programmaticBackTimer?.cancel();
    _programmaticBackTimer = null;
  }

  /// Sincroniza `window.history` tras un `Navigator.pop()` programático en Web.
  ///
  /// Usa un contador acotado y un temporizador de seguridad de 500 ms para que
  /// no quede estado residual si el navegador no emite `popstate`.
  void syncBrowserHistoryAfterProgrammaticPop() {
    if (!kIsWeb || _replaying) return;
    _programmaticBackPending++;
    _programmaticBackTimer?.cancel();
    _programmaticBackTimer = Timer(const Duration(milliseconds: 500), () {
      _programmaticBackPending = 0;
      _programmaticBackTimer = null;
    });
    goBackInBrowserHistory();
  }

  bool _consumeProgrammaticBackPending() {
    if (_programmaticBackPending <= 0) return false;
    _programmaticBackPending--;
    if (_programmaticBackPending == 0) {
      _programmaticBackTimer?.cancel();
      _programmaticBackTimer = null;
    }
    return true;
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

  String _publicPathForStack(int stackIndex, [TabDeepRoute? subRoute]) {
    if (stackIndex == rootStackIndex) {
      final activeTab = currentTabIndexNotifier.value;
      final activeFrames = _stacks[activeTab] ?? const [];
      final activeSub = activeFrames.isNotEmpty
          ? deepRouteFromRouteSettings(activeFrames.last.settings)
          : null;
      return publicPathForTabRoute(activeTab, activeSub);
    }
    return publicPathForTabRoute(stackIndex, subRoute);
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

  void _syncUrlForCurrentTop(int tab) {
    final frames = _stacks[tab] ?? const [];
    if (frames.isEmpty) return;
    final last = frames.last;
    final subRoute = deepRouteFromRouteSettings(last.settings);
    setWebPath(
      _publicPathForStack(tab, subRoute),
      replace: true,
      state: {
        'tab': tab,
        'depth': frames.length - 1,
        'token': last.token,
      },
    );
  }

  void onNavigatorPush(int stackIndex, Route<dynamic> route) {
    if (kIsWeb && route.settings.name == 'loading_dialog') return;

    final token = _nextToken++;
    _stacks[stackIndex] = [
      ...(_stacks[stackIndex] ?? []),
      NavHistoryFrame(token: token, settings: route.settings, route: route),
    ];

    if (_replaying) return;

    if (stackIndex == rootStackIndex &&
        (_stacks[rootStackIndex]!.length - 1) == 0) {
      return;
    }

    if (stackIndex != rootStackIndex &&
        stackIndex != currentTabIndexNotifier.value) {
      return;
    }

    final depth = _stacks[stackIndex]!.length - 1;
    final subRoute = deepRouteFromRouteSettings(route.settings);

    final String path;
    if (stackIndex == rootStackIndex) {
      path = getWebPathname() ?? _publicPathForStack(rootStackIndex);
    } else if (subRoute != null) {
      path = publicPathForTabRoute(stackIndex, subRoute);
    } else {
      path = getWebPathname() ?? publicPathForTabRoute(stackIndex, null);
    }

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

    final frames = _stacks[stackIndex];
    if (frames == null || frames.isEmpty) return;

    int? removeIndex;
    if (route != null) {
      for (var i = frames.length - 1; i >= 0; i--) {
        if (identical(frames[i].route, route)) {
          removeIndex = i;
          break;
        }
      }
      removeIndex ??= frames.length - 1;
    } else {
      removeIndex = frames.length - 1;
    }

    _stacks[stackIndex] = List<NavHistoryFrame>.from(frames)
      ..removeAt(removeIndex);

    if (!kIsWeb || _replaying) return;

    if (stackIndex == rootStackIndex ||
        stackIndex == currentTabIndexNotifier.value) {
      final rootFrames = _stacks[rootStackIndex] ?? const [];
      if (rootFrames.length > 1) {
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
          ? (getWebPathname() ?? _publicPathForStack(rootStackIndex))
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

  /// Único método que cualquier control de la UI debe llamar para "ir atrás".
  bool requestBack(BuildContext context, {int? forStack}) {
    if (!kIsWeb) {
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
  ) {
    final generation = ++_popStateGeneration;
    final isNativeBrowserBack = !_consumeProgrammaticBackPending();
    final next = _popStateQueue
        .catchError((Object _) {})
        .then(
          (_) => _processBrowserPopState(
            state,
            pathname,
            generation: generation,
            isNativeBrowserBack: isNativeBrowserBack,
          ),
        );
    _popStateQueue = next;
    return next;
  }

  Future<void> _processBrowserPopState(
    Map<String, Object?>? state,
    String pathname, {
    required int generation,
    required bool isNativeBrowserBack,
  }) async {
    if (generation != _popStateGeneration) return;

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
            generation: generation,
            isNativeBrowserBack: isNativeBrowserBack,
          );
          return;
        }
      }

      await _handleLegacyPopState(pathname, generation: generation);
    } catch (e, st) {
      _log.error('Error parsing popstate', error: e, stackTrace: st);
      if (generation != _popStateGeneration) return;
      try {
        final tab = AppRoutes.tabIndexFromPublicPath(pathname) ?? 0;
        _replaying = true;
        try {
          await _rebuildStackFromUrl(tab, pathname, generation: generation);
        } finally {
          _replaying = false;
        }
      } catch (fallbackErr) {
        _log.warning('Popstate fallback también falló: $fallbackErr');
      }
    }
  }

  Future<void> _handleTypedPopState({
    required int tab,
    required int depth,
    required int token,
    required String pathname,
    required int generation,
    required bool isNativeBrowserBack,
  }) async {
    if (generation != _popStateGeneration) return;
    _replaying = true;
    try {
      if (tab != rootStackIndex && tab != currentTabIndexNotifier.value) {
        onTabSwitchedByBrowser?.call(tab);
      }

      final frames = _stacks[tab] ?? const [];
      final currentDepth = frames.length - 1;

      final targetFrameStillAlive =
          depth >= 0 &&
          depth < frames.length &&
          (depth < currentDepth || frames[depth].token == token);

      if (depth < currentDepth && targetFrameStillAlive) {
        final navigator = _navigatorFor(tab);
        if (navigator == null) {
          await _rebuildStackFromUrl(tab, pathname, generation: generation);
          return;
        }
        final steps = currentDepth - depth;

        for (var i = 0; i < steps; i++) {
          if (!navigator.canPop()) break;
          final targetFrame = frames[currentDepth - i];
          final targetRoute = targetFrame.route;
          if (targetRoute != null &&
              targetRoute.isActive &&
              !targetRoute.isFirst &&
              targetRoute.navigator == navigator &&
              targetRoute.popDisposition != RoutePopDisposition.doNotPop) {
            navigator.removeRoute(targetRoute);
          } else {
            final popped = await navigator.maybePop();
            if (!popped) break;
          }
        }

        // Si un PopScope canceló el retroceso, la pila sigue por encima de `depth`:
        // restauramos la URL de la ruta que quedó activa en vez de desincronizar.
        final remaining = _stacks[tab] ?? const [];
        if (remaining.length - 1 > depth) {
          _syncUrlForCurrentTop(tab);
        }
      } else if (depth == currentDepth && targetFrameStillAlive) {
        if (isNativeBrowserBack) {
          goBackInBrowserHistory();
        }
      } else if (depth > currentDepth) {
        final last = frames.isNotEmpty ? frames.last : null;
        final subRoute = last != null
            ? deepRouteFromRouteSettings(last.settings)
            : null;
        setWebPath(
          _publicPathForStack(tab, subRoute),
          replace: true,
          state: {
            'tab': tab,
            'depth': currentDepth,
            'token': last?.token ?? -1,
          },
        );
      } else {
        await _rebuildStackFromUrl(tab, pathname, generation: generation);
      }
    } finally {
      _replaying = false;
    }
  }

  Future<void> _rebuildStackFromUrl(
    int tab,
    String pathname, {
    required int generation,
  }) async {
    if (generation != _popStateGeneration) return;

    final navigator = _navigatorFor(tab);
    navigator?.popUntil((route) => route.isFirst);

    final existingFrames = _stacks[tab] ?? const [];
    final rootFrame = existingFrames.isNotEmpty ? existingFrames.first : null;
    if (navigator == null) {
      _stacks[tab] = rootFrame == null ? [] : [rootFrame];
    }

    final subRoute = parseTabDeepRoute(
      AppRoutes.subSegmentsFromPublicPath(pathname),
    );

    if (subRoute == null) {
      if (rootFrame != null) {
        setWebPath(
          _publicPathForStack(tab, null),
          replace: true,
          state: {'tab': tab, 'depth': 0, 'token': rootFrame.token},
        );
      }
      return;
    }

    final route = await DeepRouteResolver.buildRoute(subRoute);
    if (generation != _popStateGeneration) return;

    if (route == null) {
      setWebPath(
        _publicPathForStack(tab, null),
        replace: true,
        state: rootFrame == null
            ? null
            : {'tab': tab, 'depth': 0, 'token': rootFrame.token},
      );
      return;
    }

    final liveNavigator = _navigatorFor(tab);
    if (liveNavigator == null) return;
    liveNavigator.push(route);
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
      _publicPathForStack(tab, subRoute),
      replace: true,
      state: {
        'tab': tab,
        'depth': (_stacks[tab]!.length - 1),
        'token': frameToken,
      },
    );
  }

  Future<void> _handleLegacyPopState(
    String pathname, {
    required int generation,
  }) async {
    if (generation != _popStateGeneration) return;

    _replaying = true;
    try {
      final tab = AppRoutes.tabIndexFromPublicPath(pathname) ?? 0;
      if (tab != currentTabIndexNotifier.value) {
        onTabSwitchedByBrowser?.call(tab);
      }

      final frames = _stacks[tab] ?? const [];
      if (frames.isNotEmpty) {
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

        for (int i = frames.length - 2; i >= 0; i--) {
          final frameRoute = deepRouteFromRouteSettings(frames[i].settings);
          final framePath = publicPathForTabRoute(tab, frameRoute);
          if (framePath == pathname) {
            final navigator = _navigatorFor(tab);
            final stepsToPop = frames.length - 1 - i;

            if (navigator != null) {
              for (int j = 0; j < stepsToPop; j++) {
                if (!navigator.canPop()) break;
                final popped = await navigator.maybePop();
                if (!popped) break;
              }
            }

            final remaining = _stacks[tab] ?? const [];
            if (remaining.length - 1 > i) {
              _syncUrlForCurrentTop(tab);
            } else {
              setWebPath(
                pathname,
                replace: true,
                state: {'tab': tab, 'depth': i, 'token': frames[i].token},
              );
            }
            return;
          }
        }
      }

      await _rebuildStackFromUrl(tab, pathname, generation: generation);
    } finally {
      _replaying = false;
    }
  }

  void recordTabSwitch(int toTab, {int retries = 0}) {
    if (toTab != currentTabIndexNotifier.value) {
      _pendingTabSwitches.remove(toTab);
      return;
    }
    if (retries > 0 && !_pendingTabSwitches.contains(toTab)) {
      return;
    }
    final frames = _stacks[toTab] ?? const [];
    if (frames.isEmpty) {
      if (retries >= 5) {
        _pendingTabSwitches.remove(toTab);
        _log.debug(
          'recordTabSwitch: frames de tab $toTab siguen vacíos tras $retries reintentos; usando ruta raíz',
        );
        setWebPath(
          publicPathForTabRoute(toTab, null),
          replace: false,
          state: {'tab': toTab, 'depth': 0, 'token': 0},
        );
        return;
      }
      _pendingTabSwitches.add(toTab);
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
      replace: false,
      state: {'tab': toTab, 'depth': depth, 'token': last.token},
    );
  }
}

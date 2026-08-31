import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home/home_screen.dart';
import 'library/search_screen.dart';
import 'activity/activity_screen.dart';
import 'profile/profile_screen.dart';
import 'bundles/bundles_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import '../theme/corpus_theme_extension.dart';
import '../theme/corpus_typography.dart';
import '../theme/style_pack.dart';
import '../widgets/p5r_dynamic_frame.dart';
import '../utils/web_js.dart';
import 'package:corpus/routes/app_routes.dart';
import '../routes/tab_deep_route.dart';
import '../routes/deep_route_resolver.dart';
import '../routes/tab_url_sync.dart';
import '../services/deep_link_service.dart';
import 'package:corpus/globals.dart';
import '../widgets/edge_swipe_back_detector.dart';
import '../routes/app_navigation_controller.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  StreamSubscription<void>? _webPopStateSub;
  RealtimeChannel? _friendshipsChannel;
  RealtimeChannel? _activityFeedChannel;
  RealtimeChannel? _notificationsChannel;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  // Un observer por pestaña: mantiene la URL del navegador (web) alineada
  // con lo que haya arriba de la pila de esa pestaña (juego, perfil,
  // reseña, logros...). Ver routes/tab_url_sync.dart.
  late final List<TabUrlSyncObserver> _tabUrlObservers = List.generate(
    5,
    (i) => TabUrlSyncObserver(i),
  );

  // Lazy loading: las pantallas solo se instancian la primera vez que se visitan.
  // Un Set rastrea qué pestañas ya han sido inicializadas.
  final Set<int> _initializedTabs = {
    0,
  }; // La pestaña 0 (Inicio) siempre se carga de entrada.
  late final List<Widget?> _screens = List.filled(5, null);

  Widget _getScreen(int index) {
    if (_screens[index] == null) {
      _screens[index] = switch (index) {
        0 => HomeScreen(
          onNavigateToSearch: () => _onTabTapped(1),
          onNavigateToBundles: (query) {
            BundlesNavigation.targetQuery.value = query;
            _onTabTapped(3);
          },
        ),
        1 => const SearchScreen(),
        2 => const ActivityScreen(),
        3 => const BundlesScreen(),
        4 => const ProfileScreen(),
        _ => const SizedBox.shrink(),
      };
    }
    return _screens[index]!;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppNavigationController.instance.registerTabNavigatorKeys(_navigatorKeys);
    AppNavigationController.instance.registerRootNavigatorKey(
      DeepLinkService.navigatorKey,
    );
    AppNavigationController.instance.onTabSwitchedByBrowser = (newTab) {
      if (!mounted) return;
      setState(() {
        _currentIndex = newTab;
        _initializedTabs.add(newTab);
      });
      currentTabIndexNotifier.value = newTab;
      if (newTab == 2) _markActivityRead();
      if (_shouldPersistTab) {
        SharedPreferences.getInstance().then(
          (p) => p.setInt('main_tab_index', newTab),
        );
      }
    };
    // Pre-instanciamos la primera pantalla
    _getScreen(0);
    _loadSavedTab();
    if (kIsWeb) {
      _webPopStateSub = webPopStateStream().listen((state) {
        final pathname = getWebPathname();
        if (pathname == null) return;
        AppNavigationController.instance.handleBrowserPopState(state, pathname);
      });
    }
    // Señalar al splash HTML que ya tenemos la UI lista para mostrar.
    // addPostFrameCallback garantiza que el primer frame ya ha sido pintado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      dispatchCorpusReady();
    });
    DeepLinkService.pendingTab.addListener(_onPendingTab);
    _subscribeFriendRequests();
    _subscribeActivityFeed();
    _subscribeNotifications();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_currentIndex == 2) {
        // Seguimos "dentro" de Actividad: cualquier cosa nueva llegada
        // mientras estábamos en segundo plano también se marca como leída.
        _markActivityRead();
        _fetchNotificationsCount();
      } else {
        // En cualquier otra pestaña: recalculamos los contadores por si el
        // WebSocket se cerró mientras estábamos en segundo plano y perdimos
        // eventos de Realtime.
        _fetchInitialBadges();
        _fetchNotificationsCount();
      }
    }
  }

  /// Marca la actividad como leída: resetea el badge de forma optimista en la
  /// UI al instante, y persiste el "leído hasta ahora" en el servidor (vía
  /// mark_activity_read(), que usa la hora del servidor) para que el resto de
  /// dispositivos de la misma cuenta también vean el badge a 0.
  Future<void> _markActivityRead() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    unreadActivityCount.value = 0; // Reset optimista inmediato en la UI.

    try {
      await Supabase.instance.client.rpc('mark_activity_read');
    } catch (e) {
      debugPrint('[MainScreen] Error marcando actividad como leída: $e');
      // No revertimos el 0 optimista: es preferible que el badge desaparezca
      // un instante de más a que se quede "pegado". El próximo resync
      // (resume de la app, reconexión del canal, o el siguiente arranque)
      // recalculará el valor correcto desde el servidor de todas formas.
    }
  }

  void _fetchInitialBadges() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    // Recargar solicitudes de amistad (sin cambios respecto a antes).
    try {
      final res = await Supabase.instance.client
          .from('friendships')
          .select('requester_id')
          .eq('addressee_id', myId)
          .eq('status', 'pending');
      if (mounted) unreadFriendRequestsCount.value = res.length;
    } catch (_) {}

    // Recargar el contador de actividad no leída, calculado en el servidor
    // (get_unread_activity_summary) a partir de users.last_activity_read_at.
    // Sustituye a la antigua lectura de SharedPreferences('last_activity_visit')
    // + query manual, que era local al dispositivo.
    try {
      final res = await Supabase.instance.client
          .rpc('get_unread_activity_summary')
          .single();
      if (mounted) {
        unreadActivityCount.value = (res['unread_count'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint('[MainScreen] Error fetch activity resume: $e');
    }
  }

  void _subscribeActivityFeed() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    // Carga inicial al arrancar.
    _fetchInitialBadges();

    // --- FIX TEMPORAL PARA FECHAS EN EL FUTURO ---
    // (sin cambios: se mantiene tal cual estaba; ver sección 7 de este spec)
    try {
      final futureDate = DateTime.now()
          .add(const Duration(minutes: 1))
          .toUtc()
          .toIso8601String();
      final nowStr = DateTime.now().toUtc().toIso8601String();

      final afRes = await Supabase.instance.client
          .from('activity_feed')
          .select('id')
          .eq('user_id', myId)
          .gt('created_at', futureDate);
      for (var row in (afRes as List)) {
        await Supabase.instance.client
            .from('activity_feed')
            .update({'created_at': nowStr})
            .eq('id', row['id']);
      }

      final rRes = await Supabase.instance.client
          .from('reviews')
          .select('id')
          .eq('user_id', myId)
          .gt('created_at', futureDate);
      for (var row in (rRes as List)) {
        await Supabase.instance.client
            .from('reviews')
            .update({'created_at': nowStr})
            .eq('id', row['id']);
      }
    } catch (e) {
      debugPrint('[MainScreen] Error fixing future dates: $e');
    }
    // ---------------------------------------------

    if (!mounted) return;

    final recentGames = <String>{};

    _activityFeedChannel = Supabase.instance.client
        .channel('main_activity_feed_badge')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'activity_feed',
          callback: (payload) {
            final userId = payload.newRecord['user_id'];
            if (userId == myId) return; // Ignorar posts propios

            final gameId = payload.newRecord['game_id'];
            if (gameId != null) {
              final key = '${userId}_$gameId';
              if (recentGames.contains(key)) return; // Ya sumado recientemente
              recentGames.add(key);
              if (recentGames.length > 50) recentGames.clear();
            }

            // Solo incrementar si el usuario NO está ya en la pestaña Actividad.
            if (_currentIndex != 2) {
              unreadActivityCount.value++;
            }
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            // Se ejecuta también en cada reconexión (no solo en la suscripción
            // inicial), que es precisamente el caso que antes se perdía: un
            // corte de red o una suspensión del equipo mientras la app seguía
            // en primer plano, sin pasar por didChangeAppLifecycleState.
            _fetchInitialBadges();
          }
          if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            debugPrint(
              '[MainScreen] Canal de actividad con problemas: $status / $error',
            );
          }
        });
  }

  Future<void> _fetchNotificationsCount() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;
    try {
      final res = await Supabase.instance.client.rpc(
        'get_unread_notifications_count',
      );
      if (mounted) {
        unreadNotificationsCount.value = (res as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint('[MainScreen] Error fetch notifications count: $e');
    }
  }

  void _subscribeNotifications() {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    _fetchNotificationsCount();

    // Escuchamos TODOS los eventos (insert/update/delete), no solo insert:
    // un like retirado, una solicitud cancelada o un "marcar como leído"
    // hecho desde otro dispositivo también deben mover este contador, y
    // recalcularlo por completo en servidor evita que un incremento/
    // decremento local a ciegas se desincronice.
    _notificationsChannel = Supabase.instance.client
        .channel('unread_notifications_badge')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: myId,
          ),
          callback: (payload) => _fetchNotificationsCount(),
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            // Se ejecuta también en cada reconexión, no solo en la
            // suscripción inicial (mismo motivo que en
            // _subscribeActivityFeed: un corte de red o una suspensión del
            // equipo con la app en primer plano no debe perder eventos
            // para siempre).
            _fetchNotificationsCount();
          }
        });
  }

  void _subscribeFriendRequests() {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    // Cargar el conteo inicial de solicitudes pendientes
    Supabase.instance.client
        .from('friendships')
        .select('requester_id')
        .eq('addressee_id', myId)
        .eq('status', 'pending')
        .then((rows) {
          if (mounted) unreadFriendRequestsCount.value = rows.length;
        });

    // Suscribirse a nuevas solicitudes en tiempo real
    _friendshipsChannel = Supabase.instance.client
        .channel('pending_friend_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'friendships',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'addressee_id',
            value: myId,
          ),
          callback: (payload) {
            final status = payload.newRecord['status'];
            if (status == 'pending') {
              unreadFriendRequestsCount.value++;
            }
          },
        )
        .subscribe();
  }

  void _onPendingTab() {
    final index = DeepLinkService.pendingTab.value;
    if (index != null) {
      DeepLinkService.pendingTab.value = null;
      _onTabTapped(index);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DeepLinkService.pendingTab.removeListener(_onPendingTab);
    _friendshipsChannel?.unsubscribe();
    _activityFeedChannel?.unsubscribe();
    _notificationsChannel?.unsubscribe();
    _webPopStateSub?.cancel();
    super.dispose();
  }

  bool get _shouldPersistTab {
    if (kIsWeb) return true;
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadSavedTab() async {
    if (kIsWeb) {
      final pathname = getWebPathname();
      if (pathname != null) {
        final fromUrl = AppRoutes.tabIndexFromPublicPath(pathname);
        if (fromUrl != null) {
          final subRoute = parseTabDeepRoute(
            AppRoutes.subSegmentsFromPublicPath(pathname),
          );
          if (mounted) {
            setState(() {
              _currentIndex = fromUrl;
              _initializedTabs.add(fromUrl);
            });
            currentTabIndexNotifier.value = fromUrl;
            if (fromUrl == 2) _markActivityRead();
            if (subRoute != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await _resolveAndPushSubRoute(fromUrl, subRoute);
              });
            }
          }
          return;
        }
      }
    }

    if (!_shouldPersistTab) return;
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      final savedIndex = prefs.getInt('main_tab_index') ?? 0;
      setState(() {
        _currentIndex = savedIndex;
        _initializedTabs.add(savedIndex);
      });
      currentTabIndexNotifier.value = savedIndex;
      if (savedIndex == 2) _markActivityRead();
      if (kIsWeb) {
        setWebPath(AppRoutes.publicPathForTab(savedIndex), replace: true);
      }
    }
  }

  /// Resuelve [subRoute] (con su fetch de datos) y la empuja en la pestaña
  /// [tabIndex]. Si el recurso ya no existe (id inventado en la URL, o el
  /// juego/reseña se borró), deja la pestaña en su raíz y corrige la URL
  /// para no dejar un enlace roto en la barra de direcciones.
  Future<void> _resolveAndPushSubRoute(
    int tabIndex,
    TabDeepRoute subRoute,
  ) async {
    final route = await DeepRouteResolver.buildRoute(subRoute);
    if (!mounted) return;
    final nav = _navigatorKeys[tabIndex].currentState;
    if (nav == null) return;
    if (route == null) {
      if (kIsWeb && currentTabIndexNotifier.value == tabIndex) {
        setWebPath(AppRoutes.publicPathForTab(tabIndex), replace: true);
      }
      return;
    }
    nav.push(route);
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) {
      final truncated =
          AppNavigationController.instance.framesFor(index).length > 1;
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      if (truncated) {
        AppNavigationController.instance.truncateStack(index, keepFirst: true);
        AppNavigationController.instance.replaceCurrentUrlWithRoot(index);
      }

      // Si ya estamos en Actividad y el badge quedó "pegado" por cualquier
      // motivo (p. ej. llegó actividad nueva mientras estábamos aquí y no se
      // marcó como leída), volver a tocar el icono también lo limpia.
      if (index == 2 && unreadActivityCount.value != 0) {
        _markActivityRead();
      }
      return;
    }

    if (index == 2) {
      // Al entrar a Actividad, reseteamos badge y lo persistimos en servidor.
      _markActivityRead();
    }

    if (index == 4) {
      // Al abrir la pestaña Perfil, reseteamos el badge de solicitudes.
      unreadFriendRequestsCount.value = 0;
    }

    setState(() {
      _currentIndex = index;
      _initializedTabs.add(index); // Marca la pestaña como inicializada
    });
    currentTabIndexNotifier.value = index;
    if (_shouldPersistTab) {
      SharedPreferences.getInstance().then(
        (p) => p.setInt('main_tab_index', index),
      );
    }

    AppNavigationController.instance.recordTabSwitch(index);
  }

  Widget _buildNavigator(int index) {
    // Si la pestaña aún no ha sido visitada, no la construimos (nil widget)
    if (!_initializedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    return Offstage(
      offstage: _currentIndex != index,
      child: Navigator(
        key: _navigatorKeys[index],
        observers: [_tabUrlObservers[index]],
        onGenerateRoute: (routeSettings) {
          final tabRoute = switch (index) {
            0 => AppRoutes.tabHome,
            1 => AppRoutes.tabSearch,
            2 => AppRoutes.tabActivity,
            3 => AppRoutes.tabBundles,
            4 => AppRoutes.tabProfile,
            _ => AppRoutes.tabHome,
          };
          return MaterialPageRoute(
            settings: RouteSettings(name: tabRoute),
            builder: (context) => _getScreen(index),
          );
        },
      ),
    );
  }

  Widget _buildTopNavigationBar(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    if (ext.navBarStyle == NavBarStyle.persona5Royal) {
      return _buildPersona5RoyalTopNav(context);
    }

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Row(
            children: [
              Icon(Icons.gamepad, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'CORPUS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const Spacer(),
          _buildTopNavItem(0, 'Inicio', Icons.home),
          const SizedBox(width: 16),
          _buildTopNavItem(1, 'Buscar', Icons.search),
          const SizedBox(width: 16),
          _buildTopNavItem(2, 'Actividad', Icons.group),
          const SizedBox(width: 16),
          _buildTopNavItem(3, 'Bundles', Icons.local_offer),
          const SizedBox(width: 16),
          _buildTopNavItem(4, 'Perfil', Icons.person),
        ],
      ),
    );
  }

  static const Color _p5rRed = Color(0xFFD3112D);

  Widget _buildPersona5RoyalTopNav(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        height: 60,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            const Positioned.fill(
              child: P5rDynamicBackground(
                backgroundColor: _p5rRed,
                borderColor: Colors.black,
                borderWidth: 2,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.gamepad, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(
                        'CORPUS',
                        style: CorpusTypography.display(
                          context,
                          Theme.of(context).extension<CorpusThemeExtension>()!,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _buildPersona5RoyalTopNavItem(0, 'Inicio', Icons.home),
                  const SizedBox(width: 16),
                  _buildPersona5RoyalTopNavItem(1, 'Buscar', Icons.search),
                  const SizedBox(width: 16),
                  _buildPersona5RoyalTopNavItem(2, 'Actividad', Icons.group),
                  const SizedBox(width: 16),
                  _buildPersona5RoyalTopNavItem(
                    3,
                    'Bundles',
                    Icons.local_offer,
                  ),
                  const SizedBox(width: 16),
                  _buildPersona5RoyalTopNavItem(4, 'Perfil', Icons.person),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersona5RoyalTopNavItem(int index, String label, IconData icon) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? Colors.white : Colors.white70;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _withNavBadge(index, Icon(icon, color: color, size: 20)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );

    return InkWell(
      onTap: () => _onTabTapped(index),
      child: isSelected
          ? SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  const Positioned.fill(
                    child: P5rDynamicBackground(
                      backgroundColor: Colors.black,
                      borderColor: Colors.white,
                      borderWidth: 1,
                    ),
                  ),
                  content,
                ],
              ),
            )
          : content,
    );
  }

  Widget _buildTopNavItem(int index, String label, IconData icon) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final isSelected = _currentIndex == index;
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade400;

    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: ext.radiusSmall,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _withNavBadge(index, Icon(icon, color: color, size: 20)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiquidGlassNavBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth =
              constraints.maxWidth - 40; // 20px padding a cada lado
          const barHeight = 64.0;
          const bottomMargin = 12.0;
          const totalHeight = barHeight + bottomMargin;

          return SizedBox(
            width: constraints.maxWidth,
            height: totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Centramos y posicionamos la barra nosotros mismos.
                // alignment/margin del widget se ponen a neutral para que no interfieran.
                Positioned(
                  bottom: bottomMargin,
                  left: (constraints.maxWidth - barWidth) / 2,
                  child: LiquidGlassBottomNavBar(
                    width: barWidth,
                    height: barHeight,
                    alignment: Alignment.topLeft,
                    margin: EdgeInsets.zero,
                    itemStyle: LiquidGlassNavItemStyle(
                      selectedColor: isDark
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black,
                      unselectedColor: isDark ? Colors.white70 : Colors.black54,
                    ),
                    items: const [
                      LiquidGlassTabBarItem(icon: Icons.home, label: 'Inicio'),
                      LiquidGlassTabBarItem(
                        icon: Icons.search,
                        label: 'Buscar',
                      ),
                      LiquidGlassTabBarItem(
                        icon: Icons.group,
                        label: 'Actividad',
                      ),
                      LiquidGlassTabBarItem(
                        icon: Icons.local_offer,
                        label: 'Bundles',
                      ),
                      LiquidGlassTabBarItem(
                        icon: Icons.person,
                        label: 'Perfil',
                      ),
                    ],
                    selectedIndex: _currentIndex,
                    onChanged: (index) => _onTabTapped(index),
                    pillStyle: const LiquidGlassNavPillStyle(
                      animated: true,
                      mode: LiquidGlassPillMode.both,
                      enableInnerRadiusTransparent: true,
                      magnification: 1.25,
                      glassStyle: LiquidGlassStyle(
                        refraction: LiquidGlassRefraction(
                          distortion: 0.15,
                          distortionWidth: 24.0,
                          chromaticAberration: 0.025,
                        ),
                      ),
                    ),
                  ),
                ),
                // Badge flotante sobre el ítem Actividad (índice 2 de 5).
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: totalHeight,
                  child: _buildLiquidGlassBadge(barWidth: barWidth),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Badges flotantes para el LiquidGlass nav bar.
  /// Muestra badge de Actividad (ítem 2) y badge de solicitudes (ítem 4).
  Widget _buildLiquidGlassBadge({required double barWidth}) {
    const sideOffset = 20.0;
    final itemWidth = barWidth / 5;

    Widget? badge(int tabIndex, ValueNotifier<int> notifier) {
      return ValueListenableBuilder<int>(
        valueListenable: notifier,
        builder: (context, count, _) {
          if (count == 0) return const SizedBox.shrink();
          final centerX = sideOffset + itemWidth * (tabIndex + 0.5);
          return Positioned(
            left: centerX + 8,
            top: 6,
            child: _buildBadgeDot(count),
          );
        },
      );
    }

    return Stack(
      children: [
        badge(2, unreadActivityCount)!,
        badge(4, unreadFriendRequestsCount)!,
      ],
    );
  }

  Widget _buildPersona5RoyalNavBar(BuildContext context) {
    const items = [
      (Icons.home, 'Inicio'),
      (Icons.search, 'Buscar'),
      (Icons.group, 'Actividad'),
      (Icons.local_offer, 'Bundles'),
      (Icons.person, 'Perfil'),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: ClipRect(
          child: SizedBox(
            height: 80,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                const Positioned.fill(
                  child: P5rDynamicBackground(
                    backgroundColor: _p5rRed,
                    borderColor: Colors.black,
                    borderWidth: 2,
                  ),
                ),
                Row(
                  children: List.generate(items.length, (index) {
                    final (icon, label) = items[index];
                    final isSelected = _currentIndex == index;
                    final color = isSelected ? Colors.white : Colors.white70;

                    final itemContent = Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _withNavBadge(
                          index,
                          Icon(icon, color: color, size: isSelected ? 28 : 24),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            height: 1.1,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    );

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _onTabTapped(index),
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: isSelected
                              ? SizedBox(
                                  width: 56,
                                  height: 64,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    clipBehavior: Clip.hardEdge,
                                    children: [
                                      const Positioned.fill(
                                        child: P5rDynamicBackground(
                                          backgroundColor: Colors.black,
                                          borderColor: Colors.white,
                                          borderWidth: 1,
                                        ),
                                      ),
                                      itemContent,
                                    ],
                                  ),
                                )
                              : itemContent,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSolidNavBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _onTabTapped,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
        const BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Buscar',
        ),
        BottomNavigationBarItem(
          icon: _withNavBadge(2, const Icon(Icons.group)),
          label: 'Actividad',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.local_offer),
          label: 'Bundles',
        ),
        BottomNavigationBarItem(
          icon: _withNavBadge(4, const Icon(Icons.person)),
          label: 'Perfil',
        ),
      ],
    );
  }

  Widget _buildMinimalNavBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMinimalNavItem(0, Icons.home),
            _buildMinimalNavItem(1, Icons.search),
            _buildMinimalNavItem(2, Icons.group),
            _buildMinimalNavItem(3, Icons.local_offer),
            _buildMinimalNavItem(4, Icons.person),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalNavItem(int index, IconData icon) {
    final isSelected = _currentIndex == index;
    return IconButton(
      onPressed: () => _onTabTapped(index),
      icon: _withNavBadge(
        index,
        Icon(
          icon,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          size: isSelected ? 28 : 24,
        ),
      ),
    );
  }

  Widget _buildMobileNavBar(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>();
    final style = ext?.navBarStyle ?? NavBarStyle.liquidGlass;
    return switch (style) {
      NavBarStyle.liquidGlass => _buildLiquidGlassNavBar(context),
      NavBarStyle.solid => _buildSolidNavBar(context),
      NavBarStyle.minimal => _buildMinimalNavBar(context),
      NavBarStyle.persona5Royal => _buildPersona5RoyalNavBar(context),
    };
  }

  // ─── Helpers de badge ────────────────────────────────────────────────────

  /// Envuelve [child] con un badge según [tabIndex]:
  /// - índice 2 (Actividad): badge con unreadActivityCount
  /// - índice 4 (Perfil): badge con unreadFriendRequestsCount
  Widget _withNavBadge(int tabIndex, Widget child) {
    if (tabIndex == 2) {
      return ValueListenableBuilder<int>(
        valueListenable: unreadActivityCount,
        builder: (context, count, _) {
          if (count == 0) return child;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              child,
              Positioned(right: -6, top: -4, child: _buildBadgeDot(count)),
            ],
          );
        },
      );
    }
    if (tabIndex == 4) {
      return ValueListenableBuilder<int>(
        valueListenable: unreadFriendRequestsCount,
        builder: (context, count, _) {
          if (count == 0) return child;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              child,
              Positioned(right: -6, top: -4, child: _buildBadgeDot(count)),
            ],
          );
        },
      );
    }
    return child;
  }

  /// Punto/número rojo del badge.
  Widget _buildBadgeDot(int count) {
    final label = count > 9 ? '9+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.5),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final handled = AppNavigationController.instance.requestBack(
          context,
          forStack: _currentIndex,
        );
        if (!handled) {
          if (_currentIndex != 0) {
            // Si estamos en la raíz de otra pestaña, volvemos a Inicio. Vía
            // _onTabTapped (no un setState directo) para que la URL y la
            // pestaña persistida en disco también queden al día.
            _onTabTapped(0);
          } else {
            // Si estamos en la raíz de Inicio, cerramos la app
            SystemNavigator.pop();
          }
        }
      },
      child: EdgeSwipeBackDetector(
        child: Scaffold(
          extendBody: !isDesktop,
          body: Column(
            children: [
              if (isDesktop) _buildTopNavigationBar(context),
              Expanded(
                child: Stack(
                  children: [
                    _buildNavigator(0),
                    _buildNavigator(1),
                    _buildNavigator(2),
                    _buildNavigator(3),
                    _buildNavigator(4),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: isDesktop ? null : _buildMobileNavBar(context),
        ),
      ),
    );
  }
}

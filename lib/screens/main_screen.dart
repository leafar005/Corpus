import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home/home_screen.dart';
import 'library/search_screen.dart';
import 'activity/activity_screen.dart';
import 'profile/profile_screen.dart';
import 'bundles/bundles_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  // Lazy loading: las pantallas solo se instancian la primera vez que se visitan.
  // Un Set rastrea qué pestañas ya han sido inicializadas.
  final Set<int> _initializedTabs = {0}; // La pestaña 0 (Inicio) siempre se carga de entrada.
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
    // Pre-instanciamos la primera pantalla
    _getScreen(0);
    _loadSavedTab();
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
    if (!_shouldPersistTab) return;
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      final savedIndex = prefs.getInt('main_tab_index') ?? 0;
      setState(() {
        _currentIndex = savedIndex;
        _initializedTabs.add(savedIndex);
      });
    }
  }

  void _onTabTapped(int index) async {
    if (_currentIndex == index) {
      // Si toca la misma pestaña, hace "pop" hasta el principio de esa pestaña
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _currentIndex = index;
        _initializedTabs.add(index); // Marca la pestaña como inicializada
      });
      if (_shouldPersistTab) {
        SharedPreferences.getInstance().then(
          (prefs) => prefs.setInt('main_tab_index', index),
        );
      }
    }
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
        onGenerateRoute: (routeSettings) {
          return MaterialPageRoute(builder: (context) => _getScreen(index));
        },
      ),
    );
  }

  Widget _buildTopNavigationBar(BuildContext context) {
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

  Widget _buildTopNavItem(int index, String label, IconData icon) {
    final isSelected = _currentIndex == index;
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade400;

    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(35),
            child: LiquidGlassBottomNavBar(
            itemStyle: LiquidGlassNavItemStyle(
              selectedColor: isDark ? Theme.of(context).colorScheme.primary : Colors.black,
              unselectedColor: isDark ? Colors.white70 : Colors.black54,
            ),
            items: const [
              LiquidGlassTabBarItem(icon: Icons.home, label: 'Inicio'),
              LiquidGlassTabBarItem(icon: Icons.search, label: 'Buscar'),
              LiquidGlassTabBarItem(icon: Icons.group, label: 'Actividad'),
              LiquidGlassTabBarItem(icon: Icons.local_offer, label: 'Bundles'),
              LiquidGlassTabBarItem(icon: Icons.person, label: 'Perfil'),
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
        ),
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

        final NavigatorState navigator =
            _navigatorKeys[_currentIndex].currentState!;
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          if (_currentIndex != 0) {
            // Si estamos en la raíz de otra pestaña, volvemos a Inicio
            setState(() => _currentIndex = 0);
          } else {
            // Si estamos en la raíz de Inicio, cerramos la app
            SystemNavigator.pop();
          }
        }
      },
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
        bottomNavigationBar: isDesktop
            ? null
            : _buildLiquidGlassNavBar(context),
      ),
    );
  }
}

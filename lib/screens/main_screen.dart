import 'dart:io';
import 'dart:ui';
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

  late final List<Widget> _screens = [
    HomeScreen(onNavigateToSearch: () => _onTabTapped(1)),
    const SearchScreen(),
    const ActivityScreen(),
    const BundlesScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
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

  bool _isDraggingGlass = false;
  double _dragGlassX = 0.0;

  Future<void> _loadSavedTab() async {
    if (!_shouldPersistTab) return;
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentIndex = prefs.getInt('main_tab_index') ?? 0;
      });
    }
  }

  void _onTabTapped(int index) async {
    if (_currentIndex == index) {
      // Si toca la misma pestaña, hace "pop" hasta el principio de esa pestaña
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() => _currentIndex = index);
      if (_shouldPersistTab) {
        SharedPreferences.getInstance().then(
          (prefs) => prefs.setInt('main_tab_index', index),
        );
      }
    }
  }

  Widget _buildNavigator(int index) {
    return Offstage(
      offstage: _currentIndex != index,
      child: Navigator(
        key: _navigatorKeys[index],
        onGenerateRoute: (routeSettings) {
          return MaterialPageRoute(builder: (context) => _screens[index]);
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
    final isApple = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (isApple) {
      return LiquidGlassBottomNavBar(
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
        ),
      );
    }

    final items = [
      (Icons.home, 'Inicio'),
      (Icons.search, 'Buscar'),
      (Icons.group, 'Actividad'),
      (Icons.local_offer, 'Bundles'),
      (Icons.person, 'Perfil'),
    ];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        height: 65,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(35),
                // Acabado MATE elegante y escarchado para Android:
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E24).withValues(alpha: 0.78)
                    : const Color(0xFFF2F2F7).withValues(alpha: 0.88),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final itemWidth = totalWidth / items.length;
                  final pillWidth = (itemWidth * 0.85).clamp(44.0, 70.0);
                  final targetCenter = (_currentIndex + 0.5) * itemWidth;
                  final currentCenter = _isDraggingGlass
                      ? _dragGlassX.clamp(
                          pillWidth / 2,
                          totalWidth - (pillWidth / 2),
                        )
                      : targetCenter;
                  final pillLeft = currentCenter - (pillWidth / 2);

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (details) {
                      setState(() {
                        _isDraggingGlass = true;
                        _dragGlassX = details.localPosition.dx;
                      });
                    },
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _dragGlassX = details.localPosition.dx.clamp(0.0, totalWidth);
                        final int closestIndex = ((_dragGlassX / itemWidth) - 0.5)
                            .round()
                            .clamp(0, items.length - 1);
                        if (_currentIndex != closestIndex) {
                          _currentIndex = closestIndex;
                          if (_shouldPersistTab) {
                            SharedPreferences.getInstance().then(
                              (prefs) => prefs.setInt('main_tab_index', closestIndex),
                            );
                          }
                        }
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      setState(() {
                        _isDraggingGlass = false;
                      });
                    },
                    onHorizontalDragCancel: () {
                      setState(() {
                        _isDraggingGlass = false;
                      });
                    },
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        AnimatedPositioned(
                          duration: _isDraggingGlass
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          left: pillLeft,
                          width: pillWidth,
                          height: 48,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(items.length, (index) {
                            final isSelected = _currentIndex == index;
                            final (icon, label) = items[index];

                            return Expanded(
                              child: GestureDetector(
                                onTap: () => _onTabTapped(index),
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        icon,
                                        size: 22,
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                },
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

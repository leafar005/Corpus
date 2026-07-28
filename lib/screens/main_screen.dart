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

  final List<Widget> _screens = [
    const HomeScreen(),
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
        onGenerateRoute: (settings) {
          return MaterialPageRoute(builder: (context) => _screens[index]);
        },
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

  Widget _buildTopNavigationBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
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
            : BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: _onTabTapped,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: Theme.of(context).colorScheme.primary,
                unselectedItemColor: Colors.grey.shade600,
                backgroundColor: Theme.of(context).colorScheme.surface,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Inicio',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.search),
                    label: 'Buscar',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.group),
                    label: 'Actividad',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.local_offer),
                    label: 'Bundles',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person),
                    label: 'Perfil',
                  ),
                ],
              ),
      ),
    );
  }
}

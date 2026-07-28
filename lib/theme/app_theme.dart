import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notificador global para cambiar el tema en tiempo real
class ThemeNotifier extends ChangeNotifier {
  ThemeMode _currentMode = ThemeMode.system;
  Color _seedColor = Colors.deepPurpleAccent;

  ThemeMode get currentMode => _currentMode;
  Color get seedColor => _seedColor;

  ThemeNotifier() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('theme_mode') ?? 'system';
    _currentMode = ThemeMode.values.firstWhere(
      (e) => e.toString().split('.').last == modeStr,
      orElse: () => ThemeMode.system,
    );

    final colorVal = prefs.getInt('theme_color');
    if (colorVal != null) {
      _seedColor = Color(colorVal);
    }
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _currentMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.toString().split('.').last);
  }

  Future<void> setColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color', color.toARGB32());
  }
}

/// Sistema de colores obsoleto. ¡No usar estáticos para fondos!
/// Se mantiene solo para referencias a colores primarios fijos que no cambian (como el acento ámbar o morado puro).
class AppColors {
  static const Color primary = Colors.deepPurpleAccent;
  static final Color primaryDark = Colors.deepPurple.shade900;
  static const Color accent = Colors.amber;
  static const Color danger = Colors.redAccent;
}

/// Definición de los distintos temas de la aplicación (Modo Oscuro, Claro, etc.)
class AppTheme {
  // TEMA OSCURO
  static ThemeData getDarkTheme(Color seedColor) {
    const bgColor = Colors.black;
    final surfaceColor = Colors.grey.shade900;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ).copyWith(
          primary: seedColor,
          secondary: AppColors.accent,
          surface: surfaceColor,
          error: AppColors.danger,
          onSurfaceVariant: Colors.grey, // Usado para textSecondary
        );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      primaryColor: colorScheme.primary,
      colorScheme: colorScheme,
      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        selectedColor: colorScheme.primary,
        checkmarkColor: colorScheme.onPrimary,
        pressElevation: 0,
        secondarySelectedColor: colorScheme.primary,
        surfaceTintColor: colorScheme.primary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIconColor: Colors.grey,
      ),
      dividerTheme: const DividerThemeData(color: Colors.white24, thickness: 1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bgColor,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  // TEMA CLARO
  static ThemeData getLightTheme(Color seedColor) {
    const bgColor = Color(0xFFF5F5F5);
    const surfaceColor = Colors.white;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ).copyWith(
          primary: seedColor,
          secondary: AppColors.accent,
          surface: surfaceColor,
          error: AppColors.danger,
          onSurfaceVariant: Colors.grey.shade700, // Usado para textSecondary
        );

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgColor,
      primaryColor: colorScheme.primary,
      colorScheme: colorScheme,
      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        selectedColor: colorScheme.primary,
        checkmarkColor: colorScheme.onPrimary,
        pressElevation: 0,
        secondarySelectedColor: colorScheme.primary,
        surfaceTintColor: colorScheme.primary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:
            bgColor, // Usamos bgColor en lugar de primary para modo claro
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        hintStyle: TextStyle(color: Colors.grey.shade500),
        prefixIconColor: Colors.grey.shade600,
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade300, thickness: 1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: Colors
            .grey
            .shade600, // Oscurecemos un poco los iconos no seleccionados
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}

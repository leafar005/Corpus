import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'style_pack.dart';
import 'style_pack_registry.dart';
import 'corpus_theme_extension.dart';

/// Notificador global para cambiar el tema en tiempo real.
///
/// Gestiona el [ThemeMode], el color de acento (seed) y el [StylePack] activo.
class ThemeNotifier extends ChangeNotifier {
  ThemeMode _currentMode = ThemeMode.system;
  Color _seedColor = Colors.deepPurpleAccent;
  String _stylePackId = 'default';

  ThemeMode get currentMode => _currentMode;
  Color get seedColor => _seedColor;
  String get stylePackId => _stylePackId;
  StylePack get currentPack => StylePackRegistry.getById(_stylePackId);

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

    _stylePackId = prefs.getString('style_pack_id') ?? 'default';

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

  Future<void> setStylePack(String id) async {
    _stylePackId = id;
    final pack = currentPack;
    _seedColor = pack.seedColor;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('style_pack_id', id);
    await prefs.setInt('theme_color', pack.seedColor.toARGB32());
  }
}

/// Definición de los distintos temas de la aplicación (Modo Oscuro, Claro, etc.)
class AppTheme {
  /// Build a [TextTheme] for the given [fontFamily].
  /// If [fontFamily] is a Google Font name, uses [GoogleFonts]; otherwise
  /// falls back to the default Material text theme with that family applied.
  static TextTheme? _textThemeFor(String? fontFamily, Brightness brightness) {
    if (fontFamily == null) return null;
    try {
      return GoogleFonts.getTextTheme(fontFamily);
    } catch (_) {
      return ThemeData(brightness: brightness).textTheme.apply(fontFamily: fontFamily);
    }
  }

  // TEMA OSCURO
  static ThemeData getDarkTheme(Color seedColor, [StylePack? pack]) {
    pack ??= StylePack.defaultPack();

    final bgColor = pack.scaffoldDark ?? Colors.black;
    final surfaceColor = pack.surfaceDark ?? Colors.grey.shade900;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ).copyWith(
          primary: seedColor,
          secondary: pack.accentColor,
          surface: surfaceColor,
          error: Colors.redAccent,
          onSurfaceVariant: Colors.grey,
        );

    final ext = CorpusThemeExtension.fromPack(pack);
    final textTheme = _textThemeFor(pack.fontFamily, Brightness.dark);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      primaryColor: colorScheme.primary,
      colorScheme: colorScheme,
      textTheme: textTheme,
      extensions: [ext],
      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        selectedColor: colorScheme.primary,
        checkmarkColor: colorScheme.onPrimary,
        pressElevation: 0,
        secondarySelectedColor: colorScheme.primary,
        surfaceTintColor: colorScheme.primary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: pack.fontFamily,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ext.borderRadiusMedium),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ext.borderRadiusMedium),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: pack.fontFamily,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ext.borderRadiusMedium),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIconColor: Colors.grey,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
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
  static ThemeData getLightTheme(Color seedColor, [StylePack? pack]) {
    pack ??= StylePack.defaultPack();

    final bgColor = pack.scaffoldLight ?? const Color(0xFFF5F5F5);
    final surfaceColor = pack.surfaceLight ?? Colors.white;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ).copyWith(
          primary: seedColor,
          secondary: pack.accentColor,
          surface: surfaceColor,
          error: Colors.redAccent,
          onSurfaceVariant: Colors.grey.shade700,
        );

    final ext = CorpusThemeExtension.fromPack(pack);
    final textTheme = _textThemeFor(pack.fontFamily, Brightness.light);

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgColor,
      primaryColor: colorScheme.primary,
      colorScheme: colorScheme,
      textTheme: textTheme,
      extensions: [ext],
      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        selectedColor: colorScheme.primary,
        checkmarkColor: colorScheme.onPrimary,
        pressElevation: 0,
        secondarySelectedColor: colorScheme.primary,
        surfaceTintColor: colorScheme.primary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: pack.fontFamily,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ext.borderRadiusMedium),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ext.borderRadiusMedium),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: pack.fontFamily,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ext.borderRadiusMedium),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ext.borderRadiusMedium),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ext.borderRadiusMedium),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        hintStyle: TextStyle(color: Colors.grey.shade500),
        prefixIconColor: Colors.grey.shade600,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade300, thickness: 1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}

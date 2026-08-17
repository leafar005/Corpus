import 'package:flutter/material.dart';

class IgdbConstants {
  // ============================================================
  // CATEGORÍAS DE JUEGO (IGDB)
  // ============================================================
  // Fuente: https://api-docs.igdb.com/#game-enums
  //
  // Centraliza: resolución de categoría, nombre, color y
  // heurísticas por keywords en el título. NINGÚN otro archivo
  // debería hardcodear categorías ni hacer detección por título.
  // ============================================================

  /// Datos de cada categoría: nombre en español + color + keywords de detección
  static const Map<int, Map<String, dynamic>> _categoryData = {
    0: {'name': 'Juego Principal', 'colorValue': 0xFF2196F3}, // Colors.blue
    1: {'name': 'DLC', 'colorValue': 0xFFE040FB}, // Colors.purpleAccent
    2: {'name': 'Expansión', 'colorValue': 0xFFE040FB},
    3: {'name': 'Bundle', 'colorValue': 0xFFFFAB40}, // Colors.orangeAccent
    4: {'name': 'Exp. Standalone', 'colorValue': 0xFFE040FB},
    5: {'name': 'Mod', 'colorValue': 0xFF9E9E9E},
    6: {'name': 'Episodio', 'colorValue': 0xFF9E9E9E},
    7: {'name': 'Temporada', 'colorValue': 0xFF9E9E9E},
    8: {
      'name': 'Remake',
      'colorValue': 0xFFCDDC39,
    }, // Se sobreescribe con Theme.secondary en UI
    9: {'name': 'Remaster', 'colorValue': 0xFF64FFDA}, // Colors.tealAccent
    10: {
      'name': 'Ed. Expandida',
      'colorValue': 0xFFFF4081,
    }, // Colors.pinkAccent
    11: {'name': 'Port', 'colorValue': 0xFFB2FF59}, // Colors.lightGreenAccent
    12: {'name': 'Fork', 'colorValue': 0xFF9E9E9E},
    13: {'name': 'Pack', 'colorValue': 0xFFFFAB40},
    14: {
      'name': 'Actualización',
      'colorValue': 0xFF18FFFF,
    }, // Colors.cyanAccent
  };

  /// Keywords que indican que un juego es Remake (category 8)
  /// aunque IGDB lo haya marcado como main_game (0).
  static const List<String> _remakeKeywords = [
    'remake',
    'resynced',
    'reforged',
    'kiwami',
    'twin snakes',
    'reloaded',
    // 'part i' eliminado: se usa regex con word boundary para no afectar 'Part II', 'Part III', etc.
  ];

  /// Regex para detectar exactamente "Part I" (no "Part II", "Part III"...) mediante word boundary.
  static final RegExp _partIRegex = RegExp(r'\bpart i\b', caseSensitive: false);

  /// Keywords que indican que un juego es Remaster (category 9).
  static const List<String> _remasterKeywords = [
    'remaster',
    'definitive edition',
    "director's cut",
    'redux',
    'resurrected',
    'anniversary edition',
  ];

  /// Regex adicional para detectar "HD" como palabra completa.
  static final RegExp _hdRegex = RegExp(r'\bhd\b');

  /// Keywords que indican DLC/addon (category 1).
  static const List<String> _dlcKeywords = ['dlc', 'expansion pass'];

  /// Keywords que indican Edición Expandida (category 10).
  static const List<String> _expandedKeywords = [
    'ultimate edition',
    'game of the year',
    'goty',
    'royal',
    'golden',
    'complete edition',
    'deluxe edition',
  ];

  // ============================================================
  // API PÚBLICA
  // ============================================================

  /// Resuelve la categoría real de un juego, compensando los casos
  /// en los que IGDB devuelve `0` (main_game) para remakes, remasters, etc.
  ///
  /// [igdbCategory] — valor numérico de `category` de IGDB (puede ser null).
  /// [title] — nombre del juego (para heurísticas por keywords).
  /// [hasParentGame] — si el juego tiene `parent_game` en IGDB.
  /// [summary] — sinopsis del juego (útil para detectar mods si IGDB falla).
  ///
  /// Devuelve el `int` de categoría resuelto, o null si es un juego base normal.
  static int? resolveCategory(
    int? igdbCategory,
    String title, {
    bool hasParentGame = false,
    String? summary,
  }) {
    // Si IGDB ya devolvió una categoría no-base, confiar en ella.
    if (igdbCategory != null && igdbCategory != 0) {
      return igdbCategory;
    }

    // IGDB devolvió null o 0. Usar heurísticas para intentar resolver.
    final lowerTitle = title.toLowerCase();
    final lowerSummary = summary?.toLowerCase() ?? '';

    if (_remakeKeywords.any((k) => lowerTitle.contains(k)) ||
        _partIRegex.hasMatch(title)) {
      return 8;
    }
    if (_remasterKeywords.any((k) => lowerTitle.contains(k)) ||
        _hdRegex.hasMatch(lowerTitle)) {
      return 9;
    }
    if (_expandedKeywords.any((k) => lowerTitle.contains(k))) return 10;
    if (hasParentGame || _dlcKeywords.any((k) => lowerTitle.contains(k))) return 1;

    // Si IGDB lo catalogó mal pero el título o resumen menciona que es un mod como palabra suelta
    if (RegExp(r'\bmod\b').hasMatch(lowerTitle) ||
        RegExp(r'\bmod\b').hasMatch(lowerSummary)) {
      return 5;
    }


    // Es un juego base normal → devolver null (no mostrar badge).
    return null;
  }

  /// Nombre legible en español para una categoría resuelta.
  static String getCategoryName(int id) {
    return _categoryData[id]?['name'] ?? 'Desconocido';
  }

  /// Color asociado a una categoría.
  /// [themeSecondary] — color secundario del tema, usado para Remake.
  static Color getCategoryColor(int id, {Color? themeSecondary}) {
    if (id == 8 && themeSecondary != null) return themeSecondary;
    final colorValue = _categoryData[id]?['colorValue'] as int?;
    return colorValue != null ? Color(colorValue) : Colors.grey;
  }

  /// Devuelve true si esta categoría NO debería mostrar badge (es juego base).
  static bool isMainGame(int? category) {
    return category == null || category == 0;
  }

  /// Lista de categorías para filtros UI.
  static List<Map<String, dynamic>> get categories => _categoryData.entries
      .map((e) => {'id': e.key, 'name': e.value['name']})
      .toList();

  // ============================================================
  // OTROS DATOS ESTÁTICOS DE IGDB (sin cambios)
  // ============================================================

  static const List<Map<String, dynamic>> genres = [
    {"id": 2, "name": "Point-and-click"},
    {"id": 4, "name": "Fighting"},
    {"id": 5, "name": "Shooter"},
    {"id": 7, "name": "Music"},
    {"id": 8, "name": "Platform"},
    {"id": 9, "name": "Puzzle"},
    {"id": 10, "name": "Racing"},
    {"id": 11, "name": "Real Time Strategy (RTS)"},
    {"id": 12, "name": "Role-playing (RPG)"},
    {"id": 13, "name": "Simulator"},
    {"id": 14, "name": "Sport"},
    {"id": 15, "name": "Strategy"},
    {"id": 16, "name": "Turn-based strategy (TBS)"},
    {"id": 24, "name": "Tactical"},
    {"id": 25, "name": "Hack and slash/Beat 'em up"},
    {"id": 26, "name": "Quiz/Trivia"},
    {"id": 30, "name": "Pinball"},
    {"id": 31, "name": "Adventure"},
    {"id": 32, "name": "Indie"},
    {"id": 33, "name": "Arcade"},
    {"id": 34, "name": "Visual Novel"},
    {"id": 35, "name": "Card & Board Game"},
    {"id": 36, "name": "MOBA"},
  ];

  static const List<Map<String, dynamic>> themes = [
    {"id": 31, "name": "Drama"},
    {"id": 32, "name": "Non-fiction"},
    {"id": 33, "name": "Sandbox"},
    {"id": 34, "name": "Educational"},
    {"id": 35, "name": "Kids"},
    {"id": 38, "name": "Open world"},
    {"id": 39, "name": "Warfare"},
    {"id": 40, "name": "Party"},
    {"id": 41, "name": "4X (explore, expand, exploit, and exterminate)"},
    {"id": 42, "name": "Erotic"},
    {"id": 43, "name": "Mystery"},
    {"id": 1, "name": "Action"},
    {"id": 17, "name": "Fantasy"},
    {"id": 18, "name": "Science fiction"},
    {"id": 19, "name": "Horror"},
    {"id": 20, "name": "Thriller"},
    {"id": 21, "name": "Survival"},
    {"id": 22, "name": "Historical"},
    {"id": 23, "name": "Stealth"},
    {"id": 27, "name": "Comedy"},
    {"id": 28, "name": "Business"},
    {"id": 44, "name": "Romance"},
  ];

  static const List<Map<String, dynamic>> gameModes = [
    {"id": 1, "name": "Single player"},
    {"id": 2, "name": "Multiplayer"},
    {"id": 3, "name": "Co-operative"},
    {"id": 4, "name": "Split screen"},
    {"id": 5, "name": "Massively Multiplayer Online (MMO)"},
    {"id": 6, "name": "Battle Royale"},
  ];

  static const List<Map<String, dynamic>> playerPerspectives = [
    {"id": 1, "name": "First person"},
    {"id": 2, "name": "Third person"},
    {"id": 3, "name": "Bird view / Isometric"},
    {"id": 4, "name": "Side view"},
    {"id": 5, "name": "Text"},
    {"id": 6, "name": "Auditory"},
    {"id": 7, "name": "Virtual Reality"},
  ];

  static const List<Map<String, dynamic>> popularPlatforms = [
    {"id": 6, "name": "PC (Windows)"},
    {"id": 14, "name": "Mac"},
    {"id": 3, "name": "Linux"},
    {"id": 167, "name": "PlayStation 5"},
    {"id": 48, "name": "PlayStation 4"},
    {"id": 9, "name": "PlayStation 3"},
    {"id": 8, "name": "PlayStation 2"},
    {"id": 7, "name": "PlayStation"},
    {"id": 46, "name": "PlayStation Vita"},
    {"id": 38, "name": "PlayStation Portable"},
    {"id": 169, "name": "Xbox Series X|S"},
    {"id": 49, "name": "Xbox One"},
    {"id": 12, "name": "Xbox 360"},
    {"id": 11, "name": "Xbox"},
    {"id": 130, "name": "Nintendo Switch"},
    {"id": 41, "name": "Wii U"},
    {"id": 5, "name": "Wii"},
    {"id": 21, "name": "Nintendo GameCube"},
    {"id": 4, "name": "Nintendo 64"},
    {"id": 19, "name": "Super Nintendo (SNES)"},
    {"id": 18, "name": "Nintendo (NES)"},
    {"id": 37, "name": "Nintendo 3DS"},
    {"id": 20, "name": "Nintendo DS"},
    {"id": 24, "name": "Game Boy Advance"},
    {"id": 33, "name": "Game Boy"},
    {"id": 23, "name": "Dreamcast"},
    {"id": 32, "name": "Sega Saturn"},
    {"id": 29, "name": "Sega Mega Drive / Genesis"},
    {"id": 34, "name": "Android"},
    {"id": 39, "name": "iOS"},
  ];

  // ============================================================
  // FORMATTERS
  // ============================================================

  static const Map<String, String> _genreEmojis = {
    'Action': '💥 Acción',
    'Adventure': '🗺️ Aventura',
    'Role-playing (RPG)': '🛡️ Rol (RPG)',
    'Shooter': '🎯 Shooter',
    'Strategy': '♟️ Estrategia',
    'Puzzle': '🧩 Puzles',
    'Racing': '🏎️ Carreras',
    'Simulator': '🕹️ Simulación',
    'Sport': '⚽ Deportes',
    'Fighting': '🥊 Lucha',
    'Platform': '🍄 Plataformas',
    'Indie': '🎨 Indie',
    'Music': '🎵 Música',
    'Arcade': '👾 Arcade',
    'Visual Novel': '📖 Novela Visual',
    'Point-and-click': '🖱️ Point-and-click',
    'Tactical': '🧠 Táctica',
    'Card & Board Game': '🃏 Cartas y Tablero',
    "Hack and slash/Beat 'em up": '⚔️ Hack and slash/Beat \'em up',
    'Pinball': '🎰 Pinball',
    'Quiz/Trivia': '❓ Trivial',
    'Real Time Strategy (RTS)': '⏱️ Estrategia en tiempo real (RTS)',
    'Turn-based strategy (TBS)': '⏳ Estrategia por turnos (TBS)',
    'MOBA': '🏟️ MOBA',
  };

  static const Map<String, String> _themeEmojis = {
    'Action': '💥 Acción',
    'Fantasy': '🧙‍♂️ Fantasía',
    'Science fiction': '🚀 Ciencia ficción',
    'Horror': '👻 Terror',
    'Survival': '🏕️ Supervivencia',
    'Thriller': '😱 Suspense',
    'Comedy': '😂 Comedia',
    'Kids': '🧒 Infantil',
    'Romance': '💖 Romance',
    'Drama': '🎭 Drama',
    'Historical': '🏛️ Histórico',
    'Non-fiction': '📚 No ficción',
    'Sandbox': '🏖️ Sandbox',
    'Educational': '🎓 Educativo',
    'Mystery': '🕵️ Misterio',
    'Party': '🎉 Party',
    'Open world': '🌍 Mundo abierto',
    'Stealth': '🥷 Sigilo',
  };

  static String formatGenreWithEmoji(String genre) {
    return _genreEmojis[genre] ?? genre;
  }

  static String formatThemeWithEmoji(String theme) {
    return _themeEmojis[theme] ?? theme;
  }

  static Map<String, dynamic> getPlatformStyle(String platform) {
    final lower = platform.toLowerCase();
    if (lower.contains('pc') || lower.contains('windows')) {
      return {
        'color': Colors.blue.shade700,
        'icon': 'assets/images/windows.png',
        'textColor': Colors.white,
      };
    }
    if (lower.contains('linux')) {
      return {
        'color': Colors.orangeAccent.shade700,
        'icon': 'assets/images/linux.png',
        'textColor': Colors.white,
      };
    }
    if (lower.contains('playstation') ||
        lower == 'psn' ||
        lower == 'ps2' ||
        lower == 'ps3' ||
        lower == 'ps4' ||
        lower == 'ps5' ||
        lower.contains('vita')) {
      return {
        'color': const Color(0xFF003791),
        'icon': 'assets/images/playstation.png',
        'textColor': Colors.white,
      };
    }
    if (lower.contains('xbox')) {
      return {
        'color': const Color(0xFF107C10),
        'icon': 'assets/images/xbox.png',
        'textColor': Colors.white,
      };
    }
    if (lower.contains('wii u')) {
      return {
        'color': const Color(0xFF009AC7),
        'icon': 'assets/images/wiiu.png',
        'textColor': Colors.white,
      };
    }
    if (lower.contains('wii')) {
      return {
        'color': Colors.grey.shade400,
        'icon': 'assets/images/wii.png',
        'textColor': Colors.black87,
      };
    }
    if (lower.contains('3ds')) {
      return {
        'color': const Color(0xFFCE181E),
        'icon': 'assets/images/3ds.png',
        'textColor': Colors.white,
      };
    }
    if (lower.contains('ds')) {
      return {
        'color': Colors.grey.shade400,
        'icon': 'assets/images/ds.png',
        'textColor': Colors.black87,
      };
    }
    if (lower.contains('switch 2')) {
      return {
        'color': const Color(0xFFE60012),
        'icon': 'assets/images/switch2.png',
        'textColor': Colors.white,
      };
    }
    if (lower.contains('switch') || lower.contains('nintendo')) {
      return {
        'color': const Color(0xFFE60012),
        'icon': 'assets/images/switch.png',
        'textColor': Colors.white,
      };
    }
    if (lower.contains('mac') ||
        lower.contains('ios') ||
        lower.contains('apple')) {
      return {
        'color': Colors.grey.shade800,
        'icon': 'assets/images/mac.png',
        'textColor': Colors.white,
      };
    }
    if (lower.contains('android')) {
      return {
        'color': const Color(0xFF3DDC84),
        'icon': 'assets/images/android.png',
        'textColor': Colors.black87,
      };
    }
    if (lower.contains('google') || lower.contains('stadia')) {
      return {
        'color': Colors.deepOrange,
        'icon': 'assets/images/google.png',
        'textColor': Colors.white,
      };
    }
    if (lower.contains('vr') || lower.contains('oculus') || lower.contains('cardboard')) {
      return {
        'color': Colors.grey.shade300,
        'icon': 'assets/images/vr.png',
        'textColor': Colors.black87,
      };
    }
    if (lower.contains('fire tv') || lower.contains('amazon')) {
      return {
        'color': Colors.orange,
        'icon': null,
        'materialIcon': Icons.tv,
        'textColor': Colors.black87,
      };
    }
    return {
      'color': Colors.blueGrey.withValues(alpha: 0.3),
      'icon': null,
      'textColor': Colors.white,
    };
  }
}

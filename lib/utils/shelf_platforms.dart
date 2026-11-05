import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';

/// Dimensiones físicas aproximadas de la caja (lomo × alto en mm).
///
/// Referencias: CoverStitch case dimensions, Wikipedia keep case specs,
/// Blu-ray packaging (171.4×136×15 mm).
@immutable
class ShelfCaseDimensions {
  const ShelfCaseDimensions({
    required this.spineMm,
    required this.heightMm,
  });

  /// Grosor del lomo (profundidad de la caja en estantería).
  final double spineMm;

  /// Altura de la caja de pie.
  final double heightMm;

  /// Escala única mm → px para **ancho y alto**.
  ///
  /// Antes usábamos factores distintos para lomo y altura, lo que aplastaba
  /// las cajas (p. ej. Wii 14×135 mm se veía casi cuadrada). Una sola escala
  /// conserva la proporción real: Switch (10×160) queda más alto y fino que
  /// Wii (14×135).
  ///
  /// Referencia: Caja DVD (PS2 / Wii / Xbox 360 / PC) 183 mm ≈ 300 px de alto en pantalla.
  static const double pxPerMm = 300 / 183;

  double get uiWidth => spineMm * pxPerMm;

  double get uiHeight => heightMm * pxPerMm;

  double get aspectRatio => heightMm / spineMm;
}

/// Plataforma de propiedad para la estantería virtual.
/// Independiente de las plataformas IGDB del catálogo de juegos.
@immutable
class ShelfPlatform {
  const ShelfPlatform({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.color,
    this.iconAsset,
    this.fallbackIcon,
    this.textColor = Colors.white,
    this.group = 'Otras',
  });

  /// Valor almacenado en `user_game_platforms.platform_name`.
  final String id;
  final String label;
  final String shortLabel;
  final Color color;
  final String? iconAsset;
  final CorpusIconKind? fallbackIcon;
  final Color textColor;
  final String group;
}

/// Catálogo fijo de plataformas donde la gente suele tener juegos físicos o digitales.
abstract final class ShelfPlatforms {
  static const List<ShelfPlatform> all = [
    // PlayStation
    ShelfPlatform(
      id: 'PS1',
      label: 'PlayStation (PS1)',
      shortLabel: 'PS1',
      color: Color(0xFF003791),
      iconAsset: 'assets/images/playstation.png',
      group: 'PlayStation',
    ),
    ShelfPlatform(
      id: 'PS2',
      label: 'PlayStation 2',
      shortLabel: 'PS2',
      color: Color(0xFF003791),
      iconAsset: 'assets/images/playstation.png',
      group: 'PlayStation',
    ),
    ShelfPlatform(
      id: 'PS3',
      label: 'PlayStation 3',
      shortLabel: 'PS3',
      color: Color(0xFF003791),
      iconAsset: 'assets/images/playstation.png',
      group: 'PlayStation',
    ),
    ShelfPlatform(
      id: 'PS4',
      label: 'PlayStation 4',
      shortLabel: 'PS4',
      color: Color(0xFF003791),
      iconAsset: 'assets/images/playstation.png',
      group: 'PlayStation',
    ),
    ShelfPlatform(
      id: 'PS5',
      label: 'PlayStation 5',
      shortLabel: 'PS5',
      color: Color(0xFF003791),
      iconAsset: 'assets/images/playstation.png',
      group: 'PlayStation',
    ),
    ShelfPlatform(
      id: 'PSP',
      label: 'PSP',
      shortLabel: 'PSP',
      color: Color(0xFF003791),
      iconAsset: 'assets/images/playstation.png',
      group: 'PlayStation',
    ),
    ShelfPlatform(
      id: 'PS Vita',
      label: 'PS Vita',
      shortLabel: 'Vita',
      color: Color(0xFF003791),
      iconAsset: 'assets/images/playstation.png',
      group: 'PlayStation',
    ),

    // Xbox
    ShelfPlatform(
      id: 'Xbox',
      label: 'Xbox (original)',
      shortLabel: 'Xbox',
      color: Color(0xFF107C10),
      iconAsset: 'assets/images/xbox.png',
      group: 'Xbox',
    ),
    ShelfPlatform(
      id: 'Xbox 360',
      label: 'Xbox 360',
      shortLabel: '360',
      color: Color(0xFF107C10),
      iconAsset: 'assets/images/xbox.png',
      group: 'Xbox',
    ),
    ShelfPlatform(
      id: 'Xbox One',
      label: 'Xbox One',
      shortLabel: 'Xbox One',
      color: Color(0xFF107C10),
      iconAsset: 'assets/images/xbox.png',
      group: 'Xbox',
    ),
    ShelfPlatform(
      id: 'Xbox Series',
      label: 'Xbox Series X|S',
      shortLabel: 'Series X|S',
      color: Color(0xFF107C10),
      iconAsset: 'assets/images/xbox.png',
      group: 'Xbox',
    ),

    // Nintendo — consolas
    ShelfPlatform(
      id: 'NES',
      label: 'Nintendo (NES)',
      shortLabel: 'NES',
      color: Color(0xFFE60012),
      iconAsset: 'assets/images/switch.png',
      group: 'Nintendo',
    ),
    ShelfPlatform(
      id: 'SNES',
      label: 'Super Nintendo (SNES)',
      shortLabel: 'SNES',
      color: Color(0xFFE60012),
      iconAsset: 'assets/images/switch.png',
      group: 'Nintendo',
    ),
    ShelfPlatform(
      id: 'N64',
      label: 'Nintendo 64',
      shortLabel: 'N64',
      color: Color(0xFFE60012),
      iconAsset: 'assets/images/switch.png',
      group: 'Nintendo',
    ),
    ShelfPlatform(
      id: 'GameCube',
      label: 'Nintendo GameCube',
      shortLabel: 'GC',
      color: Color(0xFF6A5ACD),
      iconAsset: 'assets/images/switch.png',
      group: 'Nintendo',
    ),
    ShelfPlatform(
      id: 'Wii',
      label: 'Nintendo Wii',
      shortLabel: 'Wii',
      color: Color(0xFF9E9E9E),
      iconAsset: 'assets/images/wii.png',
      textColor: Color(0xFF212121),
      group: 'Nintendo',
    ),
    ShelfPlatform(
      id: 'Wii U',
      label: 'Nintendo Wii U',
      shortLabel: 'Wii U',
      color: Color(0xFF009AC7),
      iconAsset: 'assets/images/wiiu.png',
      group: 'Nintendo',
    ),
    ShelfPlatform(
      id: 'Nintendo DS',
      label: 'Nintendo DS',
      shortLabel: 'DS',
      color: Color(0xFF9E9E9E),
      iconAsset: 'assets/images/ds.png',
      textColor: Color(0xFF212121),
      group: 'Nintendo',
    ),
    ShelfPlatform(
      id: 'Nintendo 3DS',
      label: 'Nintendo 3DS',
      shortLabel: '3DS',
      color: Color(0xFFCE181E),
      iconAsset: 'assets/images/3ds.png',
      group: 'Nintendo',
    ),
    ShelfPlatform(
      id: 'Nintendo Switch',
      label: 'Nintendo Switch',
      shortLabel: 'Switch',
      color: Color(0xFFE60012),
      iconAsset: 'assets/images/switch.png',
      group: 'Nintendo',
    ),
    ShelfPlatform(
      id: 'Nintendo Switch 2',
      label: 'Nintendo Switch 2',
      shortLabel: 'Switch 2',
      color: Color(0xFFE60012),
      iconAsset: 'assets/images/switch2.png',
      group: 'Nintendo',
    ),
    ShelfPlatform(
      id: 'Game Boy',
      label: 'Game Boy / Color',
      shortLabel: 'GB',
      color: Color(0xFF9E9E9E),
      textColor: Color(0xFF212121),
      fallbackIcon: CorpusIconKind.VideogameAsset,
      group: 'Nintendo',
    ),
    ShelfPlatform(
      id: 'Game Boy Advance',
      label: 'Game Boy Advance',
      shortLabel: 'GBA',
      color: Color(0xFF6A5ACD),
      fallbackIcon: CorpusIconKind.VideogameAsset,
      group: 'Nintendo',
    ),

    // Sega
    ShelfPlatform(
      id: 'Mega Drive',
      label: 'Sega Mega Drive / Genesis',
      shortLabel: 'Mega Drive',
      color: Color(0xFF0060A8),
      fallbackIcon: CorpusIconKind.VideogameAsset,
      group: 'Sega',
    ),
    ShelfPlatform(
      id: 'Master System',
      label: 'Sega Master System',
      shortLabel: 'Master Sys',
      color: Color(0xFFB71C1C),
      fallbackIcon: CorpusIconKind.VideogameAsset,
      group: 'Sega',
    ),
    ShelfPlatform(
      id: 'Dreamcast',
      label: 'Sega Dreamcast',
      shortLabel: 'Dreamcast',
      color: Color(0xFFFF6D00),
      fallbackIcon: CorpusIconKind.VideogameAsset,
      group: 'Sega',
    ),

    // PC y tiendas digitales
    ShelfPlatform(
      id: 'PC',
      label: 'PC',
      shortLabel: 'PC',
      color: Color(0xFF1565C0),
      iconAsset: 'assets/images/windows.png',
      group: 'PC y digital',
    ),
    ShelfPlatform(
      id: 'Steam',
      label: 'Steam',
      shortLabel: 'Steam',
      color: Color(0xFF171A21),
      iconAsset: 'assets/images/steam.png',
      group: 'PC y digital',
    ),
    ShelfPlatform(
      id: 'Epic Games',
      label: 'Epic Games Store',
      shortLabel: 'Epic',
      color: Color(0xFF2F2F2F),
      fallbackIcon: CorpusIconKind.StorefrontRounded,
      group: 'PC y digital',
    ),
    ShelfPlatform(
      id: 'GOG',
      label: 'GOG',
      shortLabel: 'GOG',
      color: Color(0xFF86328A),
      fallbackIcon: CorpusIconKind.StoreRounded,
      group: 'PC y digital',
    ),
    ShelfPlatform(
      id: 'EA App',
      label: 'EA App (Origin)',
      shortLabel: 'EA',
      color: Color(0xFFFF4747),
      fallbackIcon: CorpusIconKind.StoreRounded,
      group: 'PC y digital',
    ),
    ShelfPlatform(
      id: 'Ubisoft Connect',
      label: 'Ubisoft Connect',
      shortLabel: 'Ubisoft',
      color: Color(0xFF0070FF),
      fallbackIcon: CorpusIconKind.StoreRounded,
      group: 'PC y digital',
    ),
    ShelfPlatform(
      id: 'Battle.net',
      label: 'Battle.net',
      shortLabel: 'Battle.net',
      color: Color(0xFF00AEFF),
      fallbackIcon: CorpusIconKind.CloudRounded,
      group: 'PC y digital',
    ),
    ShelfPlatform(
      id: 'Mac',
      label: 'Mac',
      shortLabel: 'Mac',
      color: Color(0xFF424242),
      iconAsset: 'assets/images/mac.png',
      group: 'PC y digital',
    ),
    ShelfPlatform(
      id: 'Linux',
      label: 'Linux',
      shortLabel: 'Linux',
      color: Color(0xFFE65100),
      iconAsset: 'assets/images/linux.png',
      textColor: Color(0xFF212121),
      group: 'PC y digital',
    ),

    // Móvil y otros
    ShelfPlatform(
      id: 'Android',
      label: 'Android',
      shortLabel: 'Android',
      color: Color(0xFF3DDC84),
      iconAsset: 'assets/images/android.png',
      textColor: Color(0xFF212121),
      group: 'Móvil',
    ),
    ShelfPlatform(
      id: 'iOS',
      label: 'iOS / iPhone',
      shortLabel: 'iOS',
      color: Color(0xFF424242),
      iconAsset: 'assets/images/mac.png',
      group: 'Móvil',
    ),
    ShelfPlatform(
      id: 'VR',
      label: 'Realidad virtual',
      shortLabel: 'VR',
      color: Color(0xFFBDBDBD),
      iconAsset: 'assets/images/vr.png',
      textColor: Color(0xFF212121),
      group: 'Otras',
    ),
  ];

  static final Map<String, ShelfPlatform> _byId = {
    for (final p in all) p.id: p,
  };

  static List<String> get allIds => all.map((p) => p.id).toList();

  static List<String> get groupOrder => [
    'PlayStation',
    'Xbox',
    'Nintendo',
    'Sega',
    'PC y digital',
    'Móvil',
    'Otras',
  ];

  static ShelfPlatform? findById(String id) => _byId[id];

  /// Dimensiones de caja física por plataforma (mm).
  ///
  /// Lomo (spineMm) × alto de pie (heightMm) en estantería (estándar PAL/Europa):
  /// - Switch / Switch 2: 161 × 10 mm
  /// - 3DS (PAL): 115 × 14 mm
  /// - DS (PAL): 115 × 16 mm
  /// - Wii / Wii U / GameCube: 183 × 14 mm
  /// - NES (cartucho): 120 × 20 mm
  /// - SNES / N64 (caja de cartón clásica): 126 × 34 mm
  /// - Game Boy / Color / GBA (caja de cartón): 126 × 25 mm
  /// - PS4 / PS5 / PS3 (Blu-ray): 149 × 14 mm
  /// - PS2 / PSP (Caja DVD): 183 × 14 mm
  /// - PS Vita: 125 × 10 mm
  /// - PS1 (PAL caja gruesa): 118 × 24 mm
  /// - Xbox One / Xbox Series X: 149 × 12 mm
  /// - Xbox Clásica / Xbox 360 (Caja DVD): 183 × 14 mm
  /// - PC (Caja DVD estándar): 183 × 14 mm
  /// - Sega Mega Drive / Master System (Caja plástica): 173 × 22 mm
  /// - Sega Dreamcast (PAL caja gruesa): 118 × 24 mm
  static const Map<String, ShelfCaseDimensions> _caseDimensionsById = {
    // PlayStation (Sony)
    'PS1': ShelfCaseDimensions(spineMm: 24, heightMm: 118),
    'PS2': ShelfCaseDimensions(spineMm: 14, heightMm: 183),
    'PS3': ShelfCaseDimensions(spineMm: 14, heightMm: 149),
    'PS4': ShelfCaseDimensions(spineMm: 14, heightMm: 149),
    'PS5': ShelfCaseDimensions(spineMm: 14, heightMm: 149),
    'PSP': ShelfCaseDimensions(spineMm: 14, heightMm: 183),
    'PS Vita': ShelfCaseDimensions(spineMm: 10, heightMm: 125),

    // Xbox (Microsoft)
    'Xbox': ShelfCaseDimensions(spineMm: 14, heightMm: 183),
    'Xbox 360': ShelfCaseDimensions(spineMm: 14, heightMm: 183),
    'Xbox One': ShelfCaseDimensions(spineMm: 12, heightMm: 149),
    'Xbox Series': ShelfCaseDimensions(spineMm: 12, heightMm: 149),

    // Nintendo (Cajas de disco/tarjeta + cartuchos/cajas de cartón clásicas)
    'NES': ShelfCaseDimensions(spineMm: 20, heightMm: 120),
    'SNES': ShelfCaseDimensions(spineMm: 34, heightMm: 126),
    'N64': ShelfCaseDimensions(spineMm: 34, heightMm: 126),
    'GameCube': ShelfCaseDimensions(spineMm: 14, heightMm: 183),
    'Wii': ShelfCaseDimensions(spineMm: 14, heightMm: 183),
    'Wii U': ShelfCaseDimensions(spineMm: 14, heightMm: 183),
    'Nintendo DS': ShelfCaseDimensions(spineMm: 16, heightMm: 115),
    'Nintendo 3DS': ShelfCaseDimensions(spineMm: 14, heightMm: 115),
    'Nintendo Switch': ShelfCaseDimensions(spineMm: 10, heightMm: 161),
    'Nintendo Switch 2': ShelfCaseDimensions(spineMm: 10, heightMm: 161),
    'Game Boy': ShelfCaseDimensions(spineMm: 25, heightMm: 126),
    'Game Boy Advance': ShelfCaseDimensions(spineMm: 25, heightMm: 126),

    // Sega
    'Mega Drive': ShelfCaseDimensions(spineMm: 22, heightMm: 173),
    'Master System': ShelfCaseDimensions(spineMm: 22, heightMm: 173),
    'Dreamcast': ShelfCaseDimensions(spineMm: 24, heightMm: 118),

    // PC / tiendas digitales (Caja DVD estándar 183 × 14 mm)
    'PC': ShelfCaseDimensions(spineMm: 14, heightMm: 183),
    'Steam': ShelfCaseDimensions(spineMm: 14, heightMm: 183),
    'Epic Games': ShelfCaseDimensions(spineMm: 14, heightMm: 183),
    'GOG': ShelfCaseDimensions(spineMm: 14, heightMm: 183),
    'EA App': ShelfCaseDimensions(spineMm: 14, heightMm: 183),
    'Ubisoft Connect': ShelfCaseDimensions(spineMm: 14, heightMm: 183),
    'Battle.net': ShelfCaseDimensions(spineMm: 14, heightMm: 183),
    'Mac': ShelfCaseDimensions(spineMm: 14, heightMm: 183),
    'Linux': ShelfCaseDimensions(spineMm: 14, heightMm: 183),

    // Móvil / otros (sin caja física estándar)
    'Android': ShelfCaseDimensions(spineMm: 8, heightMm: 120),
    'iOS': ShelfCaseDimensions(spineMm: 8, heightMm: 120),
    'VR': ShelfCaseDimensions(spineMm: 14, heightMm: 149),
  };

  static const ShelfCaseDimensions _defaultCase = ShelfCaseDimensions(
    spineMm: 14,
    heightMm: 183,
  );

  static ShelfCaseDimensions caseDimensionsFor(String platformName) {
    final id = normalizeToId(platformName) ?? platformName;
    return _caseDimensionsById[id] ?? _defaultCase;
  }

  /// Nombres IGDB esperados en `games.platforms` por plataforma de estantería.
  static const Map<String, List<String>> _igdbNamesByShelfId = {
    'PS1': ['PlayStation'],
    'PS2': ['PlayStation 2'],
    'PS3': ['PlayStation 3'],
    'PS4': ['PlayStation 4'],
    'PS5': ['PlayStation 5'],
    'PSP': ['PlayStation Portable'],
    'PS Vita': ['PlayStation Vita'],
    'Xbox': ['Xbox'],
    'Xbox 360': ['Xbox 360'],
    'Xbox One': ['Xbox One'],
    'Xbox Series': ['Xbox Series X|S'],
    'NES': ['Nintendo (NES)', 'Nintendo Entertainment System (NES)'],
    'SNES': ['Super Nintendo (SNES)'],
    'N64': ['Nintendo 64'],
    'GameCube': ['Nintendo GameCube'],
    'Wii': ['Wii'],
    'Wii U': ['Wii U'],
    'Nintendo DS': ['Nintendo DS'],
    'Nintendo 3DS': ['Nintendo 3DS'],
    'Nintendo Switch': ['Nintendo Switch'],
    'Nintendo Switch 2': ['Nintendo Switch 2'],
    'Game Boy': ['Game Boy', 'Game Boy Color'],
    'Game Boy Advance': ['Game Boy Advance'],
    'Mega Drive': ['Sega Mega Drive/Genesis', 'Genesis', 'Mega Drive'],
    'Master System': ['Sega Master System/Mark III', 'Master System'],
    'Dreamcast': ['Dreamcast'],
    'PC': ['PC (Microsoft Windows)', 'PC (Windows)', 'DOS', 'Linux', 'Mac'],
    'Steam': ['PC (Microsoft Windows)', 'PC (Windows)', 'Linux', 'Mac'],
    'Epic Games': ['PC (Microsoft Windows)', 'PC (Windows)', 'Mac'],
    'GOG': ['PC (Microsoft Windows)', 'PC (Windows)', 'DOS', 'Linux', 'Mac'],
    'EA App': ['PC (Microsoft Windows)', 'PC (Windows)', 'Mac'],
    'Ubisoft Connect': ['PC (Microsoft Windows)', 'PC (Windows)'],
    'Battle.net': ['PC (Microsoft Windows)', 'PC (Windows)', 'Mac'],
    'Mac': ['Mac'],
    'Linux': ['Linux'],
    'Android': ['Android'],
    'iOS': ['iOS'],
    'VR': [
      'Oculus VR',
      'Oculus Quest',
      'Oculus Rift',
      'HTC Vive',
      'PlayStation VR',
      'PlayStation VR2',
      'SteamVR',
    ],
  };

  /// ¿El juego del catálogo IGDB está disponible en esta plataforma de estantería?
  static bool gameMatchesShelfPlatform(
    List<String> gamePlatforms,
    String shelfPlatformId,
  ) {
    final id = normalizeToId(shelfPlatformId) ?? shelfPlatformId;
    if (gamePlatforms.isEmpty) return false;

    for (final gamePlatform in gamePlatforms) {
      if (_gamePlatformMatchesShelf(gamePlatform, id)) return true;
    }
    return false;
  }

  static bool _gamePlatformMatchesShelf(String gamePlatform, String shelfId) {
    final gp = gamePlatform.toLowerCase().trim();
    if (gp.isEmpty) return false;

    final igdbNames = _igdbNamesByShelfId[shelfId] ?? [];
    for (final name in igdbNames) {
      if (gp == name.toLowerCase()) return true;
    }

    return switch (shelfId) {
      'Wii U' => gp.contains('wii u'),
      'Wii' => gp == 'wii' || (gp.contains('wii') && !gp.contains('wii u')),
      'Nintendo Switch 2' =>
        gp.contains('switch 2') || gp.contains('switch2'),
      'Nintendo Switch' =>
        gp.contains('nintendo switch') && !gp.contains('switch 2'),
      'Nintendo DS' => gp.contains('nintendo ds') && !gp.contains('3ds'),
      'Nintendo 3DS' => gp.contains('3ds'),
      'Game Boy Advance' =>
        gp.contains('game boy advance') || gp == 'gba',
      'Game Boy' =>
        gp == 'game boy' ||
        gp.contains('game boy color') ||
        (gp.contains('game boy') && !gp.contains('advance')),
      'Xbox Series' => gp.contains('xbox series'),
      'Xbox One' => gp.contains('xbox one'),
      'Xbox 360' => gp.contains('xbox 360'),
      'Xbox' =>
        gp == 'xbox' ||
        (gp.contains('xbox') &&
            !gp.contains('360') &&
            !gp.contains('one') &&
            !gp.contains('series')),
      'PS1' => gp == 'playstation' || gp == 'ps1' || gp == 'psx',
      'PS2' => gp.contains('playstation 2') || gp == 'ps2',
      'PS3' => gp.contains('playstation 3') || gp == 'ps3',
      'PS4' => gp.contains('playstation 4') || gp == 'ps4',
      'PS5' => gp.contains('playstation 5') || gp == 'ps5',
      'PSP' => gp.contains('playstation portable') || gp == 'psp',
      'PS Vita' => gp.contains('playstation vita') || gp == 'ps vita',
      'Mega Drive' => gp.contains('mega drive') || gp.contains('genesis'),
      'Master System' => gp.contains('master system') || gp.contains('mark iii'),
      'Dreamcast' => gp.contains('dreamcast'),
      'PC' ||
      'Steam' ||
      'Epic Games' ||
      'GOG' ||
      'EA App' ||
      'Ubisoft Connect' ||
      'Battle.net' =>
        gp.contains('windows') ||
        gp == 'pc' ||
        gp.contains('pc (') ||
        gp == 'dos' ||
        gp == 'linux' ||
        gp == 'mac',
      'VR' =>
        gp.contains('vr') ||
        gp.contains('oculus') ||
        gp.contains('vive') ||
        gp.contains('quest'),
      _ => igdbNames.any((n) => gp.contains(n.toLowerCase())),
    };
  }

  /// Normaliza nombres legacy (IGDB, reseñas) al id del catálogo de estantería.
  static String? normalizeToId(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (_byId.containsKey(trimmed)) return trimmed;

    final lower = trimmed.toLowerCase();

    const exactAliases = {
      'playstation 5': 'PS5',
      'playstation 4': 'PS4',
      'playstation 3': 'PS3',
      'playstation 2': 'PS2',
      'playstation': 'PS1',
      'playstation vita': 'PS Vita',
      'ps vita': 'PS Vita',
      'playstation portable': 'PSP',
      'xbox series x|s': 'Xbox Series',
      'xbox series x': 'Xbox Series',
      'xbox series s': 'Xbox Series',
      'xbox one': 'Xbox One',
      'xbox 360': 'Xbox 360',
      'nintendo switch 2': 'Nintendo Switch 2',
      'switch 2': 'Nintendo Switch 2',
      'nintendo switch': 'Nintendo Switch',
      'switch': 'Nintendo Switch',
      'wii u': 'Wii U',
      'wii': 'Wii',
      'nintendo 3ds': 'Nintendo 3DS',
      '3ds': 'Nintendo 3DS',
      'nintendo ds': 'Nintendo DS',
      'ds': 'Nintendo DS',
      'gamecube': 'GameCube',
      'nintendo 64': 'N64',
      'n64': 'N64',
      'super nintendo (snes)': 'SNES',
      'snes': 'SNES',
      'nintendo (nes)': 'NES',
      'nes': 'NES',
      'game boy advance': 'Game Boy Advance',
      'gba': 'Game Boy Advance',
      'game boy': 'Game Boy',
      'sega mega drive/genesis': 'Mega Drive',
      'mega drive': 'Mega Drive',
      'genesis': 'Mega Drive',
      'sega master system/mark iii': 'Master System',
      'master system': 'Master System',
      'dreamcast': 'Dreamcast',
      'sega dreamcast': 'Dreamcast',
      'pc (microsoft windows)': 'PC',
      'pc (windows)': 'PC',
      'pc': 'PC',
      'windows': 'PC',
      'steam': 'Steam',
      'epic games store': 'Epic Games',
      'epic games': 'Epic Games',
      'epic': 'Epic Games',
      'gog': 'GOG',
      'origin': 'EA App',
      'ea app': 'EA App',
      'ubisoft connect': 'Ubisoft Connect',
      'uplay': 'Ubisoft Connect',
      'battle.net': 'Battle.net',
      'battlenet': 'Battle.net',
      'mac': 'Mac',
      'linux': 'Linux',
      'android': 'Android',
      'ios': 'iOS',
      'iphone': 'iOS',
    };

    if (exactAliases.containsKey(lower)) return exactAliases[lower];

    const containsAliases = {
      'ps5': 'PS5',
      'ps4': 'PS4',
      'ps3': 'PS3',
      'ps2': 'PS2',
      'ps1': 'PS1',
      'psp': 'PSP',
      'vita': 'PS Vita',
      'xbox series': 'Xbox Series',
      'xbox one': 'Xbox One',
      'xbox 360': 'Xbox 360',
      'switch 2': 'Nintendo Switch 2',
      'switch': 'Nintendo Switch',
      'wii u': 'Wii U',
      '3ds': 'Nintendo 3DS',
      'steam': 'Steam',
      'epic': 'Epic Games',
    };

    for (final entry in containsAliases.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }

    for (final platform in all) {
      if (lower == platform.id.toLowerCase()) return platform.id;
      if (lower == platform.label.toLowerCase()) return platform.id;
    }

    return null;
  }

  /// Resuelve estilo visual para un id o nombre legacy.
  static ShelfPlatform resolve(String platformName) {
    final normalized = normalizeToId(platformName);
    if (normalized != null) {
      return _byId[normalized]!;
    }
    return ShelfPlatform(
      id: platformName,
      label: platformName,
      shortLabel: platformName.length > 12
          ? '${platformName.substring(0, 10)}…'
          : platformName,
      color: Colors.blueGrey.shade700,
      fallbackIcon: CorpusIconKind.SportsEsports,
    );
  }

  /// Normaliza una lista de ids legacy al catálogo actual.
  static List<String> normalizeIds(Iterable<String> raw) {
    final result = <String>{};
    for (final item in raw) {
      final id = normalizeToId(item) ?? item;
      if (_byId.containsKey(id)) result.add(id);
    }
    return result.toList();
  }

  /// Sugiere plataformas a partir de datos de reseña / Steam.
  static List<String> suggest({
    String? reviewPlatform,
    bool steamOwned = false,
    Iterable<String> alreadyOwned = const [],
  }) {
    final suggestions = <String>{};
    final owned = normalizeIds(alreadyOwned).toSet();

    if (reviewPlatform != null && reviewPlatform.isNotEmpty) {
      final id = normalizeToId(reviewPlatform);
      if (id != null) suggestions.add(id);
    }

    if (steamOwned) suggestions.add('Steam');

    suggestions.removeAll(owned);
    return suggestions.toList();
  }
}

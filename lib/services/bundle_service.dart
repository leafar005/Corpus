import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GameBundle {
  final String id;
  final String title;
  final String storeName;
  final String url;
  final DateTime? endDate;
  final List<BundleTier> tiers;

  GameBundle({
    required this.id,
    required this.title,
    required this.storeName,
    required this.url,
    this.endDate,
    required this.tiers,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'storeName': storeName,
    'url': url,
    'endDate': endDate?.toIso8601String(),
    'tiers': tiers.map((t) => t.toJson()).toList(),
  };

  factory GameBundle.fromJson(Map<String, dynamic> json) => GameBundle(
    id: json['id'],
    title: json['title'],
    storeName: json['storeName'],
    url: json['url'],
    endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
    tiers: (json['tiers'] as List).map((t) => BundleTier.fromJson(t)).toList(),
  );
}

class BundleTier {
  final String name;
  final double? price;
  final List<BundleGame> games;

  BundleTier({required this.name, this.price, required this.games});

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
    'games': games.map((g) => g.toJson()).toList(),
  };

  factory BundleTier.fromJson(Map<String, dynamic> json) => BundleTier(
    name: json['name'],
    price: json['price'] != null ? (json['price'] as num).toDouble() : null,
    games: (json['games'] as List).map((g) => BundleGame.fromJson(g)).toList(),
  );
}

class BundleGame {
  final String title;
  final int? steamAppId;

  BundleGame({required this.title, this.steamAppId});

  Map<String, dynamic> toJson() => {
    'title': title,
    'steamAppId': steamAppId,
  };

  factory BundleGame.fromJson(Map<String, dynamic> json) => BundleGame(
    title: json['title'],
    steamAppId: json['steamAppId'] != null ? (json['steamAppId'] as num).toInt() : null,
  );
}

class BundleService {
  static const String _endpoint = 'https://barter.vg/bundles/json/';
  static const String _cacheKey = 'active_bundles_cache';

  static int storeRankPublic(String storeName) {
    if (storeName == 'Humble Bundle') return 1;
    if (storeName == 'Fanatical') return 2;
    return 99;
  }

  static Future<List<GameBundle>?> getCachedBundles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(_cacheKey);
      if (cachedString != null) {
        final List<dynamic> decoded = json.decode(cachedString);
        return decoded.map((e) => GameBundle.fromJson(e)).toList();
      }
    } catch (e) {
      if (kDebugMode) print('[BUNDLE SERVICE] Error leyendo caché: $e');
    }
    return null;
  }

  /// Extrae el Steam AppID real de una entrada de juego de barter.vg.
  /// Para "paquetes" (type == 2, p.ej. Ediciones Deluxe), el campo 'id' es un ID de paquete de Steam
  /// que NO existe en IGDB. El AppID real del juego base está dentro de 'included'.
  static double? _readPrice(Map<String, dynamic> t, Map<String, dynamic> bundleMap) {
    final raw = t['price_eur'] ?? t['price_usd'] ?? t['price'] ?? t['cost'] ?? t['min_price'] ??
                bundleMap['price_eur'] ?? bundleMap['price_usd'] ?? bundleMap['price'] ?? bundleMap['cost'];
    if (raw != null) {
      final s = raw.toString().replaceAll('\$', '').replaceAll('€', '').replaceAll('£', '').replaceAll('USD', '').replaceAll('EUR', '').trim().replaceAll(',', '.');
      final val = double.tryParse(s);
      if (val != null && val > 0) return val;
    }
    // Rescate por si el precio viene escrito dentro del propio nombre del nivel
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*(?:€|\$|USD|EUR)|(?:€|\$|USD|EUR)\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(t['name']?.toString() ?? '');
    if (match != null) {
      final strNum = match.group(1) ?? match.group(2);
      if (strNum != null) return double.tryParse(strNum.replaceAll(',', '.'));
    }
    return null;
  }

  /// Extrae el Steam AppID real de una entrada de juego de barter.vg.
  /// Para "paquetes" (type == 2, p.ej. Ediciones Deluxe), el campo 'id' es un ID de paquete de Steam
  /// que NO existe en IGDB. El AppID real del juego base está dentro de 'included'.
  static int? _extractSteamAppId(Map<String, dynamic> gMap) {
    final int gameType = int.tryParse(gMap['type']?.toString() ?? '1') ?? 1;

    if (gameType == 2 && gMap['included'] is Map) {
      final included = Map<String, dynamic>.from(gMap['included']);
      if (included.isNotEmpty) {
        final sortedKeys = included.keys.toList()
          ..sort((a, b) => (int.tryParse(a) ?? 999999).compareTo(int.tryParse(b) ?? 999999));
        final baseId = included[sortedKeys.first];
        final parsed = int.tryParse(baseId?.toString() ?? '');
        if (parsed != null && parsed > 0) return parsed;
      }
    }

    return int.tryParse(
      gMap['id']?.toString() ??
      gMap['steam_app_id']?.toString() ??
      gMap['appid']?.toString() ??
      gMap['steam_id']?.toString() ??
      '',
    );
  }

  /// Motor de lectura restaurado al 100% a la versión que resolvió los 428 juegos
  static Future<List<GameBundle>> getActiveBundles() async {
    try {
      final response = await http.get(
        Uri.parse(_endpoint),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        if (kDebugMode) print('[BUNDLE SERVICE] Error HTTP: ${response.statusCode}');
        return [];
      }

      final dynamic decoded = json.decode(response.body);
      if (decoded is! Map) return [];

      Map<String, dynamic> data = Map<String, dynamic>.from(decoded);
      if (data.containsKey('bundles') && data['bundles'] is Map) {
        data = Map<String, dynamic>.from(data['bundles']);
      } else if (data.containsKey('data') && data['data'] is Map) {
        data = Map<String, dynamic>.from(data['data']);
      }

      final List<GameBundle> activeBundles = [];
      final now = DateTime.now().toUtc();

      data.forEach((key, value) {
        if (value is! Map) return;
        final bundleMap = Map<String, dynamic>.from(value);

        final String fullDump = bundleMap.toString().toLowerCase();
        final bool isHumble = fullDump.contains('humble');
        final bool isFanatical = fullDump.contains('fanatical');

        if (!isHumble && !isFanatical) return;

        final String storeName = isHumble ? 'Humble Bundle' : 'Fanatical';

        final meta = bundleMap['meta'] is Map ? Map<String, dynamic>.from(bundleMap['meta']) : <String, dynamic>{};
        final String title = meta['title']?.toString() ?? bundleMap['title']?.toString() ?? bundleMap['name']?.toString() ?? 'Bundle sin título';
        final String url = meta['url']?.toString() ?? bundleMap['url']?.toString() ?? bundleMap['bundle_url']?.toString() ?? 'https://barter.vg/bundle/$key/';

        DateTime? endDate;
        final endRaw = meta['end'] ?? bundleMap['end'];
        if (endRaw != null) {
          try {
            final String endStr = endRaw.toString().trim();
            if (endStr != '0' && endStr.isNotEmpty && endStr != 'null') {
              final int endTimestamp = int.parse(endStr);
              if (endTimestamp > 0) {
                final isSeconds = endStr.length <= 10;
                endDate = DateTime.fromMillisecondsSinceEpoch(isSeconds ? endTimestamp * 1000 : endTimestamp, isUtc: true);
                if (endDate.isBefore(now.subtract(const Duration(days: 1)))) return;
              }
            }
          } catch (e) {
            if (kDebugMode) print('[BundleService] Error parseando timestamp "$endRaw": $e');
          }

        }

        final Map<int, List<BundleGame>> gamesByTier = {};
        final dynamic rawGames = bundleMap['games'] ?? bundleMap['items'];

        if (rawGames is Map) {
          rawGames.forEach((gameKey, gameVal) {
            if (gameVal is Map) {
              final gMap = Map<String, dynamic>.from(gameVal);
              
              // El campo 'tier' solo representa niveles de precio reales en Humble Bundle.
              // En Fanatical es un campo interno, lo ignoramos y agrupamos en un único tier.
              final int tier = isHumble
                  ? (int.tryParse(gMap['tier']?.toString() ?? '1') ?? 1)
                  : 1;

              final steamId = _extractSteamAppId(gMap);

              if (steamId != null && steamId > 0) {
                gamesByTier.putIfAbsent(tier, () => []).add(BundleGame(
                  title: gMap['title']?.toString() ?? gMap['name']?.toString() ?? gMap['game_title']?.toString() ?? 'Juego Desconocido',
                  steamAppId: steamId,
                ));
              }
            }
          });
        }

        final List<BundleTier> tiersList = [];
        final sortedTiers = gamesByTier.keys.toList()..sort();

        for (final tierNum in sortedTiers) {
          final gamesList = gamesByTier[tierNum]!;
          if (gamesList.isNotEmpty) {
            tiersList.add(BundleTier(
              name: 'Tier $tierNum',
              price: _readPrice({}, bundleMap),
              games: gamesList,
            ));
          }
        }

        if (tiersList.isNotEmpty) {
          activeBundles.add(GameBundle(
            id: key,
            title: title,
            storeName: storeName,
            url: url,
            endDate: endDate,
            tiers: tiersList,
          ));
        }
      });

      final nowSort = DateTime.now().toUtc();
      activeBundles.sort((a, b) {
        final aExpired = a.endDate != null && a.endDate!.isBefore(nowSort);
        final bExpired = b.endDate != null && b.endDate!.isBefore(nowSort);

        if (aExpired && !bExpired) return 1;
        if (!aExpired && bExpired) return -1;

        if (a.endDate == null && b.endDate != null) return 1;
        if (a.endDate != null && b.endDate == null) return -1;
        if (a.endDate == null && b.endDate == null) return 0;

        return a.endDate!.compareTo(b.endDate!);
      });

      // Guardar en caché
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonList = activeBundles.map((b) => b.toJson()).toList();
        await prefs.setString(_cacheKey, json.encode(jsonList));
      } catch (e) {
        if (kDebugMode) print('[BUNDLE SERVICE] Error guardando caché: $e');
      }

      if (kDebugMode) print('[BUNDLE SERVICE] Encontrados ${activeBundles.length} bundles activos.');
      return activeBundles;
    } catch (e) {
      if (kDebugMode) print('[BUNDLE SERVICE ERROR CRÍTICO]: $e');
      return [];
    }
  }
}
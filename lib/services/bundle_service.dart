import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
}

class BundleTier {
  final String name;
  final double? price;
  final List<BundleGame> games;

  BundleTier({required this.name, this.price, required this.games});
}

class BundleGame {
  final String title;
  final int? steamAppId;

  BundleGame({required this.title, this.steamAppId});
}

class BundleService {
  static const String _endpoint = 'https://barter.vg/bundles/json/';

  static int storeRankPublic(String storeName) {
    if (storeName == 'Humble Bundle') return 1;
    if (storeName == 'Fanatical') return 2;
    return 99;
  }

  /// Único añadido al código estable: lee divisa o texto sin alterar el bucle
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
                // Si son 10 dígitos, son segundos. Si son 13, milisegundos.
                final isSeconds = endStr.length <= 10;
                endDate = DateTime.fromMillisecondsSinceEpoch(isSeconds ? endTimestamp * 1000 : endTimestamp, isUtc: true);
                // Le damos 24h de gracia
                if (endDate.isBefore(now.subtract(const Duration(days: 1)))) return;
              }
            }
          } catch (_) {}
        }

        final Map<int, List<BundleGame>> gamesByTier = {};
        final dynamic rawGames = bundleMap['games'] ?? bundleMap['items'];

        if (rawGames is Map) {
          rawGames.forEach((gameKey, gameVal) {
            if (gameVal is Map) {
              final gMap = Map<String, dynamic>.from(gameVal);
              final tier = int.tryParse(gMap['tier']?.toString() ?? '1') ?? 1;
              final steamId = int.tryParse(gMap['id']?.toString() ?? gMap['steam_app_id']?.toString() ?? gMap['appid']?.toString() ?? gMap['steam_id']?.toString() ?? '');
              
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
        gamesByTier.forEach((tierNum, gamesList) {
          if (gamesList.isNotEmpty) {
            tiersList.add(BundleTier(
              name: 'Tier $tierNum',
              price: _readPrice({}, bundleMap), // Si barter añade precio global al bundle, lo leerá
              games: gamesList,
            ));
          }
        });

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

      if (kDebugMode) print('[BUNDLE SERVICE] Encontrados ${activeBundles.length} bundles activos.');
      return activeBundles;
    } catch (e) {
      if (kDebugMode) print('[BUNDLE SERVICE ERROR CRÍTICO]: $e');
      return [];
    }
  }
}
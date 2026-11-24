import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:stream_channel/stream_channel.dart';
// ignore: depend_on_referenced_packages
import 'package:web_socket_channel/web_socket_channel.dart';
// ignore: depend_on_referenced_packages
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

/// Ejecución síncrona (en el isolate actual) para `YAJsonIsolate`,
/// evitando lanzar isolates reales que pueden colgar o dejar handles abiertos
/// durante `flutter test`.
class SyncJsonIsolate extends YAJsonIsolate {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<dynamic> decode(String json) async => jsonDecode(json);

  @override
  Future<String> encode(Object? json) async => jsonEncode(json);
}

/// Sink simulado para responder a los mensajes del protocolo Phoenix Realtime
/// sin abrir sockets TCP reales.
class FakeWebSocketSink implements WebSocketSink {
  FakeWebSocketSink(this._onSend, this._onClose);

  final void Function(dynamic data) _onSend;
  final Future<void> Function([int? closeCode, String? closeReason]) _onClose;
  final Completer<void> _doneCompleter = Completer<void>();

  @override
  void add(dynamic data) {
    if (!_doneCompleter.isCompleted) {
      _onSend(data);
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<dynamic> addStream(Stream<dynamic> stream) async {
    await stream.forEach(add);
  }

  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) async {
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
    await _onClose(closeCode, closeReason);
  }

  @override
  Future<dynamic> get done => _doneCompleter.future;
}

/// Canal WebSocket simulado que responde con `phx_reply` `ok` a cualquier
/// `phx_join`, `heartbeat` o `phx_leave` enviado por `RealtimeClient`.
class FakeWebSocketChannel
    with StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  FakeWebSocketChannel() {
    _sink = FakeWebSocketSink(_handleOutgoing, _handleClose);
  }

  final StreamController<dynamic> _incoming =
      StreamController<dynamic>.broadcast();
  late final FakeWebSocketSink _sink;
  int? _closeCode;
  String? _closeReason;

  void _handleOutgoing(dynamic raw) {
    if (_incoming.isClosed) return;
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is Map<String, dynamic>) {
        final topic = decoded['topic'];
        final ref = decoded['ref'];
        Future<void>.microtask(() {
          if (_incoming.isClosed) return;
          _incoming.add(
            jsonEncode(<String, dynamic>{
              'topic': topic,
              'event': 'phx_reply',
              'ref': ref,
              'payload': <String, dynamic>{
                'status': 'ok',
                'response': <String, dynamic>{},
              },
            }),
          );
        });
      } else if (decoded is List && decoded.length >= 4) {
        final joinRef = decoded[0];
        final ref = decoded[1];
        final topic = decoded[2];
        Future<void>.microtask(() {
          if (_incoming.isClosed) return;
          _incoming.add(
            jsonEncode(<dynamic>[
              joinRef,
              ref,
              topic,
              'phx_reply',
              <String, dynamic>{
                'status': 'ok',
                'response': <String, dynamic>{},
              },
            ]),
          );
        });
      }
    } catch (_) {
      // Ignora payloads no JSON en mensajes de control.
    }
  }

  Future<void> _handleClose([int? closeCode, String? closeReason]) async {
    _closeCode = closeCode ?? 1000;
    _closeReason = closeReason ?? '';
    if (!_incoming.isClosed) {
      await _incoming.close();
    }
  }

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => _closeReason;

  @override
  Future<void> get ready => Future<void>.value();
}

class _AuthAccount {
  _AuthAccount({
    required this.id,
    required this.email,
    required this.password,
    required this.username,
    required this.displayName,
  });

  final String id;
  String email;
  String password;
  String username;
  String displayName;
}

/// Backend simulado en memoria compatible con GoTrue, PostgREST (tablas, joins,
/// filtros, conteos, upsert, `.single()`/`.maybeSingle()`), RPCs, Storage y
/// Edge Functions de Supabase (incluyendo `igdb-proxy`).
class FakeSupabaseBackend {
  FakeSupabaseBackend({
    bool seedSocialData = false,
  }) {
    _httpClient = _RouterHttpClient(this);
    _seedBaseData(seedSocialData: seedSocialData);
  }

  static const String baseUrl = 'https://mock.supabase.local';
  static const String anonKey = 'mock-anon-key-corpus';

  // UUIDs RFC-4122 válidos para cumplir `kUuidPattern`.
  static const String primaryUserId = '11111111-1111-4111-8111-111111111111';
  static const String primaryEmail = 'player@corpus.test';
  static const String primaryPassword = 'Password123!';
  static const String primaryUsername = 'playerone';
  static const String primaryDisplayName = 'Player One';

  static const String friendUserId = '22222222-2222-4222-8222-222222222222';
  static const String pendingRequesterId =
      '33333333-3333-4333-8333-333333333333';
  static const String searchableUserId = '44444444-4444-4444-8444-444444444444';

  static const int eldenRingId = 119133;
  static const int hollowKnightId = 14593;
  static const int witcher3Id = 1942;
  static const int baldursGate3Id = 119171;
  static const int silksongId = 115289;

  late final http.Client _httpClient;
  http.Client get httpClient => _httpClient;

  int _uuidCounter = 100;
  DateTime _clock = DateTime.utc(2026, 6, 1, 12, 0, 0);

  final Map<String, _AuthAccount> _authAccountsById = <String, _AuthAccount>{};
  final Map<String, List<Map<String, dynamic>>> _tables =
      <String, List<Map<String, dynamic>>>{};
  final List<Map<String, dynamic>> _igdbCatalog = <Map<String, dynamic>>[];

  String? _activeUserId;
  int igdbProxyCalls = 0;
  final List<String> requestedPaths = <String>[];

  String _nextUuid() {
    _uuidCounter++;
    final hex = _uuidCounter.toRadixString(16).padLeft(12, '0');
    return 'aaaaaaaa-aaaa-4aaa-8aaa-$hex';
  }

  String _nextIsoTimestamp() {
    _clock = _clock.add(const Duration(seconds: 1));
    return _clock.toIso8601String();
  }

  void _seedBaseData({required bool seedSocialData}) {
    const allTables = <String>[
      'achievements',
      'active_bundles',
      'activity_feed',
      'client_error_log',
      'feed_posts',
      'friendships',
      'game_group_items',
      'game_groups',
      'games',
      'hall_of_fame',
      'notification_preferences',
      'notifications',
      'push_tokens',
      'review_comments',
      'review_likes',
      'reviews',
      'stash_community_reviews',
      'stash_game_stats',
      'stash_sync_metadata',
      'story_views',
      'user_achievements',
      'user_game_platforms',
      'user_games',
      'user_settings',
      'users',
    ];
    for (final t in allTables) {
      _tables[t] = <Map<String, dynamic>>[];
    }

    _registerAccount(
      id: primaryUserId,
      email: primaryEmail,
      password: primaryPassword,
      username: primaryUsername,
      displayName: primaryDisplayName,
      bio: 'Jugador de Corpus en pruebas.',
      xp: 250,
    );

    _registerAccount(
      id: friendUserId,
      email: 'amigo@corpus.test',
      password: 'Password123!',
      username: 'amigogamer',
      displayName: 'Amigo Gamer',
      bio: 'Compañero de partidas.',
      xp: 480,
    );

    _registerAccount(
      id: pendingRequesterId,
      email: 'solicitante@corpus.test',
      password: 'Password123!',
      username: 'nuevojugador',
      displayName: 'Nuevo Jugador',
      bio: 'Buscando amigos.',
      xp: 90,
    );

    _registerAccount(
      id: searchableUserId,
      email: 'buscable@corpus.test',
      password: 'Password123!',
      username: 'explorador',
      displayName: 'Explorador Pro',
      bio: 'Amante de los RPG.',
      xp: 310,
    );

    _seedIgdbCatalog();

    if (seedSocialData) {
      // Amistad aceptada con friendUserId y solicitud pendiente de pendingRequesterId.
      _tables['friendships']!.addAll(<Map<String, dynamic>>[
        <String, dynamic>{
          'requester_id': primaryUserId,
          'addressee_id': friendUserId,
          'status': 'accepted',
          'created_at': _nextIsoTimestamp(),
        },
        <String, dynamic>{
          'requester_id': pendingRequesterId,
          'addressee_id': primaryUserId,
          'status': 'pending',
          'created_at': _nextIsoTimestamp(),
        },
      ]);

      seedFriendReview(
        userId: friendUserId,
        gameId: witcher3Id,
        rating: 9.5,
        comment: 'Una aventura inolvidable en los Reinos del Norte.',
      );
    }
  }

  void _registerAccount({
    required String id,
    required String email,
    required String password,
    required String username,
    required String displayName,
    String bio = '',
    int xp = 50,
  }) {
    _authAccountsById[id] = _AuthAccount(
      id: id,
      email: email,
      password: password,
      username: username,
      displayName: displayName,
    );
    _tables['users']!.add(<String, dynamic>{
      'id': id,
      'username': username,
      'display_name': displayName,
      'avatar_url': null,
      'banner_url': null,
      'steam_id': null,
      'bio': bio,
      'platforms': <String>['PC', 'PS5'],
      'xp': xp,
      'role': 'user',
      'style_pack': 'default',
      'active_frame': null,
      'active_badge_id': null,
      'is_online': false,
      'last_seen_at': _nextIsoTimestamp(),
      'created_at': _nextIsoTimestamp(),
      'last_activity_read_at': _clock.toIso8601String(),
    });
  }

  void _seedIgdbCatalog() {
    final eldenRingIgdb = <String, dynamic>{
      'id': eldenRingId,
      'name': 'Elden Ring',
      'cover': <String, dynamic>{
        'id': 1,
        'image_id': 'co4jni',
        'url': '//images.igdb.com/igdb/image/upload/t_thumb/co4jni.jpg',
      },
      'artworks': <Map<String, dynamic>>[
        <String, dynamic>{
          'image_id': 'ar1450',
          'url': '//images.igdb.com/igdb/image/upload/t_thumb/ar1450.jpg',
        },
      ],
      'screenshots': <Map<String, dynamic>>[
        <String, dynamic>{
          'image_id': 'sc1001',
          'url': '//images.igdb.com/igdb/image/upload/t_thumb/sc1001.jpg',
        },
      ],
      'first_release_date': 1645747200,
      'genres': <Map<String, dynamic>>[
        <String, dynamic>{'id': 12, 'name': 'Role-playing (RPG)'},
        <String, dynamic>{'id': 31, 'name': 'Adventure'},
      ],
      'platforms': <Map<String, dynamic>>[
        <String, dynamic>{'id': 6, 'name': 'PC (Microsoft Windows)'},
        <String, dynamic>{'id': 167, 'name': 'PlayStation 5'},
      ],
      'involved_companies': <Map<String, dynamic>>[
        <String, dynamic>{
          'company': <String, dynamic>{'id': 1012, 'name': 'FromSoftware'},
          'developer': true,
          'publisher': false,
        },
      ],
      'summary':
          'Álzate, Sinluz, y deja que la gracia te guíe hacia el Círculo de Elden.',
      'total_rating': 95.4,
      'total_rating_count': 1200,
      'follows': 5400,
      'hypes': 900,
      'game_type': 0,
      'category': 0,
    };

    final hollowKnightIgdb = <String, dynamic>{
      'id': hollowKnightId,
      'name': 'Hollow Knight',
      'cover': <String, dynamic>{
        'id': 2,
        'image_id': 'co1rgi',
        'url': '//images.igdb.com/igdb/image/upload/t_thumb/co1rgi.jpg',
      },
      'artworks': <Map<String, dynamic>>[
        <String, dynamic>{
          'image_id': 'ar1451',
          'url': '//images.igdb.com/igdb/image/upload/t_thumb/ar1451.jpg',
        },
      ],
      'screenshots': <Map<String, dynamic>>[
        <String, dynamic>{
          'image_id': 'sc1002',
          'url': '//images.igdb.com/igdb/image/upload/t_thumb/sc1002.jpg',
        },
      ],
      'first_release_date': 1487894400,
      'genres': <Map<String, dynamic>>[
        <String, dynamic>{'id': 8, 'name': 'Platform'},
        <String, dynamic>{'id': 31, 'name': 'Adventure'},
      ],
      'platforms': <Map<String, dynamic>>[
        <String, dynamic>{'id': 6, 'name': 'PC (Microsoft Windows)'},
        <String, dynamic>{'id': 130, 'name': 'Nintendo Switch'},
      ],
      'involved_companies': <Map<String, dynamic>>[
        <String, dynamic>{
          'company': <String, dynamic>{'id': 8368, 'name': 'Team Cherry'},
          'developer': true,
          'publisher': true,
        },
      ],
      'summary': 'Forja tu propio camino en Hallownest, un reino en ruinas.',
      'total_rating': 93.1,
      'total_rating_count': 980,
      'follows': 4100,
      'hypes': 400,
      'game_type': 0,
      'category': 0,
    };

    final witcher3Igdb = <String, dynamic>{
      'id': witcher3Id,
      'name': 'The Witcher 3: Wild Hunt',
      'cover': <String, dynamic>{
        'id': 3,
        'image_id': 'co1wyy',
        'url': '//images.igdb.com/igdb/image/upload/t_thumb/co1wyy.jpg',
      },
      'artworks': <Map<String, dynamic>>[
        <String, dynamic>{
          'image_id': 'ar1452',
          'url': '//images.igdb.com/igdb/image/upload/t_thumb/ar1452.jpg',
        },
      ],
      'screenshots': <Map<String, dynamic>>[
        <String, dynamic>{
          'image_id': 'sc1003',
          'url': '//images.igdb.com/igdb/image/upload/t_thumb/sc1003.jpg',
        },
      ],
      'first_release_date': 1431993600,
      'genres': <Map<String, dynamic>>[
        <String, dynamic>{'id': 12, 'name': 'Role-playing (RPG)'},
      ],
      'platforms': <Map<String, dynamic>>[
        <String, dynamic>{'id': 6, 'name': 'PC (Microsoft Windows)'},
        <String, dynamic>{'id': 167, 'name': 'PlayStation 5'},
      ],
      'involved_companies': <Map<String, dynamic>>[
        <String, dynamic>{
          'company': <String, dynamic>{'id': 908, 'name': 'CD Projekt RED'},
          'developer': true,
          'publisher': true,
        },
      ],
      'summary': 'Eres Geralt de Rivia, cazador de monstruos a sueldo.',
      'total_rating': 94.8,
      'total_rating_count': 1500,
      'follows': 6200,
      'hypes': 300,
      'game_type': 0,
      'category': 0,
    };

    final baldursGate3Igdb = <String, dynamic>{
      'id': baldursGate3Id,
      'name': "Baldur's Gate 3",
      'cover': <String, dynamic>{
        'id': 4,
        'image_id': 'co670h',
        'url': '//images.igdb.com/igdb/image/upload/t_thumb/co670h.jpg',
      },
      'artworks': <Map<String, dynamic>>[
        <String, dynamic>{
          'image_id': 'ar1453',
          'url': '//images.igdb.com/igdb/image/upload/t_thumb/ar1453.jpg',
        },
      ],
      'screenshots': <Map<String, dynamic>>[
        <String, dynamic>{
          'image_id': 'sc1004',
          'url': '//images.igdb.com/igdb/image/upload/t_thumb/sc1004.jpg',
        },
      ],
      'first_release_date': 1691020800,
      'genres': <Map<String, dynamic>>[
        <String, dynamic>{'id': 12, 'name': 'Role-playing (RPG)'},
        <String, dynamic>{'id': 15, 'name': 'Strategy'},
      ],
      'platforms': <Map<String, dynamic>>[
        <String, dynamic>{'id': 6, 'name': 'PC (Microsoft Windows)'},
        <String, dynamic>{'id': 167, 'name': 'PlayStation 5'},
      ],
      'involved_companies': <Map<String, dynamic>>[
        <String, dynamic>{
          'company': <String, dynamic>{'id': 722, 'name': 'Larian Studios'},
          'developer': true,
          'publisher': true,
        },
      ],
      'summary': 'Reúne a tu grupo y regresa a los Reinos Olvidados.',
      'total_rating': 96.2,
      'total_rating_count': 1350,
      'follows': 4900,
      'hypes': 500,
      'game_type': 0,
      'category': 0,
    };

    final futureReleaseSec =
        DateTime.now().add(const Duration(days: 60)).millisecondsSinceEpoch ~/
            1000;
    final silksongIgdb = <String, dynamic>{
      'id': silksongId,
      'name': 'Hollow Knight: Silksong',
      'cover': <String, dynamic>{
        'id': 5,
        'image_id': 'co8999',
        'url': '//images.igdb.com/igdb/image/upload/t_thumb/co8999.jpg',
      },
      'artworks': <Map<String, dynamic>>[
        <String, dynamic>{
          'image_id': 'ar1454',
          'url': '//images.igdb.com/igdb/image/upload/t_thumb/ar1454.jpg',
        },
      ],
      'screenshots': <Map<String, dynamic>>[
        <String, dynamic>{
          'image_id': 'sc1005',
          'url': '//images.igdb.com/igdb/image/upload/t_thumb/sc1005.jpg',
        },
      ],
      'first_release_date': futureReleaseSec,
      'genres': <Map<String, dynamic>>[
        <String, dynamic>{'id': 8, 'name': 'Platform'},
        <String, dynamic>{'id': 31, 'name': 'Adventure'},
      ],
      'platforms': <Map<String, dynamic>>[
        <String, dynamic>{'id': 6, 'name': 'PC (Microsoft Windows)'},
        <String, dynamic>{'id': 130, 'name': 'Nintendo Switch'},
      ],
      'involved_companies': <Map<String, dynamic>>[
        <String, dynamic>{
          'company': <String, dynamic>{'id': 8368, 'name': 'Team Cherry'},
          'developer': true,
          'publisher': true,
        },
      ],
      'summary': 'Secuela de acción y aventura protagonizada por Hornet.',
      'total_rating': null,
      'total_rating_count': 0,
      'follows': 9800,
      'hypes': 9800,
      'game_type': 0,
      'category': 0,
    };

    _igdbCatalog.addAll(<Map<String, dynamic>>[
      eldenRingIgdb,
      hollowKnightIgdb,
      witcher3Igdb,
      baldursGate3Igdb,
      silksongIgdb,
    ]);

    _tables['games']!.addAll(<Map<String, dynamic>>[
      <String, dynamic>{
        'igdb_id': eldenRingId,
        'title': 'Elden Ring',
        'cover_url':
            'https://images.igdb.com/igdb/image/upload/t_cover_big/co4jni.jpg',
        'release_date': '2022-02-25',
        'genres': <String>['Role-playing (RPG)', 'Adventure'],
        'platforms': <String>['PC (Microsoft Windows)', 'PlayStation 5'],
        'developer': 'FromSoftware',
        'summary':
            'Álzate, Sinluz, y deja que la gracia te guíe hacia el Círculo de Elden.',
      },
      <String, dynamic>{
        'igdb_id': hollowKnightId,
        'title': 'Hollow Knight',
        'cover_url':
            'https://images.igdb.com/igdb/image/upload/t_cover_big/co1rgi.jpg',
        'release_date': '2017-02-24',
        'genres': <String>['Platform', 'Adventure'],
        'platforms': <String>['PC (Microsoft Windows)', 'Nintendo Switch'],
        'developer': 'Team Cherry',
        'summary': 'Forja tu propio camino en Hallownest, un reino en ruinas.',
      },
      <String, dynamic>{
        'igdb_id': witcher3Id,
        'title': 'The Witcher 3: Wild Hunt',
        'cover_url':
            'https://images.igdb.com/igdb/image/upload/t_cover_big/co1wyy.jpg',
        'release_date': '2015-05-19',
        'genres': <String>['Role-playing (RPG)'],
        'platforms': <String>['PC (Microsoft Windows)', 'PlayStation 5'],
        'developer': 'CD Projekt RED',
        'summary': 'Eres Geralt de Rivia, cazador de monstruos a sueldo.',
      },
      <String, dynamic>{
        'igdb_id': baldursGate3Id,
        'title': "Baldur's Gate 3",
        'cover_url':
            'https://images.igdb.com/igdb/image/upload/t_cover_big/co670h.jpg',
        'release_date': '2023-08-03',
        'genres': <String>['Role-playing (RPG)', 'Strategy'],
        'platforms': <String>['PC (Microsoft Windows)', 'PlayStation 5'],
        'developer': 'Larian Studios',
        'summary': 'Reúne a tu grupo y regresa a los Reinos Olvidados.',
      },
    ]);
  }

  /// Inserta una reseña ya completada de un amigo (con entrada en `user_games`,
  /// `activity_feed` y `feed_posts`) para pruebas sociales.
  void seedFriendReview({
    required String userId,
    required int gameId,
    double rating = 9.0,
    String comment = 'Gran juego.',
    String status = 'beaten',
  }) {
    final now = _nextIsoTimestamp();
    final reviewId = _nextUuid();
    final reviewRow = <String, dynamic>{
      'id': reviewId,
      'user_id': userId,
      'game_id': gameId,
      'rating': rating,
      'rating_gameplay': rating,
      'rating_narrative': rating,
      'rating_soundtrack': rating,
      'rating_visuals': rating,
      'comment': comment,
      'status': status,
      'completion_type': 'story',
      'is_replay': false,
      'replay_number': null,
      'platform': 'PC',
      'play_time_hours': 40.0,
      'played_from': null,
      'played_until': null,
      'progress_percent': 100,
      'created_at': now,
      'image_urls': <String>[],
    };
    _tables['reviews']!.add(reviewRow);
    _applyReviewSideEffects(reviewRow, isStatusChange: true);
  }

  /// Añade un juego ya completado/jugado a la biblioteca y lista de reseñas
  /// del usuario (útil para precondiciones de colecciones o perfil).
  void seedBeatenGame({
    String userId = primaryUserId,
    int gameId = eldenRingId,
    double rating = 9.0,
    String comment = 'Obra maestra.',
  }) {
    seedFriendReview(
      userId: userId,
      gameId: gameId,
      rating: rating,
      comment: comment,
      status: 'beaten',
    );
  }

  List<Map<String, dynamic>> tableRows(String table) =>
      List<Map<String, dynamic>>.from(
        (_tables[table] ?? <Map<String, dynamic>>[])
            .map((r) => Map<String, dynamic>.from(r)),
      );

  // ---------------------------------------------------------------------------
  // JWT y Autenticación
  // ---------------------------------------------------------------------------

  String _encodeJwt(_AuthAccount account) {
    final header = _base64UrlEncodeJson(<String, dynamic>{
      'alg': 'HS256',
      'typ': 'JWT',
    });
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final payload = _base64UrlEncodeJson(<String, dynamic>{
      'aud': 'authenticated',
      'exp': nowSec + 86400,
      'iat': nowSec,
      'iss': '$baseUrl/auth/v1',
      'sub': account.id,
      'email': account.email,
      'role': 'authenticated',
      'user_metadata': <String, dynamic>{
        'username': account.username,
        'display_name': account.displayName,
      },
    });
    return '$header.$payload.mock-sig';
  }

  String _base64UrlEncodeJson(Map<String, dynamic> map) {
    return base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  }

  String? _extractRequestUserId(Map<String, String> headers) {
    final authHeader = headers['authorization'] ?? headers['Authorization'];
    if (authHeader != null && authHeader.startsWith('Bearer ')) {
      final token = authHeader.substring(7).trim();
      final parts = token.split('.');
      if (parts.length == 3) {
        try {
          var normalized = parts[1];
          while (normalized.length % 4 != 0) {
            normalized += '=';
          }
          final jsonStr = utf8.decode(base64Url.decode(normalized));
          final decoded = jsonDecode(jsonStr);
          if (decoded is Map<String, dynamic>) {
            final role = decoded['role'];
            final sub = decoded['sub'] as String?;
            if (role == 'authenticated' && sub != null && sub.isNotEmpty) {
              return sub;
            }
          }
        } catch (_) {}
      }
    }
    return _activeUserId;
  }

  Map<String, dynamic> _authUserJson(_AuthAccount account) {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    return <String, dynamic>{
      'id': account.id,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': account.email,
      'email_confirmed_at': '2026-01-01T00:00:00.000Z',
      'phone': '',
      'confirmed_at': '2026-01-01T00:00:00.000Z',
      'last_sign_in_at': nowIso,
      'app_metadata': <String, dynamic>{
        'provider': 'email',
        'providers': <String>['email'],
      },
      'user_metadata': <String, dynamic>{
        'username': account.username,
        'display_name': account.displayName,
      },
      'identities': <dynamic>[],
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': nowIso,
    };
  }

  Map<String, dynamic> _sessionJson(_AuthAccount account) {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return <String, dynamic>{
      'access_token': _encodeJwt(account),
      'token_type': 'bearer',
      'expires_in': 86400,
      'expires_at': nowSec + 86400,
      'refresh_token': 'mock-refresh-${account.id}',
      'user': _authUserJson(account),
    };
  }

  // ---------------------------------------------------------------------------
  // Router HTTP principal
  // ---------------------------------------------------------------------------

  Future<http.Response> _handleRequest(http.BaseRequest request) async {
    final uri = request.url;
    final path = uri.path;
    requestedPaths.add('${request.method} $path');

    final bodyBytes = await request.finalize().toBytes();
    final bodyText = utf8.decode(bodyBytes, allowMalformed: true);
    final headers = _lowercaseHeaders(request.headers);

    if (path.startsWith('/auth/v1')) {
      return _handleAuth(request.method, uri, bodyText, headers);
    }
    if (path.startsWith('/rest/v1/rpc/')) {
      return _handleRpc(request.method, uri, bodyText, headers);
    }
    if (path.startsWith('/rest/v1/')) {
      return _handleRest(request.method, uri, bodyText, headers);
    }
    if (path.startsWith('/functions/v1/')) {
      return _handleFunction(request.method, uri, bodyText, headers);
    }
    if (path.startsWith('/storage/v1/')) {
      return _jsonResponse(200, <String, dynamic>{'Key': path});
    }

    return _jsonResponse(404, <String, dynamic>{'error': 'Not found: $path'});
  }

  Map<String, String> _lowercaseHeaders(Map<String, String> raw) {
    final result = <String, String>{};
    raw.forEach((k, v) => result[k.toLowerCase()] = v);
    return result;
  }

  http.Response _jsonResponse(
    int statusCode,
    dynamic payload, {
    Map<String, String>? extraHeaders,
  }) {
    final respHeaders = <String, String>{
      'content-type': 'application/json; charset=utf-8',
      ...?extraHeaders,
    };
    if (payload == null && (statusCode == 201 || statusCode == 204)) {
      return http.Response('', statusCode, headers: respHeaders);
    }
    return http.Response(
      jsonEncode(payload),
      statusCode,
      headers: respHeaders,
    );
  }

  // ---------------------------------------------------------------------------
  // GoTrue /auth/v1/*
  // ---------------------------------------------------------------------------

  Future<http.Response> _handleAuth(
    String method,
    Uri uri,
    String bodyText,
    Map<String, String> headers,
  ) async {
    final path = uri.path;
    final body = bodyText.isNotEmpty
        ? (jsonDecode(bodyText) as Map<String, dynamic>? ?? <String, dynamic>{})
        : <String, dynamic>{};

    if (method == 'POST' && path == '/auth/v1/token') {
      final grantType = uri.queryParameters['grant_type'];
      if (grantType == 'password') {
        final email = (body['email'] as String? ?? '').trim().toLowerCase();
        final password = body['password'] as String? ?? '';
        final match = _authAccountsById.values.where(
          (a) => a.email.toLowerCase() == email && a.password == password,
        );
        if (match.isEmpty) {
          return _jsonResponse(400, <String, dynamic>{
            'error': 'invalid_grant',
            'error_description': 'Invalid login credentials',
            'code': 400,
            'msg': 'Invalid login credentials',
          });
        }
        final account = match.first;
        _activeUserId = account.id;
        return _jsonResponse(200, _sessionJson(account));
      }

      if (grantType == 'refresh_token') {
        final refresh = body['refresh_token'] as String? ?? '';
        final id = refresh.replaceFirst('mock-refresh-', '');
        final account = _authAccountsById[id] ??
            (_activeUserId != null ? _authAccountsById[_activeUserId] : null);
        if (account == null) {
          return _jsonResponse(400, <String, dynamic>{
            'error': 'invalid_grant',
            'error_description': 'Invalid Refresh Token',
          });
        }
        _activeUserId = account.id;
        return _jsonResponse(200, _sessionJson(account));
      }
    }

    if (method == 'POST' && path == '/auth/v1/signup') {
      final email = (body['email'] as String? ?? '').trim();
      final password = body['password'] as String? ?? '';
      final data = body['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final rawUsername = (data['username'] as String? ?? '').trim();
      final username = rawUsername.isNotEmpty
          ? rawUsername
          : email.split('@').first.replaceAll(RegExp('[^a-zA-Z0-9_]'), '');
      final displayName =
          (data['display_name'] as String? ?? username).trim();

      final duplicateEmail = _authAccountsById.values.any(
        (a) => a.email.toLowerCase() == email.toLowerCase(),
      );
      if (duplicateEmail) {
        return _jsonResponse(422, <String, dynamic>{
          'code': 'user_already_exists',
          'msg': 'User already registered',
        });
      }

      final newId = _nextUuid();
      final account = _AuthAccount(
        id: newId,
        email: email,
        password: password,
        username: username,
        displayName: displayName,
      );
      _registerAccount(
        id: newId,
        email: email,
        password: password,
        username: username,
        displayName: displayName,
      );
      _activeUserId = newId;
      return _jsonResponse(200, _sessionJson(account));
    }

    if (method == 'GET' && path == '/auth/v1/user') {
      final uid = _extractRequestUserId(headers);
      final account = uid != null ? _authAccountsById[uid] : null;
      if (account == null) {
        return _jsonResponse(401, <String, dynamic>{
          'error': 'unauthorized',
          'msg': 'Auth session missing',
        });
      }
      return _jsonResponse(200, _authUserJson(account));
    }

    if (method == 'PUT' && path == '/auth/v1/user') {
      final uid = _extractRequestUserId(headers);
      final account = uid != null ? _authAccountsById[uid] : null;
      if (account == null) {
        return _jsonResponse(401, <String, dynamic>{'msg': 'Unauthorized'});
      }
      if (body['email'] is String && (body['email'] as String).isNotEmpty) {
        account.email = (body['email'] as String).trim();
      }
      if (body['password'] is String &&
          (body['password'] as String).isNotEmpty) {
        account.password = body['password'] as String;
      }
      if (body['data'] is Map<String, dynamic>) {
        final data = body['data'] as Map<String, dynamic>;
        if (data['username'] is String) {
          account.username = data['username'] as String;
        }
        if (data['display_name'] is String) {
          account.displayName = data['display_name'] as String;
        }
      }
      return _jsonResponse(200, _authUserJson(account));
    }

    if (method == 'POST' && path == '/auth/v1/logout') {
      _activeUserId = null;
      return http.Response('', 204);
    }

    return _jsonResponse(404, <String, dynamic>{
      'error': 'Unsupported auth endpoint: $method $path',
    });
  }

  // ---------------------------------------------------------------------------
  // Edge Functions /functions/v1/*
  // ---------------------------------------------------------------------------

  Future<http.Response> _handleFunction(
    String method,
    Uri uri,
    String bodyText,
    Map<String, String> headers,
  ) async {
    final fnName = uri.path.replaceFirst('/functions/v1/', '');
    final body = bodyText.isNotEmpty
        ? (jsonDecode(bodyText) as Map<String, dynamic>? ?? <String, dynamic>{})
        : <String, dynamic>{};

    switch (fnName) {
      case 'igdb-proxy':
        igdbProxyCalls++;
        return _handleIgdbProxy(body);
      case 'get-metacritic-score':
        return _jsonResponse(200, <String, dynamic>{
          'score': 94,
          'url': 'https://www.metacritic.com',
        });
      case 'fetch-stash-reviews':
        return _jsonResponse(200, <String, dynamic>{
          'reviews': <dynamic>[],
          'imported': 0,
        });
      case 'fetch-stash-game-stats':
        return _jsonResponse(200, <String, dynamic>{
          'stats': null,
        });
      case 'fetch-duracionde-time':
        return _jsonResponse(200, <String, dynamic>{
          'main_story': 58,
          'main_extra': 100,
          'completionist': 134,
        });
      case 'resolve-steam-id':
      case 'steam-library-import':
      case 'send-test-notification':
      case 'send-push-notification':
        return _jsonResponse(200, <String, dynamic>{'ok': true});
      default:
        return _jsonResponse(200, <String, dynamic>{'ok': true});
    }
  }

  http.Response _handleIgdbProxy(Map<String, dynamic> body) {
    final endpoint = (body['endpoint'] as String? ?? 'games').toLowerCase();
    final query = body['query'] as String? ?? '';

    if (endpoint == 'time_to_beats' || endpoint == 'game_time_to_beats') {
      return _jsonResponse(200, <Map<String, dynamic>>[
        <String, dynamic>{
          'game_id': eldenRingId,
          'hastily': 180000,
          'normally': 288000,
          'completely': 468000,
        },
      ]);
    }

    if (endpoint != 'games') {
      return _jsonResponse(200, <dynamic>[]);
    }

    var results = List<Map<String, dynamic>>.from(_igdbCatalog);

    // 1. Filtro de búsqueda: search "...";
    final searchMatch = RegExp(r'search\s+"([^"]+)"\s*;').firstMatch(query);
    if (searchMatch != null) {
      final term = searchMatch.group(1)!.trim().toLowerCase();
      results = results
          .where((g) => (g['name'] as String).toLowerCase().contains(term))
          .toList();
    } else {
      // 2. Filtro por ID único o lista: where id = 123 o where id = (1, 2)
      final idListMatch =
          RegExp(r'\bwhere\s+id\s*=\s*\(([^)]+)\)').firstMatch(query);
      final singleIdMatch =
          RegExp(r'\bwhere\s+id\s*=\s*(\d+)\b').firstMatch(query);

      if (idListMatch != null) {
        final ids = idListMatch
            .group(1)!
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>()
            .toSet();
        results = results.where((g) => ids.contains(g['id'])).toList();
      } else if (singleIdMatch != null) {
        final targetId = int.tryParse(singleIdMatch.group(1)!);
        results = results.where((g) => g['id'] == targetId).toList();
      } else if (query.contains('first_release_date >')) {
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        results = results
            .where((g) => ((g['first_release_date'] as int?) ?? 0) > nowSec)
            .toList();
      } else if (query.contains('hypes >') || query.contains('follows >')) {
        // Más esperados o populares sin query de texto.
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (query.contains('sort hypes desc')) {
          results = results
              .where((g) => ((g['first_release_date'] as int?) ?? 0) > nowSec)
              .toList();
        } else {
          results = results
              .where((g) => ((g['first_release_date'] as int?) ?? 0) <= nowSec)
              .toList();
        }
      } else {
        // Tendencias por defecto: juegos ya lanzados.
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        results = results
            .where((g) => ((g['first_release_date'] as int?) ?? 0) <= nowSec)
            .toList();
      }
    }

    final offsetMatch = RegExp(r'\boffset\s+(\d+)\s*;').firstMatch(query);
    final limitMatch = RegExp(r'\blimit\s+(\d+)\s*;').firstMatch(query);
    final offset = offsetMatch != null ? int.parse(offsetMatch.group(1)!) : 0;
    final limit = limitMatch != null ? int.parse(limitMatch.group(1)!) : 50;

    final paged = results.skip(offset).take(limit).toList();
    return _jsonResponse(200, paged);
  }

  // ---------------------------------------------------------------------------
  // RPCs /rest/v1/rpc/*
  // ---------------------------------------------------------------------------

  Future<http.Response> _handleRpc(
    String method,
    Uri uri,
    String bodyText,
    Map<String, String> headers,
  ) async {
    final rpcName = uri.path.replaceFirst('/rest/v1/rpc/', '');
    final args = bodyText.isNotEmpty
        ? (jsonDecode(bodyText) as Map<String, dynamic>? ?? <String, dynamic>{})
        : <String, dynamic>{};
    final uid = _extractRequestUserId(headers);
    final accept = headers['accept'] ?? '';
    final wantsObject = accept.contains('application/vnd.pgrst.object+json');

    switch (rpcName) {
      case 'get_unread_activity_summary':
        final lastRead = uid != null
            ? (_tables['users']!
                    .where((u) => u['id'] == uid)
                    .map((u) => u['last_activity_read_at'] as String?)
                    .firstOrNull ??
                _clock.toIso8601String())
            : _clock.toIso8601String();
        final count = uid == null
            ? 0
            : _tables['activity_feed']!
                .where(
                  (af) =>
                      af['user_id'] != uid &&
                      ((af['created_at'] as String?) ?? '')
                              .compareTo(lastRead) >
                          0,
                )
                .map((af) => af['post_id'] ?? af['id'])
                .toSet()
                .length;
        final row = <String, dynamic>{
          'unread_count': count,
          'last_read_at': lastRead,
        };
        return _jsonResponse(200, wantsObject ? row : <dynamic>[row]);

      case 'mark_activity_read':
        if (uid != null) {
          final now = _nextIsoTimestamp();
          for (final u in _tables['users']!) {
            if (u['id'] == uid) {
              u['last_activity_read_at'] = now;
            }
          }
        }
        return _jsonResponse(200, null);

      case 'get_unread_notifications_count':
        final count = uid == null
            ? 0
            : _tables['notifications']!
                .where((n) => n['recipient_id'] == uid && n['read_at'] == null)
                .length;
        return _jsonResponse(200, count);

      case 'mark_all_notifications_read':
        if (uid != null) {
          final now = _nextIsoTimestamp();
          for (final n in _tables['notifications']!) {
            if (n['recipient_id'] == uid && n['read_at'] == null) {
              n['read_at'] = now;
            }
          }
        }
        return _jsonResponse(200, null);

      case 'mark_notification_read':
        final nid = args['p_notification_id'] as String?;
        if (uid != null && nid != null) {
          final now = _nextIsoTimestamp();
          for (final n in _tables['notifications']!) {
            if (n['id'] == nid && n['recipient_id'] == uid) {
              n['read_at'] = now;
            }
          }
        }
        return _jsonResponse(200, null);

      case 'current_post_for_review':
        final reviewId = args['p_review_id'] as String?;
        final postId =
            reviewId != null ? _findPostIdForReview(reviewId) : null;
        return _jsonResponse(200, postId);

      case 'ensure_review_post':
        final reviewId = args['p_review_id'] as String?;
        if (reviewId == null) {
          return _jsonResponse(200, null);
        }
        final existingPostId = _findPostIdForReview(reviewId);
        if (existingPostId != null) {
          return _jsonResponse(200, existingPostId);
        }
        final review = _tables['reviews']!
            .where((r) => r['id'] == reviewId)
            .firstOrNull;
        if (review == null) {
          return _jsonResponse(200, null);
        }
        final ts = (review['created_at'] as String?) ?? _nextIsoTimestamp();
        final newPostId = _nextUuid();
        _tables['feed_posts']!.add(<String, dynamic>{
          'id': newPostId,
          'user_id': review['user_id'],
          'status': review['status'],
          'groupable': false,
          'starts_at': ts,
          'ends_at': ts,
          'review_id': reviewId,
          'created_at': ts,
        });
        return _jsonResponse(200, newPostId);

      case 'get_post_stats':
        final rawIds = (args['p_post_ids'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => e.toString())
            .toList();
        final stats = rawIds.map((pid) {
          final likes = _tables['review_likes']!
              .where((l) => l['post_id'] == pid)
              .toList();
          final commentsCount = _tables['review_comments']!
              .where((c) => c['post_id'] == pid)
              .length;
          final likedByMe =
              uid != null && likes.any((l) => l['user_id'] == uid);
          return <String, dynamic>{
            'post_id': pid,
            'likes_count': likes.length,
            'comments_count': commentsCount,
            'liked_by_me': likedByMe,
          };
        }).toList();
        return _jsonResponse(200, stats);

      case 'get_review_post_stats':
        final rawIds = (args['p_review_ids'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => e.toString())
            .toList();
        final stats = rawIds.map((rid) {
          final pid = _findPostIdForReview(rid);
          final likes = _tables['review_likes']!.where(
            (l) =>
                (pid != null && l['post_id'] == pid) ||
                l['review_id'] == rid,
          );
          final comments = _tables['review_comments']!.where(
            (c) =>
                (pid != null && c['post_id'] == pid) ||
                c['review_id'] == rid,
          );
          final likedByMe =
              uid != null && likes.any((l) => l['user_id'] == uid);
          return <String, dynamic>{
            'review_id': rid,
            'post_id': pid,
            'likes_count': likes.length,
            'comments_count': comments.length,
            'liked_by_me': likedByMe,
          };
        }).toList();
        return _jsonResponse(200, stats);

      default:
        return _jsonResponse(200, <dynamic>[]);
    }
  }

  String? _findPostIdForReview(String reviewId) {
    final fromActivity = _tables['activity_feed']!
        .where((af) => af['review_id'] == reviewId && af['post_id'] != null)
        .toList();
    if (fromActivity.isNotEmpty) {
      fromActivity.sort(
        (a, b) => ((b['created_at'] as String?) ?? '')
            .compareTo((a['created_at'] as String?) ?? ''),
      );
      return fromActivity.first['post_id'] as String?;
    }
    final fromPosts = _tables['feed_posts']!
        .where((p) => p['review_id'] == reviewId)
        .toList();
    if (fromPosts.isNotEmpty) {
      return fromPosts.first['id'] as String?;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // PostgREST /rest/v1/<table>
  // ---------------------------------------------------------------------------

  Future<http.Response> _handleRest(
    String method,
    Uri uri,
    String bodyText,
    Map<String, String> headers,
  ) async {
    final table = uri.path.replaceFirst('/rest/v1/', '');
    final prefer = headers['prefer'] ?? '';
    final accept = headers['accept'] ?? '';
    final wantsObject = accept.contains('application/vnd.pgrst.object+json');
    final wantsCountExact = prefer.contains('count=exact');
    final wantsRepresentation = prefer.contains('return=representation');
    final selectParam = uri.queryParameters['select'] ?? '*';

    if (table == 'v_friend_pairs') {
      if (method != 'GET' && method != 'HEAD') {
        return _jsonResponse(405, <String, dynamic>{'msg': 'Read-only view'});
      }
      final pairs = _computeFriendPairs();
      return _serveGetRows(
        rows: pairs,
        table: table,
        uri: uri,
        headers: headers,
        selectParam: selectParam,
        wantsObject: wantsObject,
        wantsCountExact: wantsCountExact,
        headOnly: method == 'HEAD',
      );
    }

    final tableList = _tables.putIfAbsent(table, () => <Map<String, dynamic>>[]);

    if (method == 'GET' || method == 'HEAD') {
      return _serveGetRows(
        rows: tableList,
        table: table,
        uri: uri,
        headers: headers,
        selectParam: selectParam,
        wantsObject: wantsObject,
        wantsCountExact: wantsCountExact,
        headOnly: method == 'HEAD',
      );
    }

    if (method == 'POST') {
      final decoded = bodyText.isNotEmpty ? jsonDecode(bodyText) : <dynamic>[];
      final incomingList = decoded is List
          ? decoded.cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[decoded as Map<String, dynamic>];
      final isUpsert = prefer.contains('resolution=merge-duplicates');
      final isIgnore = prefer.contains('resolution=ignore-duplicates');
      final onConflict = uri.queryParameters['on_conflict']
              ?.split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList() ??
          _defaultConflictKeys(table);

      final affected = <Map<String, dynamic>>[];

      for (final rawItem in incomingList) {
        final item = Map<String, dynamic>.from(rawItem);
        _applyInsertDefaults(table, item, headers);

        Map<String, dynamic>? existing;
        if (isUpsert || isIgnore) {
          existing = _findConflictingRow(tableList, item, onConflict);
        }

        if (existing != null) {
          if (isUpsert) {
            final prevSnapshot = Map<String, dynamic>.from(existing);
            existing.addAll(item);
            _onRowMutated(table, existing, previous: prevSnapshot);
            affected.add(existing);
          } else {
            affected.add(existing);
          }
        } else {
          // Para review_likes evita duplicados por (user_id, post_id) o (user_id, review_id).
          if (table == 'review_likes') {
            final resolved = _prepareInteractionRow(table, item);
            final dup = tableList.where(
              (l) =>
                  l['user_id'] == resolved['user_id'] &&
                  ((resolved['post_id'] != null &&
                          l['post_id'] == resolved['post_id']) ||
                      (resolved['review_id'] != null &&
                          l['review_id'] == resolved['review_id'])),
            );
            if (dup.isNotEmpty) {
              affected.add(dup.first);
              continue;
            }
          }
          tableList.add(item);
          _onRowMutated(table, item);
          affected.add(item);
        }
      }

      if (!wantsRepresentation && uri.queryParameters['select'] == null) {
        return http.Response('', 201);
      }

      final projected = _projectRows(table, affected, selectParam);
      if (wantsObject) {
        if (projected.isEmpty) {
          return _pgrst116();
        }
        return _jsonResponse(200, projected.first);
      }
      return _jsonResponse(201, projected);
    }

    if (method == 'PATCH') {
      final decoded = bodyText.isNotEmpty
          ? (jsonDecode(bodyText) as Map<String, dynamic>)
          : <String, dynamic>{};
      final matching = _filterRows(table, tableList, uri);
      for (final row in matching) {
        final prev = Map<String, dynamic>.from(row);
        row.addAll(decoded);
        _onRowMutated(table, row, previous: prev);
      }
      if (!wantsRepresentation && uri.queryParameters['select'] == null) {
        return http.Response('', 204);
      }
      final projected = _projectRows(table, matching, selectParam);
      if (wantsObject) {
        if (projected.isEmpty) {
          return _pgrst116();
        }
        return _jsonResponse(200, projected.first);
      }
      return _jsonResponse(200, projected);
    }

    if (method == 'DELETE') {
      final matching = _filterRows(table, tableList, uri).toList();
      for (final row in matching) {
        tableList.remove(row);
        _onRowDeleted(table, row);
      }
      if (!wantsRepresentation && uri.queryParameters['select'] == null) {
        return http.Response('', 204);
      }
      final projected = _projectRows(table, matching, selectParam);
      if (wantsObject) {
        if (projected.isEmpty) {
          return _pgrst116();
        }
        return _jsonResponse(200, projected.first);
      }
      return _jsonResponse(200, projected);
    }

    return _jsonResponse(405, <String, dynamic>{'error': 'Unsupported $method'});
  }

  http.Response _serveGetRows({
    required List<Map<String, dynamic>> rows,
    required String table,
    required Uri uri,
    required Map<String, String> headers,
    required String selectParam,
    required bool wantsObject,
    required bool wantsCountExact,
    required bool headOnly,
  }) {
    final filtered = _filterRows(table, rows, uri);

    // Conserva la fila original junto a la proyectada para filtrar `!inner` y
    // permitir ordenar aunque la columna de `order=` no figure en `select=`.
    var pairs = _projectRowPairs(
      table,
      filtered,
      selectParam,
      dropMissingInner: true,
    );

    final orderParam = uri.queryParameters['order'];
    if (orderParam != null && orderParam.isNotEmpty) {
      pairs = _sortRowPairs(pairs, orderParam);
    }

    var projected = pairs.map((p) => p.projected).toList();
    final totalCount = projected.length;

    // Aplica offset / limit / cabecera Range.
    var offset = int.tryParse(uri.queryParameters['offset'] ?? '') ?? 0;
    var limit = int.tryParse(uri.queryParameters['limit'] ?? '');

    final rangeHeader = headers['range'];
    if (rangeHeader != null && limit == null && offset == 0) {
      final rangeMatch = RegExp(r'^(\d+)-(\d+)$').firstMatch(rangeHeader.trim());
      if (rangeMatch != null) {
        final from = int.parse(rangeMatch.group(1)!);
        final to = int.parse(rangeMatch.group(2)!);
        offset = from;
        limit = max(0, to - from + 1);
      }
    }

    if (offset > 0 || limit != null) {
      final iterable = projected.skip(offset);
      projected = limit != null ? iterable.take(limit).toList() : iterable.toList();
    }

    final extraHeaders = <String, String>{};
    if (wantsCountExact) {
      if (totalCount == 0 || projected.isEmpty) {
        extraHeaders['content-range'] = '*/$totalCount';
      } else {
        final end = offset + projected.length - 1;
        extraHeaders['content-range'] = '$offset-$end/$totalCount';
      }
    }

    if (headOnly) {
      return http.Response('', 200, headers: extraHeaders);
    }

    if (wantsObject) {
      if (projected.isEmpty) {
        return _pgrst116();
      }
      return _jsonResponse(200, projected.first, extraHeaders: extraHeaders);
    }

    return _jsonResponse(200, projected, extraHeaders: extraHeaders);
  }

  http.Response _pgrst116() {
    return _jsonResponse(406, <String, dynamic>{
      'code': 'PGRST116',
      'details': 'Results contain 0 rows',
      'hint': null,
      'message':
          'JSON object requested, multiple (or no) rows returned',
    });
  }

  List<Map<String, dynamic>> _computeFriendPairs() {
    final pairs = <Map<String, dynamic>>[];
    for (final f in _tables['friendships']!) {
      if (f['status'] == 'accepted') {
        pairs.add(<String, dynamic>{
          'user_id': f['requester_id'],
          'friend_id': f['addressee_id'],
        });
        pairs.add(<String, dynamic>{
          'user_id': f['addressee_id'],
          'friend_id': f['requester_id'],
        });
      }
    }
    return pairs;
  }

  List<String> _defaultConflictKeys(String table) {
    switch (table) {
      case 'user_games':
        return <String>['user_id', 'game_id'];
      case 'friendships':
        return <String>['requester_id', 'addressee_id'];
      case 'games':
        return <String>['igdb_id'];
      case 'user_settings':
      case 'notification_preferences':
        return <String>['user_id'];
      case 'game_group_items':
        return <String>['group_id', 'game_id'];
      case 'hall_of_fame':
        return <String>['user_id', 'pin_order'];
      case 'stash_game_stats':
      case 'stash_sync_metadata':
        return <String>['game_id'];
      default:
        return <String>['id'];
    }
  }

  Map<String, dynamic>? _findConflictingRow(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> incoming,
    List<String> keys,
  ) {
    for (final row in rows) {
      var allMatch = true;
      for (final k in keys) {
        if (!incoming.containsKey(k) || row[k] != incoming[k]) {
          allMatch = false;
          break;
        }
      }
      if (allMatch) {
        return row;
      }
    }
    return null;
  }

  void _applyInsertDefaults(
    String table,
    Map<String, dynamic> item,
    Map<String, String> headers,
  ) {
    final uid = _extractRequestUserId(headers);
    final now = _nextIsoTimestamp();

    const tablesWithUuidId = <String>{
      'reviews',
      'review_comments',
      'activity_feed',
      'feed_posts',
      'game_groups',
      'game_group_items',
      'notifications',
    };
    if (tablesWithUuidId.contains(table) &&
        (item['id'] == null || (item['id'] as String).isEmpty)) {
      item['id'] = _nextUuid();
    }

    if (uid != null &&
        (table == 'reviews' ||
            table == 'review_comments' ||
            table == 'review_likes' ||
            table == 'user_games' ||
            table == 'game_groups') &&
        item['user_id'] == null) {
      item['user_id'] = uid;
    }

    if (table == 'user_games') {
      item['updated_at'] ??= now;
      item['play_count'] ??= 1;
      item['status'] ??= 'wishlist';
      item['is_steam_only'] ??= false;
    } else if (table == 'reviews') {
      item['created_at'] ??= now;
      item['status'] ??= 'beaten';
      item['completion_type'] ??= 'story';
      item['is_replay'] ??= false;
      item['image_urls'] ??= <String>[];
    } else if (table == 'activity_feed') {
      item['created_at'] ??= now;
      item['metadata'] ??= <String, dynamic>{};
      if (item['post_id'] == null) {
        final actionType = item['action_type'] as String? ?? 'status_change';
        final postId = _computeOrReusePostForActivity(
          userId: item['user_id'] as String? ?? primaryUserId,
          actionType: actionType,
          reviewId: item['review_id'] as String?,
          metadata: item['metadata'] as Map<String, dynamic>?,
          ts: item['created_at'] as String,
        );
        item['post_id'] = postId;
      }
    } else if (table == 'review_comments' || table == 'review_likes') {
      item['created_at'] ??= now;
      _prepareInteractionRow(table, item);
    } else if (table == 'game_groups' || table == 'game_group_items') {
      item['created_at'] ??= now;
      item['sort_order'] ??= 0;
      if (table == 'game_groups') {
        item['is_ranked'] ??= false;
      }
    } else if (table == 'friendships') {
      item['created_at'] ??= now;
      item['status'] ??= 'pending';
    } else if (table == 'user_settings') {
      item['updated_at'] ??= now;
    }
  }

  Map<String, dynamic> _prepareInteractionRow(
    String table,
    Map<String, dynamic> item,
  ) {
    var postId = item['post_id'] as String?;
    var reviewId = item['review_id'] as String?;

    if (postId == null && reviewId != null) {
      postId = _findPostIdForReview(reviewId);
      if (postId == null) {
        final review = _tables['reviews']!
            .where((r) => r['id'] == reviewId)
            .firstOrNull;
        final ts = (review?['created_at'] as String?) ?? _nextIsoTimestamp();
        postId = _nextUuid();
        _tables['feed_posts']!.add(<String, dynamic>{
          'id': postId,
          'user_id': review?['user_id'] ?? item['user_id'],
          'status': review?['status'],
          'groupable': false,
          'starts_at': ts,
          'ends_at': ts,
          'review_id': reviewId,
          'created_at': ts,
        });
      }
      item['post_id'] = postId;
    } else if (postId != null && reviewId == null) {
      final linkedActivity = _tables['activity_feed']!
          .where((af) => af['post_id'] == postId && af['review_id'] != null)
          .firstOrNull;
      if (linkedActivity != null) {
        reviewId = linkedActivity['review_id'] as String?;
      } else {
        final post =
            _tables['feed_posts']!.where((p) => p['id'] == postId).firstOrNull;
        reviewId = post?['review_id'] as String?;
      }
      if (reviewId != null) {
        item['review_id'] = reviewId;
      }
    }
    return item;
  }

  String _computeOrReusePostForActivity({
    required String userId,
    required String actionType,
    String? reviewId,
    Map<String, dynamic>? metadata,
    required String ts,
  }) {
    if (reviewId != null) {
      final existing = _findPostIdForReview(reviewId);
      if (existing != null) {
        return existing;
      }
    }
    final status = metadata?['status'] as String?;
    final newPostId = _nextUuid();
    _tables['feed_posts']!.add(<String, dynamic>{
      'id': newPostId,
      'user_id': userId,
      'status': status,
      'groupable': false,
      'starts_at': ts,
      'ends_at': ts,
      'review_id': reviewId,
      'created_at': ts,
    });
    return newPostId;
  }

  void _onRowMutated(
    String table,
    Map<String, dynamic> row, {
    Map<String, dynamic>? previous,
  }) {
    if (table == 'reviews') {
      final isStatusChange =
          previous == null || previous['status'] != row['status'];
      _applyReviewSideEffects(row, isStatusChange: isStatusChange);
    } else if (table == 'user_games') {
      final statusChanged =
          previous == null || previous['status'] != row['status'];
      if (statusChanged) {
        final uid = row['user_id'] as String;
        final gid = row['game_id'];
        // Evita duplicar si acaba de generarse desde una review en esta operación.
        final matchingReview = _tables['reviews']!
            .where((r) => r['user_id'] == uid && r['game_id'] == gid)
            .lastOrNull;
        final reviewId = matchingReview?['id'] as String?;
        final hasRecentStatus = _tables['activity_feed']!.any(
          (af) =>
              af['user_id'] == uid &&
              af['game_id'] == gid &&
              af['action_type'] == 'status_change' &&
              (af['metadata'] as Map<String, dynamic>?)?['status'] ==
                  row['status'] &&
              af['review_id'] == reviewId,
        );
        if (!hasRecentStatus) {
          final ts = _nextIsoTimestamp();
          final postId = _computeOrReusePostForActivity(
            userId: uid,
            actionType: 'status_change',
            reviewId: reviewId,
            metadata: <String, dynamic>{'status': row['status']},
            ts: ts,
          );
          _tables['activity_feed']!.add(<String, dynamic>{
            'id': _nextUuid(),
            'user_id': uid,
            'action_type': 'status_change',
            'game_id': gid,
            'review_id': reviewId,
            'post_id': postId,
            'metadata': <String, dynamic>{'status': row['status']},
            'created_at': ts,
          });
        }
      }
    } else if (table == 'friendships' &&
        previous != null &&
        previous['status'] == 'pending' &&
        row['status'] == 'accepted') {
      _tables['notifications']!.removeWhere(
        (n) =>
            n['type'] == 'friend_request' &&
            n['recipient_id'] == row['addressee_id'] &&
            n['actor_id'] == row['requester_id'],
      );
    }
  }

  void _applyReviewSideEffects(
    Map<String, dynamic> review, {
    required bool isStatusChange,
  }) {
    final uid = review['user_id'] as String;
    final gid = review['game_id'];
    final reviewId = review['id'] as String;
    final ts = _nextIsoTimestamp();

    final existingUg = _tables['user_games']!
        .where((ug) => ug['user_id'] == uid && ug['game_id'] == gid)
        .firstOrNull;
    final statusChangedInUg =
        existingUg == null || existingUg['status'] != review['status'];

    if (existingUg != null) {
      existingUg['status'] = review['status'];
      existingUg['rating'] = review['rating'];
      existingUg['rating_gameplay'] = review['rating_gameplay'];
      existingUg['rating_narrative'] = review['rating_narrative'];
      existingUg['rating_soundtrack'] = review['rating_soundtrack'];
      existingUg['rating_visuals'] = review['rating_visuals'];
      existingUg['comment'] = review['comment'];
      existingUg['play_time_hours'] = review['play_time_hours'];
      existingUg['updated_at'] = ts;
      existingUg['last_played_at'] = review['played_until'] ?? review['created_at'];
    } else {
      _tables['user_games']!.add(<String, dynamic>{
        'user_id': uid,
        'game_id': gid,
        'status': review['status'] ?? 'beaten',
        'rating': review['rating'],
        'rating_gameplay': review['rating_gameplay'],
        'rating_narrative': review['rating_narrative'],
        'rating_soundtrack': review['rating_soundtrack'],
        'rating_visuals': review['rating_visuals'],
        'comment': review['comment'],
        'play_count': 1,
        'play_time_hours': review['play_time_hours'],
        'last_played_at': review['played_until'] ?? review['created_at'],
        'updated_at': ts,
        'is_steam_only': false,
      });
    }

    if (isStatusChange || statusChangedInUg) {
      final unlinkedStatusActivity = _tables['activity_feed']!
          .where(
            (af) =>
                af['user_id'] == uid &&
                af['game_id'] == gid &&
                af['action_type'] == 'status_change' &&
                af['review_id'] == null &&
                (af['metadata'] as Map<String, dynamic>?)?['status'] ==
                    review['status'],
          )
          .lastOrNull;

      if (unlinkedStatusActivity != null) {
        unlinkedStatusActivity['review_id'] = reviewId;
        final meta = Map<String, dynamic>.from(
          (unlinkedStatusActivity['metadata'] as Map<String, dynamic>?) ??
              <String, dynamic>{},
        );
        meta['rating'] = review['rating'];
        meta['comment'] = review['comment'];
        unlinkedStatusActivity['metadata'] = meta;
        final linkedPostId = unlinkedStatusActivity['post_id'];
        if (linkedPostId != null) {
          for (final p in _tables['feed_posts']!) {
            if (p['id'] == linkedPostId) {
              p['review_id'] = reviewId;
            }
          }
        }
      } else {
        final postId = _nextUuid();
        _tables['feed_posts']!.add(<String, dynamic>{
          'id': postId,
          'user_id': uid,
          'status': review['status'],
          'groupable': false,
          'starts_at': ts,
          'ends_at': ts,
          'review_id': reviewId,
          'created_at': ts,
        });
        _tables['activity_feed']!.add(<String, dynamic>{
          'id': _nextUuid(),
          'user_id': uid,
          'action_type': 'status_change',
          'game_id': gid,
          'review_id': reviewId,
          'post_id': postId,
          'metadata': <String, dynamic>{
            'status': review['status'],
            'rating': review['rating'],
            'comment': review['comment'],
          },
          'created_at': ts,
        });
      }
    } else {
      // Actualiza metadatos de la entrada existente si solo cambió nota o texto.
      for (final af in _tables['activity_feed']!) {
        if (af['review_id'] == reviewId) {
          final meta = Map<String, dynamic>.from(
            (af['metadata'] as Map<String, dynamic>?) ?? <String, dynamic>{},
          );
          meta['status'] = review['status'];
          meta['rating'] = review['rating'];
          meta['comment'] = review['comment'];
          af['metadata'] = meta;
        }
      }
    }
  }

  void _onRowDeleted(String table, Map<String, dynamic> row) {
    if (table == 'reviews') {
      final reviewId = row['id'];
      _tables['activity_feed']!.removeWhere(
        (af) => af['review_id'] == reviewId && af['action_type'] == 'reviewed',
      );
      for (final af in _tables['activity_feed']!) {
        if (af['review_id'] == reviewId) {
          af['review_id'] = null;
        }
      }
    } else if (table == 'user_games') {
      final uid = row['user_id'];
      final gid = row['game_id'];
      final deletedReviewIds = _tables['reviews']!
          .where((r) => r['user_id'] == uid && r['game_id'] == gid)
          .map((r) => r['id'])
          .toSet();
      _tables['reviews']!
          .removeWhere((r) => r['user_id'] == uid && r['game_id'] == gid);
      _tables['activity_feed']!.removeWhere(
        (af) =>
            (af['user_id'] == uid && af['game_id'] == gid) ||
            deletedReviewIds.contains(af['review_id']),
      );
    } else if (table == 'game_groups') {
      final groupId = row['id'];
      _tables['game_group_items']!.removeWhere((i) => i['group_id'] == groupId);
    }
  }

  // ---------------------------------------------------------------------------
  // Motor de filtros, ordenación y proyecciones PostgREST
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _filterRows(
    String table,
    List<Map<String, dynamic>> rows,
    Uri uri,
  ) {
    const reserved = <String>{
      'select',
      'order',
      'limit',
      'offset',
      'on_conflict',
      'columns',
    };
    final params = uri.queryParametersAll;
    return rows.where((row) {
      for (final entry in params.entries) {
        final key = entry.key;
        if (reserved.contains(key)) continue;
        for (final expr in entry.value) {
          if (key == 'or') {
            if (!_matchesLogicalExpr(table, row, expr, isOr: true)) {
              return false;
            }
          } else if (key == 'and') {
            if (!_matchesLogicalExpr(table, row, expr, isOr: false)) {
              return false;
            }
          } else if (!_matchesColumnExpr(table, row, key, expr)) {
            return false;
          }
        }
      }
      return true;
    }).toList();
  }

  bool _matchesLogicalExpr(
    String table,
    Map<String, dynamic> row,
    String rawExpr, {
    required bool isOr,
  }) {
    var inner = rawExpr.trim();
    if (inner.startsWith('(') && inner.endsWith(')')) {
      inner = inner.substring(1, inner.length - 1);
    }
    final parts = _splitTopLevel(inner, ',');
    if (isOr) {
      for (final p in parts) {
        if (_evaluatePredicateNode(table, row, p.trim())) {
          return true;
        }
      }
      return false;
    } else {
      for (final p in parts) {
        if (!_evaluatePredicateNode(table, row, p.trim())) {
          return false;
        }
      }
      return true;
    }
  }

  bool _evaluatePredicateNode(
    String table,
    Map<String, dynamic> row,
    String node,
  ) {
    if (node.startsWith('and(') && node.endsWith(')')) {
      return _matchesLogicalExpr(
        table,
        row,
        node.substring(3),
        isOr: false,
      );
    }
    if (node.startsWith('or(') && node.endsWith(')')) {
      return _matchesLogicalExpr(
        table,
        row,
        node.substring(2),
        isOr: true,
      );
    }
    final firstDot = node.indexOf('.');
    if (firstDot <= 0) return true;
    final col = node.substring(0, firstDot);
    final rest = node.substring(firstDot + 1);
    return _matchesColumnExpr(table, row, col, rest);
  }

  bool _matchesColumnExpr(
    String table,
    Map<String, dynamic> row,
    String columnPath,
    String expr,
  ) {
    // Soporte para filtros en relaciones punteadas (p.ej. `games.title`).
    final val = _resolveFieldPath(table, row, columnPath);

    var negate = false;
    var opAndVal = expr;
    if (opAndVal.startsWith('not.')) {
      negate = true;
      opAndVal = opAndVal.substring(4);
    }

    final dotIdx = opAndVal.indexOf('.');
    if (dotIdx <= 0) return true;
    final op = opAndVal.substring(0, dotIdx);
    final rawTarget = opAndVal.substring(dotIdx + 1);

    var matched = false;
    switch (op) {
      case 'eq':
        matched = _equals(val, rawTarget);
      case 'neq':
        matched = !_equals(val, rawTarget);
      case 'gt':
        matched = _compare(val, rawTarget) > 0;
      case 'gte':
        matched = _compare(val, rawTarget) >= 0;
      case 'lt':
        matched = _compare(val, rawTarget) < 0;
      case 'lte':
        matched = _compare(val, rawTarget) <= 0;
      case 'like':
        matched = _matchLike(val, rawTarget, caseInsensitive: false);
      case 'ilike':
        matched = _matchLike(val, rawTarget, caseInsensitive: true);
      case 'is':
        if (rawTarget == 'null') {
          matched = val == null;
        } else if (rawTarget == 'true') {
          matched = val == true;
        } else if (rawTarget == 'false') {
          matched = val == false;
        }
      case 'in':
        final listStr = rawTarget.startsWith('(') && rawTarget.endsWith(')')
            ? rawTarget.substring(1, rawTarget.length - 1)
            : rawTarget;
        final items = listStr.isEmpty
            ? <String>[]
            : _splitTopLevel(listStr, ',')
                .map((s) => s.trim().replaceAll('"', ''))
                .toList();
        matched = items.any((candidate) => _equals(val, candidate));
      case 'cs':
      case 'ov':
        matched = true;
      default:
        matched = true;
    }

    return negate ? !matched : matched;
  }

  dynamic _resolveFieldPath(
    String table,
    Map<String, dynamic> row,
    String columnPath,
  ) {
    if (!columnPath.contains('.')) {
      return row[columnPath];
    }
    final parts = columnPath.split('.');
    final rel = parts.first.split('!').first;
    final field = parts.sublist(1).join('.');
    if (rel == 'games' && row['game_id'] != null) {
      final game = _tables['games']!
          .where((g) => g['igdb_id'] == row['game_id'])
          .firstOrNull;
      return game?[field];
    }
    if (rel == 'users' && row['user_id'] != null) {
      final user = _tables['users']!
          .where((u) => u['id'] == row['user_id'])
          .firstOrNull;
      return user?[field];
    }
    return row[columnPath];
  }

  bool _equals(dynamic val, String rawTarget) {
    if (val == null) return rawTarget == 'null';
    if (val is bool) {
      return (val && rawTarget == 'true') || (!val && rawTarget == 'false');
    }
    if (val is num) {
      final parsed = num.tryParse(rawTarget);
      if (parsed != null) return val == parsed;
    }
    return val.toString() == rawTarget;
  }

  int _compare(dynamic val, String rawTarget) {
    if (val == null) return -1;
    if (val is num) {
      final parsed = num.tryParse(rawTarget);
      if (parsed != null) return val.compareTo(parsed);
    }
    return val.toString().compareTo(rawTarget);
  }

  bool _matchLike(
    dynamic val,
    String pattern, {
    required bool caseInsensitive,
  }) {
    if (val == null) return false;
    final source =
        caseInsensitive ? val.toString().toLowerCase() : val.toString();
    final pat = caseInsensitive ? pattern.toLowerCase() : pattern;
    final clean = pat.replaceAll('%', '.*').replaceAll('_', '.');
    return RegExp('^$clean\$', dotAll: true).hasMatch(source);
  }

  List<({Map<String, dynamic> raw, Map<String, dynamic> projected})>
      _sortRowPairs(
    List<({Map<String, dynamic> raw, Map<String, dynamic> projected})> pairs,
    String orderParam,
  ) {
    final specs = orderParam.split(',');
    final copy = List.of(pairs);
    copy.sort((a, b) {
      for (final spec in specs) {
        final parts = spec.trim().split('.');
        final col = parts.first;
        final desc = parts.length > 1 && parts[1] == 'desc';
        final nullsFirst = parts.contains('nullsfirst');
        final va = a.projected[col] ?? a.raw[col];
        final vb = b.projected[col] ?? b.raw[col];
        if (va == null && vb == null) continue;
        if (va == null) return nullsFirst ? -1 : 1;
        if (vb == null) return nullsFirst ? 1 : -1;
        int cmp;
        if (va is num && vb is num) {
          cmp = va.compareTo(vb);
        } else {
          cmp = va.toString().compareTo(vb.toString());
        }
        if (cmp != 0) {
          return desc ? -cmp : cmp;
        }
      }
      return 0;
    });
    return copy;
  }

  // ---------------------------------------------------------------------------
  // Proyección y resolución de joins embebidos
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _projectRows(
    String table,
    List<Map<String, dynamic>> rows,
    String selectParam, {
    bool dropMissingInner = false,
  }) {
    return _projectRowPairs(
      table,
      rows,
      selectParam,
      dropMissingInner: dropMissingInner,
    ).map((p) => p.projected).toList();
  }

  List<({Map<String, dynamic> raw, Map<String, dynamic> projected})>
      _projectRowPairs(
    String table,
    List<Map<String, dynamic>> rows,
    String selectParam, {
    bool dropMissingInner = false,
  }) {
    final trimmed = selectParam.trim();
    if (trimmed.isEmpty) {
      return rows
          .map((r) => (raw: r, projected: Map<String, dynamic>.from(r)))
          .toList();
    }
    final tokens = _splitTopLevel(trimmed, ',');
    final out =
        <({Map<String, dynamic> raw, Map<String, dynamic> projected})>[];

    for (final row in rows) {
      final projected = <String, dynamic>{};
      var dropRow = false;

      for (final rawToken in tokens) {
        final token = rawToken.trim();
        if (token.isEmpty) continue;

        final openParen = token.indexOf('(');
        if (openParen > 0 && token.endsWith(')')) {
          final prefix = token.substring(0, openParen).trim();
          final innerSelect =
              token.substring(openParen + 1, token.length - 1).trim();

          final relResult = _resolveRelation(
            table: table,
            row: row,
            prefix: prefix,
            innerSelect: innerSelect,
          );
          if (relResult.isInner && relResult.isEmpty) {
            dropRow = true;
            break;
          }
          projected[relResult.outputKey] = relResult.value;
        } else if (token == '*') {
          projected.addAll(Map<String, dynamic>.from(row));
        } else if (token.contains(':')) {
          final colonIdx = token.indexOf(':');
          final alias = token.substring(0, colonIdx).trim();
          final col = token.substring(colonIdx + 1).trim();
          projected[alias] = row[col];
        } else {
          projected[token] = row[token];
        }
      }

      if (!(dropMissingInner && dropRow)) {
        out.add((raw: row, projected: projected));
      }
    }
    return out;
  }

  _RelationResolution _resolveRelation({
    required String table,
    required Map<String, dynamic> row,
    required String prefix,
    required String innerSelect,
  }) {
    String? alias;
    var spec = prefix;
    if (prefix.contains(':')) {
      final colonIdx = prefix.indexOf(':');
      alias = prefix.substring(0, colonIdx).trim();
      spec = prefix.substring(colonIdx + 1).trim();
    }

    final segments = spec.split('!');
    final targetName = segments.first.trim();
    final hints = segments.sublist(1);
    final isInner = hints.contains('inner');
    final outputKey = alias ?? targetName;

    // Relaciones 1:N (tabla hija apuntando a la fila actual).
    if (table == 'game_groups' && targetName == 'game_group_items') {
      final children = _tables['game_group_items']!
          .where((i) => i['group_id'] == row['id'])
          .toList()
        ..sort(
          (a, b) => ((a['sort_order'] as num?) ?? 0)
              .compareTo((b['sort_order'] as num?) ?? 0),
        );
      final projectedChildren = _projectRows(
        'game_group_items',
        children,
        innerSelect,
      );
      return _RelationResolution(
        outputKey: outputKey,
        value: projectedChildren,
        isInner: isInner,
        isEmpty: projectedChildren.isEmpty,
      );
    }

    if (table == 'feed_posts' && targetName == 'activity_feed') {
      final children = _tables['activity_feed']!
          .where((af) => af['post_id'] == row['id'])
          .toList();
      final projectedChildren =
          _projectRows('activity_feed', children, innerSelect);
      return _RelationResolution(
        outputKey: outputKey,
        value: projectedChildren,
        isInner: isInner,
        isEmpty: projectedChildren.isEmpty,
      );
    }

    // Relaciones N:1 (FK en la fila actual).
    Map<String, dynamic>? match;
    String resolvedTargetTable = targetName;

    if (targetName == 'games') {
      final gid = row['game_id'] ?? row['cover_game_id'];
      match = _tables['games']!.where((g) => g['igdb_id'] == gid).firstOrNull;
    } else if (targetName == 'reviews') {
      final rid = row['review_id'];
      match = _tables['reviews']!.where((r) => r['id'] == rid).firstOrNull;
    } else if (targetName == 'feed_posts') {
      final pid = row['post_id'];
      match = _tables['feed_posts']!.where((p) => p['id'] == pid).firstOrNull;
    } else if (targetName == 'game_groups') {
      final gid = row['group_id'];
      match = _tables['game_groups']!.where((g) => g['id'] == gid).firstOrNull;
    } else if (targetName == 'achievements') {
      final aid = row['achievement_id'];
      match =
          _tables['achievements']!.where((a) => a['id'] == aid).firstOrNull;
    } else {
      // Usuarios y alias de FK en `friendships` / `notifications` / `activity_feed`.
      resolvedTargetTable = 'users';
      String? fkCol;
      if (targetName == 'requester_id' ||
          targetName == 'addressee_id' ||
          targetName == 'actor_id' ||
          targetName == 'friend_id' ||
          targetName == 'user_id' ||
          targetName == 'recipient_id') {
        fkCol = targetName;
      } else if (targetName == 'requester') {
        fkCol = 'requester_id';
      } else if (targetName == 'addressee') {
        fkCol = 'addressee_id';
      } else if (targetName == 'actor') {
        fkCol = 'actor_id';
      } else if (hints.any((h) => h.contains('addressee_id'))) {
        fkCol = 'addressee_id';
      } else if (hints.any((h) => h.contains('requester_id'))) {
        fkCol = 'requester_id';
      } else if (hints.any((h) => h.contains('actor_id'))) {
        fkCol = 'actor_id';
      } else {
        fkCol = row.containsKey('user_id')
            ? 'user_id'
            : (row.containsKey('friend_id') ? 'friend_id' : 'actor_id');
      }
      final uid = row[fkCol];
      match = _tables['users']!.where((u) => u['id'] == uid).firstOrNull;
    }

    if (match == null) {
      return _RelationResolution(
        outputKey: outputKey,
        value: null,
        isInner: isInner,
        isEmpty: true,
      );
    }

    final projectedMatch = _projectRows(
      resolvedTargetTable,
      <Map<String, dynamic>>[match],
      innerSelect,
    ).first;

    return _RelationResolution(
      outputKey: outputKey,
      value: projectedMatch,
      isInner: isInner,
      isEmpty: false,
    );
  }

  List<String> _splitTopLevel(String input, String delimiter) {
    final result = <String>[];
    var depth = 0;
    var inQuotes = false;
    var start = 0;

    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (ch == '"' && (i == 0 || input[i - 1] != '\\')) {
        inQuotes = !inQuotes;
      } else if (!inQuotes) {
        if (ch == '(') {
          depth++;
        } else if (ch == ')') {
          depth = max(0, depth - 1);
        } else if (ch == delimiter && depth == 0) {
          result.add(input.substring(start, i));
          start = i + 1;
        }
      }
    }
    result.add(input.substring(start));
    return result;
  }
}

class _RelationResolution {
  _RelationResolution({
    required this.outputKey,
    required this.value,
    required this.isInner,
    required this.isEmpty,
  });

  final String outputKey;
  final dynamic value;
  final bool isInner;
  final bool isEmpty;
}

class _RouterHttpClient extends http.BaseClient {
  _RouterHttpClient(this._backend);

  final FakeSupabaseBackend _backend;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _backend._handleRequest(request);
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable(<List<int>>[response.bodyBytes]),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

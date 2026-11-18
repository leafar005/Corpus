import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/models/models.dart';
import 'package:corpus/repositories/review_repository.dart';

void main() {
  group('ReviewRepository.sanitizeReviewData (Lógica de Limpieza en Wishlist)', () {
    test(
      'Fuerza a null las notas de gameplay, narrativa, tiempo, etc. cuando status es "wishlist"',
      () {
        final sanitized = ReviewRepository.sanitizeReviewData(
          userId: 'user-123',
          igdbId: 100,
          status: 'wishlist',
          rating: 9.5,
          ratingGameplay: 9.0,
          ratingNarrative: 10.0,
          ratingSoundtrack: 8.5,
          ratingVisuals: 9.0,
          comment: 'Comentario que no debería guardarse',
          completionType: '100%',
          isReplay: true,
          replayNumber: 2,
          platform: 'PC',
          playTimeHours: 50.0,
          playedFrom: DateTime(2025, 1, 1),
          playedUntil: DateTime(2025, 1, 10),
          progressPercent: 100,
          imageUrls: ['https://ejemplo.com/foto1.jpg'],
          partnerIds: const [],
        );

        expect(sanitized['status'], 'wishlist');
        expect(sanitized['rating'], isNull);
        expect(sanitized['rating_gameplay'], isNull);
        expect(sanitized['rating_narrative'], isNull);
        expect(sanitized['rating_soundtrack'], isNull);
        expect(sanitized['rating_visuals'], isNull);
        expect(sanitized['comment'], isNull);
        expect(sanitized['completion_type'], 'none');
        expect(sanitized['is_replay'], isFalse);
        expect(sanitized['replay_number'], isNull);
        expect(sanitized['platform'], isNull);
        expect(sanitized['play_time_hours'], isNull);
        expect(sanitized['played_from'], isNull);
        expect(sanitized['played_until'], isNull);
        expect(sanitized['progress_percent'], isNull);
        expect(sanitized['image_urls'], isEmpty);
      },
    );

    test(
      'Conserva las notas, comentario e imágenes cuando status es "beaten" o "playing"',
      () {
        final sanitized = ReviewRepository.sanitizeReviewData(
          userId: 'user-123',
          igdbId: 100,
          status: 'beaten',
          rating: 9.5,
          ratingGameplay: 9.0,
          ratingNarrative: 10.0,
          ratingSoundtrack: 8.5,
          ratingVisuals: 9.0,
          comment: 'Juegazo increíble',
          completionType: 'story',
          isReplay: false,
          replayNumber: null,
          platform: 'PlayStation 5',
          playTimeHours: 40.0,
          playedFrom: DateTime(2025, 1, 1),
          playedUntil: DateTime(2025, 1, 10),
          progressPercent: 100,
          imageUrls: ['https://ejemplo.com/foto1.jpg'],
          partnerIds: const [],
        );

        expect(sanitized['status'], 'beaten');
        expect(sanitized['rating'], 9.5);
        expect(sanitized['rating_gameplay'], 9.0);
        expect(sanitized['rating_narrative'], 10.0);
        expect(sanitized['comment'], 'Juegazo increíble');
        expect(sanitized['platform'], 'PlayStation 5');
        expect(sanitized['play_time_hours'], 40.0);
        expect(sanitized['image_urls'], ['https://ejemplo.com/foto1.jpg']);
      },
    );
  });

  group(
    'ReviewRepository.computeUnlockedAchievements (Lógica de Logros Desbloqueados)',
    () {
      test(
        'Detecta exactamente el ID del logro recién desbloqueado (1 antes -> 2 después)',
        () {
          final before = {'logro-bienvenida'};
          final after = {'logro-bienvenida', 'logro-primer-juego'};

          final unlocked = ReviewRepository.computeUnlockedAchievements(
            before,
            after,
          );

          expect(unlocked.length, 1);
          expect(unlocked.first, 'logro-primer-juego');
        },
      );

      test('Devuelve conjunto vacío si no se desbloquearon nuevos logros', () {
        final before = {'logro-1', 'logro-2'};
        final after = {'logro-1', 'logro-2'};

        final unlocked = ReviewRepository.computeUnlockedAchievements(
          before,
          after,
        );

        expect(unlocked, isEmpty);
      });

      test(
        'Maneja correctamente cuando el usuario parte de 0 logros antes de guardar',
        () {
          final before = <String>{};
          final after = {'logro-1'};

          final unlocked = ReviewRepository.computeUnlockedAchievements(
            before,
            after,
          );

          expect(unlocked, {'logro-1'});
        },
      );
    },
  );

  group('SaveReviewResult Model Test', () {
    test('Almacena correctamente los IDs de logros y sus detalles', () {
      const result = SaveReviewResult(
        newlyUnlockedAchievementIds: {'logro-100'},
        newAchievementDetails: [
          {'id': 'logro-100', 'title': 'Coleccionista I', 'xp': 100},
        ],
      );

      expect(result.newlyUnlockedAchievementIds, contains('logro-100'));
      expect(result.newAchievementDetails.length, 1);
      expect(result.newAchievementDetails.first['title'], 'Coleccionista I');
    });
  });

  group('ReviewRepository DATA-02 (Protección de posts agrupados)', () {
    test(
      'deleteReview preserva imágenes de comentarios en un post agrupado y borra las de posts implícitos/directos',
      () async {
        final db = _InMemorySupabaseDb(
          currentUserId: 'u1',
          reviews: [
            {
              'id': 'rev-1',
              'user_id': 'u1',
              'game_id': 1,
              'image_urls': ['https://cdn.example/rev1.jpg'],
            },
            {
              'id': 'rev-2',
              'user_id': 'u1',
              'game_id': 2,
              'image_urls': ['https://cdn.example/rev2.jpg'],
            },
          ],
          userGames: [
            {'user_id': 'u1', 'game_id': 1},
            {'user_id': 'u1', 'game_id': 2},
          ],
          activityFeed: [
            {
              'id': 'af-1',
              'post_id': 'post-group',
              'user_id': 'u1',
              'game_id': 1,
              'review_id': 'rev-1',
              'action_type': 'reviewed',
            },
            {
              'id': 'af-2',
              'post_id': 'post-group',
              'user_id': 'u1',
              'game_id': 2,
              'review_id': 'rev-2',
              'action_type': 'reviewed',
            },
          ],
          feedPosts: [
            {'id': 'post-group', 'review_id': null},
            {'id': 'post-implicit-1', 'review_id': 'rev-1'},
          ],
          reviewComments: [
            {
              'id': 'c-group',
              'post_id': 'post-group',
              'review_id': null,
              'image_url': 'https://cdn.example/group-comment.jpg',
            },
            {
              'id': 'c-implicit',
              'post_id': 'post-implicit-1',
              'review_id': null,
              'image_url': 'https://cdn.example/implicit-comment.jpg',
            },
            {
              'id': 'c-direct',
              'post_id': null,
              'review_id': 'rev-1',
              'image_url': 'https://cdn.example/direct-comment.jpg',
            },
          ],
        );
        final deletedUrls = <String>[];
        final repo = ReviewRepository(
          client: db.client,
          deleteImagesFromUrls: (urls) async => deletedUrls.addAll(urls),
        );

        final removedFromLibrary = await repo.deleteReview(
          reviewId: 'rev-1',
          reviewData: const Review(
            id: 'rev-1',
            userId: 'u1',
            gameId: 1,
            status: GameStatus.completed,
            imageUrls: ['https://cdn.example/rev1.jpg'],
          ),
          gameId: 1,
        );

        expect(removedFromLibrary, isTrue);
        expect(
          deletedUrls,
          unorderedEquals([
            'https://cdn.example/rev1.jpg',
            'https://cdn.example/implicit-comment.jpg',
            'https://cdn.example/direct-comment.jpg',
          ]),
        );
        expect(
          deletedUrls,
          isNot(contains('https://cdn.example/group-comment.jpg')),
        );
        expect(db.tables['review_comments']!.length, 1);
        expect(db.tables['review_comments']!.first['id'], 'c-group');
      },
    );

    test(
      'deleteReview limpia imágenes de comentarios cuando el post es individual',
      () async {
        final db = _InMemorySupabaseDb(
          currentUserId: 'u1',
          reviews: [
            {
              'id': 'rev-1',
              'user_id': 'u1',
              'game_id': 1,
              'image_urls': ['https://cdn.example/rev1.jpg'],
            },
          ],
          userGames: [
            {'user_id': 'u1', 'game_id': 1},
          ],
          activityFeed: [
            {
              'id': 'af-1',
              'post_id': 'post-indiv',
              'user_id': 'u1',
              'game_id': 1,
              'review_id': 'rev-1',
              'action_type': 'reviewed',
            },
            {
              'id': 'af-status',
              'post_id': 'post-indiv',
              'user_id': 'u1',
              'game_id': 1,
              'review_id': null,
              'action_type': 'status_change',
            },
          ],
          feedPosts: [
            {'id': 'post-indiv', 'review_id': null},
          ],
          reviewComments: [
            {
              'id': 'c-indiv',
              'post_id': 'post-indiv',
              'review_id': null,
              'image_url': 'https://cdn.example/indiv-comment.jpg',
            },
          ],
        );
        final deletedUrls = <String>[];
        final repo = ReviewRepository(
          client: db.client,
          deleteImagesFromUrls: (urls) async => deletedUrls.addAll(urls),
        );

        final removedFromLibrary = await repo.deleteReview(
          reviewId: 'rev-1',
          reviewData: const Review(
            id: 'rev-1',
            userId: 'u1',
            gameId: 1,
            status: GameStatus.completed,
            imageUrls: ['https://cdn.example/rev1.jpg'],
          ),
          gameId: 1,
        );

        expect(removedFromLibrary, isTrue);
        expect(
          deletedUrls,
          unorderedEquals([
            'https://cdn.example/rev1.jpg',
            'https://cdn.example/indiv-comment.jpg',
          ]),
        );
        expect(db.tables['reviews'], isEmpty);
        expect(db.tables['user_games'], isEmpty);
      },
    );

    test(
      'deleteReview preserva imágenes de status_change en el mismo post_id si queda otra reseña del juego',
      () async {
        final db = _InMemorySupabaseDb(
          currentUserId: 'u1',
          reviews: [
            {
              'id': 'rev-1',
              'user_id': 'u1',
              'game_id': 1,
              'image_urls': ['https://cdn.example/rev1.jpg'],
            },
            {
              'id': 'rev-other',
              'user_id': 'u1',
              'game_id': 1,
              'image_urls': <String>[],
            },
          ],
          userGames: [
            {'user_id': 'u1', 'game_id': 1},
          ],
          activityFeed: [
            {
              'id': 'af-1',
              'post_id': 'post-game-1',
              'user_id': 'u1',
              'game_id': 1,
              'review_id': 'rev-1',
              'action_type': 'reviewed',
            },
            {
              'id': 'af-status',
              'post_id': 'post-game-1',
              'user_id': 'u1',
              'game_id': 1,
              'review_id': null,
              'action_type': 'status_change',
            },
          ],
          feedPosts: [
            {'id': 'post-game-1', 'review_id': null},
          ],
          reviewComments: [
            {
              'id': 'c-status',
              'post_id': 'post-game-1',
              'review_id': null,
              'image_url': 'https://cdn.example/status-comment.jpg',
            },
          ],
        );
        final deletedUrls = <String>[];
        final repo = ReviewRepository(
          client: db.client,
          deleteImagesFromUrls: (urls) async => deletedUrls.addAll(urls),
        );

        final removedFromLibrary = await repo.deleteReview(
          reviewId: 'rev-1',
          reviewData: const Review(
            id: 'rev-1',
            userId: 'u1',
            gameId: 1,
            status: GameStatus.completed,
            imageUrls: ['https://cdn.example/rev1.jpg'],
          ),
          gameId: 1,
        );

        expect(removedFromLibrary, isFalse);
        expect(deletedUrls, ['https://cdn.example/rev1.jpg']);
        expect(db.tables['user_games']!.length, 1);
      },
    );

    test(
      'deleteFromLibrary preserva imágenes del post grupal al borrar un juego del grupo',
      () async {
        final db = _InMemorySupabaseDb(
          currentUserId: 'u1',
          reviews: [
            {
              'id': 'rev-1',
              'user_id': 'u1',
              'game_id': 1,
              'image_urls': ['https://cdn.example/rev1.jpg'],
            },
            {
              'id': 'rev-2',
              'user_id': 'u1',
              'game_id': 2,
              'image_urls': ['https://cdn.example/rev2.jpg'],
            },
          ],
          userGames: [
            {'user_id': 'u1', 'game_id': 1},
            {'user_id': 'u1', 'game_id': 2},
          ],
          activityFeed: [
            {
              'id': 'af-1',
              'post_id': 'post-group',
              'user_id': 'u1',
              'game_id': 1,
              'review_id': 'rev-1',
              'action_type': 'reviewed',
            },
            {
              'id': 'af-2',
              'post_id': 'post-group',
              'user_id': 'u1',
              'game_id': 2,
              'review_id': 'rev-2',
              'action_type': 'reviewed',
            },
          ],
          feedPosts: [
            {'id': 'post-group', 'review_id': null},
          ],
          reviewComments: [
            {
              'id': 'c-group',
              'post_id': 'post-group',
              'review_id': null,
              'image_url': 'https://cdn.example/group-comment.jpg',
            },
          ],
        );
        final deletedUrls = <String>[];
        final repo = ReviewRepository(
          client: db.client,
          deleteImagesFromUrls: (urls) async => deletedUrls.addAll(urls),
        );

        await repo.deleteFromLibrary(userId: 'u1', gameId: 1);

        expect(deletedUrls, ['https://cdn.example/rev1.jpg']);
        expect(
          deletedUrls,
          isNot(contains('https://cdn.example/group-comment.jpg')),
        );
        expect(db.tables['user_games']!.length, 1);
        expect(db.tables['review_comments']!.length, 1);
      },
    );

    test(
      'deleteFromLibrary limpia imágenes de comentarios de un post individual antes de que los triggers en cascada borren feed_posts',
      () async {
        final db = _InMemorySupabaseDb(
          currentUserId: 'u1',
          reviews: [
            {
              'id': 'rev-1',
              'user_id': 'u1',
              'game_id': 1,
              'image_urls': ['https://cdn.example/rev1.jpg'],
            },
          ],
          userGames: [
            {'user_id': 'u1', 'game_id': 1},
          ],
          activityFeed: [
            {
              'id': 'af-1',
              'post_id': 'post-indiv',
              'user_id': 'u1',
              'game_id': 1,
              'review_id': 'rev-1',
              'action_type': 'reviewed',
            },
            {
              'id': 'af-status',
              'post_id': 'post-status',
              'user_id': 'u1',
              'game_id': 1,
              'review_id': null,
              'action_type': 'status_change',
            },
          ],
          feedPosts: [
            {'id': 'post-indiv', 'review_id': null},
            {'id': 'post-status', 'review_id': null},
          ],
          reviewComments: [
            {
              'id': 'c-indiv',
              'post_id': 'post-indiv',
              'review_id': null,
              'image_url': 'https://cdn.example/indiv-comment.jpg',
            },
            {
              'id': 'c-status',
              'post_id': 'post-status',
              'review_id': null,
              'image_url': 'https://cdn.example/status-comment.jpg',
            },
          ],
        );
        final deletedUrls = <String>[];
        final repo = ReviewRepository(
          client: db.client,
          deleteImagesFromUrls: (urls) async => deletedUrls.addAll(urls),
        );

        await repo.deleteFromLibrary(userId: 'u1', gameId: 1);

        expect(
          deletedUrls,
          unorderedEquals([
            'https://cdn.example/rev1.jpg',
            'https://cdn.example/indiv-comment.jpg',
            'https://cdn.example/status-comment.jpg',
          ]),
        );
        expect(db.tables['reviews'], isEmpty);
        expect(db.tables['user_games'], isEmpty);
        expect(db.tables['review_comments'], isEmpty);
      },
    );
  });
}

typedef _RowPredicate = bool Function(Map<String, dynamic> row);

class _InMemorySupabaseDb {
  _InMemorySupabaseDb({
    required this.currentUserId,
    List<Map<String, dynamic>> reviews = const [],
    List<Map<String, dynamic>> userGames = const [],
    List<Map<String, dynamic>> activityFeed = const [],
    List<Map<String, dynamic>> feedPosts = const [],
    List<Map<String, dynamic>> reviewComments = const [],
  }) : tables = {
         'reviews': reviews.map((e) => Map<String, dynamic>.from(e)).toList(),
         'user_games': userGames
             .map((e) => Map<String, dynamic>.from(e))
             .toList(),
         'activity_feed': activityFeed
             .map((e) => Map<String, dynamic>.from(e))
             .toList(),
         'feed_posts': feedPosts
             .map((e) => Map<String, dynamic>.from(e))
             .toList(),
         'review_comments': reviewComments
             .map((e) => Map<String, dynamic>.from(e))
             .toList(),
       } {
    final user = _MockUser();
    when(() => user.id).thenReturn(currentUserId);
    final auth = _MockGoTrueClient();
    when(() => auth.currentUser).thenReturn(user);
    client = _FakeSupabaseClient(this, auth);
  }

  final String currentUserId;
  final Map<String, List<Map<String, dynamic>>> tables;
  late final SupabaseClient client;

  void deleteRows(String table, List<_RowPredicate> filters) {
    final rows = tables[table] ?? [];
    final removed = <Map<String, dynamic>>[];
    rows.removeWhere((row) {
      final matches = filters.every((f) => f(row));
      if (matches) removed.add(row);
      return matches;
    });

    if (removed.isEmpty) return;

    if (table == 'reviews') {
      final deletedIds = removed.map((r) => r['id']?.toString()).toSet();
      tables['activity_feed']!.removeWhere(
        (af) =>
            af['action_type'] == 'reviewed' &&
            deletedIds.contains(af['review_id']?.toString()),
      );
      for (final af in tables['activity_feed']!) {
        if (deletedIds.contains(af['review_id']?.toString())) {
          af['review_id'] = null;
        }
      }
      tables['feed_posts']!.removeWhere(
        (fp) => deletedIds.contains(fp['review_id']?.toString()),
      );
      tables['review_comments']!.removeWhere(
        (c) => deletedIds.contains(c['review_id']?.toString()),
      );
      _pruneFeedPosts();
    } else if (table == 'user_games') {
      final pairs = removed
          .map((ug) => '${ug['user_id']}:${ug['game_id']}')
          .toSet();
      tables['activity_feed']!.removeWhere(
        (af) =>
            af['action_type'] == 'status_change' &&
            pairs.contains('${af['user_id']}:${af['game_id']}'),
      );
      _pruneFeedPosts();
    }
  }

  void _pruneFeedPosts() {
    final activePostIds = tables['activity_feed']!
        .map((af) => af['post_id']?.toString())
        .whereType<String>()
        .toSet();
    tables['feed_posts']!.removeWhere(
      (fp) =>
          fp['review_id'] == null &&
          !activePostIds.contains(fp['id']?.toString()),
    );
    final remainingPostIds = tables['feed_posts']!
        .map((fp) => fp['id']?.toString())
        .whereType<String>()
        .toSet();
    tables['review_comments']!.removeWhere(
      (c) =>
          c['post_id'] != null &&
          !remainingPostIds.contains(c['post_id']?.toString()),
    );
  }
}

class _MockUser extends Mock implements User {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _FakeSupabaseClient extends Fake implements SupabaseClient {
  _FakeSupabaseClient(this._db, this._auth);

  final _InMemorySupabaseDb _db;
  final GoTrueClient _auth;

  @override
  GoTrueClient get auth => _auth;

  @override
  SupabaseQueryBuilder from(String table) =>
      _FakeSupabaseQueryBuilder(_db, table);
}

class _FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  _FakeSupabaseQueryBuilder(this._db, this._table);

  final _InMemorySupabaseDb _db;
  final String _table;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    return _FakeFilterBuilder<PostgrestList>((filters) async {
      final rows = _db.tables[_table] ?? const [];
      return rows
          .where((row) => filters.every((f) => f(row)))
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    });
  }

  @override
  PostgrestFilterBuilder<dynamic> delete() {
    return _FakeFilterBuilder<dynamic>((filters) async {
      _db.deleteRows(_table, filters);
      return const <Map<String, dynamic>>[];
    });
  }
}

class _FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  _FakeFilterBuilder(this._execute, {List<_RowPredicate>? filters})
    : _filters = filters ?? const [];

  final Future<T> Function(List<_RowPredicate> filters) _execute;
  final List<_RowPredicate> _filters;

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) {
    return _FakeFilterBuilder<T>(
      _execute,
      filters: [
        ..._filters,
        (row) => row[column]?.toString() == value.toString(),
      ],
    );
  }

  @override
  PostgrestFilterBuilder<T> inFilter(String column, List<dynamic> values) {
    final valueSet = values.map((v) => v?.toString()).toSet();
    return _FakeFilterBuilder<T>(
      _execute,
      filters: [
        ..._filters,
        (row) => valueSet.contains(row[column]?.toString()),
      ],
    );
  }

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() {
    return _FakeTransformBuilder<PostgrestMap?>(() async {
      final result = await _execute(_filters);
      if (result is List && result.isNotEmpty) {
        return Map<String, dynamic>.from(result.first as Map);
      }
      return null;
    });
  }

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) => _execute(_filters).then(onValue, onError: onError);

  @override
  Future<T> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) => _execute(_filters).catchError(onError, test: test);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      _execute(_filters).whenComplete(action);

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      _execute(_filters).timeout(timeLimit, onTimeout: onTimeout);

  @override
  Stream<T> asStream() => _execute(_filters).asStream();
}

class _FakeTransformBuilder<T> extends Fake
    implements PostgrestTransformBuilder<T> {
  _FakeTransformBuilder(this._execute);

  final Future<T> Function() _execute;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) => _execute().then(onValue, onError: onError);

  @override
  Future<T> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) => _execute().catchError(onError, test: test);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      _execute().whenComplete(action);

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      _execute().timeout(timeLimit, onTimeout: onTimeout);

  @override
  Stream<T> asStream() => _execute().asStream();
}

import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/models/game_filters.dart';
import 'package:corpus/models/game_group.dart';
import 'package:corpus/models/game_group_item.dart';
import 'package:corpus/models/game_status.dart';
import 'package:corpus/models/genre_radar_entry.dart';
import 'package:corpus/models/genre_time_stat.dart';
import 'package:corpus/models/post_stats.dart';

void main() {
  group('GameGroup decodeRankedDescription y blindaje (BUG-158, ARQ-12)', () {
    test('decodeRankedDescription recorta espacios de forma consistente', () {
      expect(GameGroup.decodeRankedDescription(null), (
        description: null,
        isRanked: false,
      ));
      expect(GameGroup.decodeRankedDescription('   '), (
        description: null,
        isRanked: false,
      ));
      expect(GameGroup.decodeRankedDescription('  Sin marcador  '), (
        description: 'Sin marcador',
        isRanked: false,
      ));
      expect(
        GameGroup.decodeRankedDescription('${GameGroup.rankedMarker}\n  Top 10  '),
        (description: 'Top 10', isRanked: true),
      );
      expect(GameGroup.decodeRankedDescription(GameGroup.rankedMarker), (
        description: null,
        isRanked: true,
      ));
    });

    test('encodeRankedDescription round-trip preserva descripción limpia', () {
      final encoded = GameGroup.encodeRankedDescription('  Favoritos  ', true);
      expect(encoded, '${GameGroup.rankedMarker}\nFavoritos');
      expect(GameGroup.decodeRankedDescription(encoded), (
        description: 'Favoritos',
        isRanked: true,
      ));
      expect(GameGroup.encodeRankedDescription('   ', true), GameGroup.rankedMarker);
      expect(GameGroup.encodeRankedDescription('   ', false), isNull);
    });

    test('fromMap tolera nulos, Map<dynamic, dynamic> y expone lista inmodificable', () {
      final group = GameGroup.fromMap(const <String, dynamic>{
        'id': null,
        'user_id': null,
        'name': 'RPGs',
        'cover_game_id': 42.0,
        'sort_order': 2.0,
        'game_count': 1.0,
        'game_group_items': <dynamic>[
          <dynamic, dynamic>{
            'id': 'item-1',
            'group_id': 'g-1',
            'game_id': 42.0,
            'sort_order': 1.0,
            'library_status': 'onHold',
            'games': <dynamic, dynamic>{'igdb_id': 42, 'title': 'Chrono Trigger'},
          },
        ],
      });

      expect(group.id, '');
      expect(group.coverGameId, 42);
      expect(group.items.single.libraryStatus, GameStatus.onHold);
      expect(group.items.single.game?.title, 'Chrono Trigger');
      expect(
        () => group.items.add(
          const GameGroupItem(id: 'x', groupId: 'g', gameId: 1),
        ),
        throwsUnsupportedError,
      );
    });

    test('copyWith permite limpiar nulos e igualdad compara items por valor', () {
      final a = GameGroup.fromMap(const {
        'id': 'g1',
        'user_id': 'u1',
        'name': 'Lista',
        'description': 'Desc',
        'cover_game_id': 10,
      });
      final cleared = a.copyWith(description: null, coverGameId: null);
      expect(cleared.description, isNull);
      expect(cleared.coverGameId, isNull);

      final b = GameGroup.fromMap(const {
        'id': 'g1',
        'user_id': 'u1',
        'name': 'Lista',
        'description': 'Desc',
        'cover_game_id': 10,
      });
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('GameGroupItem, GameFilters, PostStats y Radar immutability', () {
    test('GameGroupItem.copyWith limpia nulos explícitamente', () {
      const item = GameGroupItem(
        id: '1',
        groupId: 'g1',
        gameId: 100,
        note: 'Joya',
        libraryStatus: GameStatus.beaten,
      );
      final updated = item.copyWith(note: null, libraryStatus: null);
      expect(updated.note, isNull);
      expect(updated.libraryStatus, isNull);
    });

    test('GameFilters mantiene listas inmodificables e igualdad por valor', () {
      const base = GameFilters();
      final f1 = base.copyWith(genres: const [1, 2], platforms: const [6]);
      final f2 = base.copyWith(genres: const [1, 2], platforms: const [6]);

      expect(f1, equals(f2));
      expect(f1.hashCode, f2.hashCode);
      expect(f1.hasFilters, isTrue);
      expect(f1.filterCount, 3);
      expect(() => f1.genres.add(3), throwsUnsupportedError);
    });

    test('PostStats soporta fromDynamic e igualdad por valor', () {
      final stats = PostStats.fromDynamic(<dynamic, dynamic>{
        'post_id': 'p-1',
        'likes_count': 4.0,
        'comments_count': 2.0,
        'liked_by_me': true,
      });
      expect(stats, const PostStats(
        postId: 'p-1',
        likesCount: 4,
        commentsCount: 2,
        likedByMe: true,
      ));
      expect(
        PostStats.fromDynamic('invalid', fallbackPostId: 'p-2'),
        const PostStats(postId: 'p-2'),
      );
    });

    test('GenreRadarEntry y GenreTimeStat comparan listas por valor', () {
      final date = DateTime.utc(2025, 1, 1);
      final e1 = GenreRadarEntry(
        gameId: 1,
        gameTitle: 'Hades',
        genres: const ['Action', 'Indie'],
        hours: 20,
        effectiveDate: date,
      );
      final e2 = GenreRadarEntry(
        gameId: 1,
        gameTitle: 'Hades',
        genres: const ['Action', 'Indie'],
        hours: 20,
        effectiveDate: date,
      );
      expect(e1, equals(e2));
      expect(e1.hashCode, e2.hashCode);

      final s1 = GenreTimeStat(
        genre: 'Action',
        totalHours: 20,
        gameCount: 1,
        games: [e1],
      );
      final s2 = GenreTimeStat(
        genre: 'Action',
        totalHours: 20,
        gameCount: 1,
        games: [e2],
      );
      expect(s1, equals(s2));
      expect(s1.hashCode, s2.hashCode);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:corpus/repositories/notifications_repository.dart';
import 'package:corpus/screens/social/notifications_feed_screen.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:corpus/widgets/corpus_network_image.dart';

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

Map<String, dynamic> _fakeNotification(
  String id, {
  String? coverUrl,
  String? avatarUrl,
}) {
  return {
    'id': id,
    'type': 'like',
    'read_at': null,
    'created_at': DateTime.now().toUtc().toIso8601String(),
    'review_id': 'rev-$id',
    'metadata': {
      'game_title': 'Game $id',
      'game_cover_url': ?coverUrl,
    },
    'users': {
      'id': 'actor-$id',
      'username': 'user_$id',
      'display_name': 'User $id',
      'avatar_url': avatarUrl,
    },
  };
}

void main() {
  late MockNotificationsRepository mockRepo;

  setUp(() {
    mockRepo = MockNotificationsRepository();
    when(() => mockRepo.isGuest).thenReturn(false);
    when(() => mockRepo.markAllRead()).thenAnswer((_) async {});
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ThemeData(extensions: const [CorpusThemeExtension()]),
      home: child,
    );
  }

  group('NotificationsFeedScreen (UI1-10)', () {
    testWidgets(
      'recovers from first-page error with retry button instead of infinite spinner',
      (tester) async {
        var calls = 0;
        when(() => mockRepo.fetchNotificationsPage(0)).thenAnswer((_) async {
          calls++;
          if (calls == 1) {
            throw Exception('Network timeout');
          }
          return NotificationsPageResult(
            notifications: [_fakeNotification('1')],
            hasMore: false,
            nextOffset: 1,
          );
        });

        await tester.pumpWidget(
          wrap(NotificationsFeedScreen(repository: mockRepo)),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.text('No se pudieron cargar las notificaciones.'),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsOneWidget);

        await tester.tap(find.text('Reintentar'));
        await tester.pump();
        await tester.pump();

        expect(
          find.text('User 1 le dio like a tu reseña de Game 1'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'deduplicates paginated items, validates empty coverUrl, and handles loadMore error',
      (tester) async {
        // Generate enough items so scrolling down triggers loadMore
        final page1 = List.generate(
          20,
          (i) => _fakeNotification(
            'n$i',
            coverUrl: i == 0 ? '' : null,
            avatarUrl: '',
          ),
        );
        when(() => mockRepo.fetchNotificationsPage(0)).thenAnswer(
          (_) async => NotificationsPageResult(
            notifications: page1,
            hasMore: true,
            nextOffset: 20,
          ),
        );

        var page2Calls = 0;
        when(() => mockRepo.fetchNotificationsPage(20)).thenAnswer((_) async {
          page2Calls++;
          if (page2Calls == 1) {
            throw Exception('Flaky 3G');
          }
          return NotificationsPageResult(
            notifications: [
              // Duplicate from page 1 should be skipped
              _fakeNotification('n19'),
              _fakeNotification('n20'),
            ],
            hasMore: false,
            nextOffset: 22,
          );
        });

        await tester.pumpWidget(
          wrap(NotificationsFeedScreen(repository: mockRepo)),
        );
        await tester.pump();
        await tester.pump();

        // Empty coverUrl should not render CorpusNetworkImage
        expect(find.byType(CorpusNetworkImage), findsNothing);

        // Scroll to trigger loadMore
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pump();
        await tester.pump();

        expect(find.text('Reintentar'), findsOneWidget);
        expect(
          find.text('No se pudieron cargar más notificaciones.'),
          findsOneWidget,
        );

        // Scroll to bottom and tap Retry on footer
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pump();
        await tester.tap(find.text('Reintentar'));
        await tester.pump();
        await tester.pump();

        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pump();

        // n19 appears only once, n20 appears once
        expect(
          find.text('User n19 le dio like a tu reseña de Game n19'),
          findsOneWidget,
        );
        expect(
          find.text('User n20 le dio like a tu reseña de Game n20'),
          findsOneWidget,
        );
      },
    );
  });
}

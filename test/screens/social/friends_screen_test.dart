import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:corpus/repositories/social_repository.dart';
import 'package:corpus/screens/social/friends_screen.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';

class MockSocialRepository extends Mock implements SocialRepository {}

void main() {
  late MockSocialRepository mockRepo;

  setUp(() {
    mockRepo = MockSocialRepository();
    when(() => mockRepo.currentUserId).thenReturn('me');
    when(() => mockRepo.fetchReceivedRequests()).thenAnswer((_) async => []);
    when(() => mockRepo.fetchSentRequests()).thenAnswer((_) async => []);
    when(() => mockRepo.fetchMyFriends()).thenAnswer((_) async => []);
    when(
      () => mockRepo.fetchSentOrAcceptedIds(),
    ).thenAnswer((_) async => <String>{});
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ThemeData(extensions: const [CorpusThemeExtension()]),
      home: child,
    );
  }

  group('FriendsScreen search (UI1-10)', () {
    testWidgets(
      'debounces rapid typing by 300ms and uses corpusInputPrefixIcon',
      (tester) async {
        when(() => mockRepo.searchUsers('abc')).thenAnswer(
          (_) async => [
            {
              'id': 'u-abc',
              'username': 'abc_gamer',
              'display_name': 'ABC Gamer',
              'avatar_url': null,
            },
          ],
        );

        await tester.pumpWidget(
          wrap(FriendsScreen(initialIndex: 0, repository: mockRepo)),
        );
        await tester.pump();

        // Verify corpusInputPrefixIcon wraps CorpusTablerIcon(Search, size: 20)
        final textField = tester.widget<TextField>(find.byType(TextField));
        final prefix = textField.decoration?.prefixIcon;
        expect(prefix, isA<Padding>());
        final paddingWidget = prefix! as Padding;
        expect(paddingWidget.child, isA<CorpusTablerIcon>());
        final icon = paddingWidget.child! as CorpusTablerIcon;
        expect(icon.kind, CorpusIconKind.Search);
        expect(icon.size, 20);

        await tester.enterText(find.byType(TextField), 'a');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.enterText(find.byType(TextField), 'ab');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.enterText(find.byType(TextField), 'abc');
        await tester.pump(const Duration(milliseconds: 200));

        // Still before 300ms after last keystroke
        verifyNever(() => mockRepo.searchUsers(any()));

        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump();

        verify(() => mockRepo.searchUsers('abc')).called(1);
        verifyNever(() => mockRepo.searchUsers('a'));
        verifyNever(() => mockRepo.searchUsers('ab'));
        expect(find.text('ABC Gamer'), findsOneWidget);
      },
    );

    testWidgets(
      'ignores stale in-flight search responses when query changes',
      (tester) async {
        final slowOldCompleter = Completer<List<Map<String, dynamic>>>();

        when(
          () => mockRepo.searchUsers('old'),
        ).thenAnswer((_) => slowOldCompleter.future);
        when(() => mockRepo.searchUsers('new')).thenAnswer(
          (_) async => [
            {
              'id': 'u-new',
              'username': 'new_user',
              'display_name': 'New User',
              'avatar_url': null,
            },
          ],
        );

        await tester.pumpWidget(
          wrap(FriendsScreen(initialIndex: 0, repository: mockRepo)),
        );
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'old');
        await tester.pump(const Duration(milliseconds: 350));

        // First query is now in flight; user types a newer query
        await tester.enterText(find.byType(TextField), 'new');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();

        expect(find.text('New User'), findsOneWidget);

        // Resolve stale query AFTER newer query already rendered
        slowOldCompleter.complete([
          {
            'id': 'u-old',
            'username': 'old_user',
            'display_name': 'Old User',
            'avatar_url': null,
          },
        ]);
        await tester.pump();

        expect(find.text('New User'), findsOneWidget);
        expect(find.text('Old User'), findsNothing);
      },
    );

    testWidgets('cancels pending debounce timer cleanly on dispose', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(FriendsScreen(initialIndex: 0, repository: mockRepo)),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'pending');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      await tester.pump(const Duration(milliseconds: 400));

      verifyNever(() => mockRepo.searchUsers(any()));
    });
  });
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/widgets/game_card.dart';
import 'package:corpus/models/models.dart';

void main() {
  group('GameCard Widget Tests', () {
    testWidgets(
      'Muestra título al hacer hover, nota y carátula cuando tiene datos completos',
      (WidgetTester tester) async {
        final gameMock = {
          'id': 1,
          'title': 'Elden Ring',
          'cover_url':
              'https://images.igdb.com/igdb/image/upload/t_cover_big/co4j8m.jpg',
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GameCard(
                game: Game.fromMap(gameMock),
                isInLibrary: true,
                userRating: 9.5,
                onReturn: () {},
              ),
            ),
          ),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(tester.getCenter(find.byType(GameCard)));
        await tester.pumpAndSettle();

        expect(find.text('Elden Ring'), findsWidgets);
        expect(find.text('9.5'), findsOneWidget);
      },
    );

    testWidgets(
      'No muestra nota si el juego no está valorado (userRating = 0)',
      (WidgetTester tester) async {
        final gameMock = {'id': 2, 'title': 'Hollow Knight'};

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GameCard(
                game: Game.fromMap(gameMock),
                isInLibrary: false,
                userRating: 0.0,
                onReturn: () {},
              ),
            ),
          ),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(tester.getCenter(find.byType(GameCard)));
        await tester.pumpAndSettle();

        expect(find.text('Hollow Knight'), findsWidgets);
        expect(find.text('0.0'), findsNothing);
      },
    );

    testWidgets(
      'Muestra un icono genérico (Icons.videogame_asset) cuando la URL de la carátula es nula o vacía',
      (WidgetTester tester) async {
        final gameMock = {'id': 3, 'title': 'Juego Sin Carátula', 'cover_url': ''};

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GameCard(
                game: Game.fromMap(gameMock),
                isInLibrary: true,
                userRating: 0.0,
                onReturn: () {},
              ),
            ),
          ),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(tester.getCenter(find.byType(GameCard)));
        await tester.pumpAndSettle();

        expect(find.text('Juego Sin Carátula'), findsWidgets);
        expect(find.byIcon(Icons.videogame_asset), findsOneWidget);
      },
    );
  });
}

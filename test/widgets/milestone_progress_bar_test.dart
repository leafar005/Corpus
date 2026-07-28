import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/widgets/milestone_progress_bar.dart';

void main() {
  group('MilestoneProgressBar Unit & Widget Tests', () {
    test(
      'getSegmentColor devuelve colores correctos para Bronce, Plata y Oro',
      () {
        const fallback = Colors.blue;
        final bronze = MilestoneProgressBar.getSegmentColor(0, 3, fallback);
        final silver = MilestoneProgressBar.getSegmentColor(1, 3, fallback);
        final gold = MilestoneProgressBar.getSegmentColor(2, 3, fallback);

        expect(bronze, const Color(0xFFCD7F32));
        expect(silver, const Color(0xFFC0C0C0));
        expect(gold, const Color(0xFFFFD700));
      },
    );

    test(
      'getSegmentColor salta Plata y usa Oro como segundo nivel cuando solo hay 2 hitos',
      () {
        const fallback = Colors.blue;
        final first = MilestoneProgressBar.getSegmentColor(0, 2, fallback);
        final second = MilestoneProgressBar.getSegmentColor(1, 2, fallback);

        expect(first, const Color(0xFFCD7F32)); // Bronce
        expect(second, const Color(0xFFFFD700)); // Oro
      },
    );

    testWidgets('Muestra textos de progreso con cantidad de juegos y XP', (
      WidgetTester tester,
    ) async {
      final milestonesMock = [
        {'target': 5, 'xp': 100},
        {'target': 15, 'xp': 300},
        {'target': 30, 'xp': 1000},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MilestoneProgressBar(
              current: 10,
              milestones: milestonesMock,
              color: Colors.deepPurple,
              backgroundColor: Colors.grey,
            ),
          ),
        ),
      );

      expect(find.text('5 🎮 • 100 XP'), findsOneWidget);
      expect(find.text('15 🎮 • 300 XP'), findsOneWidget);
      expect(find.text('30 🎮 • 1000 XP'), findsOneWidget);
    });

    testWidgets(
      'No renderiza nada (SizedBox.shrink) si la lista de hitos está vacía',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MilestoneProgressBar(
                current: 5,
                milestones: [],
                color: Colors.deepPurple,
                backgroundColor: Colors.grey,
              ),
            ),
          ),
        );

        expect(find.byType(MilestoneProgressBar), findsOneWidget);
        expect(find.textContaining('🎮'), findsNothing);
      },
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/screens/activity/activity_story_viewer.dart';
import 'package:corpus/screens/home/hero_showcase.dart';
import 'package:corpus/screens/profile/profile_controller.dart';
import 'package:corpus/screens/profile/widgets/profile_hall_of_fame.dart';
import 'package:corpus/screens/settings/integrations_screen.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:corpus/theme/style_pack.dart';
import 'package:corpus/widgets/achievement_toast.dart';
import 'package:corpus/widgets/paginated_scroll_mixin.dart';

class _FakeProfileController extends Fake implements ProfileController {}

class _PaginatedTestWidget extends StatefulWidget {
  const _PaginatedTestWidget({this.externalController});

  final ScrollController? externalController;

  @override
  State<_PaginatedTestWidget> createState() => _PaginatedTestWidgetState();
}

class _PaginatedTestWidgetState extends State<_PaginatedTestWidget>
    with PaginatedScrollMixin<_PaginatedTestWidget> {
  int loadMoreCalls = 0;

  @override
  void initState() {
    super.initState();
    initPagination(externalController: widget.externalController);
  }

  @override
  void dispose() {
    disposePagination();
    super.dispose();
  }

  @override
  Future<void> loadMore() async {
    loadMoreCalls++;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      itemCount: 30,
      itemBuilder: (_, index) => SizedBox(height: 60, child: Text('Item $index')),
    );
  }
}

void main() {
  setUp(() {
    kDisableCarouselForTests = true;
  });

  tearDown(() {
    kDisableCarouselForTests = false;
  });

  testWidgets(
    'CorpusThemeExtension.of devuelve fallback de StylePack.defaultPack sin extensión registrada (BUG-97)',
    (tester) async {
      late CorpusThemeExtension captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              captured = CorpusThemeExtension.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final expected = CorpusThemeExtension.fromPack(StylePack.defaultPack());
      expect(captured.heroFontWeight, expected.heroFontWeight);
      expect(captured.borderRadiusMedium, expected.borderRadiusMedium);
      expect(captured.navBarStyle, expected.navBarStyle);
    },
  );

  testWidgets(
    'ProfileHallOfFame tolera menos de 5 elementos sin RangeError (BUG-13)',
    (tester) async {
      final controller = _FakeProfileController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileHallOfFame(
              hallOfFame: const [],
              controller: controller,
            ),
          ),
        ),
      );
      expect(find.text('Hall of Fame'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileHallOfFame(
              hallOfFame: const [
                {'igdb_id': 1, 'title': 'Hades'},
              ],
              controller: controller,
            ),
          ),
        ),
      );
      expect(find.text('Hall of Fame'), findsOneWidget);
    },
  );

  testWidgets(
    'HeroShowcase actualiza sin RangeError al encoger o vaciar playingGames (BUG-14)',
    (tester) async {
      final initialGames = List.generate(
        4,
        (i) => {
          'id': i + 1,
          'title': 'Juego ${i + 1}',
          'screenshots_list': <String>[],
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: HeroShowcase(
                playingGames: initialGames,
                userName: 'Tester',
              ),
            ),
          ),
        ),
      );

      // Navega dos veces para mover _currentGameIndex más allá de 1
      await tester.tap(find.byType(HeroShowcase));
      await tester.pump();
      await tester.tap(find.byType(HeroShowcase));
      await tester.pump();

      // Reduce playingGames a 1 solo juego (distinto a Juego 1..3 -> dispara didUpdateWidget)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: HeroShowcase(
                playingGames: [
                  {
                    'id': 99,
                    'title': 'Nuevo Juego',
                    'screenshots_list': <String>[],
                  },
                ],
                userName: 'Tester',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Vacía por completo
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: HeroShowcase(playingGames: [], userName: 'Tester'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'ActivityStoryViewer cierra de forma segura si groups está vacío (BUG-07)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ActivityStoryViewer(
                        groups: [],
                        initialGroupIndex: 0,
                      ),
                    ),
                  );
                },
                child: const Text('Abrir historias'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir historias'));
      await tester.pumpAndSettle();

      expect(find.byType(ActivityStoryViewer), findsNothing);
      expect(find.text('Abrir historias'), findsOneWidget);
    },
  );

  testWidgets(
    'AchievementToast tolera sin Overlay, casts nulos y doble toque sin error (BUG-18)',
    (tester) async {
      // 1) Sin Overlay ancestor no debe lanzar
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              AchievementToast.show(context, title: 'Sin Overlay');
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // 2) showFromList con campos nulos / num double + doble tap idempotente
      late BuildContext rootContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                rootContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      AchievementToast.showFromList(
        rootContext,
        const [
          {'id': null, 'name': null, 'xp_reward': 50.0, 'rarity': null},
        ],
        isMounted: () => rootContext.mounted,
      );

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Logro desbloqueado'), findsWidgets);

      // Doble tap durante la animación de cierre no debe hacer doble OverlayEntry.remove()
      await tester.tap(find.text('Logro desbloqueado').first);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(
        find.text('Logro desbloqueado').first,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'PaginatedScrollMixin con externalController se desmonta sin fugas ni doble dispose (BUG-153)',
    (tester) async {
      final externalController = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _PaginatedTestWidget(externalController: externalController),
          ),
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      // El controlador externo sigue vivo y no fue dispuesto por el mixin
      expect(() => externalController.position, throwsAssertionError);
      externalController.dispose();
    },
  );

  testWidgets(
    'IntegrationsScreen en modo invitado no queda bloqueada cargando (BUG-16)',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: IntegrationsScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text(
          'Inicia sesión para vincular e integrar servicios externos.',
        ),
        findsOneWidget,
      );
    },
  );
}

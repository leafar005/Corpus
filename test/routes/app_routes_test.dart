import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/routes/app_navigation_controller.dart';
import 'package:corpus/routes/app_routes.dart';
import 'package:corpus/routes/app_root.dart';
import 'package:corpus/routes/tab_deep_route.dart';

void main() {
  group('AppRoutes.tabIndexFromPublicPath', () {
    test('resuelve rutas públicas de pestañas', () {
      expect(AppRoutes.tabIndexFromPublicPath('/'), 0);
      expect(AppRoutes.tabIndexFromPublicPath('/inicio'), 0);
      expect(AppRoutes.tabIndexFromPublicPath('/buscar'), 1);
      expect(AppRoutes.tabIndexFromPublicPath('/actividad'), 2);
      expect(AppRoutes.tabIndexFromPublicPath('/mis-juegos'), 3);
      expect(AppRoutes.tabIndexFromPublicPath('/bundles'), 1);
      expect(AppRoutes.tabIndexFromPublicPath('/perfil'), 4);
    });

    test('ignora rutas que no son pestañas', () {
      expect(AppRoutes.tabIndexFromPublicPath('/style/persona5'), null);
      expect(AppRoutes.tabIndexFromPublicPath('/game-details'), null);
      expect(AppRoutes.tabIndexFromPublicPath('/design'), null);
    });

    test('sigue resolviendo la pestaña aunque haya una sub-ruta', () {
      expect(AppRoutes.tabIndexFromPublicPath('/buscar/1942'), 1);
      expect(AppRoutes.tabIndexFromPublicPath('/actividad/resena/abc-123'), 2);
    });
  });

  group('AppRoutes.subSegmentsFromPublicPath', () {
    test('vacío cuando no hay sub-ruta', () {
      expect(AppRoutes.subSegmentsFromPublicPath('/buscar'), <String>[]);
      expect(AppRoutes.subSegmentsFromPublicPath('/'), <String>[]);
    });

    test('extrae los segmentos posteriores a la pestaña', () {
      expect(AppRoutes.subSegmentsFromPublicPath('/buscar/1942'), ['1942']);
      expect(AppRoutes.subSegmentsFromPublicPath('/actividad/usr-1/logros'), [
        'usr-1',
        'logros',
      ]);
    });
  });

  group('parseTabDeepRoute', () {
    test('un primer segmento numérico siempre es un juego', () {
      expect(parseTabDeepRoute(['1942']), const GameDeepRoute(1942));
    });

    test('resena/{id} es una reseña', () {
      expect(
        parseTabDeepRoute(['resena', 'r-1']),
        const ReviewDeepRoute('r-1'),
      );
    });

    test('logros son los propios (userId null)', () {
      expect(parseTabDeepRoute(['logros']), const AchievementsDeepRoute());
    });

    const sampleUuid = '3f2a0000-0000-4000-8000-000000000001';

    test('{id}/logros son los de otro usuario', () {
      expect(
        parseTabDeepRoute([sampleUuid, 'logros']),
        const AchievementsDeepRoute(userId: sampleUuid),
      );
    });

    test('un id UUID válido es un perfil', () {
      expect(
        parseTabDeepRoute([sampleUuid]),
        const ProfileDeepRoute(sampleUuid),
      );
    });

    test('un segmento desconocido que no es UUID devuelve null', () {
      expect(parseTabDeepRoute(['u-1']), isNull);
    });

    test('vacío no resuelve nada', () {
      expect(parseTabDeepRoute([]), null);
    });
  });

  group('publicPathForTabRoute', () {
    test('sin sub-ruta es solo la raíz de la pestaña', () {
      expect(publicPathForTabRoute(1), '/buscar');
    });

    test('compone pestaña + sub-ruta', () {
      expect(
        publicPathForTabRoute(1, const GameDeepRoute(1942)),
        '/buscar/1942',
      );
      expect(
        publicPathForTabRoute(2, const ReviewDeepRoute('r-1')),
        '/actividad/resena/r-1',
      );
      expect(
        publicPathForTabRoute(4, const AchievementsDeepRoute(userId: 'u-1')),
        '/perfil/u-1/logros',
      );
    });

    test(
      'ida y vuelta: parsear el resultado de construir da la misma ruta',
      () {
        const route = GameDeepRoute(1942);
        final path = publicPathForTabRoute(1, route);
        final segments = AppRoutes.subSegmentsFromPublicPath(path);
        expect(parseTabDeepRoute(segments), route);
      },
    );
  });

  group('isDesignPublicPath', () {
    test('resuelve la ruta del design system', () {
      expect(isDesignPublicPath('/design'), isTrue);
      expect(isDesignPublicPath('/design/'), isTrue);
      expect(isDesignPublicPath('/inicio'), isFalse);
    });
  });

  group('AppRoutes.publicPathForTab', () {
    test('genera paths públicos para cada pestaña', () {
      expect(AppRoutes.publicPathForTab(0), AppRoutes.publicHome);
      expect(AppRoutes.publicPathForTab(2), AppRoutes.publicActivity);
    });
  });

  group('AppNavigationController', () {
    void clearAllStacks() {
      final nav = AppNavigationController.instance;
      nav.resetForSessionChange();
      nav.truncateStack(
        AppNavigationController.rootStackIndex,
        keepFirst: false,
      );
    }

    tearDown(clearAllStacks);

    test(
      'resetForSessionChange limpia las pilas 0..4 y preserva rootStackIndex',
      () {
        clearAllStacks();
        final nav = AppNavigationController.instance;
        final rootRoute = MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/'),
          builder: (_) => const SizedBox(),
        );
        final tabRoute = MaterialPageRoute<void>(
          settings: const RouteSettings(name: AppRoutes.tabHome),
          builder: (_) => const SizedBox(),
        );

        nav.onNavigatorPush(AppNavigationController.rootStackIndex, rootRoute);
        nav.onNavigatorPush(0, tabRoute);
        nav.onNavigatorPush(1, tabRoute);

        nav.resetForSessionChange();

        for (var i = 0; i < 5; i++) {
          expect(nav.framesFor(i), isEmpty);
        }
        expect(
          nav.framesFor(AppNavigationController.rootStackIndex).length,
          1,
        );
      },
    );

    test(
      'onNavigatorPush en rootStackIndex con depth 0 no altera pilas de pestañas y onNavigatorPop desapila limpio',
      () {
        clearAllStacks();
        final nav = AppNavigationController.instance;
        final rootRoute = MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/'),
          builder: (_) => const SizedBox(),
        );
        final modalRoute = MaterialPageRoute<void>(
          settings: const RouteSettings(name: AppRoutes.settings),
          builder: (_) => const SizedBox(),
        );

        nav.onNavigatorPush(AppNavigationController.rootStackIndex, rootRoute);
        for (var i = 0; i < 5; i++) {
          expect(nav.framesFor(i), isEmpty);
        }
        expect(
          nav.framesFor(AppNavigationController.rootStackIndex).length,
          1,
        );

        nav.onNavigatorPush(
          AppNavigationController.rootStackIndex,
          modalRoute,
        );
        expect(
          nav.framesFor(AppNavigationController.rootStackIndex).length,
          2,
        );

        nav.onNavigatorPop(
          AppNavigationController.rootStackIndex,
          modalRoute,
        );
        expect(
          nav.framesFor(AppNavigationController.rootStackIndex).length,
          1,
        );

        nav.onNavigatorPop(AppNavigationController.rootStackIndex, rootRoute);
        expect(
          nav.framesFor(AppNavigationController.rootStackIndex),
          isEmpty,
        );
      },
    );
  });
}

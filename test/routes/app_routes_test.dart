import 'package:flutter_test/flutter_test.dart';
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
      expect(AppRoutes.tabIndexFromPublicPath('/bundles'), 3);
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

    test('{id}/logros son los de otro usuario', () {
      expect(
        parseTabDeepRoute(['u-1', 'logros']),
        const AchievementsDeepRoute(userId: 'u-1'),
      );
    });

    test('un id "pelado" es un perfil', () {
      expect(parseTabDeepRoute(['u-1']), const ProfileDeepRoute('u-1'));
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
}

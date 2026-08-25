import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/routes/app_routes.dart';
import 'package:corpus/routes/app_root.dart';

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

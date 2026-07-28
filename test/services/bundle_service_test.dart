import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/services/bundle_service.dart';

void main() {
  group('BundleService.storeRankPublic (Ranking y ordenación de tiendas)', () {
    test(
      'Asigna rangos prioritarios a tiendas principales (Humble Bundle, Fanatical, Steam)',
      () {
        expect(BundleService.storeRankPublic('Humble Bundle'), 1);
        expect(BundleService.storeRankPublic('Fanatical'), 2);
        expect(BundleService.storeRankPublic('Steam'), 3);
      },
    );

    test('Asigna rango secundario (99) a tiendas no prioritarias', () {
      expect(BundleService.storeRankPublic('IndieGala'), 99);
      expect(BundleService.storeRankPublic('Itch.io'), 99);
      expect(BundleService.storeRankPublic('GOG'), 99);
    });

    test(
      'Ordena correctamente una lista de tiendas posicionando primero las principales',
      () {
        final stores = [
          'Itch.io',
          'Fanatical',
          'IndieGala',
          'Steam',
          'Humble Bundle',
        ];

        stores.sort(
          (a, b) => BundleService.storeRankPublic(
            a,
          ).compareTo(BundleService.storeRankPublic(b)),
        );

        expect(stores[0], 'Humble Bundle');
        expect(stores[1], 'Fanatical');
        expect(stores[2], 'Steam');
        // Las secundarias quedan con el mismo rango (99) al final
        expect(BundleService.storeRankPublic(stores[3]), 99);
        expect(BundleService.storeRankPublic(stores[4]), 99);
      },
    );
  });
}

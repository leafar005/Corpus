import 'package:corpus/utils/web_js.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web_js helpers (ARQ-03, BUG-104)', () {
    test('buildPreservedWebSearch preserva style y parámetros OAuth/PKCE', () {
      expect(
        buildPreservedWebSearch('?style=persona5&foo=bar&code=abc123&token_hash=xyz&type=recovery'),
        '?style=persona5&code=abc123&token_hash=xyz&type=recovery',
      );
      expect(buildPreservedWebSearch('?utm_source=x'), '');
      expect(buildPreservedWebSearch('?=legacy'), '?=legacy');
      expect(buildPreservedWebSearch(null), '');
    });

    test('buildPreservedWebHash preserva tokens implícitos de auth', () {
      expect(
        buildPreservedWebHash('#access_token=tok&type=recovery'),
        '#access_token=tok&type=recovery',
      );
      expect(buildPreservedWebHash('#section-2'), '');
      expect(buildPreservedWebHash(''), '');
    });

    test('readWebHistoryState interpreta JSON String y Map sin fallar', () {
      expect(readWebHistoryState('{"tab":2,"depth":1,"token":9}'), {
        'tab': 2,
        'depth': 1,
        'token': 9,
      });
      expect(readWebHistoryState({'tab': 0, 'depth': 0, 'token': 1}), {
        'tab': 0,
        'depth': 0,
        'token': 1,
      });
      expect(readWebHistoryState('{broken-json'), isNull);
    });

    test('ensureCropperJsLoaded y webNotificationClickStream responden de forma segura', () async {
      final loaded = await ensureCropperJsLoaded();
      if (!kIsWeb) {
        expect(loaded, isTrue);
      } else {
        expect(loaded, isFalse);
      }

      if (kIsWeb) {
        setWebPath('/actividad', replace: true, state: {'tab': 2, 'depth': 0, 'token': 1});
        expect(getWebPathname(), '/actividad');
      }
      expect(webNotificationClickStream(), isA<Stream<Map<String, dynamic>>>());
    });
  });
}

@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:corpus/utils/web_js.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  group('web_js browser history & query preservation (Chrome)', () {
    test('setWebPath preserva query params de auth y style junto con history.state', () {
      web.window.history.replaceState(
        '{"tab":0,"depth":0,"token":1}'.toJS,
        '',
        '/buscar?code=pkce_123&style=persona5&utm_source=dropme',
      );

      setWebPath(
        '/buscar/1942',
        replace: true,
        state: {'tab': 0, 'depth': 1, 'token': 2},
      );

      expect(web.window.location.pathname, '/buscar/1942');
      expect(web.window.location.search, contains('code=pkce_123'));
      expect(web.window.location.search, contains('style=persona5'));
      expect(web.window.location.search, isNot(contains('utm_source')));

      final decoded = readWebHistoryState(web.window.history.state?.dartify());
      expect(decoded, {'tab': 0, 'depth': 1, 'token': 2});
    });

    test('push y popstate real en navegador mantienen estado consistente', () async {
      setWebPath(
        '/actividad',
        replace: true,
        state: {'tab': 2, 'depth': 0, 'token': 10},
      );
      setWebPath(
        '/actividad/post/abc',
        replace: false,
        state: {'tab': 2, 'depth': 1, 'token': 11},
      );
      expect(getWebPathname(), '/actividad/post/abc');

      final rawPopEvents = <Map<String, Object?>?>[];
      final sub = webPopStateStream().listen(rawPopEvents.add);
      try {
        goBackInBrowserHistory();
        await Future<void>.delayed(const Duration(milliseconds: 250));
      } finally {
        await sub.cancel();
      }

      expect(getWebPathname(), '/actividad');
      expect(rawPopEvents, isNotEmpty);
      expect(rawPopEvents.last, {'tab': 2, 'depth': 0, 'token': 10});
    });

    test('webNotificationClickStream escucha CORPUS_NOTIFICATION_CLICK en serviceWorker', () async {
      final navObj = web.window.navigator as JSObject;
      final swAny = navObj.getProperty('serviceWorker'.toJS);
      expect(swAny != null && !swAny.isUndefinedOrNull, isTrue);

      final sw = swAny! as web.ServiceWorkerContainer;
      final completer = Completer<Map<String, dynamic>>();
      final sub = webNotificationClickStream().listen((event) {
        if (!completer.isCompleted) {
          completer.complete(event);
        }
      });

      try {
        final msgEvent = web.MessageEvent(
          'message',
          web.MessageEventInit(
            data: <String, Object?>{
              'type': 'CORPUS_NOTIFICATION_CLICK',
              'data': <String, Object?>{
                'post_id': 'p-99',
                'type': 'reply_to_comment',
              },
              'targetUrl': '/actividad/post/p-99',
            }.jsify(),
          ),
        );
        sw.dispatchEvent(msgEvent);

        final received = await completer.future.timeout(
          const Duration(seconds: 2),
        );
        expect(received, {'post_id': 'p-99', 'type': 'reply_to_comment'});
      } finally {
        await sub.cancel();
      }
    });
  });
}

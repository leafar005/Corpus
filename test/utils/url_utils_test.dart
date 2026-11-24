import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/utils/url_utils.dart';

void main() {
  group('parseSafeExternalUri (BUG-23)', () {
    test('acepta esquemas http, https y mailto válidos', () {
      expect(
        parseSafeExternalUri('https://store.steampowered.com/app/1145360')?.scheme,
        'https',
      );
      expect(parseSafeExternalUri('http://example.com')?.scheme, 'http');
      expect(
        parseSafeExternalUri('  mailto:soporte@corpus.app  ')?.scheme,
        'mailto',
      );
    });

    test('rechaza esquemas javascript:, data:, file: y URI inválidas', () {
      expect(parseSafeExternalUri('javascript:alert(1)'), isNull);
      expect(parseSafeExternalUri('JAVASCRIPT:void(0)'), isNull);
      expect(
        parseSafeExternalUri('data:text/html,<script>alert(1)</script>'),
        isNull,
      );
      expect(parseSafeExternalUri('file:///etc/passwd'), isNull);
      expect(parseSafeExternalUri(''), isNull);
      expect(parseSafeExternalUri('   '), isNull);
      expect(parseSafeExternalUri('https:///missing-host'), isNull);
    });
  });
}

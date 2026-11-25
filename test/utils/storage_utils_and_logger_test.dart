import 'package:corpus/utils/corpus_logger.dart';
import 'package:corpus/utils/storage_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StorageUtils y CorpusLogger (MICRO-02, MICRO-04)', () {
    test('extractUserUploadPath limpia query params, fragmentos y rechaza path traversal', () {
      expect(
        StorageUtils.extractUserUploadPath(
          'https://cdn.example.com/storage/v1/object/public/user_uploads/u1/foto%201.jpg?t=123#frag',
        ),
        'u1/foto 1.jpg',
      );
      expect(
        StorageUtils.extractUserUploadPath(
          'https://cdn.example.com/user_uploads/../secret.txt',
        ),
        isNull,
      );
      expect(StorageUtils.extractUserUploadPath('https://cdn.example.com/other/a.jpg'), isNull);
    });

    test('deleteImagesFromUrls devuelve true cuando no hay paths que eliminar', () async {
      final ok = await StorageUtils.deleteImagesFromUrls(const [
        'https://example.com/no-bucket/img.png',
      ]);
      expect(ok, isTrue);
    });

    test('CorpusLogger registra mensajes sin lanzar errores', () {
      final log = CorpusLogger('TestModule');
      expect(() {
        log.debug('debug message');
        log.info('info message');
        log.warning('warn message');
        log.error('error message', error: StateError('boom'));
      }, returnsNormally);
    });
  });
}

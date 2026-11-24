import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/utils/postgrest_utils.dart';

void main() {
  group('postgrest_utils', () {
    const validUuid = '550e8400-e29b-41d4-a716-446655440000';

    test('isValidUuid valida formato estricto con trim', () {
      expect(isValidUuid(validUuid), isTrue);
      expect(isValidUuid('  $validUuid  '), isTrue);
      expect(isValidUuid('550E8400-E29B-41D4-A716-446655440000'), isTrue);

      expect(isValidUuid(null), isFalse);
      expect(isValidUuid(''), isFalse);
      expect(isValidUuid('not-a-uuid'), isFalse);
      expect(isValidUuid('$validUuid,id.neq.0'), isFalse);
    });

    test('requireValidUuid devuelve el UUID recortado o lanza ArgumentError', () {
      expect(requireValidUuid('  $validUuid  '), validUuid);
      expect(
        () => requireValidUuid('invalid-uuid,or=(id.eq.1)'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('escapeLikePattern escapa barra invertida, % y _', () {
      expect(
        escapeLikePattern(r'100%_test\name'),
        r'100\%\_test\\name',
      );
      expect(escapeLikePattern('zelda'), 'zelda');
    });

    test('requireAllowedColumn solo permite columnas de la lista blanca', () {
      expect(
        requireAllowedColumn('  created_at  ', kAllowedJournalOrderColumns),
        'created_at',
      );
      expect(
        () => requireAllowedColumn(
          'created_at; DROP TABLE reviews',
          kAllowedJournalOrderColumns,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('proyecciones públicas de users omiten email y level', () {
      for (final projection in const [
        kPublicUserBasicColumns,
        kPublicUserProfileColumns,
        kFullPublicProfileColumns,
      ]) {
        expect(projection, isNot(contains('email')));
        expect(projection, isNot(contains('level')));
        expect(projection, isNot(contains('*')));
      }
    });
  });
}

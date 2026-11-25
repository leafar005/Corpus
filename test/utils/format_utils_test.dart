import 'package:corpus/utils/format_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatDateRelative y formatDateRange (BUG-99)', () {
    test('muestra horas hasta 23h y 1 día solo desde las 24h', () {
      final ref = DateTime.utc(2026, 8, 15, 18, 0, 0);

      final twelveHoursAgo = ref.subtract(const Duration(hours: 12)).toIso8601String();
      expect(formatDateRelative(twelveHoursAgo, now: ref), 'hace 12 horas');

      final twentyThreeHoursAgo =
          ref.subtract(const Duration(hours: 23)).toIso8601String();
      expect(formatDateRelative(twentyThreeHoursAgo, now: ref), 'hace 23 horas');

      final twentyFourHoursAgo =
          ref.subtract(const Duration(hours: 24)).toIso8601String();
      expect(formatDateRelative(twentyFourHoursAgo, now: ref), 'hace 1 día');

      final thirtySixHoursAgo =
          ref.subtract(const Duration(hours: 36)).toIso8601String();
      expect(formatDateRelative(thirtySixHoursAgo, now: ref), 'hace 1 día');
    });

    test('formatDateRange convierte a zona local igual que formatDateShort', () {
      const fromIso = '2026-01-05T23:30:00Z';
      const untilIso = '2026-02-20T12:00:00Z';
      final expectedFromLocal = DateTime.parse(fromIso).toLocal();

      final formatted = formatDateRange(fromIso, untilIso);
      expect(formatted, startsWith('${expectedFromLocal.day} '));
      expect(formatted, contains('20 Feb'));
      expect(formatted, endsWith('2026'));
    });
  });
}

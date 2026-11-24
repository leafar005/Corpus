import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/services/import_service.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  group('ImportService.fixEncoding (Reparación UTF-8 / Mojibake)', () {
    test('Repara caracteres mojibake en español correctamente', () {
      expect(
        ImportService.fixEncoding('SeÃ±or de los Anillos'),
        'Señor de los Anillos',
      );
      expect(
        ImportService.fixEncoding('EdiciÃ³n Especial'),
        'Edición Especial',
      );
      expect(ImportService.fixEncoding('AÃ±o'), 'Año');
    });

    test('Mantiene texto limpio sin alterar si no hay mojibake', () {
      expect(
        ImportService.fixEncoding('The Legend of Zelda'),
        'The Legend of Zelda',
      );
      expect(
        ImportService.fixEncoding('Chrono Trigger (SNES)'),
        'Chrono Trigger (SNES)',
      );
    });
  });

  group('ImportService.parseCsv (Mapeo de archivos CSV)', () {
    test('Extrae filas limpias con comillas y comas dentro del título', () {
      const csvContent =
          '''title,release_year,status,rating,comment,platform,play_time_hours
"The Legend of Zelda: Breath of the Wild, The",2017,Beaten,10,"Increíble, una obra maestra",Nintendo Switch,120.5
"God of War (2018)",2018,Completed,9.5,"Gran historia, buen combate",PlayStation 4,45
''';
      final Uint8List bytes = Uint8List.fromList(utf8.encode(csvContent));
      final rows = ImportService.parseCsv(bytes);

      expect(rows.length, 2);

      // Fila 1: Zelda con coma dentro del título
      final zelda = rows[0];
      expect(zelda.title, 'The Legend of Zelda: Breath of the Wild, The');
      expect(zelda.releaseYear, 2017);
      expect(zelda.status, 'beaten');
      expect(zelda.rating, 10.0);
      expect(zelda.comment, 'Increíble, una obra maestra');
      expect(zelda.platform, 'nintendo switch');
      expect(zelda.playTimeHours, 120.5);

      // Fila 2: God of War
      final gow = rows[1];
      expect(gow.title, 'God of War (2018)');
      expect(gow.status, 'completed');
      expect(gow.rating, 9.5);
    });

    test('Mapea correctamente los distintos estados en español o inglés', () {
      const csvContent = '''name,estado,score
Juego 1,terminado,10
Juego 2,jugando,8
Juego 3,wishlist,0
Juego 4,abandonado,4
Juego 5,pausado,7
Juego 6,completed,10
Juego 7,backlog,0
''';
      final Uint8List bytes = Uint8List.fromList(utf8.encode(csvContent));
      final rows = ImportService.parseCsv(bytes);

      expect(rows.length, 7);
      expect(rows[0].status, 'beaten');
      expect(rows[1].status, 'playing');
      expect(rows[2].status, 'wishlist');
      expect(rows[3].status, 'abandoned');
      expect(rows[4].status, 'on_hold');
      expect(rows[5].status, 'completed');
      expect(rows[6].status, 'to_play');
    });

    test(
      'Normaliza escalas de notas de 1-100 a escala sobre 10 y mantiene 1-10',
      () {
        const csvContent = '''title,rating
Juego Escala 10 Decimal,4.5
Juego Escala 100,85
Juego Escala 10,9.0
''';
        final Uint8List bytes = Uint8List.fromList(utf8.encode(csvContent));
        final rows = ImportService.parseCsv(bytes);

        expect(rows.length, 3);
        expect(rows[0].rating, 4.5); // se mantiene 4.5 / 10
        expect(rows[1].rating, 8.5); // 85 / 10.0 = 8.5
        expect(rows[2].rating, 9.0); // se mantiene
      },
    );

    test('Ignora filas vacías o sin título válido', () {
      const csvContent = '''title,status
,beaten
"   ",playing
Hollow Knight,beaten
''';
      final Uint8List bytes = Uint8List.fromList(utf8.encode(csvContent));
      final rows = ImportService.parseCsv(bytes);

      expect(rows.length, 1);
      expect(rows.first.title, 'Hollow Knight');
    });
  });

  group('ImportService normalización y guardas (BUG-06)', () {
    test('normalizeIsoDate convierte a UTC o devuelve null si es inválido', () {
      expect(
        ImportService.normalizeIsoDate('2025-03-10T12:00:00Z'),
        '2025-03-10T12:00:00.000Z',
      );
      expect(ImportService.normalizeIsoDate(null), isNull);
      expect(ImportService.normalizeIsoDate(''), isNull);
      expect(ImportService.normalizeIsoDate('NaN'), isNull);
      expect(ImportService.normalizeIsoDate('null'), isNull);
      expect(ImportService.normalizeIsoDate('invalid-date'), isNull);
    });

    test('normalizeCompletionType mapea alias válidos y cae a none', () {
      expect(ImportService.normalizeCompletionType('100%'), '100_percent');
      expect(ImportService.normalizeCompletionType('Platino'), '100_percent');
      expect(ImportService.normalizeCompletionType('story'), 'story');
      expect(ImportService.normalizeCompletionType('Historia'), 'story');
      expect(ImportService.normalizeCompletionType('desconocido'), 'none');
      expect(ImportService.normalizeCompletionType(null), 'none');
    });

    test('saveImportedGames lanza StateError si no hay sesión activa', () async {
      final client = _MockSupabaseClient();
      final auth = _MockGoTrueClient();
      when(() => client.auth).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(null);

      await expectLater(
        () => ImportService.saveImportedGames(
          [
            CsvGameRow(
              title: 'Hades',
              status: 'beaten',
              matchStatus: 'matched',
              igdbData: {'id': 1, 'name': 'Hades'},
            ),
          ],
          onProgress: (_, _) {},
          client: client,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

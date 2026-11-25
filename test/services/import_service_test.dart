import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/services/import_service.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _RecordingImportClient extends Fake implements SupabaseClient {
  _RecordingImportClient(this._auth);

  final GoTrueClient _auth;
  int gamesSelectCount = 0;
  int gamesUpdateCount = 0;
  List<Map<String, dynamic>> missingCoverRows = const [];

  @override
  GoTrueClient get auth => _auth;

  @override
  SupabaseQueryBuilder from(String table) =>
      _RecordingImportQueryBuilder(this, table);
}

class _RecordingImportQueryBuilder extends Fake
    implements SupabaseQueryBuilder {
  _RecordingImportQueryBuilder(this._client, this._table);

  final _RecordingImportClient _client;
  final String _table;

  @override
  PostgrestFilterBuilder<dynamic> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) => _RecordingFilterBuilder<dynamic>(() async => const []);

  @override
  PostgrestFilterBuilder<dynamic> insert(
    Object values, {
    bool defaultToNull = true,
  }) => _RecordingFilterBuilder<dynamic>(
    () async => [
      {'id': 'rev-1'},
    ],
  );

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    if (_table == 'games') _client.gamesSelectCount++;
    return _RecordingFilterBuilder<PostgrestList>(() async {
      if (_table == 'games') {
        return List<PostgrestMap>.from(_client.missingCoverRows);
      }
      return <PostgrestMap>[];
    });
  }

  @override
  PostgrestFilterBuilder<dynamic> update(Map<dynamic, dynamic> values) {
    if (_table == 'games') _client.gamesUpdateCount++;
    return _RecordingFilterBuilder<dynamic>(() async => const []);
  }

  @override
  PostgrestFilterBuilder<dynamic> delete() =>
      _RecordingFilterBuilder<dynamic>(() async => const []);
}

class _RecordingFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  _RecordingFilterBuilder(this._execute);

  final Future<T> Function() _execute;

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestFilterBuilder<T> inFilter(String column, List<dynamic> values) =>
      this;

  @override
  PostgrestFilterBuilder<T> isFilter(String column, bool? value) => this;

  @override
  PostgrestTransformBuilder<PostgrestList> select([String columns = '*']) =>
      _RecordingTransformBuilder<PostgrestList>(
        () async => List<PostgrestMap>.from(await _execute() as List),
      );

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) => _execute().then(onValue, onError: onError);
}

class _RecordingTransformBuilder<T> extends Fake
    implements PostgrestTransformBuilder<T> {
  _RecordingTransformBuilder(this._execute);

  final Future<T> Function() _execute;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) => _execute().then(onValue, onError: onError);
}

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
      expect(
        ImportService.fixEncoding('EdiciÃ³n Especial 🎮'),
        'Edición Especial 🎮',
      );
    });
  });

  group('ImportService.parseCsv (Mapeo de archivos CSV)', () {
    test('Extrae filas limpias con comillas y comas dentro del título', () async {
      const csvContent =
          '''title,release_year,status,rating,comment,platform,play_time_hours
"The Legend of Zelda: Breath of the Wild, The",2017,Beaten,10,"Increíble, una obra maestra",Nintendo Switch,120.5
"God of War (2018)",2018,Completed,9.5,"Gran historia, buen combate",PlayStation 4,45
''';
      final Uint8List bytes = Uint8List.fromList(utf8.encode(csvContent));
      final rows = await ImportService.parseCsv(bytes);

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

    test('Mapea correctamente los distintos estados en español o inglés', () async {
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
      final rows = await ImportService.parseCsv(bytes);

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
      () async {
        const csvContent = '''title,rating
Juego Escala 10 Decimal,4.5
Juego Escala 100,85
Juego Escala 10,9.0
''';
        final Uint8List bytes = Uint8List.fromList(utf8.encode(csvContent));
        final rows = await ImportService.parseCsv(bytes);

        expect(rows.length, 3);
        expect(rows[0].rating, 4.5); // se mantiene 4.5 / 10
        expect(rows[1].rating, 8.5); // 85 / 10.0 = 8.5
        expect(rows[2].rating, 9.0); // se mantiene
      },
    );

    test('Ignora filas vacías o sin título válido', () async {
      const csvContent = '''title,status
,beaten
"   ",playing
Hollow Knight,beaten
''';
      final Uint8List bytes = Uint8List.fromList(utf8.encode(csvContent));
      final rows = await ImportService.parseCsv(bytes);

      expect(rows.length, 1);
      expect(rows.first.title, 'Hollow Knight');
    });

    test('Soporta decimales con coma europea y bytes Windows-1252 (BUG-120)', () async {
      final cp1252Bytes = Uint8List.fromList([
        ...latin1.encode('título,rating,play_time_hours\n'),
        // "Edición Señor" en Windows-1252 (0xF3 = ó, 0xF1 = ñ)
        0x45, 0x64, 0x69, 0x63, 0x69, 0xF3, 0x6E, 0x20, 0x53, 0x65, 0xF1, 0x6F, 0x72,
        ...latin1.encode(',"8,5","12,25"\n'),
      ]);

      final rows = await ImportService.parseCsv(cp1252Bytes);
      expect(rows, hasLength(1));
      expect(rows.first.title, 'Edición Señor');
      expect(rows.first.rating, 8.5);
      expect(rows.first.playTimeHours, 12.25);
    });

    test('Lanza FormatException si el CSV multipunto carece de columna de título', () async {
      final bytes = Uint8List.fromList(utf8.encode('status,rating\nbeaten,9\n'));
      await expectLater(
        () => ImportService.parseCsv(bytes),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ImportService.parseStashJson y saveImportedGames batch (OPT-01, OPT-05)', () {
    test('parseStashJson decodifica exportaciones JSON de Stash de forma asíncrona', () async {
      final payload = jsonEncode({
        'items': [
          {
            'game': {'id': 26226, 'name': 'Celeste'},
            'review': {'status': 'completed', 'rating': 10},
          },
        ],
      });
      final rows = await ImportService.parseStashJson(
        Uint8List.fromList(utf8.encode(payload)),
      );
      expect(rows, hasLength(1));
      expect(rows.first.title, 'Celeste');
      expect(rows.first.igdbId, 26226);
      expect(rows.first.status, 'completed');
    });

    test('saveImportedGames consulta portadas faltantes en bloque sin UPDATE N+1 innecesarios', () async {
      final auth = _MockGoTrueClient();
      when(() => auth.currentUser).thenReturn(
        const User(
          id: 'u-1',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2025-01-01T00:00:00Z',
        ),
      );
      final client = _RecordingImportClient(auth);
      client.missingCoverRows = const [
        {'igdb_id': 2},
      ];

      await ImportService.saveImportedGames(
        [
          CsvGameRow(
            title: 'Game 1',
            igdbId: 1,
            status: 'beaten',
            matchStatus: 'matched',
            igdbData: {
              'id': 1,
              'name': 'Game 1',
              'cover': {'image_id': 'c1'},
            },
          ),
          CsvGameRow(
            title: 'Game 2',
            igdbId: 2,
            status: 'beaten',
            matchStatus: 'matched',
            igdbData: {
              'id': 2,
              'name': 'Game 2',
              'cover': {'image_id': 'c2'},
            },
          ),
        ],
        onProgress: (_, _) {},
        client: client,
      );

      expect(client.gamesSelectCount, 1);
      expect(client.gamesUpdateCount, 1);
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

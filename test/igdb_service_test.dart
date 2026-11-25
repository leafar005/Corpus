import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/services/igdb_service.dart';

void main() {
  group('IGDBService URL Generators', () {
    test('getCoverUrl genera la URL correcta para alta resolución', () {
      expect(
        IGDBService.getCoverUrl('co123'),
        'https://images.igdb.com/igdb/image/upload/t_cover_big/co123.jpg',
      );
      expect(IGDBService.getCoverUrl(null), '');
    });

    test('getScreenshotUrl genera la URL correcta a 1080p', () {
      expect(
        IGDBService.getScreenshotUrl('sc456'),
        'https://images.igdb.com/igdb/image/upload/t_1080p/sc456.jpg',
      );
      expect(IGDBService.getScreenshotUrl(null), '');
    });

    test('getArtworkUrl genera la URL correcta a 1080p', () {
      expect(
        IGDBService.getArtworkUrl('ar789'),
        'https://images.igdb.com/igdb/image/upload/t_1080p/ar789.jpg',
      );
      expect(IGDBService.getArtworkUrl(null), '');
    });

    test('getVideoThumbnailUrl y getVideoUrl para YouTube', () {
      expect(
        IGDBService.getVideoThumbnailUrl('xyz123'),
        'https://img.youtube.com/vi/xyz123/hqdefault.jpg',
      );
      expect(IGDBService.getVideoThumbnailUrl(null), '');
      expect(
        IGDBService.getVideoUrl('xyz123'),
        'https://www.youtube.com/watch?v=xyz123',
      );
      expect(IGDBService.getVideoUrl(null), '');
    });
  });

  group('IGDBService HTML Entities Decoder', () {
    test('decodeHtmlEntities decodifica entidades HTML crudas', () {
      expect(
        IGDBService.decodeHtmlEntities('The Legend of Zelda &amp; Link'),
        'The Legend of Zelda & Link',
      );
      expect(
        IGDBService.decodeHtmlEntities('Baldur&#039;s Gate 3'),
        "Baldur's Gate 3",
      );
      expect(
        IGDBService.decodeHtmlEntities('Título &quot;Especial&quot;'),
        'Título "Especial"',
      );
    });

    test('decodeHtmlEntities mantiene texto normal sin cambios', () {
      expect(IGDBService.decodeHtmlEntities('Elden Ring'), 'Elden Ring');
      expect(IGDBService.decodeHtmlEntities(''), '');
    });
  });

  group('IGDBService Apicalypse Sanitization', () {
    test('sanitizeApicalypseTerm elimina comillas, punto y coma y barras invertidas', () {
      expect(
        IGDBService.sanitizeApicalypseTerm('zelda"; where id > 0; \\test'),
        'zelda where id > 0 test',
      );
      expect(IGDBService.sanitizeApicalypseTerm('   " ; \\  '), '');
    });

    test(
      'buildLenientSearchQuery sanitiza operadores e incluye juegos sin votos',
      () {
        final query = IGDBService.buildLenientSearchQuery(
          'Hades"; where id > 0; &quot;II&quot; \\test',
        );
        expect(query, isNotNull);
        expect(query, isNot(contains('where id > 0')));
        expect(
          query,
          contains('(total_rating_count != null | total_rating_count = null)'),
        );
        expect(IGDBService.buildLenientSearchQuery('   " ; \\  '), isNull);
      },
    );
  });

  group('IGDBService Caché Cuantizada y Null Order Workaround (OPT-03, BUG-118)', () {
    test('quantizeUnixTimestamp agrupa timestamps en ventanas de 5 minutos', () {
      expect(IGDBService.quantizeUnixTimestamp(1700000100), 1700000100);
      expect(IGDBService.quantizeUnixTimestamp(1700000399), 1700000100);
      expect(IGDBService.quantizeUnixTimestamp(1700000400), 1700000400);
    });

    test('nullOrderWorkaroundForSort distingue aggregated_rating de rating con límites de palabra', () {
      expect(
        IGDBService.nullOrderWorkaroundForSort('sort aggregated_rating desc;'),
        ' & (aggregated_rating != null | aggregated_rating = null)',
      );
      expect(
        IGDBService.nullOrderWorkaroundForSort('sort rating desc;'),
        ' & (rating != null | rating = null)',
      );
      expect(
        IGDBService.nullOrderWorkaroundForSort('sort total_rating_count desc;'),
        ' & (total_rating_count != null | total_rating_count = null)',
      );
      expect(IGDBService.nullOrderWorkaroundForSort('sort rating asc;'), '');
    });
  });
}

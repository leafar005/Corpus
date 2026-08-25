import 'package:corpus/utils/game_title_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('abbreviateGameTitleIfNeeded', () {
    test('keeps short single-word titles', () {
      expect(abbreviateGameTitleIfNeeded('Kirby'), 'Kirby');
    });

    test('keeps short two-word titles', () {
      expect(abbreviateGameTitleIfNeeded('Elden Ring'), 'Elden Ring');
    });

    test('abbreviates three-word titles', () {
      expect(abbreviateGameTitleIfNeeded('PERSONA 5 ROYAL'), 'P5R');
    });

    test('abbreviates titles with semicolon segments', () {
      expect(abbreviateGameTitleIfNeeded('Far Cry; Primal'), 'FC:P');
    });

    test('abbreviates colon-separated subtitles', () {
      expect(abbreviateGameTitleIfNeeded('The Witcher 3: Wild Hunt'), 'TW3:WH');
    });

    test('abbreviates long colon-separated compilation titles', () {
      expect(
        abbreviateGameTitleIfNeeded(
          'Biohazard: The Mercenaries 3D & Revelations',
        ),
        'B:TM3R',
      );
    });
  });

  group('gameTitleNeedsAbbreviation', () {
    test('false for short titles', () {
      expect(gameTitleNeedsAbbreviation('Kirby'), isFalse);
      expect(gameTitleNeedsAbbreviation('Elden Ring'), isFalse);
    });

    test('true when more than two words', () {
      expect(gameTitleNeedsAbbreviation('PERSONA 5 ROYAL'), isTrue);
    });

    test('true when exceeding char limit', () {
      expect(gameTitleNeedsAbbreviation('A Very Long Title'), isTrue);
    });
  });
}

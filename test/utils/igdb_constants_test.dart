import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/utils/igdb_constants.dart';

void main() {
  group('IgdbConstants.resolveCategory Tests', () {
    test('Resuelve categorías numéricas de IGDB que no son juego base ( != 0 )', () {
      expect(IgdbConstants.resolveCategory(1, 'Cualquier Título'), 1); // DLC
      expect(IgdbConstants.resolveCategory(8, 'Juego X'), 8); // Remake
      expect(IgdbConstants.resolveCategory(9, 'Juego Y'), 9); // Remaster
    });

    test('Detecta Remakes por palabras clave en el título cuando category es 0 o null', () {
      expect(IgdbConstants.resolveCategory(0, 'Resident Evil 4 Remake'), 8);
      expect(IgdbConstants.resolveCategory(null, 'Yakuza Kiwami 2'), 8);
      expect(IgdbConstants.resolveCategory(0, 'The Last of Us Part I'), 8);
    });

    test('Detecta Remasters por palabras clave o HD cuando category es 0 o null', () {
      expect(IgdbConstants.resolveCategory(0, 'Dark Souls Remastered'), 9);
      expect(IgdbConstants.resolveCategory(0, 'Age of Empires II: Definitive Edition'), 9);
      expect(IgdbConstants.resolveCategory(null, 'Zelda Twilight Princess HD'), 9);
    });

    test('Detecta Ediciones Expandidas por palabras clave', () {
      expect(IgdbConstants.resolveCategory(0, 'Persona 5 Royal'), 10);
      expect(IgdbConstants.resolveCategory(0, 'The Witcher 3: Game of the Year'), 10);
      expect(IgdbConstants.resolveCategory(0, 'Cyberpunk 2077 Ultimate Edition'), 10);
    });

    test('Detecta DLCs por nombre o por tener parent_game', () {
      expect(IgdbConstants.resolveCategory(0, 'Elden Ring: Shadow of the Erdtree DLC'), 1);
      expect(IgdbConstants.resolveCategory(0, 'Expansion Pass Vol 1'), 1);
      expect(IgdbConstants.resolveCategory(0, 'Misión adicional', hasParentGame: true), 1);
      expect(IgdbConstants.resolveCategory(0, 'DLC sin palabra clave', hasParentGame: true), 1);
    });

    test('Detecta Mods por palabra suelta en título o resumen', () {
      expect(IgdbConstants.resolveCategory(0, 'Skyrim: Enderal Mod'), 5);
      expect(
        IgdbConstants.resolveCategory(0, 'Proyecto de fans', summary: 'Este es un mod creado por la comunidad'),
        5,
      );
    });

    test('Devuelve null para juegos base normales sin keywords ni parent_game', () {
      expect(IgdbConstants.resolveCategory(0, 'Elden Ring'), isNull);
      expect(IgdbConstants.resolveCategory(null, 'Hollow Knight'), isNull);
    });
  });

  group('IgdbConstants Helpers & Formatters', () {
    test('getCategoryName devuelve nombres legibles en español', () {
      expect(IgdbConstants.getCategoryName(0), 'Juego Principal');
      expect(IgdbConstants.getCategoryName(1), 'DLC');
      expect(IgdbConstants.getCategoryName(8), 'Remake');
      expect(IgdbConstants.getCategoryName(999), 'Desconocido');
    });

    test('isMainGame identifica correctamente juegos base (0 o null)', () {
      expect(IgdbConstants.isMainGame(null), isTrue);
      expect(IgdbConstants.isMainGame(0), isTrue);
      expect(IgdbConstants.isMainGame(1), isFalse);
      expect(IgdbConstants.isMainGame(8), isFalse);
    });

    test('getCategoryColor respeta el color secundario del tema para Remakes (8)', () {
      const customSecondary = Colors.deepOrange;
      final color = IgdbConstants.getCategoryColor(8, themeSecondary: customSecondary);
      expect(color, customSecondary);
    });

    test('getPlatformStyle devuelve estilos específicos para plataformas conocidas', () {
      final pcStyle = IgdbConstants.getPlatformStyle('PC (Windows)');
      expect(pcStyle['icon'], 'assets/images/windows.png');

      final psStyle = IgdbConstants.getPlatformStyle('PlayStation 5');
      expect(psStyle['icon'], 'assets/images/playstation.png');

      final unknownStyle = IgdbConstants.getPlatformStyle('Plataforma Rara 3000');
      expect(unknownStyle['icon'], isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/theme/style_pack_registry.dart';

void main() {
  group('StylePackRegistry.isSafeArchivePath', () {
    // ── Rutas válidas ────────────────────────────────────────────────────
    test('acepta un nombre de archivo simple', () {
      expect(StylePackRegistry.isSafeArchivePath('manifest.json'), isTrue);
    });

    test('acepta ruta con subdirectorio', () {
      expect(StylePackRegistry.isSafeArchivePath('assets/music.mp3'), isTrue);
    });

    test('acepta ruta con múltiples niveles', () {
      expect(
        StylePackRegistry.isSafeArchivePath('assets/images/bg.png'),
        isTrue,
      );
    });

    // ── Rutas vacías ─────────────────────────────────────────────────────
    test('rechaza cadena vacía', () {
      expect(StylePackRegistry.isSafeArchivePath(''), isFalse);
    });

    // ── Directory traversal ──────────────────────────────────────────────
    test('rechaza ../ al inicio', () {
      expect(StylePackRegistry.isSafeArchivePath('../etc/passwd'), isFalse);
    });

    test('rechaza ../../ traversal', () {
      expect(
        StylePackRegistry.isSafeArchivePath('../../secret.txt'),
        isFalse,
      );
    });

    test('rechaza traversal en medio de la ruta', () {
      expect(
        StylePackRegistry.isSafeArchivePath('assets/../../../etc/passwd'),
        isFalse,
      );
    });

    test('rechaza solo ..', () {
      expect(StylePackRegistry.isSafeArchivePath('..'), isFalse);
    });

    // ── Rutas absolutas ──────────────────────────────────────────────────
    test('rechaza ruta absoluta Unix', () {
      expect(StylePackRegistry.isSafeArchivePath('/etc/passwd'), isFalse);
    });

    test('rechaza ruta absoluta Windows', () {
      expect(StylePackRegistry.isSafeArchivePath('C:\\Windows\\system32'), isFalse);
    });

    // ── Archivos ocultos ─────────────────────────────────────────────────
    test('rechaza archivo oculto (dot file)', () {
      expect(StylePackRegistry.isSafeArchivePath('.env'), isFalse);
    });

    test('rechaza directorio oculto', () {
      expect(StylePackRegistry.isSafeArchivePath('.ssh/authorized_keys'), isFalse);
    });

    test('rechaza subdirectorio oculto', () {
      expect(StylePackRegistry.isSafeArchivePath('assets/.hidden/file.txt'), isFalse);
    });

    // ── Nombres reservados de Windows ────────────────────────────────────
    test('rechaza CON (reservado Windows)', () {
      expect(StylePackRegistry.isSafeArchivePath('CON'), isFalse);
    });

    test('rechaza CON.txt (reservado Windows con extensión)', () {
      expect(StylePackRegistry.isSafeArchivePath('CON.txt'), isFalse);
    });

    test('rechaza NUL (reservado Windows)', () {
      expect(StylePackRegistry.isSafeArchivePath('NUL'), isFalse);
    });

    test('rechaza PRN (reservado Windows)', () {
      expect(StylePackRegistry.isSafeArchivePath('PRN'), isFalse);
    });

    test('rechaza COM1 (reservado Windows)', () {
      expect(StylePackRegistry.isSafeArchivePath('COM1'), isFalse);
    });

    test('rechaza LPT1 (reservado Windows)', () {
      expect(StylePackRegistry.isSafeArchivePath('LPT1'), isFalse);
    });

    test('rechaza con minúsculas (case insensitive)', () {
      expect(StylePackRegistry.isSafeArchivePath('con'), isFalse);
    });

    test('rechaza AUX.json (reservado con extensión)', () {
      expect(StylePackRegistry.isSafeArchivePath('AUX.json'), isFalse);
    });

    // ── Null bytes ───────────────────────────────────────────────────────
    test('rechaza ruta con null byte', () {
      expect(
        StylePackRegistry.isSafeArchivePath('manifest.json\x00.exe'),
        isFalse,
      );
    });

    test('rechaza ruta con null byte al inicio', () {
      expect(StylePackRegistry.isSafeArchivePath('\x00file.txt'), isFalse);
    });

    // ── Separadores mixtos ───────────────────────────────────────────────
    test('rechaza traversal con backslash separators', () {
      expect(
        StylePackRegistry.isSafeArchivePath('foo\\..\\..\\etc\\passwd'),
        isFalse,
      );
    });
  });
}

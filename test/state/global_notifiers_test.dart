import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/theme/app_theme.dart';

void main() {
  group('ThemeNotifier (Estado del Tema Global)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'Actualiza currentMode a ThemeMode.dark y emite evento de cambio',
      () async {
        final notifier = ThemeNotifier();
        await notifier.initialize();
        bool notified = false;
        notifier.addListener(() {
          notified = true;
        });

        await notifier.setTheme(ThemeMode.dark);

        expect(notifier.currentMode, ThemeMode.dark);
        expect(notified, isTrue);
      },
    );

    test(
      'Actualiza seedColor a Colors.green y emite evento de cambio',
      () async {
        final notifier = ThemeNotifier();
        await notifier.initialize();
        bool notified = false;
        notifier.addListener(() {
          notified = true;
        });

        await notifier.setColor(Colors.green);

        expect(notifier.seedColor.toARGB32(), Colors.green.toARGB32());
        expect(notified, isTrue);
      },
    );
  });

  group('libraryUpdateNotifier (Estado Global de Biblioteca)', () {
    test(
      'Incrementa su valor en +1 cuando se simula un cambio en la biblioteca o borrado de juego',
      () {
        final initialValue = libraryUpdateNotifier.value;
        int notifiedCount = 0;

        void listener() {
          notifiedCount++;
        }

        libraryUpdateNotifier.addListener(listener);

        // Simular cambio en la biblioteca (ej: borrar juego o cuenta)
        libraryUpdateNotifier.value++;

        expect(libraryUpdateNotifier.value, initialValue + 1);
        expect(notifiedCount, 1);

        libraryUpdateNotifier.removeListener(listener);
      },
    );
  });
}

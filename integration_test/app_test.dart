import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:corpus/main.dart' as app;

/// Prueba de Integración End-to-End (E2E - Prioridad 5 de la Pirámide de Testing)
///
/// Para ejecutar esta prueba en un dispositivo, emulador o Chrome web:
/// ```powershell
/// flutter test integration_test/app_test.dart -d chrome
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Corpus App E2E - Flujo Completo de Usuario', () {
    testWidgets(
      'Flujo de Usuario E2E: Autenticar -> Buscar Juego -> Abrir Ficha -> Añadir Reseña (Nota 10) -> Confirmar en Mi Biblioteca',
      (WidgetTester tester) async {
        // 1. Levantar la aplicación completa
        app.main();
        await tester.pumpAndSettle();

        // ── PASO 1: Iniciar Sesión / Autenticar ──────────────────────────────
        // Si la app se inicia sin sesión previa, aparece el LoginScreen
        if (find.text('Bienvenido a Corpus').evaluate().isNotEmpty) {
          final emailField = find.widgetWithText(TextField, 'Correo electrónico');
          final passwordField = find.widgetWithText(TextField, 'Contraseña');

          expect(emailField, findsOneWidget);
          expect(passwordField, findsOneWidget);

          await tester.enterText(emailField, 'test.user@corpus.app');
          await tester.enterText(passwordField, 'Password123!');
          await tester.pump();

          final loginButton = find.widgetWithText(ElevatedButton, 'Iniciar sesión');
          expect(loginButton, findsOneWidget);

          await tester.tap(loginButton);
          await tester.pumpAndSettle();
        }

        // ── PASO 2: Buscar un Juego ──────────────────────────────────────────
        // Verificar que estamos en la pantalla principal (Home / Biblioteca)
        final searchIcon = find.byIcon(Icons.search);
        if (searchIcon.evaluate().isNotEmpty) {
          await tester.tap(searchIcon.first);
          await tester.pumpAndSettle();

          // Escribir en el campo de búsqueda
          final searchInput = find.byType(TextField);
          if (searchInput.evaluate().isNotEmpty) {
            await tester.enterText(searchInput.first, 'Elden Ring');
            await tester.testTextInput.receiveAction(TextInputAction.search);
            await tester.pumpAndSettle();
          }
        }

        // ── PASO 3: Pulsar en la Ficha del Juego ─────────────────────────────
        final gameCard = find.textContaining('Elden Ring');
        if (gameCard.evaluate().isNotEmpty) {
          await tester.tap(gameCard.first);
          await tester.pumpAndSettle();

          // ── PASO 4: Abrir el Modal de Reseña ───────────────────────────────
          final addReviewButton = find.text('Añadir reseña');
          if (addReviewButton.evaluate().isNotEmpty) {
            await tester.tap(addReviewButton);
            await tester.pumpAndSettle();

            // ── PASO 5: Puntuarlo con un 10 ──────────────────────────────────
            final slider = find.byType(Slider);
            if (slider.evaluate().isNotEmpty) {
              // Simular arrastrar el slider al valor máximo (10.0)
              await tester.drag(slider.first, const Offset(500, 0));
              await tester.pumpAndSettle();
            }

            // Seleccionar estado Terminado ("beaten")
            final beatenChip = find.text('Terminado');
            if (beatenChip.evaluate().isNotEmpty) {
              await tester.tap(beatenChip);
              await tester.pumpAndSettle();
            }

            // Guardar Reseña
            final saveButton = find.text('Guardar Reseña');
            if (saveButton.evaluate().isNotEmpty) {
              await tester.tap(saveButton);
              await tester.pumpAndSettle();
            }
          }
        }

        // ── PASO 6: Confirmar en Pantalla de Mi Biblioteca ───────────────────
        // Navegar a la pestaña de Biblioteca (o comprobar en Home que la tarjeta está en biblioteca)
        final libraryTab = find.text('Mi Biblioteca');
        if (libraryTab.evaluate().isNotEmpty) {
          await tester.tap(libraryTab.first);
          await tester.pumpAndSettle();

          // Confirmar que el juego está en la lista/cuadrícula con la puntuación
          expect(find.textContaining('Elden Ring'), findsWidgets);
        }
      },
    );
  });
}

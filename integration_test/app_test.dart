import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/main.dart' as app;
import 'package:corpus/globals.dart' as globals;
import 'package:corpus/widgets/game_card.dart';

/// Prueba de Integración End-to-End (E2E - Prioridad 5 de la Pirámide de Testing)
///
/// Flujo robusto con aserciones estrictas (expect), sin temporizadores periódicos (kDisableCarouselForTests)
/// y con finders estables por Key y por tipo (GameCard):
/// 1. Desactiva temporizadores infinitos (carrusel/fondo) y resetea pestaña en SharedPreferences.
/// 2. Cierra sesión previa y genera una cuenta transitoria con timestamp.
/// 3. Intenta iniciar sesión y comprueba que la cuenta no existe.
/// 4. Navega al registro y rellena campos usando Keys robustas (byKey).
/// 5. Al completar registro, AuthGate entra automáticamente en la app.
/// 6. Busca 'Elden Ring', abre la ficha con pump controlado, añade reseña (Nota 10, Terminado).
/// 7. Verifica que la reseña aparece en 'Mi Biblioteca'.
/// 8. Al terminar, elimina de la BD todos los datos transitorios creados y cierra sesión.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // 1. Desactivar temporizadores de carrusel/fondo para que pumpAndSettle no se quede colgado
  globals.kDisableCarouselForTests = true;

  group('Corpus App E2E - Flujo Completo de Usuario Transitorio', () {
    testWidgets(
      'Flujo de Usuario E2E: Login fallido -> Registro transitorio -> Iniciar Sesión -> Reseñar -> Limpieza final',
      (WidgetTester tester) async {
        // Generar credenciales únicas transitorias para esta ejecución
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final transientEmail = 'e2e_transient_$timestamp@corpus.app';
        const transientPassword = 'Password123!';
        final transientUsername = 'Tester_$timestamp';

        // Función auxiliar para esperar a que aparezca un widget (ej: tras peticiones HTTP reales a IGDB/Supabase)
        Future<void> waitFor(
          Finder finder, {
          Duration timeout = const Duration(seconds: 25),
        }) async {
          final end = DateTime.now().add(timeout);
          while (DateTime.now().isBefore(end)) {
            await tester.pump(const Duration(milliseconds: 300));
            if (finder.evaluate().isNotEmpty) {
              return;
            }
          }
        }

        // 2. Levantar la aplicación completa
        app.main();
        await tester.pumpAndSettle();

        // ── PASO 0: Limpiar cualquier sesión previa y resetear tab ───────────
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('main_tab_index', 0);
          if (Supabase.instance.client.auth.currentUser != null) {
            await Supabase.instance.client.auth.signOut();
            await tester.pumpAndSettle();
            await tester.pump(
              const Duration(milliseconds: 500),
            ); // Margen para el stream de auth
          }
        } catch (_) {}

        try {
          // ── PASO 1: Comprobar pantalla de Login e intentar entrar sin cuenta ──
          expect(
            find.text('Bienvenido a Corpus'),
            findsOneWidget,
            reason: 'Debe mostrarse la pantalla de inicio de sesión',
          );

          final emailField = find.widgetWithText(
            TextField,
            'Correo electrónico',
          );
          final passwordField = find.widgetWithText(TextField, 'Contraseña');
          expect(emailField, findsOneWidget);
          expect(passwordField, findsOneWidget);

          await tester.enterText(emailField, transientEmail);
          await tester.enterText(passwordField, transientPassword);
          await tester.pump();

          final loginButton = find.widgetWithText(
            ElevatedButton,
            'Iniciar sesión',
          );
          expect(loginButton, findsOneWidget);

          // Intentamos iniciar sesión con una cuenta que aún no existe
          await tester.tap(loginButton);
          await tester.pumpAndSettle();

          // Comprobamos que seguimos en la pantalla de Login porque el usuario no existía
          expect(
            find.text('Bienvenido a Corpus'),
            findsOneWidget,
            reason:
                'El login con una cuenta inexistente debe permanecer en LoginScreen',
          );

          // ── PASO 2: Navegar a pantalla de Registro y crear la cuenta ────────
          final registerLink = find.text('¿No tienes cuenta? Regístrate aquí');
          expect(registerLink, findsOneWidget);
          await tester.tap(registerLink);
          await tester.pumpAndSettle();

          expect(
            find.text('Crear cuenta'),
            findsOneWidget,
            reason: 'Debe haberse abierto el RegisterScreen',
          );

          // Rellenar campos de registro con finders robustos por Key
          final usernameField = find.byKey(
            const Key('register_username_field'),
          );
          final regEmailField = find.byKey(const Key('register_email_field'));
          final regPasswordField = find.byKey(
            const Key('register_password_field'),
          );

          expect(usernameField, findsOneWidget);
          expect(regEmailField, findsOneWidget);
          expect(regPasswordField, findsOneWidget);

          await tester.enterText(usernameField, transientUsername);
          await tester.enterText(regEmailField, transientEmail);
          await tester.enterText(regPasswordField, transientPassword);
          await tester.pump();

          final completeRegisterButton = find.widgetWithText(
            ElevatedButton,
            'Completar registro',
          );
          expect(completeRegisterButton, findsOneWidget);

          await tester.tap(completeRegisterButton);
          await tester.pumpAndSettle();
          await tester.pump(
            const Duration(milliseconds: 500),
          ); // Margen para propagación de sesión

          // ── PASO 3: Verificar entrada a MainScreen vía AuthGate ─────────────
          // Al registrarse en Supabase, el AuthGate de main.dart detecta la sesión
          // y nos lleva directamente a la aplicación principal (sin pasar por Login de nuevo).
          final searchIcon = find.byIcon(Icons.search);
          await waitFor(searchIcon, timeout: const Duration(seconds: 15));
          expect(
            searchIcon,
            findsWidgets,
            reason:
                'Tras completar el registro, AuthGate nos lleva automáticamente a la interfaz principal',
          );

          // ── PASO 4: Buscar un Juego ('Elden Ring') ─────────────────────────
          await tester.tap(searchIcon.first);
          await tester.pumpAndSettle();

          final searchInput = find.byType(TextField);
          expect(searchInput, findsWidgets);
          await tester.enterText(searchInput.first, 'Elden Ring');

          // Esperamos activamente a que IGDB responda y renderice la tarjeta del juego
          // Importante: usamos find.ancestor con GameCard para NO confundirlo con el texto 'Elden Ring' dentro del propio TextField
          final eldenRingCard = find.ancestor(
            of: find.textContaining(RegExp('elden ring', caseSensitive: false)),
            matching: find.byType(GameCard),
          );
          await waitFor(eldenRingCard, timeout: const Duration(seconds: 25));
          expect(
            eldenRingCard,
            findsWidgets,
            reason:
                'La búsqueda de Elden Ring debe devolver al menos una GameCard',
          );
          await tester.tap(eldenRingCard.first);
          // Usar pumps de duración fija para no bloquearnos en fetches asíncronos de IGDB/covers
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));

          // ── PASO 5: Añadir a Biblioteca con nota 10 y estado 'Terminado' ────
          final addLibraryButton = find.text('Añadir a Biblioteca');
          await waitFor(addLibraryButton, timeout: const Duration(seconds: 15));
          expect(addLibraryButton, findsOneWidget);
          await tester.tap(addLibraryButton);
          await tester.pumpAndSettle();

          // Mover el slider hasta el valor 10.0
          final slider = find.byType(Slider);
          expect(slider, findsWidgets);
          await tester.drag(slider.first, const Offset(500, 0));
          await tester.pumpAndSettle();

          // Marcar como 'Terminado'
          final beatenChip = find.text('Terminado');
          expect(beatenChip, findsWidgets);
          await tester.tap(beatenChip.first);
          await tester.pumpAndSettle();

          // Guardar Reseña
          final saveButton = find.text('Guardar Reseña');
          expect(saveButton, findsOneWidget);
          await tester.tap(saveButton);
          await tester.pumpAndSettle();

          // ── PASO 6: Confirmar en Pantalla 'Mi Biblioteca' ──────────────────
          final libraryTab = find.text('Mi Biblioteca');
          expect(libraryTab, findsWidgets);
          await tester.tap(libraryTab.first);
          await tester.pumpAndSettle();

          final eldenRingInLibrary = find.ancestor(
            of: find.textContaining(RegExp('elden ring', caseSensitive: false)),
            matching: find.byType(GameCard),
          );
          await waitFor(
            eldenRingInLibrary,
            timeout: const Duration(seconds: 15),
          );
          expect(
            eldenRingInLibrary,
            findsWidgets,
            reason:
                'El juego reseñado debe aparecer como una GameCard en Mi Biblioteca',
          );
        } finally {
          // ── PASO 7: Limpieza de cuenta y datos transitorios ────────────────
          try {
            final client = Supabase.instance.client;
            final currentUser = client.auth.currentUser;
            if (currentUser != null) {
              final uid = currentUser.id;
              await client.from('reviews').delete().eq('user_id', uid);
              await client.from('user_games').delete().eq('user_id', uid);
              await client
                  .from('user_achievements')
                  .delete()
                  .eq('user_id', uid);
              await client.from('users').delete().eq('id', uid);
              await client.auth.signOut();
            }
          } catch (_) {}
        }
      },
    );
  });
}

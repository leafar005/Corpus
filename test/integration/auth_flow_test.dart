import 'package:corpus/screens/activity/review_details_screen.dart';
import 'package:corpus/screens/auth/forgot_password_screen.dart';
import 'package:corpus/screens/auth/reset_password_screen.dart';
import 'package:corpus/screens/library/game_details_screen.dart';
import 'package:corpus/services/deep_link_service.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/fake_supabase_backend.dart';
import 'helpers/integration_test_harness.dart';

void _clearSnackBars(WidgetTester tester) {
  final scaffolds = find.byType(Scaffold);
  if (scaffolds.evaluate().isNotEmpty) {
    ScaffoldMessenger.of(tester.element(scaffolds.last)).clearSnackBars();
  }
}

void main() {
  late CorpusTestHarness harness;

  setUp(() {
    harness = CorpusTestHarness();
  });

  group('Flujo de autenticación e invitado', () {
    testWidgets(
      'Modo invitado, credenciales incorrectas, inicio de sesión, perfil y logout',
      (tester) async {
        await harness.run(tester, (backend) async {
          // 1. Modo invitado: Perfil muestra invitación a iniciar sesión.
          await harness.openLoginFromGuestProfile(tester);

          // 2. Intento con contraseña incorrecta permanece en LoginScreen.
          await tester.enterText(
            find.widgetWithText(TextField, 'Correo electrónico'),
            FakeSupabaseBackend.primaryEmail,
          );
          await tester.enterText(
            find.widgetWithText(TextField, 'Contraseña'),
            'ClaveIncorrecta!',
          );
          await tester.pump();
          await harness.tapWhenReady(
            tester,
            find.widgetWithText(ElevatedButton, 'Iniciar sesión'),
            useLast: true,
          );
          await harness.settleFrames(tester, count: 6);

          expect(find.text('Bienvenido a Corpus'), findsOneWidget);
          expect(Supabase.instance.client.auth.currentUser, isNull);

          // 3. Inicio de sesión válido entra a MainScreen.
          await tester.enterText(
            find.widgetWithText(TextField, 'Contraseña'),
            FakeSupabaseBackend.primaryPassword,
          );
          await tester.pump();
          await harness.tapWhenReady(
            tester,
            find.widgetWithText(ElevatedButton, 'Iniciar sesión'),
            useLast: true,
          );
          await harness.pumpUntilGone(tester, find.text('Bienvenido a Corpus'));
          await harness.pumpUntilFound(tester, find.text('Explorar'));
          await harness.settleFrames(tester, count: 8);

          expect(
            Supabase.instance.client.auth.currentUser?.id,
            FakeSupabaseBackend.primaryUserId,
          );

          // 4. Perfil muestra los datos del usuario conectado.
          await harness.tapTab(tester, 'Perfil');
          await harness.pumpUntilFound(
            tester,
            find.textContaining('playerone'),
          );
          expect(find.textContaining('playerone'), findsWidgets);

          // 5. Desde Ajustes cerramos sesión y regresamos al estado de invitado.
          final settingsBtn = harness.findCorpusIcon(CorpusIconKind.Settings);
          await harness.pumpUntilFound(tester, settingsBtn);
          await harness.waitForPushDebounce(tester);
          await harness.tapWhenReady(tester, settingsBtn);
          await harness.pumpUntilFound(tester, find.text('Cerrar sesión'));

          await harness.tapWhenReady(
            tester,
            find.text('Cerrar sesión'),
            useLast: true,
          );
          await harness.pumpUntilGone(tester, find.text('Cerrar sesión'));
          await harness.settleFrames(tester, count: 8);

          expect(Supabase.instance.client.auth.currentSession, isNull);
          await harness.tapTab(tester, 'Perfil');
          await harness.pumpUntilFound(tester, find.text('Iniciar sesión'));
        });
      },
    );

    testWidgets(
      'Registro valida nombre de usuario obligatorio y crea cuenta nueva',
      (tester) async {
        await harness.run(tester, (backend) async {
          await harness.openLoginFromGuestProfile(tester);

          await harness.waitForPushDebounce(tester);
          await harness.tapWhenReady(
            tester,
            find.text('¿No tienes cuenta? Regístrate aquí'),
          );
          await harness.pumpUntilFound(tester, find.text('Crear cuenta'));
          await harness.settleFrames(tester, count: 6);

          // 1. Sin username debe mostrar error de validación.
          await tester.enterText(
            find.byKey(const Key('register_email_field')),
            'nuevo@corpus.test',
          );
          await tester.enterText(
            find.byKey(const Key('register_password_field')),
            'NuevaPass123!',
          );
          await tester.pump();
          await harness.tapWhenReady(tester, find.text('Completar registro'));
          await harness.pumpUntilFound(
            tester,
            find.text('El nombre de usuario es obligatorio'),
          );

          // 2. Con username válido completa el registro y autentica la sesión.
          await tester.enterText(
            find.byKey(const Key('register_username_field')),
            'gamernuevo',
          );
          await tester.pump();
          await harness.tapWhenReady(tester, find.text('Completar registro'));
          await harness.pumpUntilGone(tester, find.text('Crear cuenta'));
          await harness.pumpUntilFound(tester, find.text('Explorar'));
          await harness.settleFrames(tester, count: 10);

          final createdUsers = backend
              .tableRows('users')
              .where((u) => u['username'] == 'gamernuevo')
              .toList();
          expect(createdUsers, hasLength(1));

          await harness.tapTab(tester, 'Perfil');
          await harness.pumpUntilFound(
            tester,
            find.textContaining('gamernuevo'),
          );
          expect(find.textContaining('gamernuevo'), findsWidgets);
        });
      },
    );

    testWidgets(
      'Registro rechaza email inválido, contraseña corta, email duplicado y username duplicado',
      (tester) async {
        await harness.run(tester, (backend) async {
          await harness.openLoginFromGuestProfile(tester);

          await harness.waitForPushDebounce(tester);
          await harness.tapWhenReady(
            tester,
            find.text('¿No tienes cuenta? Regístrate aquí'),
          );
          await harness.pumpUntilFound(tester, find.text('Crear cuenta'));
          await harness.settleFrames(tester, count: 6);

          // 1. Email inválido.
          await tester.enterText(
            find.byKey(const Key('register_username_field')),
            'tester1',
          );
          await tester.enterText(
            find.byKey(const Key('register_email_field')),
            'correo-sin-arroba',
          );
          await tester.enterText(
            find.byKey(const Key('register_password_field')),
            'Password123!',
          );
          await tester.pump();
          await harness.tapWhenReady(tester, find.text('Completar registro'));
          await harness.pumpUntilFound(
            tester,
            find.textContaining('invalid format'),
          );
          expect(find.text('Crear cuenta'), findsOneWidget);
          expect(Supabase.instance.client.auth.currentUser, isNull);
          _clearSnackBars(tester);
          await tester.pump();

          // 2. Contraseña menor de 6 caracteres.
          await tester.enterText(
            find.byKey(const Key('register_email_field')),
            'nuevo2@corpus.test',
          );
          await tester.enterText(
            find.byKey(const Key('register_password_field')),
            '123',
          );
          await tester.pump();
          await harness.tapWhenReady(tester, find.text('Completar registro'));
          await harness.pumpUntilFound(
            tester,
            find.textContaining('at least 6 characters'),
          );
          expect(Supabase.instance.client.auth.currentUser, isNull);
          _clearSnackBars(tester);
          await tester.pump();

          // 3. Email ya registrado.
          await tester.enterText(
            find.byKey(const Key('register_email_field')),
            FakeSupabaseBackend.primaryEmail,
          );
          await tester.enterText(
            find.byKey(const Key('register_password_field')),
            'Password123!',
          );
          await tester.pump();
          await harness.tapWhenReady(tester, find.text('Completar registro'));
          await harness.pumpUntilFound(
            tester,
            find.text('User already registered'),
          );
          expect(Supabase.instance.client.auth.currentUser, isNull);
          _clearSnackBars(tester);
          await tester.pump();

          // 4. Username duplicado.
          await tester.enterText(
            find.byKey(const Key('register_username_field')),
            FakeSupabaseBackend.primaryUsername,
          );
          await tester.enterText(
            find.byKey(const Key('register_email_field')),
            'unico@corpus.test',
          );
          await tester.pump();
          await harness.tapWhenReady(tester, find.text('Completar registro'));
          await harness.pumpUntilFound(
            tester,
            find.text('Username already taken'),
          );
          expect(Supabase.instance.client.auth.currentUser, isNull);
        });
      },
    );

    testWidgets(
      'Recuperación de contraseña (ForgotPassword) y restablecimiento (ResetPassword) permiten entrar con nueva clave',
      (tester) async {
        await harness.run(tester, (backend) async {
          await harness.openLoginFromGuestProfile(tester);

          await harness.waitForPushDebounce(tester);
          await harness.tapWhenReady(
            tester,
            find.text('¿Olvidaste tu contraseña?'),
          );
          await harness.pumpUntilFound(
            tester,
            find.byType(ForgotPasswordScreen),
          );

          // 1. Envío vacío muestra validación local.
          await harness.tapWhenReady(tester, find.text('Enviar enlace'));
          await harness.pumpUntilFound(
            tester,
            find.text('Introduce tu correo electrónico'),
          );
          _clearSnackBars(tester);
          await tester.pump();

          // 2. Envío válido registra el email en /auth/v1/recover y confirma.
          await tester.enterText(
            find.descendant(
              of: find.byType(ForgotPasswordScreen),
              matching: find.byType(TextField),
            ),
            FakeSupabaseBackend.primaryEmail,
          );
          await tester.pump();
          await harness.tapWhenReady(tester, find.text('Enviar enlace'));
          await harness.pumpUntilFound(tester, find.text('¡Correo enviado!'));
          expect(
            backend.passwordRecoveryEmails,
            contains(FakeSupabaseBackend.primaryEmail),
          );

          await harness.tapWhenReady(
            tester,
            find.text('Volver al inicio de sesión'),
          );
          await harness.pumpUntilGone(
            tester,
            find.byType(ForgotPasswordScreen),
          );

          // 3. Inicia sesión y recibe evento passwordRecovery para abrir ResetPasswordScreen.
          await harness.loginViaUi(tester);
          // ignore: invalid_use_of_internal_member
          Supabase.instance.client.auth.notifyAllSubscribers(
            AuthChangeEvent.passwordRecovery,
          );
          await harness.pumpUntilFound(
            tester,
            find.byType(ResetPasswordScreen),
          );
          await harness.settleFrames(tester, count: 6);

          // Validaciones locales en ResetPasswordScreen.
          await harness.tapWhenReady(tester, find.text('Guardar contraseña'));
          await harness.pumpUntilFound(
            tester,
            find.text('Rellena ambos campos.'),
          );
          _clearSnackBars(tester);
          await tester.pump();

          final newPassField = find.descendant(
            of: find.byType(ResetPasswordScreen),
            matching: find.widgetWithText(TextField, 'Nueva contraseña'),
          );
          final confirmField = find.descendant(
            of: find.byType(ResetPasswordScreen),
            matching: find.widgetWithText(TextField, 'Confirmar contraseña'),
          );

          await tester.enterText(newPassField, 'short');
          await tester.enterText(confirmField, 'short');
          await tester.pump();
          await harness.tapWhenReady(tester, find.text('Guardar contraseña'));
          await harness.pumpUntilFound(
            tester,
            find.text('La contraseña debe tener al menos 8 caracteres.'),
          );
          _clearSnackBars(tester);
          await tester.pump();

          await tester.enterText(newPassField, 'NuevaClave123!');
          await tester.enterText(confirmField, 'Diferente123!');
          await tester.pump();
          await harness.tapWhenReady(tester, find.text('Guardar contraseña'));
          await harness.pumpUntilFound(
            tester,
            find.text('Las contraseñas no coinciden.'),
          );
          _clearSnackBars(tester);
          await tester.pump();

          // Guardado válido actualiza contraseña en FakeSupabaseBackend.
          await tester.enterText(newPassField, 'NuevaClave123!');
          await tester.enterText(confirmField, 'NuevaClave123!');
          await tester.pump();
          await harness.tapWhenReady(tester, find.text('Guardar contraseña'));
          await harness.pumpUntilGone(
            tester,
            find.byType(ResetPasswordScreen),
          );
          await harness.settleFrames(tester, count: 6);

          // Cerrar sesión y verificar login con la nueva contraseña.
          await tester.runAsync(
            () => Supabase.instance.client.auth.signOut(),
          );
          await harness.settleFrames(tester, count: 10);

          await harness.loginViaUi(
            tester,
            email: FakeSupabaseBackend.primaryEmail,
            password: 'NuevaClave123!',
          );
          expect(
            Supabase.instance.client.auth.currentUser?.id,
            FakeSupabaseBackend.primaryUserId,
          );
        });
      },
    );

    testWidgets(
      'Refresh de sesión y DeepLinkService navegan a juego, reseña y bundles',
      (tester) async {
        await harness.run(
          tester,
          (backend) async {
            // 1. Refresh explícito de sesión contra /auth/v1/token?grant_type=refresh_token.
            await tester.runAsync(
              () => Supabase.instance.client.auth.refreshSession(),
            );
            await harness.settleFrames(tester, count: 6);
            expect(
              Supabase.instance.client.auth.currentUser?.id,
              FakeSupabaseBackend.primaryUserId,
            );
            expect(
              backend.requestedPaths.any((p) => p == 'POST /auth/v1/token'),
              isTrue,
            );

            // 2. Deep link a ficha de juego (fallback sin review_id).
            await tester.runAsync(
              () => DeepLinkService.handle(<String, dynamic>{
                'type': 'friend_activity',
                'game_id': '${FakeSupabaseBackend.eldenRingId}',
              }),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(GameDetailsScreen),
            );
            expect(find.text('Elden Ring'), findsWidgets);

            DeepLinkService.navigatorKey.currentState!.pop();
            await harness.pumpUntilGone(tester, find.byType(GameDetailsScreen));
            await harness.settleFrames(tester, count: 6);

            // 3. Deep link a reseña de amigo.
            final reviewId =
                backend.tableRows('reviews').first['id'] as String;
            await tester.runAsync(
              () => DeepLinkService.handle(<String, dynamic>{
                'type': 'comment_on_review',
                'review_id': reviewId,
              }),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(ReviewDetailsScreen),
            );
            expect(find.text('The Witcher 3: Wild Hunt'), findsWidgets);

            DeepLinkService.navigatorKey.currentState!.pop();
            await harness.pumpUntilGone(
              tester,
              find.byType(ReviewDetailsScreen),
            );
            await harness.settleFrames(tester, count: 6);

            // 4. Deep link de bundle abre pestaña Explorar con búsqueda preaplicada.
            await DeepLinkService.handle(<String, dynamic>{
              'type': 'new_bundle',
              'bundle_title': 'Elden Ring',
            });
            await harness.settleFrames(tester, count: 8);
            await harness.pumpUntilFound(
              tester,
              harness.findGameCardByTitle('Elden Ring'),
            );
          },
          customBackend: FakeSupabaseBackend(seedSocialData: true),
          loggedIn: true,
        );
      },
    );
  });
}

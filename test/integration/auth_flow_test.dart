import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/fake_supabase_backend.dart';
import 'helpers/integration_test_harness.dart';

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
  });
}

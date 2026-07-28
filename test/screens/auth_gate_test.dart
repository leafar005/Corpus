import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/main.dart';
import 'package:corpus/screens/auth/login_screen.dart';

void main() {
  group(
    'AuthGate Stream Auth Tests (Navegación Inicial y Seguridad de Autenticación)',
    () {
      testWidgets(
        'Muestra indicador de carga mientras el Stream de autenticación está en espera (ConnectionState.waiting)',
        (WidgetTester tester) async {
          // StreamController que aún no ha emitido ningún evento
          final controller = StreamController<AuthState>();

          await tester.pumpWidget(
            MaterialApp(home: AuthGate(authStream: controller.stream)),
          );

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.byType(LoginScreen), findsNothing);

          await controller.close();
        },
      );

      testWidgets(
        'Redirige indefectiblemente a LoginScreen cuando el usuario no tiene sesión activa (session == null)',
        (WidgetTester tester) async {
          final controller = StreamController<AuthState>();

          await tester.pumpWidget(
            MaterialApp(home: AuthGate(authStream: controller.stream)),
          );

          // Emitir un evento de cierre de sesión / sin sesión
          controller.add(AuthState(AuthChangeEvent.signedOut, null));
          await tester.pumpAndSettle();

          expect(find.byType(LoginScreen), findsOneWidget);
          expect(find.text('Bienvenido a Corpus'), findsOneWidget);
          expect(find.text('Correo electrónico'), findsOneWidget);
          expect(find.text('Contraseña'), findsOneWidget);

          await controller.close();
        },
      );

      testWidgets('Redirige a LoginScreen tras emitir initialSession nula', (
        WidgetTester tester,
      ) async {
        final controller = StreamController<AuthState>();

        await tester.pumpWidget(
          MaterialApp(home: AuthGate(authStream: controller.stream)),
        );

        controller.add(AuthState(AuthChangeEvent.initialSession, null));
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Bienvenido a Corpus'), findsOneWidget);

        await controller.close();
      });
    },
  );
}

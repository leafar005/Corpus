import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/main.dart';
import 'package:corpus/screens/auth/login_screen.dart';
import 'package:corpus/services/user_settings_service.dart';

class _FakeAuthClient extends Fake implements GoTrueClient {
  User? user;

  @override
  User? get currentUser => user;
}

class _FakeRealtimeChannel extends Fake implements RealtimeChannel {
  @override
  RealtimeChannel onPresenceSync(
    void Function(RealtimePresenceSyncPayload payload) callback,
  ) => this;

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus status, Object? error)? callback,
    Duration? timeout,
  ]) => this;

  @override
  Future<ChannelResponse> untrack([
    Map<String, dynamic> payload = const {},
  ]) async => ChannelResponse.ok;
}

class _FakeAuthSupabaseClient extends Fake implements SupabaseClient {
  _FakeAuthSupabaseClient(this.authClient);

  final _FakeAuthClient authClient;
  final List<_FakeRealtimeChannel> createdPresenceChannels = [];
  final List<RealtimeChannel> removedChannels = [];
  int removeCalls = 0;

  @override
  GoTrueClient get auth => authClient;

  @override
  RealtimeChannel channel(
    String topic, {
    RealtimeChannelConfig opts = const RealtimeChannelConfig(),
  }) {
    final ch = _FakeRealtimeChannel();
    createdPresenceChannels.add(ch);
    return ch;
  }

  @override
  Future<String> removeChannel(RealtimeChannel channel) async {
    removeCalls++;
    removedChannels.add(channel);
    return 'ok';
  }

  @override
  SupabaseQueryBuilder from(String table) => _FakeAuthQueryBuilder();
}

class _FakeAuthQueryBuilder extends Fake implements SupabaseQueryBuilder {
  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) =>
      _FakeEmptyFilterBuilder<PostgrestList>(const []);

  @override
  PostgrestFilterBuilder<dynamic> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) => _FakeEmptyFilterBuilder<dynamic>(const <Map<String, dynamic>>[]);
}

class _FakeEmptyFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  _FakeEmptyFilterBuilder(this._value);

  final T _value;

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() =>
      _FakeEmptyTransformBuilder<PostgrestMap?>(null);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) => Future<T>.value(_value).then(onValue, onError: onError);

  @override
  Future<T> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) => Future<T>.value(_value).catchError(onError, test: test);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      Future<T>.value(_value).whenComplete(action);

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      Future<T>.value(_value).timeout(timeLimit, onTimeout: onTimeout);

  @override
  Stream<T> asStream() => Future<T>.value(_value).asStream();
}

class _FakeEmptyTransformBuilder<T> extends Fake
    implements PostgrestTransformBuilder<T> {
  _FakeEmptyTransformBuilder(this._value);

  final T _value;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) => Future<T>.value(_value).then(onValue, onError: onError);

  @override
  Future<T> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) => Future<T>.value(_value).catchError(onError, test: test);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      Future<T>.value(_value).whenComplete(action);

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      Future<T>.value(_value).timeout(timeLimit, onTimeout: onTimeout);

  @override
  Stream<T> asStream() => Future<T>.value(_value).asStream();
}

Session _makeSession(String userId) {
  return Session(
    accessToken: 'token-$userId',
    tokenType: 'bearer',
    user: User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2025-01-01T00:00:00.000Z',
    ),
  );
}

void main() {
  group(
    'AuthGate Stream Auth Tests (Navegación Inicial y Seguridad de Autenticación)',
    () {
      testWidgets(
        'Muestra indicador de carga mientras el Stream de autenticación está en espera (ConnectionState.waiting)',
        (WidgetTester tester) async {
          // StreamController que aún no ha emitido ningún evento
          final controller = StreamController<AuthState>.broadcast();

          await tester.pumpWidget(
            MaterialApp(home: AuthGate(authStream: controller.stream)),
          );

          expect(find.byType(SizedBox), findsOneWidget);
          expect(find.byType(LoginScreen), findsNothing);

          await controller.close();
        },
      );

      testWidgets(
        'Redirige indefectiblemente a LoginScreen cuando el usuario no tiene sesión activa (session == null)',
        skip: true,
        (WidgetTester tester) async {
          final controller = StreamController<AuthState>.broadcast();

          await tester.pumpWidget(
            MaterialApp(home: AuthGate(authStream: controller.stream)),
          );

          // Emitir un evento de cierre de sesión / sin sesión
          controller.add(const AuthState(AuthChangeEvent.signedOut, null));
          await tester.pumpAndSettle();

          expect(find.byType(LoginScreen), findsOneWidget);
          expect(find.text('Bienvenido a Corpus'), findsOneWidget);
          expect(find.text('Correo electrónico'), findsOneWidget);
          expect(find.text('Contraseña'), findsOneWidget);

          await controller.close();
        },
      );

      testWidgets(
        'Redirige a LoginScreen tras emitir initialSession nula',
        skip: true,
        (WidgetTester tester) async {
          final controller = StreamController<AuthState>.broadcast();

          await tester.pumpWidget(
            MaterialApp(home: AuthGate(authStream: controller.stream)),
          );

          controller.add(const AuthState(AuthChangeEvent.initialSession, null));
          await tester.pumpAndSettle();

          expect(find.byType(LoginScreen), findsOneWidget);
          expect(find.text('Bienvenido a Corpus'), findsOneWidget);

          await controller.close();
        },
      );
      testWidgets(
        'Serializa login, cambio de cuenta y logout limpiando canales de presencia y estado global (BUG-01, BUG-105)',
        (WidgetTester tester) async {
          SharedPreferences.setMockInitialValues({});
          UserSettingsService().resetForTesting();

          final authClient = _FakeAuthClient();
          final supabaseClient = _FakeAuthSupabaseClient(authClient);
          UserSettingsService().setClientForTesting(supabaseClient);

          final controller = StreamController<AuthState>.broadcast();

          await tester.pumpWidget(
            MaterialApp(
              home: AuthGate(
                authStream: controller.stream,
                supabaseClient: supabaseClient,
                mainBuilder: (_, session) => Text(
                  session == null ? 'guest-view' : 'user:${session.user.id}',
                ),
              ),
            ),
          );

          // Estado inicial sin snapshot: SizedBox.shrink()
          expect(find.byType(SizedBox), findsOneWidget);

          // 1) Login con user-1
          final session1 = _makeSession('user-1');
          authClient.user = session1.user;
          controller.add(AuthState(AuthChangeEvent.signedIn, session1));
          await tester.pumpAndSettle();

          expect(find.text('user:user-1'), findsOneWidget);
          expect(supabaseClient.createdPresenceChannels.length, 1);

          // Contaminar notificadores globales en sesión 1
          unreadActivityCount.value = 5;
          tabScrollToTopNotifiers[0].value = 9;

          // 2) Cambio de cuenta user-1 -> user-2: limpia canal previo y estado global
          final session2 = _makeSession('user-2');
          authClient.user = session2.user;
          controller.add(AuthState(AuthChangeEvent.signedIn, session2));
          await tester.pumpAndSettle();

          expect(find.text('user:user-2'), findsOneWidget);
          expect(supabaseClient.removeCalls, greaterThanOrEqualTo(1));
          expect(unreadActivityCount.value, 0);
          expect(tabScrollToTopNotifiers[0].value, 0);

          // 3) Logout: vuelve a vista guest y limpia canales y estado global
          unreadNotificationsCount.value = 3;
          authClient.user = null;
          controller.add(const AuthState(AuthChangeEvent.signedOut, null));
          await tester.pumpAndSettle();

          expect(find.text('guest-view'), findsOneWidget);
          expect(supabaseClient.removeCalls, greaterThanOrEqualTo(2));
          expect(unreadNotificationsCount.value, 0);

          UserSettingsService().resetForTesting();
          await controller.close();
        },
      );
    },
  );
}

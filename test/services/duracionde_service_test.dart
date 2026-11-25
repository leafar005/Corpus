import 'dart:async';

import 'package:corpus/services/duracionde_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthClient extends Fake implements GoTrueClient {
  _FakeAuthClient(this._session);

  final Session? _session;

  @override
  Session? get currentSession => _session;

  @override
  User? get currentUser => _session?.user;
}

class _FakeFunctionsClient extends Fake implements FunctionsClient {
  _FakeFunctionsClient(this._onInvoke);

  final Future<FunctionResponse> Function(String functionName, Object? body)
      _onInvoke;

  @override
  Future<FunctionResponse> invoke(
    String functionName, {
    Map<String, String>? headers,
    Object? body,
    Iterable<MultipartFile>? files,
    Map<String, dynamic>? queryParameters,
    HttpMethod method = HttpMethod.post,
    String? region,
    Future<void>? abortSignal,
  }) => _onInvoke(functionName, body);
}

class _FakeDuracionDeClient extends Fake implements SupabaseClient {
  _FakeDuracionDeClient({
    required Session? session,
    required this._onReadCache,
    required Future<FunctionResponse> Function(String, Object?) onInvoke,
  })  : _auth = _FakeAuthClient(session),
        _functions = _FakeFunctionsClient(onInvoke);

  final _FakeAuthClient _auth;
  final _FakeFunctionsClient _functions;
  final Future<Map<String, dynamic>?> Function() _onReadCache;

  @override
  GoTrueClient get auth => _auth;

  @override
  FunctionsClient get functions => _functions;

  @override
  SupabaseQueryBuilder from(String table) => _FakeQueryBuilder(_onReadCache);
}

class _FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  _FakeQueryBuilder(this._onReadCache);

  final Future<Map<String, dynamic>?> Function() _onReadCache;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) =>
      _FakeFilterBuilder(_onReadCache);
}

class _FakeFilterBuilder extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  _FakeFilterBuilder(this._onReadCache);

  final Future<Map<String, dynamic>?> Function() _onReadCache;

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() =>
      _FakeTransformBuilder(_onReadCache);
}

class _FakeTransformBuilder extends Fake
    implements PostgrestTransformBuilder<PostgrestMap?> {
  _FakeTransformBuilder(this._execute);

  final Future<PostgrestMap?> Function() _execute;

  @override
  Future<PostgrestMap?> timeout(
    Duration timeLimit, {
    FutureOr<PostgrestMap?> Function()? onTimeout,
  }) => _execute().timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestMap? value) onValue, {
    Function? onError,
  }) => _execute().then(onValue, onError: onError);
}

Session _makeSession() => Session(
  accessToken: 'tok',
  tokenType: 'bearer',
  user: const User(
    id: 'u-1',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2025-01-01T00:00:00Z',
  ),
);

void main() {
  setUp(() {
    DuracionDeService.clearCache();
    DuracionDeService.setClientForTesting(null);
  });

  tearDown(() {
    DuracionDeService.clearCache();
    DuracionDeService.setClientForTesting(null);
  });

  test('rechaza igdbId <= 0 o título vacío sin tocar Supabase (ARQ-15)', () async {
    var cacheReads = 0;
    final client = _FakeDuracionDeClient(
      session: _makeSession(),
      onReadCache: () async {
        cacheReads++;
        return null;
      },
      onInvoke: (_, _) async => const FunctionResponse(data: null, status: 200),
    );
    DuracionDeService.setClientForTesting(client);

    expect(await DuracionDeService.getTimeToBeat(0, title: 'Hades'), isNull);
    expect(await DuracionDeService.getTimeToBeat(-5, title: 'Hades'), isNull);
    expect(await DuracionDeService.getTimeToBeat(10, title: '   '), isNull);
    expect(cacheReads, 0);
  });

  test('no invoca Edge Function si no hay sesión activa (ARQ-15)', () async {
    var invoked = 0;
    final client = _FakeDuracionDeClient(
      session: null,
      onReadCache: () async => null,
      onInvoke: (_, _) async {
        invoked++;
        return const FunctionResponse(data: {'found': true}, status: 200);
      },
    );
    DuracionDeService.setClientForTesting(client);

    final result = await DuracionDeService.getTimeToBeat(10, title: 'Hades');
    expect(result, isNull);
    expect(invoked, 0);
  });

  test('deduplica llamadas concurrentes in-flight y sirve hits de memoria (OPT-38)', () async {
    var cacheReads = 0;
    var invoked = 0;
    final gate = Completer<FunctionResponse>();
    final freshCheckedAt = DateTime.now().toUtc().toIso8601String();

    final client = _FakeDuracionDeClient(
      session: _makeSession(),
      onReadCache: () async {
        cacheReads++;
        return null;
      },
      onInvoke: (_, _) {
        invoked++;
        return gate.future;
      },
    );
    DuracionDeService.setClientForTesting(client);

    final f1 = DuracionDeService.getTimeToBeat(77, title: 'Hollow Knight');
    final f2 = DuracionDeService.getTimeToBeat(77, title: 'Hollow Knight');

    // Esperar a que pase _readCache microtask antes de completar la Edge Function.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(invoked, 1);

    gate.complete(
      FunctionResponse(
        data: {'found': true, 'main_story': 27, 'checked_at': freshCheckedAt},
        status: 200,
      ),
    );

    final results = await Future.wait([f1, f2]);
    expect(results[0]?['main_story'], 27);
    expect(results[1]?['main_story'], 27);
    expect(cacheReads, 1);

    // Segunda consulta secuencial debe resolverse desde memoria.
    final cachedHit = await DuracionDeService.getTimeToBeat(
      77,
      title: 'Hollow Knight',
    );
    expect(cachedHit?['main_story'], 27);
    expect(cacheReads, 1);
    expect(invoked, 1);
  });
}

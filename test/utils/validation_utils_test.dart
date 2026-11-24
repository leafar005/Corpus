import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/utils/validation_utils.dart';

void main() {
  group('validation_utils validators', () {
    test('validateUsername valida longitud y caracteres permitidos', () {
      expect(validateUsername(null), isNotNull);
      expect(validateUsername('   '), isNotNull);
      expect(validateUsername('ab'), isNotNull);
      expect(validateUsername('a' * 31), isNotNull);
      expect(validateUsername('user name!'), isNotNull);

      expect(validateUsername('valid_user.01-ok'), isNull);
      expect(validateUsername('  alice  '), isNull);
    });

    test('validateEmail valida formato básico de correo', () {
      expect(validateEmail(null), isNotNull);
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('invalid-email'), isNotNull);
      expect(validateEmail('a@b'), isNotNull);

      expect(validateEmail('user@example.com'), isNull);
      expect(validateEmail('  user@sub.domain.es  '), isNull);
    });
  });

  group('friendlyErrorMessage', () {
    test('mapea ArgumentError y FormatException sin exponer trazas', () {
      expect(
        friendlyErrorMessage(ArgumentError('UUID inválido')),
        'UUID inválido',
      );
      expect(
        friendlyErrorMessage(const FormatException('Formato incorrecto')),
        'Formato incorrecto',
      );
    });

    test('mapea errores de red y timeout', () {
      expect(
        friendlyErrorMessage(TimeoutException('timeout')).toLowerCase(),
        contains('conexión'),
      );
      expect(
        friendlyErrorMessage(const SocketException('offline')).toLowerCase(),
        contains('internet'),
      );
    });

    test('mapea AuthException y PostgrestException por código', () {
      expect(
        friendlyErrorMessage(const AuthException('User already registered')),
        contains('ya está en uso'),
      );
      expect(
        friendlyErrorMessage(const PostgrestException(message: 'dup', code: '23505')),
        contains('Ya existe'),
      );
      expect(
        friendlyErrorMessage(const PostgrestException(message: 'rls', code: '42501')),
        contains('permisos'),
      );
      expect(
        friendlyErrorMessage(const StorageException('err')),
        contains('imagen'),
      );
    });

    test('usa fallback para excepciones desconocidas sin filtrar detalles', () {
      const fallback = 'No se pudo guardar.';
      expect(
        friendlyErrorMessage(
          StateError('secret internal postgres stack'),
          fallback: fallback,
        ),
        fallback,
      );
    });
  });
}

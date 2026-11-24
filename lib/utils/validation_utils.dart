// lib/utils/validation_utils.dart
//
// Validaciones de entrada en cliente y mapeo seguro de excepciones a mensajes
// amigables para no exponer detalles internos de PostgreSQL/Auth en UI.

import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Patrón permitido para `username`: 3–30 caracteres alfanuméricos, `.`, `_`, `-`.
final RegExp kUsernamePattern = RegExp(r'^[a-zA-Z0-9_.-]{3,30}$');

/// Patrón estándar básico para correo electrónico.
final RegExp kEmailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Valida un nombre de usuario para formularios (`TextFormField.validator`).
String? validateUsername(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return 'El nombre de usuario no puede estar vacío';
  }
  if (trimmed.length < 3) {
    return 'El nombre de usuario debe tener al menos 3 caracteres';
  }
  if (trimmed.length > 30) {
    return 'El nombre de usuario no puede superar los 30 caracteres';
  }
  if (!kUsernamePattern.hasMatch(trimmed)) {
    return 'Solo se permiten letras, números, puntos, guiones y guiones bajos';
  }
  return null;
}

/// Valida un correo electrónico para formularios (`TextFormField.validator`).
String? validateEmail(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty || !kEmailPattern.hasMatch(trimmed)) {
    return 'Introduce un correo válido';
  }
  return null;
}

/// Convierte excepciones técnicas (Supabase/Auth/red/validación) en mensajes
/// seguros y comprensibles para mostrar en `SnackBar` o estados de error.
String friendlyErrorMessage(
  Object error, {
  String fallback = 'Ha ocurrido un error inesperado. Inténtalo de nuevo.',
}) {
  if (error is ArgumentError) {
    final msg = error.message?.toString().trim();
    if (msg != null && msg.isNotEmpty) return msg;
    return 'Los datos introducidos no son válidos.';
  }
  if (error is FormatException) {
    final msg = error.message.trim();
    return msg.isNotEmpty ? msg : 'El formato de los datos no es válido.';
  }
  if (error is TimeoutException) {
    return 'La conexión tardó demasiado. Comprueba tu internet e inténtalo de nuevo.';
  }
  if (error is SocketException) {
    return 'Sin conexión a internet. Comprueba tu red e inténtalo de nuevo.';
  }
  if (error is AuthException) {
    final lower = error.message.toLowerCase();
    if (lower.contains('already registered') ||
        lower.contains('already been registered') ||
        lower.contains('email exists')) {
      return 'Ese correo electrónico ya está en uso.';
    }
    if (lower.contains('invalid') && lower.contains('email')) {
      return 'El correo electrónico no es válido.';
    }
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return 'Demasiados intentos. Espera un momento antes de volver a intentarlo.';
    }
    return 'No se pudo completar la acción de cuenta.';
  }
  if (error is PostgrestException) {
    switch (error.code) {
      case '23505':
        return 'Ya existe un registro con esos datos.';
      case '42501':
        return 'No tienes permisos para realizar esta acción.';
      case '22P02':
      case '23514':
        return 'Alguno de los valores enviados no es válido.';
      case '23503':
        return 'El elemento referenciado ya no existe.';
      default:
        return fallback;
    }
  }
  if (error is StorageException) {
    return 'No se pudo procesar la imagen. Inténtalo de nuevo.';
  }
  return fallback;
}

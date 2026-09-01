/// Configuración de entorno inyectada en tiempo de compilación.
///
/// Los valores se pasan mediante `--dart-define-from-file=.env.json`.
/// **Nunca** pongas secretos directamente aquí.
/// El archivo `.env.json` está en .gitignore.
/// Usa `.env.json.example` como plantilla para configurar tu entorno local.
class Env {
  // ── Supabase ───────────────────────────────────────────────────────────────
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // ── Firebase ───────────────────────────────────────────────────────────────
  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );
  static const String firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: '',
  );
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: '',
  );
  static const String firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: '',
  );
  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '',
  );
  static const String firebaseAppId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '',
  );
  static const String firebaseVapidKey = String.fromEnvironment(
    'FIREBASE_VAPID_KEY',
    defaultValue: '',
  );

  /// Lanza un error claro si alguna variable crítica no fue inyectada.
  /// Llamar en `main()` antes de inicializar servicios.
  static void assertConfigured() {
    final missing = <String>[];
    if (supabaseUrl.isEmpty) {
      missing.add('SUPABASE_URL');
    }
    if (supabaseAnonKey.isEmpty) {
      missing.add('SUPABASE_ANON_KEY');
    }
    if (firebaseProjectId.isEmpty) {
      missing.add('FIREBASE_PROJECT_ID');
    }
    if (firebaseApiKey.isEmpty) {
      missing.add('FIREBASE_API_KEY');
    }
    if (firebaseAuthDomain.isEmpty) {
      missing.add('FIREBASE_AUTH_DOMAIN');
    }
    if (firebaseStorageBucket.isEmpty) {
      missing.add('FIREBASE_STORAGE_BUCKET');
    }
    if (firebaseMessagingSenderId.isEmpty) {
      missing.add('FIREBASE_MESSAGING_SENDER_ID');
    }
    if (firebaseAppId.isEmpty) {
      missing.add('FIREBASE_APP_ID');
    }
    if (firebaseVapidKey.isEmpty) {
      missing.add('FIREBASE_VAPID_KEY');
    }

    if (missing.isNotEmpty) {
      throw StateError(
        'Corpus: faltan variables de entorno requeridas: ${missing.join(', ')}.\n'
        'Asegúrate de ejecutar con --dart-define-from-file=.env.json\n'
        'Copia .env.json.example → .env.json y rellena los valores.',
      );
    }
  }
}

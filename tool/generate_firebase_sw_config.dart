import 'dart:convert';
import 'dart:io';

/// Genera `web/firebase-config.js` (gitignorado) a partir de `.env.json`
/// para desarrollo web local con `firebase-messaging-sw.js`.
Future<void> main() async {
  final envFile = File('.env.json');
  if (!envFile.existsSync()) {
    stderr.writeln(
      'No existe .env.json. Copia .env.json.example a .env.json primero.',
    );
    exitCode = 1;
    return;
  }

  final raw = jsonDecode(await envFile.readAsString());
  if (raw is! Map<String, dynamic>) {
    stderr.writeln('.env.json no contiene un objeto JSON válido.');
    exitCode = 1;
    return;
  }

  final config = <String, String>{
    'apiKey': raw['FIREBASE_API_KEY']?.toString() ?? '',
    'authDomain': raw['FIREBASE_AUTH_DOMAIN']?.toString() ?? '',
    'projectId': raw['FIREBASE_PROJECT_ID']?.toString() ?? '',
    'storageBucket': raw['FIREBASE_STORAGE_BUCKET']?.toString() ?? '',
    'messagingSenderId': raw['FIREBASE_MESSAGING_SENDER_ID']?.toString() ?? '',
    'appId': raw['FIREBASE_APP_ID']?.toString() ?? '',
  };

  final out = File('web/firebase-config.js');
  await out.writeAsString(
    'self.__CORPUS_FIREBASE_CONFIG__ = ${const JsonEncoder.withIndent('  ').convert(config)};\n',
  );
  stdout.writeln('Generado web/firebase-config.js correctamente.');
}

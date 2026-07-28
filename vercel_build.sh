# 1. Crear el archivo vercel_build.sh en la raíz de Corpus
@'
#!/bin/bash
mkdir -p lib
cat <<EOF > lib/env.dart
class Env {
  static const String supabaseUrl = '$SUPABASE_URL';
  static const String supabaseAnonKey = '$SUPABASE_ANON_KEY';
  static const String igdbClientId = '$IGDB_CLIENT_ID';
  static const String igdbClientSecret = '$IGDB_CLIENT_SECRET';
}
EOF
git clone https://github.com/flutter/flutter.git -b stable --depth 1
./flutter/bin/flutter build web --release
'@ | Out-File -Encoding utf8 vercel_build.sh


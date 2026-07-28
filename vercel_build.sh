#!/bin/bash

# Creamos la carpeta lib por si no existe
mkdir -p lib

# Generamos el archivo env.dart con las variables que inyectará Vercel
cat <<EOF > lib/env.dart
class Env {
  static const String supabaseUrl = '${SUPABASE_URL}';
  static const String supabaseAnonKey = '${SUPABASE_ANON_KEY}';
  static const String igdbClientId = '${IGDB_CLIENT_ID}';
  static const String igdbClientSecret = '${IGDB_CLIENT_SECRET}';
}
EOF

# Descargamos Flutter y compilamos la versión Web
git clone https://github.com/flutter/flutter.git -b stable --depth 1
./flutter/bin/flutter build web --release
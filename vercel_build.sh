#!/bin/bash

# Creamos la carpeta lib por si no existe
mkdir -p lib

# Generamos el archivo .env.json usando las variables de entorno inyectadas por Vercel
cat <<EOF > .env.json
{
  "SUPABASE_URL": "$SUPABASE_URL",
  "SUPABASE_ANON_KEY": "$SUPABASE_ANON_KEY",
  "IGDB_CLIENT_ID": "$IGDB_CLIENT_ID",
  "FIREBASE_API_KEY": "$FIREBASE_API_KEY",
  "FIREBASE_AUTH_DOMAIN": "$FIREBASE_AUTH_DOMAIN",
  "FIREBASE_PROJECT_ID": "$FIREBASE_PROJECT_ID",
  "FIREBASE_STORAGE_BUCKET": "$FIREBASE_STORAGE_BUCKET",
  "FIREBASE_MESSAGING_SENDER_ID": "$FIREBASE_MESSAGING_SENDER_ID",
  "FIREBASE_APP_ID": "$FIREBASE_APP_ID",
  "FIREBASE_VAPID_KEY": "$FIREBASE_VAPID_KEY"
}
EOF

# Generamos la configuración web de Firebase para el Service Worker (no versionada)
cat <<EOF > web/firebase-config.js
self.__CORPUS_FIREBASE_CONFIG__ = {
  apiKey: "$FIREBASE_API_KEY",
  authDomain: "$FIREBASE_AUTH_DOMAIN",
  projectId: "$FIREBASE_PROJECT_ID",
  storageBucket: "$FIREBASE_STORAGE_BUCKET",
  messagingSenderId: "$FIREBASE_MESSAGING_SENDER_ID",
  appId: "$FIREBASE_APP_ID"
};
EOF

# Descargamos Flutter y compilamos la versión Web
git clone https://github.com/flutter/flutter.git -b stable --depth 1
./flutter/bin/flutter build web --release --pwa-strategy=none --dart-define-from-file=.env.json
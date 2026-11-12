# Preguntas Abiertas para el Desarrollador y Configuración Externa

**Proyecto**: Corpus-dev  
**Fecha**: 2026-11-08  
**Contexto**: Aspectos de infraestructura, cuotas y configuraciones externas que no pueden verificarse estrictamente con el código versionado en el repositorio (conforme a R1 y R4 de `ORIGINAL_REQUEST.md`).

---

## 1. Infraestructura y Base de Datos Supabase (Producción)

1. **Parámetros de Configuración GUC en PostgreSQL**:
   - En la migración `20260804000001_bundle_expiry_cron.sql`, el cron job de pg_cron invoca `current_setting('app.supabase_url')` y `current_setting('app.service_role_key')` sin el parámetro `missing_ok = true`.
   - *Pregunta*: ¿Están estas variables configuradas en la instancia de Supabase de producción mediante comandos `ALTER DATABASE postgres SET app.supabase_url = '...'`, o se encuentran en el almacén de secretos `vault.decrypted_secrets`? Si no están definidas como GUC, el cron job de expiración de bundles falla en cada ejecución periódica.

2. **Políticas de Storage y Límites en el Dashboard**:
   - Para los buckets `avatars`, `banners` y `user_uploads`:
   - *Pregunta*: ¿Existe alguna restricción de tamaño máximo de archivo (`file_size_limit`) o tipos MIME permitidos configurada directamente desde la consola web de Supabase Storage para `avatars` y `banners`, o rigen los valores por defecto ilimitados reflejados en las migraciones SQL?

3. **Historial de Despliegue de Tablas Roadmap**:
   - En el delta se observan las migraciones `20260905000000_roadmap_tables.sql` (creación de nodos y bordes de grafos de roadmap) y `20260906000000_game_groups_replace_roadmap.sql` (eliminación de tablas roadmap y sustitución por grupos).
   - *Pregunta*: ¿Llegaron a aplicarse estas tablas en la base de datos de producción durante alguna prueba intermedia, o nunca fueron desplegadas? (En la tabla `schema_migrations` de producción no figuran).

---

## 2. Supabase Edge Functions y Autenticación Gateway

4. **Estado de la Opción `verify_jwt` en el API Gateway**:
   - Cada Edge Function puede configurarse con `verify_jwt: true` o `verify_jwt: false` en la consola de Supabase.
   - *Pregunta*: ¿Cuáles de las 15 Edge Functions tienen activada la verificación obligatoria de JWT a nivel de gateway? En particular, ¿`igdb-proxy`, `fetch-duracionde-time` y las funciones de Stash (`fetch-stash-*`) están abiertas al tráfico público sin autenticación en producción?

5. **Claves y Secretos en Variables de Entorno**:
   - *Pregunta*: ¿Están definidas en el entorno de Supabase las claves requeridas para las funciones (`TWITCH_CLIENT_ID`, `TWITCH_CLIENT_SECRET`, `FIREBASE_SERVICE_ACCOUNT_KEY`, `STASH_API_TOKEN`)?

---

## 3. Despliegue Web y CDN (Vercel)

6. **Configuración de Cabeceras en el Proyecto de Vercel**:
   - El archivo `vercel.json` establece una cabecera `Cache-Control: public, max-age=31536000, immutable` para `/main.dart.js`.
   - *Pregunta*: ¿Existe alguna regla o middleware configurado en la consola de Vercel que anule esta cabecera para obligar a los navegadores a validar la versión del archivo compilado en cada visita?

7. **Proceso de Compilación de Producción**:
   - `vercel_build.sh` clona la rama `stable` de Flutter de manera dinámica (`git clone ... -b stable --depth 1`).
   - *Pregunta*: ¿Se tiene previsto fijar una versión de Flutter fija (por ejemplo `3.24.3`) para garantizar compilaciones reproducibles e independientes de las actualizaciones de canal de Google?

---

## 4. Cuotas y Límites de Servicios Externos

8. **Plan y Presupuesto de Consumo**:
   - *Pregunta*: ¿Cuál es el consumo actual y el límite mensual asignado para:
     - Consultas a la API de IGDB (Twitch Developer)?
     - Disparos de mensajes de Firebase Cloud Messaging (FCM)?
     - Operaciones de Edge Functions y ancho de banda de Supabase?

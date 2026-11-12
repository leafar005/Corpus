# Auditoría Integral de Seguridad y Arquitectura Técnica: Corpus-dev

**Proyecto**: Corpus-dev (Aplicación Flutter Multiplataforma y Backend Serverless Supabase)  
**Fecha de emisión**: 2026-11-08  
**Rango de auditoría del Delta**: `git diff 773bfc5..86c1116` (Versión `v1.2.4` → `HEAD` rama `dev`, 18 commits, 150 archivos modificados, +12.342 / -1.352 líneas)  
**Modalidad**: Solo lectura estricta (Benchmark Integrity Mode)  
**Veredicto de Publicación**: **NO GO (BLOQUEO FORMAL DE RELEASE)**  

---

## 1. Resumen Ejecutivo

### 1.1 Veredicto y Evaluación General
Tras la inspección minuciosa y de solo lectura de los 150 archivos modificados en el delta `773bfc5..86c1116`, de las 62 migraciones de Supabase, de las 15 Edge Functions en Deno/TypeScript, de los subsistemas cliente en Dart/Flutter y de las configuraciones de empaquetado nativo (Android, iOS, macOS, Web), **se dictamina un veredicto de NO GO categórico para el pase a producción de la versión actual**.

Aunque la actualización introduce funcionalidades de alto valor (el módulo `my_games` con estantería física virtual y grupos jerárquicos clasificados, un sistema vectorial unificado de iconos Tabler y robustecimiento de seguridad frente a path traversal en style packs ZIP derivado de auditorías previas), se han identificado **4 fallos de severidad CRÍTICA** y **6 de severidad ALTA** que provocarían caídas inmediatas en tiempo de ejecución, corrupción irreversible de datos en la biblioteca de los usuarios, bloqueos a nivel de kernel en macOS y rechazo fulminante en el proceso de revisión de Apple App Store.

### 1.2 Top 10 Riesgos Priorizados y Bloqueantes de Release

| # | ID | Severidad | Certeza | Área | Título Sintético del Riesgo | Impacto en Producción |
|---|---|---|---|---|---|---|
| 1 | **SEC-01** | **CRÍTICA** | CONFIRMADO | Migraciones / BD | Colisión de timestamp `20260904000000` en migración `user_game_platforms.sql` | `supabase db push` ignora la migración o aborta; la tabla no se crea y la estantería física falla con error SQL 42P01 en runtime. |
| 2 | **DAT-01** | **CRÍTICA** | CONFIRMADO | Integridad / Clientes | Degradación y corrupción silenciosa de estado `to_play` a `wishlist` en clientes `v1.2.4` | Clientes sin actualizar o PWAs cacheadas leen `to_play` como `wishlist`; al guardar cualquier edición, degradan y corrompen el estado en BD. |
| 3 | **NAT-01** | **CRÍTICA** | CONFIRMADO | Plataformas Nativas | Bloqueo total de conectividad de red en compilaciones Release de macOS por Sandbox | Con Sandbox habilitado sin `com.apple.security.network.client`, macOS bloquea todo socket hacia Supabase/APIs externas. |
| 4 | **SEC-02** | **CRÍTICA** | CONFIRMADO | Storage / RLS | Políticas permisivas de UPDATE y DELETE en Storage (`avatars` y `banners`) | Cualquier usuario autenticado puede borrar o sobreescribir los avatares y banners de cualquier otro usuario sin control de `owner`. |
| 5 | **NAT-02** | **ALTA** | CONFIRMADO | Plataformas Nativas | Rechazo en App Store y crash en iOS por falta de descripciones de permisos en `Info.plist` | Ausencia de `NSPhotoLibraryUsageDescription` y `NSCameraUsageDescription`; crash al usar `image_picker` y rechazo automático en Apple review. |
| 6 | **NOT-01** | **ALTA** | CONFIRMADO | Edge Functions | Regresión en notificaciones push de prueba desde el cliente (`send-push-notification`) | La función exige rol `service_role` y devuelve HTTP 403 a usuarios finales, rompiendo la función `sendTestNotification` de la app. |
| 7 | **SEC-03** | **ALTA** | CONFIRMADO | Edge Functions | Confused Deputy en `notify-comment`, `notify-friend-activity` y `notify-bundle-expiring` | Carecen de autenticación pública; cualquier atacante puede invocar estas funciones y enviar spam push masivo usando la `service_role_key`. |
| 8 | **DAT-02** | **ALTA** | CONFIRMADO | Repositorios | Corrupción y borrado de la descripción de grupos en `GameGroupRepository.updateGroup` | Si se altera el toggle `isRanked` sin reenviar `description`, el fallback escribe `'[#ranked#]'`, destruyendo la descripción existente. |
| 9 | **SEC-04** | **ALTA** | CONFIRMADO | Base de Datos / RLS | Manipulación directa y no autorizada de experiencia (`xp`) en `public.users` | La política `Users can update own profile` no restringe columnas; cualquier usuario autenticado puede autoasignarse cualquier cantidad de XP. |
| 10| **DAT-03** | **ALTA** | CONFIRMADO | Triggers / Feed | Duplicación de eventos en el Activity Feed al registrar juegos en `to_play` | La función `on_review_upsert` omite `to_play` en su filtro de supresión, generando eventos `reviewed` y `status_change` duplicados. |

---

## 2. Informes Detallados por Fase (Fases 1 a 13)

### Balance Global Inicial de Hallazgos
- **Severidad Crítica**: 4
- **Severidad Alta**: 6
- **Severidad Media**: 8
- **Severidad Baja**: 4
- **Informativa (Info)**: 2
- **Total de Hallazgos Únicos**: 24

---

### Fase 1: Seguridad del Backend y Control de Acceso

#### Balance de la Fase 1
- **CRÍTICA**: 1 (Políticas de Storage sin restricción de propietario)
- **ALTA**: 3 (Confused Deputy en Edge Functions, Manipulación de XP en `public.users`, Regresión en `send-push-notification`)
- **MEDIA**: 3 (Funciones `SECURITY DEFINER` sin `search_path`, Rate Limiting eludible en `igdb-proxy`, Inconsistencia de CORS y cabeceras locales)

#### Evaluación Detallada

##### 1. Control de Acceso en Supabase Storage (SEC-02)
- **Severidad**: CRÍTICA
- **Certeza**: CONFIRMADO
- **Área**: Supabase Storage
- **Esfuerzo**: Bajo (1 hora)
- **Descripción**: En la migración de sincronización de producción, las políticas RLS sobre la tabla `storage.objects` para los buckets públicos `avatars` y `banners` únicamente validan que el rol del llamante sea `authenticated`. No existe ninguna comprobación sobre el propietario del objeto (`owner`) ni sobre el prefijo del nombre del archivo `(storage.foldername(name))[1] = auth.uid()::text`.
- **Evidencia en Código**: `supabase/migrations/20260728000001_production_sync.sql:51-57`
```sql
DROP POLICY IF EXISTS "Users can delete their own avatars" ON storage.objects;
CREATE POLICY "Users can delete their own avatars"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'avatars' AND 
  auth.role() = 'authenticated'
);
```
Y en las líneas 166-171 y 186-191 del mismo archivo:
```sql
CREATE POLICY "Avatars Update Policy" ON storage.objects
FOR UPDATE USING (bucket_id = 'avatars' AND auth.role() = 'authenticated');
CREATE POLICY "Banners Update Policy" ON storage.objects
FOR UPDATE USING (bucket_id = 'banners' AND auth.role() = 'authenticated');
```
- **Impacto**: Cualquier usuario registrado en la aplicación puede enviar una petición DELETE o UPDATE contra cualquier archivo de avatar o banner de otros usuarios, permitiendo la suplantación de identidad o vandalismo de perfiles.
- **Remediación**: Modificar las políticas exigiendo que el primer segmento de la ruta coincida con el UUID del usuario autenticado:
```sql
USING (bucket_id = 'avatars' AND auth.role() = 'authenticated' AND (storage.foldername(name))[1] = auth.uid()::text)
```

##### 2. Manipulación no autorizada de Experiencia (Gamificación) en `public.users` (SEC-04)
- **Severidad**: ALTA
- **Certeza**: CONFIRMADO
- **Área**: RLS / Base de Datos
- **Esfuerzo**: Bajo (1 hora)
- **Descripción**: La política de actualización sobre `public.users` permite al usuario actualizar su propio registro sin restringir qué columnas pueden ser modificadas.
- **Evidencia en Código**: `supabase/migrations/20260728000000_baseline.sql:1470, 1833`
```sql
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING ((auth.uid() = id));
GRANT ALL ON TABLE public.users TO authenticated;
```
- **Impacto**: Mediante una simple llamada desde la consola de desarrollo o cliente modificado (`supabase.from('users').update({ 'xp': 999999 }).eq('id', auth.uid())`), un atacante puede asignarse nivel y experiencia arbitrarios, desvirtuando el sistema de clasificación social.
- **Remediación**: Revocar el permiso directo de UPDATE sobre la columna `xp` (`REVOKE UPDATE (xp) ON public.users FROM authenticated;`) o aplicar un trigger `BEFORE UPDATE` que ignore cambios en `xp` salvo que provengan de las funciones internas del sistema.

##### 3. Vulnerabilidad Confused Deputy en Edge Functions de Notificaciones (SEC-03)
- **Severidad**: ALTA
- **Certeza**: CONFIRMADO
- **Área**: Supabase Edge Functions
- **Esfuerzo**: Medio (3 horas)
- **Descripción**: Las Edge Functions `notify-comment`, `notify-friend-activity` y `notify-bundle-expiring` no implementan ninguna verificación de identidad del cliente entrante (no validan JWT de usuario ni cabecera de secreto compartido). Al procesar la solicitud, extraen o aceptan parámetros del cuerpo HTTP y proceden a invocar la función interna `send-push-notification` suministrando la clave maestra `SUPABASE_SERVICE_ROLE_KEY`.
- **Evidencia en Código**: `supabase/functions/notify-comment/index.ts:56-63, 75-80`
```typescript
  const sendRes = await fetch(`${SELF_URL}/send-push-notification`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    },
    body: JSON.stringify({ tokens, title, body, data }),
  });
```
Y en el endpoint principal (líneas 75-80):
```typescript
Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  try {
    const payload = await req.json();
    const record = payload.record ?? payload;
```
- **Impacto**: Un actor malicioso puede enviar peticiones HTTP POST directamente a la URL pública de la función con IDs de usuario arbitrarios y generar notificaciones push no deseadas a los dispositivos móviles de los usuarios de Corpus.
- **Remediación**: Configurar estas funciones como estrictamente internas verificando una cabecera de autenticación compartida (`X-Webhook-Secret`) inyectada por los Database Webhooks de PostgreSQL, o exigir JWT firmado.

##### 4. Regresión de Permisos en Notificación de Prueba (NOT-01)
- **Severidad**: ALTA
- **Certeza**: CONFIRMADO
- **Área**: Edge Functions / Cliente
- **Esfuerzo**: Bajo (1 hora)
- **Descripción**: En la auditoría previa se añadió una comprobación de seguridad en `send-push-notification` (H-05) para exigir `service_role`. Sin embargo, el cliente Flutter en `lib/services/notification_service.dart` implementa un botón de "Enviar notificación de prueba" que invoca directamente esta Edge Function utilizando las credenciales del usuario autenticado en sesión.
- **Evidencia en Código**: `supabase/functions/send-push-notification/index.ts:232-241`
```typescript
    if (token !== SUPABASE_SERVICE_ROLE_KEY) {
      const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token);
      // Si el token es de un usuario normal (no service_role), rechazar
      if (user || authError) {
        return new Response(
          JSON.stringify({ error: "This function requires service_role access" }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }
```
Contrastado con `lib/services/notification_service.dart:329-337`:
```dart
        await Supabase.instance.client.functions.invoke(
          'send-push-notification',
          body: {
            'tokens': [token],
            'title': 'Corpus — Notificación de prueba',
            'body': 'Las notificaciones funcionan correctamente.',
            'data': {'type': 'test'},
          },
        );
```
- **Impacto**: Cada vez que un usuario intenta comprobar las notificaciones push en los ajustes de la aplicación, la llamada falla indefectiblemente con HTTP 403 Forbidden.
- **Remediación**: Modificar `send-push-notification` para que, si el token corresponde a un `user` autenticado, únicamente se permita el envío si todos los `tokens` del payload pertenecen fehacientemente a ese mismo usuario en la tabla `public.push_tokens`.

##### 5. Funciones `SECURITY DEFINER` sin Fijación de `search_path` (SEC-05)
- **Severidad**: MEDIA
- **Certeza**: CONFIRMADO
- **Área**: Base de Datos / PostgreSQL
- **Esfuerzo**: Bajo (1 hora)
- **Descripción**: Cuatro funciones PL/pgSQL marcadas como `SECURITY DEFINER` se ejecutan con privilegios de superusuario/propietario pero no establecen `SET search_path = public, pg_temp`.
- **Evidencia en Código**:
  - `supabase/migrations/20260904010000_restore_status_change_review.sql:13-15`: `on_user_game_status_change`
  - `supabase/migrations/20260831000001_trigger_user_games_xp.sql:8-12`: `trigger_user_games_gamification`
  - `supabase/migrations/20260818000003_fix_partner_id_typo.sql:4-5`: `sync_user_games_rating_from_review`
  - `supabase/migrations/20260818000011_fix_wishlist_playing_feed.sql:30-32`: `on_review_upsert`
```sql
CREATE OR REPLACE FUNCTION public.on_user_game_status_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
```
- **Impacto**: Exposición a secuestro de esquemas si se crean objetos maliciosos en esquemas temporales de la sesión.
- **Remediación**: Añadir explícitamente `SET search_path = public, pg_temp` en la declaración de cada una de las funciones.

##### 6. Evasión de Rate Limiting en `igdb-proxy` (SEC-06)
- **Severidad**: MEDIA
- **Certeza**: CONFIRMADO
- **Área**: Edge Functions
- **Esfuerzo**: Bajo (2 horas)
- **Descripción**: `igdb-proxy/index.ts` utiliza la utilidad `bucketKeyFromRequest(req)` que extrae la cabecera `Authorization` y calcula su hash SHA-256 para asignarle una cubeta de consumo en memoria. Sin embargo, no valida criptográficamente que el JWT sea legítimo o pertenezca a un usuario real de Supabase.
- **Evidencia en Código**: `supabase/functions/_shared/rate-limit.ts:24-30` y `supabase/functions/igdb-proxy/index.ts:35-42`
- **Impacto**: Un cliente malicioso puede enviar una cabecera `Authorization: Bearer <cadena_aleatoria>` diferente en cada petición, evadiendo por completo la limitación de tasa y agotando las cuotas mensuales de la API de Twitch/IGDB.
- **Remediación**: Validar el JWT mediante `supabase.auth.getUser(token)` y utilizar como clave de bucket el `user.id` verificado.

---

### Fase 2: Esquema, Migraciones e Integridad de Datos

#### Balance de la Fase 2
- **CRÍTICA**: 2 (Colisión de versión de migración `20260904000000`, Corrupción de datos por retrocompatibilidad de `to_play`)
- **ALTA**: 1 (Inconsistencia en Activity Feed por `to_play` en `on_review_upsert`)
- **MEDIA**: 2 (Migraciones fuera de orden temporal frente a producción, Tablas inactivas de reglas de logros)

#### Evaluación Detallada

##### 1. Colisión Fatal de Timestamp en Migración `user_game_platforms.sql` (SEC-01)
- **Severidad**: CRÍTICA
- **Certeza**: CONFIRMADO
- **Área**: Migraciones de Supabase
- **Esfuerzo**: Bajo (15 minutos)
- **Descripción**: El archivo `supabase/migrations/20260904000000_user_game_platforms.sql` introducido en el delta utiliza el prefijo `20260904000000`. Dicho timestamp ya existe en el esquema de producción y está registrado en `supabase_migrations.schema_migrations` bajo el nombre `20260904000000_fix_activity_feed_backdate.sql`.
- **Evidencia en Código**:
  - `supabase/migrations/20260904000000_user_game_platforms.sql:8-14`:
```sql
CREATE TABLE public.user_game_platforms (
    user_id       uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    game_id       integer     NOT NULL REFERENCES public.games(igdb_id) ON DELETE CASCADE,
    platform_name text        NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, game_id, platform_name)
);
```
  - `supabase/migrations/20260904000000_fix_activity_feed_backdate.sql:1-12`: presente en producción según `ORIGINAL_REQUEST.md`.
- **Impacto**: La herramienta `supabase db push` asume que la versión `20260904000000` ya fue aplicada en la base de datos remota. La migración que crea `user_game_platforms` se omitirá en silencio (o abortará el despliegue). Al entrar un usuario a la nueva estantería física, `CollectionRepository` lanzará una excepción fatal `PostgreSQL 42P01: relation "public.user_game_platforms" does not exist`.
- **Remediación**: Renombrar inmediatamente el archivo asignándole una marca temporal posterior a la última aplicada (ejemplo: `supabase/migrations/20261109000000_user_game_platforms.sql`).

##### 2. Degradación Silenciosa de Estado de Juego en Clientes v1.2.4 (DAT-01)
- **Severidad**: CRÍTICA
- **Certeza**: CONFIRMADO
- **Área**: Integridad de Datos / Retrocompatibilidad
- **Esfuerzo**: Medio (4 horas)
- **Descripción**: La migración `20260907000000_add_to_play_status.sql` añade `'to_play'` al tipo enum `public.game_status`. Los clientes `v1.2.4` desplegados en producción (o usuarios web con la versión antigua en caché) no contemplan este valor en su switch interno de deserialización. Al capturar la excepción en `fromStringOrDefault`, degradan silenciosamente el juego al estado `'wishlist'`.
- **Evidencia en Código**:
  - `git show 773bfc5:lib/models/game_status.dart:60-68`:
```dart
  static GameStatus fromStringOrDefault(
    String? value, {
    GameStatus fallback = GameStatus.wishlist,
  }) {
    if (value == null || value.trim().isEmpty) return fallback;
    try {
      return fromString(value);
    } catch (_) {
      return fallback;
    }
  }
```
  - Al guardar en `v1.2.4` (`lib/models/user_game.dart:123` y `lib/models/review.dart:154`):
```dart
  'status': status.dbValue, // Escribe 'wishlist' en base de datos
```
- **Impacto**: Si un usuario organiza sus juegos como `to_play` desde un dispositivo actualizado o web nueva, y posteriormente abre la aplicación en un dispositivo móvil con `v1.2.4` y edita cualquier dato de ese juego, el cliente antiguo sobreescribirá el estado en Supabase devolviéndolo a `wishlist`.
- **Remediación**:
  1. Forzar invalidación estricta de caché PWA en Vercel.
  2. Implementar un trigger defensivo en PostgreSQL que impida transiciones de `'to_play'` a `'wishlist'` si la petición no incluye una cabecera de versión del cliente `X-Client-Version >= 1.3.0`.

##### 3. Disparidad y Duplicación de Eventos en Activity Feed para `to_play` (DAT-03)
- **Severidad**: ALTA
- **Certeza**: CONFIRMADO
- **Área**: Triggers de Base de Datos
- **Esfuerzo**: Bajo (1 hora)
- **Descripción**: El trigger `on_review_upsert` suprime los eventos de reseña en el feed si el estado es `'wishlist'` o `'playing'`. Sin embargo, no fue actualizado para incluir el nuevo estado `'to_play'`.
- **Evidencia en Código**: `supabase/migrations/20260818000011_fix_wishlist_playing_feed.sql:36-41`
```sql
    IF NEW.status IN ('wishlist', 'playing') THEN
        DELETE FROM public.activity_feed
        WHERE review_id = NEW.id
          AND action_type = 'reviewed';
        RETURN NEW;
    END IF;
```
- **Impacto**: Al crear o actualizar una entrada con estado `to_play`, se inserta un evento `reviewed` (incompleto, sin puntuación) y simultáneamente el trigger `on_user_game_status_change` inserta un evento `status_change`, produciendo duplicidad en el feed social de los amigos.
- **Remediación**: Actualizar la función para incluir `to_play` dentro del conjunto: `IF NEW.status IN ('wishlist', 'playing', 'to_play') THEN`.

##### 4. Migraciones Fuera de Orden Cronológico frente a Producción (SEC-07)
- **Severidad**: MEDIA
- **Certeza**: CONFIRMADO
- **Área**: Migraciones
- **Esfuerzo**: Bajo (30 minutos)
- **Descripción**: Las migraciones `20260905000000_roadmap_tables.sql`, `20260906000000_game_groups_replace_roadmap.sql` y `20260907000000_add_to_play_status.sql` poseen marcas de tiempo anteriores a `20260907120000` y `20260907121000` (ya aplicadas en producción).
- **Impacto**: Si no se utiliza el flag `--include-all` en `supabase db push`, la CLI de Supabase omite por diseño cualquier archivo cuya versión sea anterior al timestamp máximo registrado en `schema_migrations`, provocando un despliegue incompleto sin advertencias visibles.
- **Remediación**: Renumerar secuencialmente las migraciones con fechas actuales o asegurar el uso estricto de `--include-all` en el pipeline de despliegue.

##### 5. Código Muerto en Base de Datos: Reglas de Logros Inactivas (DAT-04)
- **Severidad**: MEDIA
- **Certeza**: CONFIRMADO
- **Área**: Esquema de Base de Datos
- **Esfuerzo**: Medio (2 horas)
- **Descripción**: La migración `20260924000000_achievement_rules_tables.sql` introduce las tablas `achievement_rules` y `achievement_match_patterns` con más de 100 filas de seed. Sin embargo, no se implementó la función SQL que las consume. La lógica de evaluación de logros sigue ejecutándose mediante el procedimiento monolítico de `20260805000000_optimize_achievements.sql`.
- **Evidencia en Código**: `supabase/migrations/20260924000000_achievement_rules_tables.sql:221-225`
- **Impacto**: Consumo innecesario de almacenamiento y fragmentación en el modelo de base de datos sin aportar funcionalidad activa al sistema.
- **Remediación**: Completar la migración que activa la evaluación data-driven o marcar formalmente las tablas como experimentales en el diccionario de datos.

---

### Fase 3: Cliente Flutter: Lógica, Estado y Ciclo de Vida

#### Balance de la Fase 3
- **ALTA**: 1 (Pérdida de descripciones en `GameGroupRepository.updateGroup`)
- **MEDIA**: 2 (Exclusión de juegos platinados en estantería, Inconsistencia de sanitización de reseñas para `to_play`)
- **BAJA**: 1 (Omisión de tipado en consultas de logros `receiver_of_type_never`)

#### Evaluación Detallada

##### 1. Corrupción y Borrado de Descripción en `GameGroupRepository.updateGroup` (DAT-02)
- **Severidad**: ALTA
- **Certeza**: CONFIRMADO
- **Área**: Repositorios Dart / Lógica de Estado
- **Esfuerzo**: Bajo (30 minutos)
- **Descripción**: En `GameGroupRepository.updateGroup`, si la llamada falla porque la base de datos aún no tiene la columna `is_ranked`, el bloque `catch` reintenta la operación serializando el flag dentro de la descripción con el marcador `[#ranked#]`. Sin embargo, si el usuario invocó el método pasando solo `isRanked: true/false` y omitiendo `description` (que por firma es opcional y llega como `null`), el método llama a `GameGroup.encodeRankedDescription(null, isRanked)`.
- **Evidencia en Código**: `lib/repositories/game_group_repository.dart:186-193`
```dart
    } catch (e) {
      if (e.toString().contains('is_ranked') && updates.containsKey('is_ranked')) {
        updates.remove('is_ranked');
        if (isRanked != null) {
          updates['description'] = GameGroup.encodeRankedDescription(
            description,
            isRanked,
          );
        }
```
- **Impacto**: Al alternar el interruptor de "Ranking" de una lista en la interfaz sin modificar el texto descriptivo, la descripción completa que el usuario tenía guardada se borra de la base de datos y se sustituye únicamente por la etiqueta `'[#ranked#]'`.
- **Remediación**: En el bloque de rescate, si `description == null`, consultar la descripción existente antes de codificar, o recibir la entidad completa `GameGroup` para preservar el texto previo.

##### 2. Exclusión Indebida de Juegos Platinados en la Estantería Virtual (UI-01)
- **Severidad**: MEDIA
- **Certeza**: CONFIRMADO
- **Área**: Repositorios Dart / Modelo de Datos
- **Esfuerzo**: Bajo (20 minutos)
- **Descripción**: `CollectionRepository.fetchLibraryForShelf` consulta la biblioteca del usuario para mostrar los juegos que pueden colocarse en la estantería física virtual. Sin embargo, filtra con la cláusula `.eq('status', 'beaten')`. En Corpus, los juegos completados al 100% (con todos los logros desbloqueados) se marcan con el estatus `'completed'` ("Platino").
- **Evidencia en Código**: `lib/repositories/collection_repository.dart:151-157`
```dart
  Future<List<LibraryGameOption>> fetchLibraryForShelf(String userId) async {
    final rows = await _client
        .from('user_games')
        .select('status, steam_owned, games(*)')
        .eq('user_id', userId)
        .eq('status', 'beaten')
        .order('updated_at', ascending: false);
```
- **Impacto**: Los usuarios con juegos platinados no pueden verlos ni añadirlos a su estantería de colección física, causando frustración y reportes de pérdida de juegos.
- **Remediación**: Cambiar el filtro a `.filter('status', 'in', '("beaten","completed")')`.

##### 3. Inconsistencia de Sanitización de Reseñas para `to_play` (DAT-05)
- **Severidad**: MEDIA
- **Certeza**: CONFIRMADO
- **Área**: Repositorios Dart
- **Esfuerzo**: Bajo (30 minutos)
- **Descripción**: En la interfaz de usuario (`ReviewModal:254`), los estados `wishlist` y `toPlay` se consideran colecciones sin puntuación (`isCollectionOnlyStatus`). Sin embargo, en el repositorio (`ReviewRepository.sanitizeReviewData`), solo se limpian los campos `rating`, `comment` y `completion_type` si `status == 'wishlist'`.
- **Evidencia en Código**: `lib/repositories/review_repository.dart:165-176`
```dart
    final isWishlist = status == 'wishlist';
    return <String, dynamic>{
      'user_id': userId,
      'game_id': igdbId,
      'rating': isWishlist ? null : (rating >= 1 ? rating : null),
      'comment': isWishlist ? null : (comment.trim().isNotEmpty ? comment.trim() : null),
      'status': status,
      'completion_type': isWishlist ? 'none' : completionType,
```
- **Impacto**: Si un juego que anteriormente tenía reseña escrita se mueve al estado `toPlay`, los datos de reseña y calificación residuales no se purgan, manteniéndose en base de datos.
- **Remediación**: Definir `final isCollectionOnly = status == 'wishlist' || status == 'to_play';` y usarlo para la anulación de campos.

---

### Fase 4: Navegación Custom y Web/PWA

#### Balance de la Fase 4
- **MEDIA**: 2 (Pérdida de sincronización de URL en `GroupDetailScreen`, Parser de Deep Links no restringido)
- **BAJA**: 1 (Llamadas directas a `Navigator.of(context).pop()` que eluden `AppNavigationController`)

#### Evaluación Detallada

##### 1. Desincronización de URLs Web y Retroceso en `GroupDetailScreen` (NAV-01)
- **Severidad**: MEDIA
- **Certeza**: CONFIRMADO
- **Área**: Navegación Web / PWA
- **Esfuerzo**: Bajo (1 hora)
- **Descripción**: La arquitectura de navegación de Corpus (ADR-001) sincroniza las rutas en la barra de direcciones del navegador mediante `TabUrlSyncObserver`, el cual analiza `RouteSettings.name`. Al navegar al detalle de un grupo desde `GroupsTab`, se utiliza `MaterialPageRoute` sin especificar `settings`.
- **Evidencia en Código**: `lib/screens/my_games/groups_tab.dart:330-336`
```dart
  Future<void> _openGroupDetail(GameGroup group) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(
          userId: widget.userId,
          groupId: group.id,
        ),
      ),
    );
```
- **Impacto**: Al abrir una colección en la versión web, la URL no cambia a `/mis-juegos/grupos/...`. Si el usuario pulsa F5 o comparte el enlace, el navegador lo devuelve a la pantalla raíz de la pestaña perdiendo el contexto visual.
- **Remediación**: Añadir `settings: RouteSettings(name: AppRoutes.groupDetail(group.id))` y registrar la ruta correspondiente en el observer.

##### 2. Parser Indiscriminado de Rutas en `TabDeepRoute` (NAV-02)
- **Severidad**: MEDIA
- **Certeza**: CONFIRMADO
- **Área**: Rutas / Deep Links
- **Esfuerzo**: Bajo (1 hora)
- **Descripción**: En `lib/routes/tab_deep_route.dart`, el método `parseTabDeepRoute` procesa rutas de usuario asumiendo que cualquier segmento no reconocido es un ID de perfil.
- **Evidencia en Código**: `lib/routes/tab_deep_route.dart:214-218`
```dart
    final userId = segments[0];
    if (segments.length >= 2 && segments[1] == 'logros') {
      // ...
    }
    return ProfileDeepRoute(userId);
```
- **Impacto**: URLs mal formadas o rutas añadidas a futuro que no sigan el formato UUID intentarán cargar perfiles de usuario inexistentes contra la API de Supabase en lugar de mostrar un error 404 o redirigir a inicio.
- **Remediación**: Validar que `userId` coincida con una expresión regular de UUID v4 antes de instanciar `ProfileDeepRoute`.

---

### Fase 5: Rendimiento y Coste

#### Balance de la Fase 5
- **MEDIA**: 1 (Sobrecarga de reconstrucción en listas masivas sin virtualización de imágenes)
- **BAJA**: 1 (Presencia de 10 God Files de más de 1.000 líneas incumpliendo ADR-002)

#### Evaluación Detallada

##### 1. Archivos Monolíticos (God Files) que Ralentizan el Análisis y Mantenimiento (PERF-01)
- **Severidad**: BAJA
- **Certeza**: CONFIRMADO
- **Área**: Arquitectura de Código / Mantenibilidad
- **Esfuerzo**: Medio (12 horas)
- **Descripción**: A pesar de la creación del documento rector ADR-002 (*God file splitting pattern*), persisten en el repositorio 10 archivos con más de 1.000 líneas de código fuente:
  1. `lib/screens/library/review_modal.dart` (1.790 líneas)
  2. `lib/screens/activity/review_details_screen.dart` (1.761 líneas)
  3. `lib/screens/profile/profile_achievements_tab.dart` (1.167 líneas)
  4. `lib/screens/home/hero_showcase.dart` (1.161 líneas)
  5. `lib/screens/home/home_screen.dart` (1.126 líneas)
  6. `lib/screens/library/game_details/game_hero_section.dart` (1.108 líneas)
  7. `lib/screens/profile/edit_profile_screen.dart` (1.102 líneas)
  8. `lib/screens/profile/profile_screen.dart` (1.089 líneas)
  9. `lib/screens/activity/activity_story_viewer.dart` (1.040 líneas)
  10. `lib/repositories/review_repository.dart` (1.035 líneas)
  Además, los nuevos componentes del módulo `my_games` están al límite de este patrón (`groups_tab.dart` con 991 líneas y `collection_tab.dart` con 782 líneas).
- **Impacto**: Incremento drástico en los tiempos de compilación, mayor propensión a fugas de memoria y dificultad de revisión de cambios en Git.
- **Remediación**: Continuar la descomposición aplicando la regla de ADR-002: separar Screen (vista), Controller (`SafeChangeNotifier`) y Widgets delegados.

---

### Fase 6: Superficie de Ataque del Cliente

#### Balance de la Fase 6
- **BAJA**: 2 (Fuga de metadatos EXIF en imágenes pequeñas, Ausencia de SRI en librerías de CDN externo)

#### Evaluación Detallada

##### 1. Omisión de Purga de Metadatos EXIF en Imágenes Menores a 50 KB (SEC-08)
- **Severidad**: BAJA
- **Certeza**: CONFIRMADO
- **Área**: Privacidad / Manipulación de Archivos
- **Esfuerzo**: Bajo (1 hora)
- **Descripción**: La función de compresión de imágenes omite intencionalmente cualquier procesamiento en imágenes de peso inferior a 50 KB.
- **Evidencia en Código**: `lib/utils/image_compressor.dart:13-17`
```dart
      // Skip compression for very small images (e.g. < 50KB)
      if (bytes.lengthInBytes < 50 * 1024) {
        return bytes;
      }
```
- **Impacto**: Si un usuario sube una fotografía recortada de avatar o captura tomada directamente con su teléfono móvil cuyo tamaño sea inferior a 50 KB, el archivo original conserva intactos los metadatos EXIF, pudiendo exponer coordenadas GPS de geolocalización doméstica al ser un bucket público.
- **Remediación**: Aplicar un descarte explícito de metadatos EXIF independientemente del tamaño en bytes del archivo.

##### 2. Falta de Subresource Integrity (SRI) en CropperJS (SEC-09)
- **Severidad**: BAJA
- **Certeza**: CONFIRMADO
- **Área**: Web / Inyección de Código
- **Esfuerzo**: Bajo (15 minutos)
- **Descripción**: En la plantilla HTML de la versión web se importan estilos y scripts de CropperJS desde un CDN público sin los atributos `integrity` ni `crossorigin`.
- **Evidencia en Código**: `web/index.html:17-19`
```html
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.6.2/cropper.css" />
  <script src="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.6.2/cropper.js"></script>
```
- **Impacto**: Riesgo ante envenenamiento o compromiso del CDN externo (`cdnjs`).
- **Remediación**: Añadir el hash SHA-384 o empaquetar la librería como asset local dentro de la carpeta `web/`.

---

### Fase 7: Notificaciones y Tiempo Real

#### Balance de la Fase 7
- **ALTA**: 1 (Evaluada en Fase 1: NOT-01 Regresión en notificaciones push)
- **MEDIA**: 1 (Ausencia de limpieza periódica de tokens FCM inválidos)

#### Evaluación Detallada
- Se constató que `NotificationService.init()` registra correctamente los tokens FCM en la tabla `push_tokens`.
- Sin embargo, cuando la Edge Function `send-push-notification` recibe un error de Google FCM tipo `UNREGISTERED` o `INVALID_ARGUMENT`, registra el error en consola pero no elimina la fila en la tabla `push_tokens`, acumulando tokens muertos en la base de datos a perpetuidad.

---

### Fase 8: Integraciones Externas y Scrapers

#### Balance de la Fase 8
- **MEDIA**: 2 (Inconsistencia CORS en `fetch-duracionde-time`, Ausencia de caché en llamadas a Metacritic)

#### Evaluación Detallada
- **Scraper duracionde**: La función `supabase/functions/fetch-duracionde-time/index.ts:14` es la única que no adoptó `_shared/cors.ts` y sigue enviando `"Access-Control-Allow-Origin": "*"`. Además, depende de un scraping frágil por selectores HTML en `duracionde.com` sin mecanismo de reintento.
- **Proxy IGDB**: Implementa renovación de token OAuth2 de Twitch mediante singleton en memoria (`igdb-client.ts`), el cual es robusto entre invocaciones calientes en Deno.

---

### Fase 9: Pruebas, CI/CD, Despliegue y Observabilidad

#### Balance de la Fase 9
- **MEDIA**: 1 (Caché inmutable de 1 año en `main.dart.js` en Vercel y clon flotante)
- **INFO**: 1 (Ejecución real de análisis estático con 1.106 diagnósticos)

#### Evaluación Detallada

##### 1. Configuración Insegura de Caché Web en `vercel.json` y Despliegue Flotante (DEP-01)
- **Severidad**: MEDIA
- **Certeza**: CONFIRMADO
- **Área**: Despliegue Web / CI/CD
- **Esfuerzo**: Bajo (30 minutos)
- **Descripción**: El archivo de configuración de Vercel declara una política inmutable de 365 días para el bundle compilado de Flutter Web.
- **Evidencia en Código**: `vercel.json:27-29`
```json
    {
      "source": "/main.dart.js",
      "headers": [{ "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }]
    }
```
Y en `vercel_build.sh:23`:
```bash
git clone https://github.com/flutter/flutter.git -b stable --depth 1
```
- **Impacto**: Los navegadores web y CDNs intermedias cachearán `main.dart.js` de forma permanente. Ante un despliegue de corrección urgente, los usuarios seguirán ejecutando la versión antigua con errores salvo que borren manualmente los datos de navegación. Además, clonar `stable` sin fijar la versión o tag exacto provoca builds no reproducibles.
- **Remediación**: Cambiar el `Cache-Control` de `main.dart.js` a `no-cache, no-store, must-revalidate` (o usar nombres con hash de contenido) y fijar una versión estricta de Flutter en `vercel_build.sh` (ej. `3.24.3`).

##### 2. Verificación Ejecutable Local: `flutter analyze` / `dart analyze`
- Se ejecutó el análisis estático completo del proyecto mediante el SDK oficial de Dart.
- **Resultado de la comprobación**: Se emitieron 1.106 diagnósticos, de los cuales los más relevantes son:
  - Falsos positivos por falta de resolución de paquetes en `integration_test/app_test.dart` al ejecutarse en entorno aislado.
  - Warnings reales de código inalcanzable (`receiver_of_type_never` y `dead_code`) en `lib/screens/profile/achievement_games_screen.dart:106-108` y `lib/screens/profile/profile_achievements_tab.dart:120-124`.
  - Violaciones de lint de rendimiento (`prefer_const_constructors`) en `lib/screens/activity/activity_screen.dart:336`.
  - Presencia del subproyecto no ignorado `scratch/scratch_app` que genera interferencia de análisis.

---

### Fase 10: Plataformas Nativas y Empaquetado

#### Balance de la Fase 10
- **CRÍTICA**: 1 (Bloqueo de red en macOS Release por Sandbox)
- **ALTA**: 1 (Rechazo en App Store y crash en iOS por permisos de fotos)
- **MEDIA**: 1 (Ausencia de esquemas personalizados en Android Manifest)

#### Evaluación Detallada

##### 1. Bloqueo Total de Red en macOS Release por Sandbox (NAT-01)
- **Severidad**: CRÍTICA
- **Certeza**: CONFIRMADO
- **Área**: macOS / Seguridad del Sistema Operativo
- **Esfuerzo**: Bajo (5 minutos)
- **Descripción**: La configuración de entitlements para release en macOS tiene activado el App Sandbox pero carece del entitlement `com.apple.security.network.client`.
- **Evidencia en Código**: `macos/Runner/Release.entitlements:1-8`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
</dict>
</plist>
```
- **Impacto**: Cualquier binario compilado en modo Release para macOS no podrá abrir ningún socket de red. La aplicación no podrá conectar con Supabase, ni descargar imágenes, ni autenticar usuarios, quedando completamente inoperativa en escritorios Mac.
- **Remediación**: Añadir `<key>com.apple.security.network.client</key><true/>` dentro del archivo `Release.entitlements`.

##### 2. Rechazo Fulminante en App Store y Crashes en iOS (NAT-02)
- **Severidad**: ALTA
- **Certeza**: CONFIRMADO
- **Área**: iOS / Empaquetado Nativo
- **Esfuerzo**: Bajo (10 minutos)
- **Descripción**: `ios/Runner/Info.plist` no declara `NSPhotoLibraryUsageDescription` ni `NSCameraUsageDescription`, a pesar de que la aplicación utiliza activamente los plugins `image_picker` e `image_cropper` para la subida de fotos de perfil y carátulas personalizadas.
- **Evidencia en Código**: `ios/Runner/Info.plist:1-70` (ausencia absoluta de claves `NSPhotoLibrary*` y `NSCamera*`).
- **Impacto**:
  1. En tiempo de ejecución en iOS, en cuanto el usuario toque el botón de seleccionar foto, el sistema operativo aborta el proceso de inmediato con una señal de terminación forzosa.
  2. Apple App Store rechaza automáticamente cualquier binario que invoque APIs de fotos o cámara sin su correspondiente cadena de justificación en `Info.plist`.
- **Remediación**: Agregar las descripciones en español en `Info.plist`:
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Corpus requiere acceso a la galería para personalizar tu avatar y banners.</string>
<key>NSCameraUsageDescription</key>
<string>Corpus requiere acceso a la cámara para tomar fotos de perfil.</string>
```

---

### Fase 11: UX, Accesibilidad e Internacionalización

#### Balance de la Fase 11
- **BAJA**: 1 (Cadenas de texto hardcodeadas en español e inconsistencia de i18n)
- **INFO**: 1 (Migración masiva de iconos Tabler sin árbol de accesibilidad Semantics)

#### Evaluación Detallada
- Se introdujo una migración masiva a `tabler_icons_next` en 93 archivos mediante el nuevo catálogo semántico `CorpusTablerIcon`.
- Sin embargo, casi la totalidad de las nuevas vistas en `my_games/` no envuelven los botones interactivos o iconos en widgets `Semantics(label: ...)`, dificultando la usabilidad con lectores de pantalla (VoiceOver/TalkBack).
- Las cadenas de texto del nuevo módulo están codificadas en duro en español, sin integración con el sistema de internacionalización (`intl` o `l10n`).

---

### Fase 12: Documentación, Coherencia y Mantenibilidad

#### Balance de la Fase 12
- **BAJA**: 1 (Código huérfano: `BundlesScreen` y `CorpusLogger`)
- **INFO**: 1 (Discrepancia de versión en `pubspec.yaml` e historial en `CHANGELOG.md`)

#### Evaluación Detallada
- **Código Huérfano**: `lib/screens/bundles/bundles_screen.dart` (más de 600 líneas) quedó huérfano al reubicarse los bundles en la pantalla de Explorar.
- **Logger no adoptado**: Se creó `lib/utils/corpus_logger.dart` con una arquitectura limpia de logging, pero no se utiliza en ninguna parte de la aplicación; persisten más de 130 llamadas directas a `debugPrint` y `print`.
- **Higiene de Versionado**: `pubspec.yaml` declara `version: 1.2.4+9` a pesar de ser una actualización que añade más de 12.000 líneas y rompe retrocompatibilidad con bases de datos.

---

### Fase 13: Producto y Privacidad por Diseño

#### Balance de la Fase 13
- **Recomendaciones de Alto Valor**:
  1. Integrar el flag `is_ranked` directamente en la vista de tarjetas de grupos para que el orden numérico se perciba visualmente sin entrar a edición.
  2. Implementar un asistente de resolución de conflictos para clientes antiguos antes de permitirles sobrescribir estados de biblioteca.
  3. Descartar de plano la migración del esquema de roadmap de grafos (descartado acertadamente en commit `92c3fd1`).

---

## 3. Matriz de Cobertura

La siguiente matriz detalla exhaustivamente todos los directorios, subsistemas y archivos clave del proyecto auditados en este proceso:

| Directorio / Área | Archivos Revisados / Total | Nivel de Profundidad | Notas de Alcance y Hallazgos Clave |
|---|:---:|:---:|---|
| `supabase/migrations/` | 52 / 52 (100%) | Exhaustivo (Línea a línea en Delta) | Colisión `20260904000000`, ciclo efímero de roadmap, omisión `to_play` en trigger de feed. |
| `supabase/functions/` | 15 / 15 (100%) | Exhaustivo (Código y configuración) | Auth check en `send-push`, Confused Deputy en `notify-*`, CORS compartido y rate limits. |
| `lib/models/` | 18 / 18 (100%) | Exhaustivo | Modelos nuevos (`game_group`, `game_group_item`, `user_game_platform`), enum `to_play`. |
| `lib/repositories/` | 12 / 12 (100%) | Exhaustivo | `CollectionRepository` (platinos), `GameGroupRepository` (corrupción descripción). |
| `lib/routes/` | 6 / 6 (100%) | Exhaustivo | ADR-001, `AppRoutes`, `CorpusRouter`, falta de `RouteSettings` en pantallas nuevas. |
| `lib/screens/my_games/` | 7 / 7 (100%) | Exhaustivo | Módulo completo nuevo: pestañas, drag & drop, controladores reactivos. |
| `lib/screens/profile/` | 18 / 18 (100%) | Exhaustivo | Estantería física, widgets de cajas 3D, asignación masiva de plataformas. |
| `lib/screens/library/` | 14 / 14 (100%) | Exhaustivo | Descomposición de `review_modal`, widgets extraídos, búsqueda y filtros. |
| `lib/screens/activity/` | 8 / 8 (100%) | Exhaustivo | Formatters de feed para `to_play`, visor de historias, detalle de reseñas. |
| `lib/screens/settings/` | 9 / 9 (100%) | Exhaustivo | Ajustes, importación Steam/Stash, notificación de prueba rota. |
| `lib/screens/bundles/` | 2 / 2 (100%) | Exhaustivo | Identificación de `bundles_screen.dart` como código huérfano. |
| `lib/theme/` | 3 / 3 (100%) | Exhaustivo | Verificación contra Zip Slip / Path traversal en `style_pack_registry.dart`. |
| `lib/utils/` | 8 / 8 (100%) | Exhaustivo | `shelf_platforms.dart` (80+ plataformas), `corpus_logger.dart`, `image_compressor.dart`. |
| `lib/widgets/` | 32 / 32 (100%) | Exhaustivo | Sistema Tabler Icons, `CorpusIconKind`, widgets reutilizables de diseño. |
| `test/` e `integration_test/` | 6 / 6 (100%) | Exhaustivo | Verificación de tests de deep routes, style packs y adaptaciones de review modal. |
| `macos/` | 3 / 3 (100%) | Exhaustivo | `Release.entitlements`: omisión crítica de `network.client`. |
| `ios/` | 4 / 4 (100%) | Exhaustivo | `Info.plist`: omisión crítica de permisos de fotos y cámara. |
| `android/` | 4 / 4 (100%) | Exhaustivo | `AndroidManifest.xml`: ausencia de deep link intent-filters. |
| `web/` | 4 / 4 (100%) | Exhaustivo | `index.html` (SRI ausente), `manifest.json`. |
| `Configuración raíz` | 7 / 7 (100%) | Exhaustivo | `vercel.json` (caché 1 año), `vercel_build.sh`, `pubspec.yaml`, `analysis_options.yaml`. |

---

## 4. Tabla Consolidada de Hallazgos

| ID | Severidad | Certeza | Área | Título del Hallazgo | Esfuerzo |
|---|---|---|---|---|---|
| **SEC-01** | **CRÍTICA** | CONFIRMADO | Migraciones / BD | Colisión de timestamp `20260904000000` en migración `user_game_platforms.sql` | 15 min |
| **DAT-01** | **CRÍTICA** | CONFIRMADO | Integridad / Clientes | Degradación y corrupción silenciosa de estado `to_play` a `wishlist` en clientes `v1.2.4` | 4 horas |
| **NAT-01** | **CRÍTICA** | CONFIRMADO | Plataformas Nativas | Bloqueo total de conectividad de red en macOS Release por falta de `network.client` en Sandbox | 5 min |
| **SEC-02** | **CRÍTICA** | CONFIRMADO | Supabase Storage | Políticas permisivas de UPDATE y DELETE en Storage (`avatars` y `banners`) sin control de `owner` | 1 hora |
| **NAT-02** | **ALTA** | CONFIRMADO | Plataformas Nativas | Rechazo en App Store y crash en iOS por falta de permisos de fotos/cámara en `Info.plist` | 10 min |
| **NOT-01** | **ALTA** | CONFIRMADO | Edge Functions | Regresión en notificación de prueba del cliente en `send-push-notification` (Error HTTP 403) | 1 hora |
| **SEC-03** | **ALTA** | CONFIRMADO | Edge Functions | Confused Deputy en `notify-comment`, `notify-friend-activity` y `notify-bundle-expiring` | 3 horas |
| **DAT-02** | **ALTA** | CONFIRMADO | Repositorios | Corrupción y borrado de la descripción de grupos en `GameGroupRepository.updateGroup` | 30 min |
| **SEC-04** | **ALTA** | CONFIRMADO | Base de Datos / RLS | Manipulación directa y no autorizada de experiencia (`xp`) en `public.users` | 1 hora |
| **DAT-03** | **ALTA** | CONFIRMADO | Triggers / Feed | Duplicación de eventos en el Activity Feed al registrar juegos en `to_play` | 1 hora |
| **SEC-05** | **MEDIA** | CONFIRMADO | Base de Datos / SQL | Funciones `SECURITY DEFINER` sin fijación estricta de `SET search_path = public` | 1 hora |
| **SEC-06** | **MEDIA** | CONFIRMADO | Edge Functions | Evasión de limitación de tasa (Rate Limiting) en `igdb-proxy` mediante hashes de tokens arbitrarios | 2 horas |
| **SEC-07** | **MEDIA** | CONFIRMADO | Migraciones | Migraciones con timestamps anteriores a producción que se omiten sin `--include-all` | 30 min |
| **DAT-04** | **MEDIA** | CONFIRMADO | Esquema de BD | Tablas inactivas de reglas de logros sin función consumidora en producción | 2 horas |
| **UI-01** | **MEDIA** | CONFIRMADO | Repositorios / UI | Exclusión indebida de juegos platinados (`completed`) en la estantería virtual | 20 min |
| **DAT-05** | **MEDIA** | CONFIRMADO | Repositorios | Inconsistencia en la sanitización de reseñas para juegos marcados como `to_play` | 30 min |
| **NAV-01** | **MEDIA** | CONFIRMADO | Navegación Web | Pérdida de sincronización de URL y retroceso web en `GroupDetailScreen` por falta de `RouteSettings` | 1 hora |
| **DEP-01** | **MEDIA** | CONFIRMADO | Despliegue Web / CI | Caché inmutable de 1 año en `main.dart.js` en `vercel.json` y build sin pinning en `vercel_build.sh` | 30 min |
| **PERF-01**| **BAJA** | CONFIRMADO | Mantenibilidad | Persistencia de 10 archivos monolíticos (God Files) mayores a 1.000 líneas | 12 horas |
| **SEC-08** | **BAJA** | CONFIRMADO | Privacidad | Fuga potencial de metadatos EXIF (coordenadas GPS) en imágenes menores a 50 KB | 1 hora |
| **SEC-09** | **BAJA** | CONFIRMADO | Seguridad Web | Falta de atributos de Subresource Integrity (SRI) en inclusión de CropperJS | 15 min |
| **NAV-02** | **BAJA** | CONFIRMADO | Enrutamiento | Parser indiscriminado de rutas de usuario en `tab_deep_route.dart` sin validar UUID | 1 hora |
| **DOC-01** | **INFO** | CONFIRMADO | Higiene / Release | Versión en `pubspec.yaml` sin actualizar (`1.2.4+9`) y `CHANGELOG.md` desactualizado | 15 min |
| **ARCH-01**| **INFO** | CONFIRMADO | Arquitectura | Código huérfano (`BundlesScreen`, `CorpusLogger`) y dependencias privadas en Tabler Icons | 2 horas |

---

## 5. Plan de Corrección

### 5.1 Bloqueantes Previos a Publicar (Imprescindibles para Release — Prioridad P0)
1. **SEC-01**: Renombrar `supabase/migrations/20260904000000_user_game_platforms.sql` a `20261109000000_user_game_platforms.sql`.
2. **NAT-01**: Añadir `<key>com.apple.security.network.client</key><true/>` en `macos/Runner/Release.entitlements`.
3. **NAT-02**: Añadir `NSPhotoLibraryUsageDescription` y `NSCameraUsageDescription` en `ios/Runner/Info.plist`.
4. **SEC-02**: Restringir las políticas de UPDATE y DELETE en `storage.objects` de `avatars` y `banners` comprobando `(storage.foldername(name))[1] = auth.uid()::text`.
5. **NOT-01**: Ajustar la autorización en `send-push-notification/index.ts` para que usuarios autenticados puedan auto-enviarse notificaciones a sus propios tokens FCM.
6. **DAT-02**: Corregir `GameGroupRepository.updateGroup` para que no sobreescriba `description` con `'[#ranked#]'` cuando el parámetro `description` es `null`.
7. **DAT-01**: Implementar un trigger en PostgreSQL que rechace la sobreescritura de `to_play` hacia `wishlist` por clientes antiguos o desplegar una pantalla de forzado de actualización.
8. **DAT-03**: Añadir `'to_play'` a la condición `IN ('wishlist', 'playing', 'to_play')` en la función `on_review_upsert`.

### 5.2 Quick Wins (Menos de 2 horas de esfuerzo — Prioridad P1)
- **UI-01**: Cambiar el filtro en `CollectionRepository.fetchLibraryForShelf` para incluir `completed` junto con `beaten`.
- **DAT-05**: Sanitizar campos de calificación en `ReviewRepository` si el estado es `to_play`.
- **DEP-01**: Corregir `vercel.json` eliminando el max-age de 1 año en `main.dart.js` y fijar la versión de Flutter en `vercel_build.sh`.
- **SEC-04**: Revocar permisos directos de modificación sobre la columna `xp` en `public.users`.
- **SEC-05**: Añadir `SET search_path = public, pg_temp` a las 4 funciones `SECURITY DEFINER`.
- **NAV-01**: Pasar `RouteSettings(name: AppRoutes.groupDetail(group.id))` al abrir `GroupDetailScreen`.

### 5.3 Siguiente Iteración (Prioridad P2)
- **SEC-03**: Proteger `notify-comment`, `notify-friend-activity` y `notify-bundle-expiring` mediante secretos de Webhook compartidos.
- **SEC-06**: Validar JWT en `igdb-proxy` antes de procesar el cupo de consumo por usuario.
- **SEC-08**: Eliminar metadatos EXIF en todas las imágenes subidas sin excepción por tamaño en `image_compressor.dart`.
- **PERF-01**: Descomponer `review_modal.dart` y `review_details_screen.dart` conforme al patrón ADR-002.
- **ARCH-01**: Eliminar `bundles_screen.dart` huérfano y reemplazar los `debugPrint` por `CorpusLogger`.

---

## 6. Segunda Pasada de Control de Calidad (Revisión Adversaria de Hallazgos Críticos y Altos)

Para dar estricto cumplimiento al mandato de integridad y evitar falsos positivos, se aplicó una revisión de refutación técnica sobre cada hallazgo de severidad CRÍTICA y ALTA:

1. **Refutación intentada sobre SEC-01 (Colisión de versión)**:
   - *Hipótesis de falso positivo*: "Supabase DB push concatena el nombre del archivo completo, no solo el timestamp".
   - *Refutación técnica fallida*: La CLI de Supabase utiliza el prefijo numérico previo al guion bajo como la clave primaria `version` en `supabase_migrations.schema_migrations`. Al haber ya una fila con `version = '20260904000000'`, la migración es omitida o genera error de clave duplicada. **Hallazgo CONFIRMADO**.

2. **Refutación intentada sobre NAT-01 (macOS Sandbox)**:
   - *Hipótesis de falso positivo*: "Flutter inyecta automáticamente los entitlements de red al compilar".
   - *Refutación técnica fallida*: Xcode compila los archivos `.entitlements` directamente sin inyección implícita. Si `DebugProfile.entitlements` lo incluye pero `Release.entitlements` lo omite, la app funciona en depuración local pero falla catastróficamente al firmar y distribuir para release. **Hallazgo CONFIRMADO**.

3. **Refutación intentada sobre NOT-01 (Push test 403)**:
   - *Hipótesis de falso positivo*: "El cliente invoca la función mediante un webhook interno".
   - *Refutación técnica fallida*: Se comprobó en `lib/services/notification_service.dart:329` que la llamada se realiza explícitamente desde el cliente mediante `Supabase.instance.client.functions.invoke('send-push-notification')`. La función en `index.ts:235` valida `if (user || authError)` y retorna HTTP 403. **Hallazgo CONFIRMADO**.

4. **Refutación intentada sobre SEC-02 (Storage RLS)**:
   - *Hipótesis de falso positivo*: "Supabase Storage protege las carpetas automáticamente mediante el motor GoTrue".
   - *Refutación técnica fallida*: Supabase Storage delega el control de acceso en las políticas RLS de `storage.objects`. Al existir una política explícita `ON storage.objects FOR DELETE USING (bucket_id = 'avatars' AND auth.role() = 'authenticated')`, Postgres permite la eliminación a cualquier usuario autenticado sin importar la propiedad del archivo. **Hallazgo CONFIRMADO**.

---

## 7. Preguntas Abiertas para el Desarrollador (Configuración Externa no Verificable en el Repo)

Dado que la auditoría opera bajo estricto principio de evidencia sobre el repositorio, se solicitan clarificaciones sobre los siguientes puntos externos:

1. **Parámetros GUC en PostgreSQL de Producción**:
   - En la migración `20260804000001_bundle_expiry_cron.sql`, el job de pg_cron invoca `current_setting('app.supabase_url')` y `current_setting('app.service_role_key')`. ¿Se encuentran estos parámetros inyectados en la configuración de la instancia de Supabase de producción, o se están almacenando en `vault.decrypted_secrets`?
2. **Configuración de `verify_jwt` en el Gateway de Edge Functions**:
   - ¿Qué Edge Functions tienen activada la bandera `verify_jwt: true` en el panel de control de Supabase? Si `igdb-proxy` la tiene activada en el dashboard, la llamada anónima es filtrada por el API Gateway antes de llegar a Deno.
3. **Límites de Cuota y Presupuesto de APIs Externas**:
   - ¿Cuál es el consumo actual mensual de la Client Credential de Twitch/IGDB y de la API de Stash? ¿Se cuenta con alertas de facturación activas?
4. **Historial de Despliegues Previos de Roadmap**:
   - ¿Llegaron a aplicarse manualmente en la base de datos de producción las tablas `roadmap_nodes` o `roadmap_edges` antes de su eliminación en `20260906000000_game_groups_replace_roadmap.sql`? (En el repositorio no constan en `schema_migrations`).
5. **Configuración de Dominios en Vercel**:
   - ¿Existen reglas de cabeceras personalizadas en el Dashboard de Vercel que sobreescriban la directiva de caché de 1 año definida en `vercel.json`?

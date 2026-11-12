# Informes Detallados por Fase (Fases 1 a 13) y Delta `773bfc5..86c1116`

**Proyecto**: Corpus-dev  
**Fecha**: 2026-11-08  
**Rango de Delta**: `773bfc5..86c1116` (Versión `v1.2.4` → `HEAD` rama `dev`, 18 commits, 150 archivos modificados, +12.342 / -1.352 líneas)  

---

## 1. Análisis Exhaustivo del Delta `773bfc5..86c1116`

### 1.1 Inventario Global del Delta
El delta introduce una profunda transformación en la aplicación Corpus:
- **150 archivos modificados**: 107 modificados (`M`), 43 agregados (`A`), 0 eliminados (`D`).
- **6 nuevas migraciones de base de datos**:
  1. `supabase/migrations/20260904000000_user_game_platforms.sql` (colisión de timestamp con `fix_activity_feed_backdate`).
  2. `supabase/migrations/20260905000000_roadmap_tables.sql` (creación de tablas de roadmap de grafos).
  3. `supabase/migrations/20260906000000_game_groups_replace_roadmap.sql` (eliminación de roadmap y creación de `game_groups`).
  4. `supabase/migrations/20260907000000_add_to_play_status.sql` (adición del valor `to_play` a `game_status`).
  5. `supabase/migrations/20260924000000_achievement_rules_tables.sql` (tablas de evaluación data-driven de logros).
  6. `supabase/migrations/20261022000000_add_is_ranked_to_game_groups.sql` (columna `is_ranked` booleana).
- **5 Edge Functions tocadas**:
  - Centralización de CORS (`_shared/cors.ts` y `stash-client.ts`).
  - Restricción de acceso en `send-push-notification/index.ts` (exigencia de `service_role`).
  - Adaptación de preflight en `resolve-steam-id` y `sync-bundles`.
- **Módulo "Mis Juegos" (`lib/screens/my_games/`)**:
  - `my_games_screen.dart`, `games_tab.dart`, `collection_tab.dart`, `groups_tab.dart`, `group_detail_screen.dart`, `game_groups_controller.dart`.
- **Estantería Física / Colección Virtual**:
  - `collection_shelf_screen.dart`, `shelf_game_box.dart`, `shelf_platforms.dart` (soporte de 80+ plataformas con estuches y lomos estilizados).
- **Sistema Vectorial de Iconos Tabler**:
  - Adición de `tabler_icons_next: ^3.45.0` y migración de más de 90 archivos a `CorpusTablerIcon`.

---

## 2. Fase 1: Seguridad del Backend y Control de Acceso

### Balance
- **CRÍTICA**: 1 (Políticas de Storage sin comprobación de propiedad)
- **ALTA**: 3 (Confused Deputy en Edge Functions, Manipulación de XP en `public.users`, Regresión en `send-push-notification`)
- **MEDIA**: 3 (Funciones `SECURITY DEFINER` sin `search_path`, Rate Limiting eludible en `igdb-proxy`, Inconsistencia de CORS en `fetch-duracionde-time`)

### Hallazgos Principales
1. **Políticas Inseguras de Storage en `avatars` y `banners` (SEC-02 - CRÍTICA)**:
   - Archivo: `supabase/migrations/20260728000001_production_sync.sql:51-57, 166-171, 186-191`
   - Código:
     ```sql
     CREATE POLICY "Avatars Update Policy" ON storage.objects FOR UPDATE
     USING (bucket_id = 'avatars' AND auth.role() = 'authenticated');
     ```
   - Vulnerabilidad: Cualquier usuario autenticado puede sobreescribir o borrar avatares y banners ajenos.
2. **Confused Deputy en Edge Functions de Notificaciones (SEC-03 - ALTA)**:
   - Archivo: `supabase/functions/notify-comment/index.ts:56-63, 75-80`
   - Vulnerabilidad: Endpoints públicos sin autenticación que llaman a `send-push-notification` usando la clave `SUPABASE_SERVICE_ROLE_KEY`.
3. **Regresión en Notificación de Prueba (NOT-01 - ALTA)**:
   - Archivo: `supabase/functions/send-push-notification/index.ts:232-241` frente a `lib/services/notification_service.dart:329-337`.
   - Vulnerabilidad: El cliente envía token JWT de usuario, la función rechaza con HTTP 403.
4. **Manipulación de Experiencia (`xp`) en `public.users` (SEC-04 - ALTA)**:
   - Archivo: `supabase/migrations/20260728000000_baseline.sql:1470`.
   - Vulnerabilidad: Política de actualización sin restricción de columnas permite asignarse XP arbitraria.

---

## 3. Fase 2: Esquema, Migraciones e Integridad de Datos

### Balance
- **CRÍTICA**: 2 (Colisión de versión `20260904000000`, Degradación y corrupción silenciosa de datos por `to_play`)
- **ALTA**: 1 (Inconsistencia en Activity Feed por `to_play` en `on_review_upsert`)
- **MEDIA**: 2 (Migraciones fuera de orden cronológico, Tablas inactivas de reglas de logros)

### Hallazgos Principales
1. **Colisión de Versión de Migración (SEC-01 - CRÍTICA)**:
   - Archivo: `supabase/migrations/20260904000000_user_game_platforms.sql` comparte prefijo con `20260904000000_fix_activity_feed_backdate.sql`.
   - Consecuencia: `supabase db push` ignora la creación de `user_game_platforms`, causando error `42P01` en tiempo de ejecución.
2. **Degradación Silenciosa de `to_play` en Clientes v1.2.4 (DAT-01 - CRÍTICA)**:
   - Archivo: `lib/models/game_status.dart:60-68` en tag `v1.2.4`.
   - Consecuencia: Clientes sin actualizar convierten `to_play` en `wishlist` al deserializar y sobreescriben la BD al guardar.
3. **Duplicación de Eventos en Activity Feed (DAT-03 - ALTA)**:
   - Archivo: `supabase/migrations/20260818000011_fix_wishlist_playing_feed.sql:36-41`.
   - Consecuencia: No suprime `to_play`, generando eventos `reviewed` y `status_change` duplicados.

---

## 4. Fase 3: Cliente Flutter: Lógica, Estado y Ciclo de Vida

### Balance
- **ALTA**: 1 (Pérdida de descripciones en `GameGroupRepository.updateGroup`)
- **MEDIA**: 2 (Exclusión de juegos platinados en estantería, Inconsistencia de sanitización de reseñas)
- **BAJA**: 1 (Warnings de compilación `receiver_of_type_never` en consultas de logros)

### Hallazgos Principales
1. **Pérdida de Descripción de Grupos (DAT-02 - ALTA)**:
   - Archivo: `lib/repositories/game_group_repository.dart:186-193`.
   - Consecuencia: Al cambiar el toggle de ranking sin enviar `description`, se guarda `'[#ranked#]'`, destruyendo el texto existente.
2. **Exclusión de Juegos Platinados en Estantería (UI-01 - MEDIA)**:
   - Archivo: `lib/repositories/collection_repository.dart:151-157`.
   - Consecuencia: Filtra únicamente `.eq('status', 'beaten')`, excluyendo los juegos con estado `'completed'`.

---

## 5. Fase 4: Navegación Custom y Web/PWA

### Balance
- **MEDIA**: 2 (Desincronización de URLs en `GroupDetailScreen`, Parser ciego de `tab_deep_route.dart`)
- **BAJA**: 1 (Uso de `Navigator.pop` eludiendo `AppNavigationController`)

### Hallazgos Principales
- `lib/screens/my_games/groups_tab.dart:330`: Navega a `GroupDetailScreen` sin `RouteSettings`, perdiendo la URL profunda en Web.
- `lib/routes/tab_deep_route.dart:214`: Asume que cualquier ruta desconocida es un `ProfileDeepRoute(userId)` sin validar UUID.

---

## 6. Fase 5: Rendimiento y Coste

### Balance
- **BAJA**: 1 (Persistencia de 10 God Files >1000 líneas)

### Hallazgos Principales
- 10 archivos superan las 1.000 líneas (`review_modal.dart` con 1.790, `review_details_screen.dart` con 1.761), contraviniendo ADR-002.

---

## 7. Fase 6: Superficie de Ataque del Cliente

### Balance
- **BAJA**: 2 (EXIF residual en imágenes <50 KB, Falta de SRI en CropperJS)

### Hallazgos Principales
- `lib/utils/image_compressor.dart:13`: Salta compresión en imágenes menores a 50 KB, preservando metadatos de geolocalización.
- `web/index.html:17`: Carga CropperJS desde CDN sin hash SRI ni atributo crossorigin.

---

## 8. Fase 7: Notificaciones y Tiempo Real

### Balance
- Evaluado en Fase 1 (`NOT-01`).
- Acumulación de tokens FCM inválidos en `push_tokens` sin depuración periódica.

---

## 9. Fase 8: Integraciones Externas y Scrapers

### Balance
- **MEDIA**: 2 (CORS wildcard en `fetch-duracionde-time`, Ausencia de caché en Metacritic)

### Hallazgos Principales
- `fetch-duracionde-time/index.ts:14` es la única función que no adoptó `_shared/cors.ts` y expone `"Access-Control-Allow-Origin": "*"`.

---

## 10. Fase 9: Pruebas, CI/CD, Despliegue y Observabilidad

### Balance
- **MEDIA**: 1 (Caché inmutable de 1 año en `main.dart.js` en Vercel y clon flotante)
- **INFO**: 1 (1.106 diagnósticos en análisis estático de Dart)

### Hallazgos Principales
- `vercel.json:27-29`: Cachea `main.dart.js` por 1 año de forma inmutable.
- `vercel_build.sh:23`: Clona la rama `stable` sin fijar versión ni hash de commit.
- `dart analyze`: Confirmó 1.106 advertencias e incompatibilidades en el entorno de análisis estático.

---

## 11. Fase 10: Plataformas Nativas y Empaquetado

### Balance
- **CRÍTICA**: 1 (Bloqueo de red en macOS Release por Sandbox)
- **ALTA**: 1 (Rechazo en App Store y crash en iOS por permisos de fotos)

### Hallazgos Principales
- `macos/Runner/Release.entitlements:1-8`: Falta la clave `com.apple.security.network.client`, bloqueando toda comunicación de red en Release.
- `ios/Runner/Info.plist:1-70`: Ausencia de `NSPhotoLibraryUsageDescription` y `NSCameraUsageDescription`, causando crash al seleccionar fotos y rechazo en App Store.

---

## 12. Fase 11: UX, Accesibilidad e Internacionalización

### Balance
- **BAJA**: 1 (Cadenas hardcodeadas en español)
- **INFO**: 1 (Migración Tabler sin etiquetas Semantics en componentes nuevos)

---

## 13. Fase 12: Documentación, Coherencia y Mantenibilidad

### Balance
- **BAJA**: 1 (Código huérfano: `BundlesScreen` y `CorpusLogger`)
- **INFO**: 1 (Versión en `pubspec.yaml` sin actualizar: `1.2.4+9`)

---

## 14. Fase 13: Producto y Privacidad por Diseño

### Balance
- Recomendación de visibilidad de modo ranking en tarjetas y bloqueo defensivo ante clientes obsoletos.

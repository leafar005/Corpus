# Plan de Corrección y Mitigación: Corpus-dev

**Proyecto**: Corpus-dev  
**Fecha inicial**: 2026-11-08  
**Última actualización**: 2026-11-09 (Post-release `v1.3.0`)  
**Estado**: **Fases P0 y P1 completadas y desplegadas en producción (`v1.3.0`)**. Solo resta backlog P2 opcional.

---

## 1. Bloqueantes Previos a Publicar (Prioridad P0 — ✅ COMPLETADOS EN `v1.3.0`)

- [x] **1. Renombrar Migraciones en Conflicto y Fuera de Orden (SEC-01 & SEC-07)** — *Completado*:
  - Renombradas a `20260908000000_user_game_platforms.sql`, `20260909000000_roadmap_tables.sql`, `20260910000000_game_groups_replace_roadmap.sql` y `20260911000000_add_to_play_status.sql`. Aplicadas en producción (`npx supabase db push --remote`).
- [x] **2. Habilitar Entitlements de Red en macOS (NAT-01)** — *Completado*:
  - Añadido `com.apple.security.network.client = true` en `macos/Runner/Release.entitlements`.
- [x] **3. Declarar Cadenas de Permisos en iOS (NAT-02)** — *Completado*:
  - Añadidos `NSPhotoLibraryUsageDescription` y `NSCameraUsageDescription` en `ios/Runner/Info.plist`.
- [x] **4. Corregir Políticas de Storage RLS (SEC-02)** — *Completado*:
  - Aplicado en `supabase/migrations/20261108000000_security_and_feed_fixes.sql` exigiendo `(storage.foldername(name))[1] = auth.uid()::text` en `avatars` y `banners`.
- [x] **5. Permitir Notificaciones de Prueba a Tokens Propios (NOT-01)** — *Completado*:
  - Actualizado `supabase/functions/send-push-notification/index.ts` para permitir `data.type === 'test'` filtrando tokens pertenecientes a `user.id`.
- [x] **6. Preservar Descripción en Fallback de `GameGroupRepository` (DAT-02)** — *Completado*:
  - Actualizado `lib/repositories/game_group_repository.dart` y aplicada la migración `20261022000000_add_is_ranked_to_game_groups.sql` en producción.
- [x] **7. Mitigación de `to_play` frente a Clientes Antiguos (DAT-01)** — *Completado*:
  - Desplegada PWA `v1.3.0` con `Cache-Control: no-cache` en `/main.dart.js` y compilado/publicado el APK `v1.3.0`.
- [x] **8. Actualizar Filtro de Supresión de Feed para `to_play` (DAT-03)** — *Completado*:
  - Actualizado `public.on_review_upsert()` en `supabase/migrations/20261108000000_security_and_feed_fixes.sql` y limpiados eventos duplicados previos.
- [x] **9. Corregir CORS en Puertos Efímeros y Respuestas `POST` (CORS-01)** — *Completado*:
  - Actualizado `supabase/functions/_shared/cors.ts` y las 15 Edge Functions usando `corsHeadersForRequest(req)`.

---

## 2. Quick Wins (Prioridad P1 — ✅ COMPLETADOS EN `v1.3.0`)

- [x] **UI-01**: Incluido `completed` junto a `beaten` en `CollectionRepository.fetchLibraryForShelf` (`lib/repositories/collection_repository.dart`).
- [x] **DAT-05**: Sanitizados los campos de reseña al marcar `to_play` en `ReviewRepository` (`lib/repositories/review_repository.dart`).
- [x] **DEP-01**: Cambiada la caché de `/main.dart.js` a `no-cache` en `vercel.json`.
- [x] **SEC-04**: Protegida la columna `xp` en `public.users` mediante el trigger `trg_protect_user_xp` (`20261108000000_security_and_feed_fixes.sql`).
- [x] **SEC-03**: Endurecida la validación de llamante en `notify-comment`, `notify-friend-activity` y `notify-bundle-expiring`.
- [x] **NAV-01**: Añadido `RouteSettings(name: '/group-detail/${group.id}')` al navegar a `GroupDetailScreen` (`lib/screens/my_games/groups_tab.dart`).
- [x] **DOC-01**: Actualizada la versión a `1.3.0+10` en `pubspec.yaml`, `lib/screens/info_screen.dart`, `CHANGELOG.md` y `README.md`.

---

## 3. Siguiente Iteración y Deuda Técnica (Prioridad P2 — ✅ 6/8 COMPLETADOS)

- [x] **SEC-05 (Completo)**: Fijado `SET search_path = public, pg_temp` en todas las funciones `SECURITY DEFINER` del esquema `public` mediante `supabase/migrations/20261109000000_fix_security_definer_search_path.sql`.
- [x] **SEC-06**: Actualizado `bucketKeyFromRequest` en `supabase/functions/_shared/rate-limit.ts` para verificar tokens JWT de usuarios autenticados (`user:<id>`) y usar la IP real del cliente (`cf-connecting-ip`) como fallback ante tokens falsos o modo invitado.
- [x] **SEC-08**: Eliminada la omisión de imágenes `< 50 KB` en `lib/utils/image_compressor.dart` (se recomprimen a calidad 95 con `keepExif: false` para purgar siempre metadatos EXIF/GPS).
- [x] **SEC-09**: Añadidos hashes `integrity="sha384-..."` y `crossorigin="anonymous"` a las etiquetas de CropperJS 1.6.2 en `web/index.html`.
- [x] **NAV-02**: Añadida validación de expresión regular UUID (`_uuidPattern`) en `lib/routes/tab_deep_route.dart` y actualizados los tests en `test/routes/tab_deep_route_test.dart` y `test/routes/app_routes_test.dart`.
- [x] **ARCH-01**: Eliminado el archivo huérfano `lib/screens/bundles/bundles_screen.dart`.
- [ ] **DAT-04 (Evolutivo)**: Conectar el trigger `check_and_unlock_achievements` para que lea dinámicamente de `achievement_rules` y `achievement_match_patterns`.
- [ ] **PERF-01 (Evolutivo)**: Continuar la división progresiva de los 10 archivos de más de 1.000 líneas siguiendo ADR-002.

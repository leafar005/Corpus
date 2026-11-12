# Tabla Consolidada de Hallazgos: Auditoría Técnica Corpus-dev

**Proyecto**: Corpus-dev  
**Fecha de auditoría**: 2026-11-08  
**Última actualización de estado**: 2026-11-09 (Iteración P2 completada)  
**Progreso global**: **23 / 25 resueltos (92 % — 100 % de Críticos, Altos, Bajos e Info completados)**

---

| ID | Severidad | Estado Actual | Área | Título del Hallazgo | Resolución / Archivo |
|---|---|---|---|---|---|
| **SEC-01** | **CRÍTICA** | ✅ **RESUELTO (`v1.3.0`)** | Migraciones / BD | Colisión de timestamp `20260904000000` en migración `user_game_platforms.sql` | Renombrada a `20260908000000_user_game_platforms.sql` y aplicada en producción |
| **DAT-01** | **CRÍTICA** | ✅ **MITIGADO (`v1.3.0`)** | Integridad / Clientes | Degradación de estado `to_play` a `wishlist` en clientes viejos `v1.2.4` | Desplegada web `v1.3.0` (`no-cache` en `main.dart.js`) y publicado APK `v1.3.0` |
| **NAT-01** | **CRÍTICA** | ✅ **RESUELTO (`v1.3.0`)** | Plataformas Nativas | Bloqueo de red en macOS Release por falta de `network.client` en Sandbox | Añadido `com.apple.security.network.client` en `macos/Runner/Release.entitlements` |
| **SEC-02** | **CRÍTICA** | ✅ **RESUELTO (`v1.3.0`)** | Supabase Storage | Políticas permisivas de UPDATE y DELETE en Storage (`avatars` y `banners`) sin control de `owner` | Restringidas por carpeta `auth.uid()` en `20261108000000_security_and_feed_fixes.sql` |
| **NAT-02** | **ALTA** | ✅ **RESUELTO (`v1.3.0`)** | Plataformas Nativas | Falta de descripciones de permisos de fotos/cámara en `Info.plist` de iOS | Añadidos `NSPhotoLibraryUsageDescription` y `NSCameraUsageDescription` en `ios/Runner/Info.plist` |
| **NOT-01** | **ALTA** | ✅ **RESUELTO (`v1.3.0`)** | Edge Functions | Regresión en notificación de prueba del cliente en `send-push-notification` (HTTP 403) | Soportado `data.type === 'test'` validando propiedad del token en `send-push-notification/index.ts` |
| **SEC-03** | **ALTA** | ✅ **RESUELTO (`v1.3.0`)** | Edge Functions | Confused Deputy en `notify-comment`, `notify-friend-activity` y `notify-bundle-expiring` | Añadida validación de `service_role` / `CRON_SECRET` y verificación en BD del registro real |
| **DAT-02** | **ALTA** | ✅ **RESUELTO (`v1.3.0`)** | Repositorios | Borrado de la descripción de grupos en fallback de `GameGroupRepository.updateGroup` | Conservada descripción previa en `lib/repositories/game_group_repository.dart` y aplicada migración `is_ranked` |
| **SEC-04** | **ALTA** | ✅ **RESUELTO (`v1.3.0`)** | Base de Datos / RLS | Manipulación directa y no autorizada de experiencia (`xp`) en `public.users` | Creado trigger `trg_protect_user_xp` (`protect_user_xp()`) en `20261108000000_security_and_feed_fixes.sql` |
| **DAT-03** | **ALTA** | ✅ **RESUELTO (`v1.3.0`)** | Triggers / Feed | Duplicación de eventos `reviewed` en el Activity Feed al registrar juegos en `to_play` | Actualizado `on_review_upsert()` en `20261108000000_security_and_feed_fixes.sql` y limpiados duplicados |
| **CORS-01**| **ALTA** | ✅ **RESUELTO (`v1.3.0`)** | Edge Functions / Web | Bloqueo CORS en puertos efímeros `localhost:<puerto>` y respuestas `POST` con `corsHeaders` estático | Corregido `isAllowedOrigin` en `_shared/cors.ts` y `corsHeadersForRequest(req)` en las 15 funciones |
| **SEC-05** | **MEDIA** | ✅ **RESUELTO** | Base de Datos / SQL | Funciones `SECURITY DEFINER` sin fijación explícita de `SET search_path = public` | Fijado en todas las funciones `SECURITY DEFINER` de `public` en `20261109000000_fix_security_definer_search_path.sql` |
| **SEC-06** | **MEDIA** | ✅ **RESUELTO** | Edge Functions | Evasión de Rate Limiting en `igdb-proxy` rotando tokens Bearer no verificados | Verificación de usuario real (`user:<id>`) y fallback a IP (`cf-connecting-ip`) en `_shared/rate-limit.ts` |
| **SEC-07** | **MEDIA** | ✅ **RESUELTO (`v1.3.0`)** | Migraciones | Migraciones `20260905`–`20260907` con timestamps anteriores a producción (`20260907121000`) | Renombradas a `20260909000000`–`20260911000000` y aplicadas en producción |
| **DAT-04** | **MEDIA** | ⏳ **EVOLUTIVO (P2)** | Esquema de BD | Tablas `achievement_rules` y `achievement_match_patterns` aún no leídas por el trigger SQL | Las tablas ya están creadas en BD; migrar el trigger `check_and_unlock_achievements` es evolutivo |
| **UI-01** | **MEDIA** | ✅ **RESUELTO (`v1.3.0`)** | Repositorios / UI | Exclusión de juegos platinados (`completed`) en sugerencias de la estantería | Cambiado a `.inFilter('status', ['beaten', 'completed'])` en `lib/repositories/collection_repository.dart` |
| **DAT-05** | **MEDIA** | ✅ **RESUELTO (`v1.3.0`)** | Repositorios | Inconsistencia en la sanitización de reseñas para juegos marcados como `to_play` | Incluido `status == 'to_play'` en `isWishlist` dentro de `lib/repositories/review_repository.dart` |
| **NAV-01** | **MEDIA** | ✅ **RESUELTO (`v1.3.0`)** | Navegación Web | Falta de `RouteSettings` al navegar a `GroupDetailScreen` | Añadido `RouteSettings(name: '/group-detail/${group.id}')` en `lib/screens/my_games/groups_tab.dart` |
| **DEP-01** | **MEDIA** | ✅ **RESUELTO (`v1.3.0`)** | Despliegue Web / CI | Caché inmutable de 1 año en `main.dart.js` en `vercel.json` | Cambiado a `Cache-Control: no-cache` para `/main.dart.js` en `vercel.json` |
| **PERF-01**| **BAJA** | ⏳ **EVOLUTIVO (P2)** | Mantenibilidad | Persistencia de 10 archivos monolíticos (God Files) mayores a 1.000 líneas | Refactorización progresiva continua siguiendo ADR-002 |
| **SEC-08** | **BAJA** | ✅ **RESUELTO** | Privacidad | Imágenes menores a 50 KB omitían recomprimir y podían conservar metadatos EXIF | Todas las imágenes pasan por `FlutterImageCompress` (`keepExif: false`, calidad 95 si `< 50 KB`) en `lib/utils/image_compressor.dart` |
| **SEC-09** | **BAJA** | ✅ **RESUELTO** | Seguridad Web | Falta de atributos de Subresource Integrity (SRI) en CDN de CropperJS en `web/index.html` | Añadidos hashes `sha384` y `crossorigin="anonymous"` en `web/index.html` |
| **NAV-02** | **BAJA** | ✅ **RESUELTO** | Enrutamiento | Parser de rutas en `tab_deep_route.dart` no validaba formato UUID en `/user/:id` | Validación con `_uuidPattern` en `lib/routes/tab_deep_route.dart` y tests actualizados |
| **DOC-01** | **INFO** | ✅ **RESUELTO (`v1.3.0`)** | Higiene / Release | Versión en `pubspec.yaml`, `info_screen.dart` y `CHANGELOG.md` desactualizada | Actualizados a `1.3.0+10` / `Versión 1.3.0` |
| **ARCH-01**| **INFO** | ✅ **RESUELTO** | Arquitectura | Archivo `bundles_screen.dart` sin referencias tras mover Bundles a Explorar | Eliminado `lib/screens/bundles/bundles_screen.dart` |

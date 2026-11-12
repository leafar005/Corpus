# Resumen Ejecutivo: Auditoría Técnica y de Seguridad de Corpus-dev

**Proyecto**: Corpus-dev (Flutter App & Supabase Backend)  
**Fecha inicial**: 2026-11-08  
**Última actualización**: 2026-11-09 (Post-remediación y release `v1.3.0`)  
**Rango de Delta auditado**: `773bfc5..698729f` (`v1.2.4` → `v1.3.0`)  
**Veredicto Oficial**: **✅ GO (BLOQUEANTES RESUELTOS Y DESPLEGADOS EN `v1.3.0`)**  

---

## 1. Veredicto y Evaluación General
Tras la inspección minuciosa y de solo lectura de los 150 archivos modificados en el delta `773bfc5..86c1116`, de las 62 migraciones de Supabase, de las 15 Edge Functions en Deno/TypeScript, de los subsistemas cliente en Dart/Flutter y de las configuraciones de empaquetado nativo (Android, iOS, macOS, Web), **se dictamina un veredicto de NO GO categórico para el pase a producción de la versión actual**.

Aunque la actualización introduce funcionalidades de alto valor (el módulo `my_games` con estantería física virtual y grupos jerárquicos clasificados, un sistema vectorial unificado de iconos Tabler y robustecimiento de seguridad frente a path traversal en style packs ZIP derivado de auditorías previas), se han identificado **4 fallos de severidad CRÍTICA** y **6 de severidad ALTA** que provocarían caídas inmediatas en tiempo de ejecución, corrupción irreversible de datos en la biblioteca de los usuarios, bloqueos a nivel de kernel en macOS y rechazo fulminante en el proceso de revisión de Apple App Store.

---

## 2. Top 10 Riesgos Priorizados y Estado de Remediación

| # | ID | Severidad | Estado | Área | Título Sintético del Riesgo | Impacto Original / Resolución |
|---|---|---|---|---|---|---|
| 1 | **SEC-01** | **CRÍTICA** | ✅ **RESUELTO** | Migraciones / BD | Colisión de timestamp `20260904000000` en migración `user_game_platforms.sql` | Renombrada a `20260908000000_user_game_platforms.sql` y aplicada en producción (`rhcgjiwmlqswlideqzid`). |
| 2 | **DAT-01** | **CRÍTICA** | ✅ **MITIGADO** | Integridad / Clientes | Degradación y corrupción silenciosa de estado `to_play` a `wishlist` en clientes `v1.2.4` | Publicadas Web `v1.3.0` (`no-cache` en `main.dart.js`) y APK `v1.3.0`. |
| 3 | **NAT-01** | **CRÍTICA** | ✅ **RESUELTO** | Plataformas Nativas | Bloqueo total de conectividad de red en compilaciones Release de macOS por Sandbox | Añadido `com.apple.security.network.client` en `macos/Runner/Release.entitlements`. |
| 4 | **SEC-02** | **CRÍTICA** | ✅ **RESUELTO** | Storage / RLS | Políticas permisivas de UPDATE y DELETE en Storage (`avatars` y `banners`) | Restringidas por carpeta `auth.uid()` en `20261108000000_security_and_feed_fixes.sql`. |
| 5 | **NAT-02** | **ALTA** | ✅ **RESUELTO** | Plataformas Nativas | Rechazo en App Store y crash en iOS por falta de descripciones de permisos en `Info.plist` | Añadidos `NSPhotoLibraryUsageDescription` y `NSCameraUsageDescription` en `ios/Runner/Info.plist`. |
| 6 | **NOT-01** | **ALTA** | ✅ **RESUELTO** | Edge Functions | Regresión en notificaciones push de prueba desde el cliente (`send-push-notification`) | Soportado `data.type === 'test'` verificando propiedad del token en `push_tokens`. |
| 7 | **SEC-03** | **ALTA** | ✅ **RESUELTO** | Edge Functions | Confused Deputy en `notify-comment`, `notify-friend-activity` y `notify-bundle-expiring` | Añadida validación de `service_role` / `CRON_SECRET` y comprobación en BD del registro real. |
| 8 | **DAT-02** | **ALTA** | ✅ **RESUELTO** | Repositorios | Corrupción y borrado de la descripción de grupos en `GameGroupRepository.updateGroup` | Conservada la descripción previa en fallback y aplicada la migración `is_ranked` en producción. |
| 9 | **SEC-04** | **ALTA** | ✅ **RESUELTO** | Base de Datos / RLS | Manipulación directa y no autorizada de experiencia (`xp`) en `public.users` | Protegida la columna `xp` mediante trigger `trg_protect_user_xp` en producción. |
| 10| **DAT-03** | **ALTA** | ✅ **RESUELTO** | Triggers / Feed | Duplicación de eventos en el Activity Feed al registrar juegos en `to_play` | Actualizado `on_review_upsert` en producción para excluir `'to_play'` y limpiados duplicados. |

# Control de Calidad — Segunda Pasada (Revisión Adversaria)

**Proyecto**: Corpus-dev  
**Fecha**: 2026-11-08  
**Objetivo**: Someter a contraste y refutación activa todos los hallazgos de severidad CRÍTICA y ALTA para garantizar la ausencia de falsos positivos y la solidez irrefutable de la evidencia.

---

## 1. Metodología de Refutación Adversaria

Para cada hallazgo crítico o alto se plantea la hipótesis nula ("El código funciona correctamente / El hallazgo es un falso positivo por X motivo") y se contrasta minuciosamente contra el código fuente, la configuración y el comportamiento real de los runtimes (PostgreSQL, Flutter Engine, Deno, Apple Sandbox).

---

## 2. Resultados de la Evaluación Adversaria

### Caso 1: SEC-01 — Colisión de Versión de Migración `20260904000000`
- **Severidad Inicial**: CRÍTICA
- **Hipótesis Adversaria de Falso Positivo**: "La CLI de Supabase utiliza el nombre de archivo completo como identificador único o resuelve colisiones en base a la extensión o hash".
- **Contraste contra el Código y Runtime**:
  - En PostgreSQL, la tabla `supabase_migrations.schema_migrations` tiene como clave primaria la columna `version text PRIMARY KEY`.
  - En `ORIGINAL_REQUEST.md`, la consulta de producción confirma que ya existe una fila con `version = '20260904000000'` (asociada a `fix_activity_feed_backdate`).
  - La CLI de Supabase extrae el prefijo numérico previo al primer guion bajo (`20260904000000`). Al comprobar si la versión existe en la tabla remota, la consulta devuelve verdadero (`EXISTS(...) = true`).
  - En consecuencia, la CLI omite el archivo `20260904000000_user_game_platforms.sql` sin ejecutar su contenido DDL.
- **Veredicto Final**: **CONFIRMADO SIN AMBIGÜEDAD**. Severidad ratificada en **CRÍTICA**.

---

### Caso 2: DAT-01 — Degradación Silenciosa de `to_play` en Clientes v1.2.4
- **Severidad Inicial**: CRÍTICA
- **Hipótesis Adversaria de Falso Positivo**: "El cliente v1.2.4 ignora estados desconocidos o simplemente no permite guardar si no reconoce un valor".
- **Contraste contra el Código y Runtime**:
  - Se inspeccionó el archivo de la versión `v1.2.4` (`git show 773bfc5:lib/models/game_status.dart:60-68`).
  - `GameStatus.fromStringOrDefault` tiene un bloque `try/catch` que devuelve `fallback` (`GameStatus.wishlist`) ante cualquier excepción de parseo.
  - Al abrir un juego o lista en `v1.2.4`, el estado del objeto en memoria se convierte en `GameStatus.wishlist`.
  - Al presionar guardar, `UserGame.toMap()` y `Review.toMap()` envían `'status': status.dbValue` (es decir, `'wishlist'`), sobreescribiendo el registro en PostgreSQL.
- **Veredicto Final**: **CONFIRMADO**. El riesgo de corrupción y degradación de datos es real. Severidad ratificada en **CRÍTICA**.

---

### Caso 3: NAT-01 — Bloqueo de Conexiones de Red en macOS Release por Sandbox
- **Severidad Inicial**: CRÍTICA
- **Hipótesis Adversaria de Falso Positivo**: "El plugin de Supabase o Flutter macOS inyecta el entitlement de red en el proceso de build de Xcode automáticamente".
- **Contraste contra el Código y Runtime**:
  - En macOS, los entitlements son compilados e integrados en la firma de código directamente desde el archivo `macos/Runner/Release.entitlements`.
  - El archivo `DebugProfile.entitlements` sí incluye `com.apple.security.network.client`, por lo que en desarrollo local la red funciona.
  - Sin embargo, `Release.entitlements` únicamente contiene `com.apple.security.app-sandbox`.
  - El subsistema de seguridad XNU / Sandbox de macOS deniega a nivel de syscall cualquier intento de apertura de socket TCP/UDP a procesos cuyo binario carezca de este entitlement explícito.
- **Veredicto Final**: **CONFIRMADO**. Provocaría caída total de conectividad en producción macOS. Severidad ratificada en **CRÍTICA**.

---

### Caso 4: SEC-02 — Políticas Permisivas de Storage para `avatars` y `banners`
- **Severidad Inicial**: CRÍTICA
- **Hipótesis Adversaria de Falso Positivo**: "El motor de Storage de Supabase restringe internamente la sobreescritura de archivos a través de las rutas de usuario".
- **Contraste contra el Código y Runtime**:
  - Supabase Storage implementa la seguridad a través de RLS en la tabla `storage.objects`.
  - La migración `supabase/migrations/20260728000001_production_sync.sql` define explícitamente:
    `CREATE POLICY "Avatars Update Policy" ON storage.objects FOR UPDATE USING (bucket_id = 'avatars' AND auth.role() = 'authenticated');`
  - No existe ninguna condición adicional. Cualquier usuario autenticado tiene permiso concedido por PostgreSQL para ejecutar UPDATE y DELETE sobre cualquier fila de la tabla `storage.objects` cuyo `bucket_id` sea `avatars` o `banners`.
- **Veredicto Final**: **CONFIRMADO**. Vulnerabilidad de suplantación y borrado no autorizado. Severidad ratificada en **CRÍTICA**.

---

### Caso 5: NOT-01 — Regresión en Notificación Push de Prueba
- **Severidad Inicial**: ALTA
- **Hipótesis Adversaria de Falso Positivo**: "El cliente usa una Edge Function intermedia que tiene service_role".
- **Contraste contra el Código y Runtime**:
  - En `lib/services/notification_service.dart:329-337`, el cliente invoca directamente `send-push-notification` enviando el token JWT de usuario en la cabecera `Authorization`.
  - En `supabase/functions/send-push-notification/index.ts:232-241`, la función comprueba `if (token !== SUPABASE_SERVICE_ROLE_KEY) { const { data: { user } } = await supabaseAdmin.auth.getUser(token); if (user || authError) return 403; }`.
  - La condición `if (user)` se cumple para todo usuario registrado y la función responde HTTP 403.
- **Veredicto Final**: **CONFIRMADO**. El botón de prueba en la app falla sistemáticamente. Severidad ratificada en **ALTA**.

---

### Caso 6: DAT-02 — Borrado de Descripción en `GameGroupRepository.updateGroup`
- **Severidad Inicial**: ALTA
- **Hipótesis Adversaria de Falso Positivo**: "La interfaz de usuario siempre envía la descripción actual junto con el toggle de ranking".
- **Contraste contra el Código y Runtime**:
  - La firma del método en `lib/repositories/game_group_repository.dart:160` es:
    `Future<GameGroup> updateGroup({required String groupId, String? name, String? description, int? coverGameId, bool? isRanked})`
  - En los controladores de UI (por ejemplo, al alternar un switch en una lista de opciones rápidas), únicamente se invoca `updateGroup(groupId: id, isRanked: val)`.
  - El parámetro `description` es `null`.
  - En el bloque `catch`, se ejecuta `updates['description'] = GameGroup.encodeRankedDescription(description, isRanked);`.
  - `GameGroup.encodeRankedDescription(null, true)` evalúa y devuelve `'[#ranked#]'`.
  - La descripción anterior se sobrescribe en la base de datos y se destruye irreversiblemente.
- **Veredicto Final**: **CONFIRMADO**. Severidad ratificada en **ALTA**.

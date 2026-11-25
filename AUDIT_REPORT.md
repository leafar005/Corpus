# Auditoría Técnica Exhaustiva — Proyecto Corpus

> **Fase**: Diagnóstico y Registro (R3 — solo lectura sobre el código fuente)  
> **Línea base**: Rama `main` en commit `fa8c5b2` (`208` archivos en `lib/`, `55` archivos en `web/`)  
> **Documento generado desde cero** conforme a la especificación R1 & R2.

---

## Resumen Ejecutivo

Se ejecutó una auditoría técnica línea por línea sobre el 100% del alcance especificado del repositorio **Corpus** (`lib/models`, `lib/repositories`, `lib/services`, `lib/screens`, `lib/widgets`, `lib/routes`, `lib/utils`, `lib/main.dart`, `lib/globals.dart` y `web/`), cubriendo las cuatro áreas de inspección de R1: (1) bugs y fallas lógicas/runtime, (2) optimización de rendimiento UI y renderizado Flutter, (3) optimización de red, Supabase y caché, y (4) fallas de arquitectura, seguridad y mantenibilidad.

Tras consolidar los hallazgos transversales sin pérdida de ubicaciones ni sub-causas, el reporte registra **272 hallazgos accionables** distribuidos en las cuatro secciones obligatorias:

| Sección | Prefijo | Total | Crítico | Alto | Medio | Bajo |
|---|---|---:|---:|---:|---:|---:|
| **1. Bugs Críticos y Fallas** | `[BUG-XX]` | **165** | 18 | 78 | 59 | 10 |
| **2. Optimizaciones de Rendimiento y Red** | `[OPT-XX]` | **60** | 2 | 27 | 24 | 7 |
| **3. Mejoras Arquitectónicas y de Gran Escala** | `[ARQ-XX]` | **30** | 0 | 6 | 18 | 6 |
| **4. Micro-optimizaciones y Deuda Técnica** | `[MICRO-XX]` | **17** | 0 | 0 | 0 | 17 |
| **Total consolidado** | — | **272** | **20** | **111** | **101** | **40** |

---

## Tabla de Cobertura del Alcance (100% Verificado)

| # | Área / Ruta inspeccionada | Archivos / Líneas auditadas | Áreas R1 cubiertas | Estado |
|---|---|---|---|---|
| 1 | `lib/main.dart`, `lib/globals.dart`, `lib/routes/` (8), `lib/utils/` (19), `web/` (55) | 84 archivos (`lib/` + `web/`) | Áreas 1–4 | 100% auditado |
| 2 | `lib/models/` (14), `lib/repositories/` (8) | 22 archivos (5,802 líneas) | Áreas 1–4 | 100% auditado |
| 3 | `lib/services/` | 12 archivos (2,962 líneas) | Áreas 1–4 | 100% auditado |
| 4 | `lib/screens/activity/` | 11 archivos (6,289 líneas) | Áreas 1–4 | 100% auditado |
| 5 | `lib/screens/library/` | 16 archivos (8,665 líneas) | Áreas 1–4 | 100% auditado |
| 6 | `lib/screens/profile/` (pantallas) y `achievements/` | 13 archivos (7,855 líneas) | Áreas 1–4 | 100% auditado |
| 7 | `lib/screens/profile/widgets/` (10) y `lib/screens/my_games/` (7) | 17 archivos (6,348 líneas) | Áreas 1–4 | 100% auditado |
| 8 | `lib/screens/home/` (4), `settings/` (7), `auth/` (4), `bundles/` (1) | 16 archivos (6,638 líneas) | Áreas 1–4 | 100% auditado |
| 9 | `lib/screens/` raíz (4), `main/` (1), `social/` (3), `design/` (9) | 17 archivos (4,887 líneas) | Áreas 1–4 | 100% auditado |
| 10 | `lib/widgets/` (31) y `lib/widgets/design/` (18) | 49 archivos (7,286 líneas) | Áreas 1–4 | 100% auditado |

---

## 1. Bugs Críticos y Fallas

### [BUG-01] — Condiciones de carrera, fuga de canal Realtime y Null-Check crash en `_AuthGateState`
- **ID y Título**: `[BUG-01]` — Condiciones de carrera, fuga de canal Realtime y Null-Check crash en `_AuthGateState`
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Media
- **Ubicación**: `lib/main.dart:201-243`, `lib/main.dart:246-285`, `lib/main.dart:287-296`, `lib/main.dart:339-341`
- **Problema / Causa raíz**:
  1. `_setupPresence()` (L246-285) es `void ... async` sin guarda reentrante antes de `await notifService.requestPermissions()` (L256). `_presenceChannel` no se asigna hasta L262. Si `onAuthStateChange` emite eventos seguidos (`initialSession` + `signedIn`) o `didChangeAppLifecycleState(resumed)` (L301-302) se dispara mientras el diálogo de permisos está abierto, dos ejecuciones pasan `if (userId == null || _presenceChannel != null) return;`, creando dos canales Realtime y sobrescribiendo `_presenceChannel`, lo que filtra el primer canal sin `removeChannel`.
  2. Si el usuario cierra sesión (`_cleanupPresenceChannel()`, L287-296) mientras `_setupPresence()` espera `requestPermissions()`, al reanudarse crea y suscribe `_presenceChannel` estando ya deslogueado.
  3. Dentro de `.onPresenceSync` (L266) y `.subscribe` (L282) se dereferencia `_presenceChannel!` asumiendo que sigue no-nulo; si `_cleanupPresenceChannel()` puso `_presenceChannel = null` antes de que llegue el callback asíncrono, lanza `Null check operator used on a null value`.
  4. En L228-230, `UserSettingsService().pullAndApplyToLocalCache().then((_) { themeNotifier.reloadFromPrefs(); })` es un `Future` sin `await`, sin `catchError` y sin cancelar ante un logout: si el usuario cierra sesión mientras la query remota está en vuelo (timeout de 6s), `reloadFromPrefs()` corre después de `resetAllGlobalState()` (L240) reintroduciendo preferencias previas o compitiendo con `resetLocalCacheToDefaults()`.
  5. `StreamSubscription.listen((data) async { ... })` (L203-243) no serializa callbacks `async`; `await resetAllGlobalState()` (L240) puede ejecutarse en paralelo con el `signedIn` inmediato de otro usuario.
  6. En L339-341, `StreamBuilder` consume `widget.authStream ?? Supabase.instance.client.auth.onAuthStateChange` directamente en `build()` en lugar de un `Stream` cacheado en `initState` o un único listener compartido con `_authSub`.
- **Solución propuesta**:
  1. Cachear el stream de auth en `initState()` y almacenar la sesión actual en estado local de `_AuthGateState` impulsado por `_authSub` (eliminando la doble suscripción de `StreamBuilder`).
  2. Serializar las transiciones de sesión mediante una cola/token monótono (`int _authEpoch`) para descartar continuaciones obsoletas tras `signedOut` o cambio de usuario antes de aplicar `themeNotifier.reloadFromPrefs()`.
  3. Añadir flag `bool _settingUpPresence = false` al inicio de `_setupPresence()`, comprobar `mounted` y que `currentUser?.id == userId` tras `await requestPermissions()`, y capturar `final channel = Supabase.instance.client.channel('online-users');` en variable local dentro de `.onPresenceSync` y `.subscribe` en lugar de usar `_presenceChannel!`.

### [BUG-02] — Crash garantizado en fallback de `GameGroupRepository.updateGroup` por proyección incompleta hacia `GameGroup.fromMap`
- **ID y Título**: `[BUG-02]` — Crash garantizado en fallback de `GameGroupRepository.updateGroup` por proyección incompleta hacia `GameGroup.fromMap`
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/game_group_repository.dart:191-200`, `lib/models/game_group.dart:127-130`
- **Problema / Causa raíz**: En `GameGroupRepository.updateGroup`, cuando la columna `is_ranked` no existe en BD y el parámetro `description` es `null`, el fallback ejecuta `.select('description')` (línea 193) y luego pasa el mapa resultante a `GameGroup.fromMap(...)` (líneas 197-199). Sin embargo, `GameGroup.fromMap` exige `name: map['name'] as String` (línea 129) y lee `map['id']` y `map['user_id']`. Al no haber seleccionado `name`, `map['name']` es `null` y lanza `TypeError: type 'Null' is not a subtype of type 'String'` de forma determinista cada vez que se activa ese fallback.
- **Solución propuesta**:
  1. En `GameGroupRepository.updateGroup` (líneas 191-200), evitar construir un `GameGroup` completo y decodificar directamente `GameGroup.decodeRankedDescription(current['description'] as String?).description` (o seleccionar `id, user_id, name, description`).
  2. En `GameGroup.fromMap` (`lib/models/game_group.dart:127-129`), usar valores seguros: `id: map['id']?.toString() ?? ''`, `userId: map['user_id']?.toString() ?? ''`, `name: map['name']?.toString() ?? ''`.

### [BUG-03] — Crash por casts inseguros en `Game.fromMap` (`igdbId`, `cover`, `first_release_date`, `metacritic_updated_at`)
- **ID y Título**: `[BUG-03]` — Crash por casts inseguros en `Game.fromMap` (`igdbId`, `cover`, `first_release_date`, `metacritic_updated_at`)
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/models/game.dart:128-140`, `lib/models/game.dart:160-168`
- **Problema / Causa raíz**:
  1. Línea 128: `igdbId: (map['igdb_id'] ?? map['id']) as int` falla con `TypeError` si ambos son `null`, si llegan como `double` (Web/JS) o como `String` (`"123"`). El resto de campos enteros usan `(map[...] as num?)?.toInt()`, pero `igdbId` no.
  2. Líneas 132-133: `map['cover'] != null && map['cover']['image_id'] != null` no verifica `map['cover'] is Map`. Si IGDB devuelve `cover` sin expandir (un `int` ID), `map['cover']['image_id']` lanza `NoSuchMethodError`.
  3. Líneas 136-139: `(map['first_release_date'] as num)` y `map['release_date'] as String?` fallan si el tipo difiere, y `DateTime.fromMillisecondsSinceEpoch(..., isUtc: false)` usa zona horaria local, desplazando un día atrás las fechas UTC medianoche en husos negativos al truncar `.split('T')[0]`.
  4. Línea 167: `DateTime.tryParse(map['metacritic_updated_at'] as String)` falla si viene como `DateTime` o no-String.
- **Solución propuesta**:
  1. Crear helper `_parseInt(dynamic v)` (acepta `num` y `int.tryParse`) y usarlo para `igdbId` (con fallback claro o `ArgumentError` descriptivo si es obligatorio).
  2. Cambiar línea 132 a `map['cover'] is Map && (map['cover'] as Map)['image_id'] != null`.
  3. Usar `isUtc: true` en `DateTime.fromMillisecondsSinceEpoch(..., isUtc: true)` y convertir fechas/strings con `.toString()` / `is DateTime`.

### [BUG-04] — Crash en `ActivityRepository._mergeActivityItems` por `DateTime.parse` sin `tryParse` y cast `as String`
- **ID y Título**: `[BUG-04]` — Crash en `ActivityRepository._mergeActivityItems` por `DateTime.parse` sin `tryParse` y cast `as String`
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/activity_repository.dart:806-812`
- **Problema / Causa raíz**: En `_mergeActivityItems`, las líneas 807 y 811 ejecutan `DateTime.parse(dateStr as String)` y `DateTime.parse(prev['created_at'] as String)`. Si cualquier fila tiene `created_at == null` en `prev`, un valor `DateTime` en memoria o una cadena malformada, lanza `TypeError` o `FormatException` y tumba la carga completa de la página del feed o stories (en contraste con `_groupActivityItems` en línea 959, que sí usa `DateTime.tryParse`).
- **Solución propuesta**:
  1. Reemplazar ambas líneas por `final date = DateTime.tryParse(dateStr.toString());` y `final prevDate = prev['created_at'] != null ? DateTime.tryParse(prev['created_at'].toString()) : null;`.
  2. Si `date == null`, omitir el intento de fusión; en el bucle interior, saltar iteración si `prevDate == null`.

### [BUG-05] — Pérdida silenciosa de cambios offline y bloqueo de sincronización en `UserSettingsService.pullAndApplyToLocalCache`
- **ID y Título**: `[BUG-05]` — Pérdida silenciosa de cambios offline y bloqueo de sincronización en `UserSettingsService.pullAndApplyToLocalCache`
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/user_settings_service.dart:12-14, 72-78, 112-126, 140-167`, `lib/main.dart:228`
- **Problema / Causa raíz**: `_pending` vive únicamente en memoria RAM (línea 12), mientras que `user_settings_dirty` se persiste en `SharedPreferences` (líneas 113-115). Si el usuario modifica un ajuste sin conexión o cierra la app antes de que el debounce/upsert complete, en el siguiente arranque `_pending` está vacío pero `user_settings_dirty == true`. Al iniciar sesión (`lib/main.dart:228`), `pullAndApplyToLocalCache()` entra en `if (prefs.getBool('user_settings_dirty') == true)` (línea 72), llama a `flushNow()` (línea 73) -> `_flush()` retorna inmediatamente por `if (_pending.isEmpty) return;` (línea 141) -> `flushNow()` devuelve `_pending.isEmpty` (`true`, línea 125) -> la línea 74 marca `user_settings_dirty = false` y ejecuta `return;` (línea 77). Resultado: ni se suben los cambios locales pendientes a Supabase ni se descargan los ajustes remotos; el dispositivo queda permanentemente desincronizado.
- **Solución propuesta**:
  1. Cuando `user_settings_dirty == true` y `_pending.isEmpty` (arranque tras cierre con cambios sin subir), reconstruir el payload desde `_snapshotLocals(prefs)` (o persistir `_pending` serializado en JSON en `SharedPreferences` bajo una clave `user_settings_pending_json`) y enviarlo mediante `upsert` antes de limpiar `user_settings_dirty`.
  2. Tras completar el flush de cambios pendientes, realizar igualmente la descarga/reconciliación remota si procede (o registrar timestamp por clave / `updated_at`).

### [BUG-06] — `ImportService.saveImportedGames`: duplicación de reseñas al reintentar/reimportar y violación `NOT NULL` por `created_at: null`
- **ID y Título**: `[BUG-06]` — `ImportService.saveImportedGames`: duplicación de reseñas al reintentar/reimportar y violación `NOT NULL` por `created_at: null`
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Media
- **Ubicación**: `lib/services/import_service.dart:323-330, 349, 405-413, 496, 529-568`
- **Problema / Causa raíz**:
  1. `games` y `user_games` usan `upsert`, pero `reviews` ejecuta `.insert(reviewsPayload)` (línea 530). Reimportar un archivo o reintentar tras un error parcial (lote N) duplica todas las reseñas de los lotes anteriores.
  2. En líneas 405-413, si `row.steamOwned == true` y `row.steamLastPlayedAt == null && row.dateAdded == null`, `effectiveLastPlayedAt` es `null`. La línea 496 envía `'created_at': null` explícitamente en el `INSERT`, lo que anula el `DEFAULT now()` de PostgreSQL y falla si `reviews.created_at` es `NOT NULL` (o deja filas sin fecha).
  3. `row.dateAdded` (líneas 144-147, 407) y `row.completionType` (líneas 137-141, 490) no se validan antes de enviarlos: una fecha `"15/03/2024"` o un `completion_type` inválido tumba todo el lote de 25 juegos.
  4. La línea 329 retorna silenciosamente (`if (userId == null) return;`) si la sesión expiró, haciendo creer a la UI que la importación terminó con éxito.
  5. La línea 349 castea `as int` sin validar `num`/tipo.
  6. Las líneas 542-562 borran de `activity_feed` cualquier evento del usuario para esos `gameIds` en las últimas 3 horas, pudiendo eliminar actividad manual legítima previa a la importación.
- **Solución propuesta**:
  1. Consultar reseñas existentes del usuario para los `gameIds` del lote (o definir clave única/RPC idempotente de importación) para evitar duplicados.
  2. Cambiar la línea 496 a `if (effectiveLastPlayedAt != null) 'created_at': effectiveLastPlayedAt,`.
  3. Validar `DateTime.tryParse(dateAdded)` y normalizar `completionType` contra el conjunto permitido (`{'none', 'story', '100_percent'}`).
  4. Lanzar una excepción explícita si `userId == null`.
  5. En lugar de borrar por ventana de tiempo, devolver los IDs de reseñas insertadas/actualizadas o usar un parámetro/contexto que evite disparar el feed desde trigger o marque origen `import`.

### [BUG-07] — Crash por `clamp(0, -1)` y `setState` síncrono en `initState` de `ActivityStoryViewer`
- **ID y Título**: `[BUG-07]` — Crash por `clamp(0, -1)` y `setState` síncrono en `initState` de `ActivityStoryViewer`
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/activity/activity_story_viewer.dart:66-82, 129-151, 217-227, 256-264`
- **Problema / Causa raíz**: En `initState` (L68-72), `_groupIndex = widget.initialGroupIndex.clamp(0, widget.groups.length - 1)` y `_activityIndex = widget.initialActivityIndex.clamp(0, widget.groups[_groupIndex].activities.length - 1)` lanzan `ArgumentError` si `groups` o `activities` llega vacío (`max = -1 < min = 0`). Además, `initState` llama a `_loadReviewInteractions()` (L79), que invoca `setState(...)` síncronamente en L135 y L148 antes del primer `await`.
- **Solución propuesta**:
  1. Validar al inicio de `initState` si `widget.groups.isEmpty` o si todos los grupos tienen `activities.isEmpty`, y cerrar/mostrar estado vacío de forma segura sin indexar `-1`.
  2. Extraer la inicialización de `_likesCount` y `_hasLiked` sin `setState` para la llamada inicial desde `initState` (o usar `setState` solo tras el `await` o cuando no se ejecuta desde `initState`).

### [BUG-08] — Borrado de reseña sin confirmación, sin manejo de errores ni notificación global de refresco en `GameDetailsScreen`
- **ID y Título**: `[BUG-08]` — Borrado de reseña sin confirmación, sin manejo de errores ni notificación global de refresco en `GameDetailsScreen`
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/library/game_details_screen.dart:732`, `lib/screens/library/game_details/game_hero_section.dart:949`, `lib/screens/library/game_details/game_reviews_card.dart:311`, `lib/screens/library/game_details/game_details_controller.dart:827-844`
- **Problema / Causa raíz**: `GameReviewsCard` (`game_reviews_card.dart:311`) invoca directamente `onDeleteReview?.call(review)` sin mostrar diálogo de confirmación. `GameHeroSection` (`game_hero_section.dart:949`) reenvía el callback y `GameDetailsScreen` (`game_details_screen.dart:732`) pasa directamente el método `_controller.deleteReview`. Esto provoca cuatro fallas simultáneas:
  1. Un toque accidental en el icono de papelera elimina permanentemente la reseña y sus imágenes de Storage sin confirmación.
  2. No hay `try/catch` en UI ni estado de carga: si falla la red/Supabase, el `Future<bool>` queda rechazado sin feedback al usuario.
  3. A diferencia de `_saveReview` (`game_details_screen.dart:404`) y `_confirmAndDeleteFromLibrary` (`game_hero_section.dart:452`), `deleteReview` nunca incrementa `libraryUpdateNotifier.value++`, dejando `ProfileScreen`/`HomeScreen` desincronizados.
  4. En `GameDetailsController.deleteReview` (`game_details_controller.dart:836-841`), si `removedFromLibrary == true`, no resetea `status = 'wishlist'` ni las notas (`rating`, `ratingGameplay`, etc.) a `0`; si `removedFromLibrary == false`, llama `fetchUserData()` sin `await`.
- **Solución propuesta**:
  1. En `GameDetailsScreen`, crear un wrapper `Future<void> _confirmAndDeleteReview(Review review)` que muestre `AlertDialog` de confirmación antes de llamar a `_controller.deleteReview(review)`.
  2. Envolver la llamada en `try/catch`, mostrar `SnackBar` en error/éxito e incrementar `libraryUpdateNotifier.value++` tras el borrado.
  3. En `GameDetailsController.deleteReview`, resetear `status` y ratings cuando `removedFromLibrary == true` (igual que `deleteFromLibrary` en `817-823`) y hacer `await fetchUserData()` cuando queden más reseñas.

### [BUG-09] — `Review` de respaldo con `id: ''` rompe la actualización en PostgreSQL al guardar en `ReviewModal`
- **ID y Título**: `[BUG-09]` — `Review` de respaldo con `id: ''` rompe la actualización en PostgreSQL al guardar en `ReviewModal`
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/library/game_details/game_hero_section.dart:386-419, 515-521`, `lib/screens/library/review_modal.dart:191, 224`, `lib/repositories/review_repository.dart:511, 548-574`
- **Problema / Causa raíz**: Cuando `widget.inLibrary == true` y `widget.reviews.isEmpty` (p. ej., juego añadido sin fila en `reviews` o mientras `fetchReviews()` aún está cargando), `GameHeroSection._openEditOrFallbackReview` (`game_hero_section.dart:418`) construye `_buildFallbackReview(userId)` con `id: ''` (cadena vacía, `game_hero_section.dart:387`). `ReviewModal` evalúa `hasReview = widget.existingReview != null` (`review_modal.dart:191`) y asigna `reviewId = hasReview ? r!.id : null` (`review_modal.dart:224`), conservando `reviewId = ''`. Al guardar, `ReviewRepository.saveReview` comprueba `if (reviewId != null)` (`review_repository.dart:511`), que resulta `true`, y ejecuta `.from('reviews').update(...).eq('id', '')`, fallando contra la columna UUID de PostgreSQL (`invalid input syntax for type uuid: ""`) e impidiendo guardar.
- **Solución propuesta**:
  1. En `review_modal.dart:224`, normalizar `reviewId = (hasReview && r!.id.isNotEmpty) ? r.id : null;`.
  2. En `game_hero_section.dart:402-419`, bloquear la edición mientras `controller.isLoadingUserData` sea `true` o pasar `existingReview: null` (con `currentStatus`/`currentRating` actuales) en lugar de fabricar un `Review` sintético con `id: ''`.

### [BUG-10] — `ProfileController._init` borra `userProfile` a `null` ante refrescos de token o cambios de sesión
- **ID y Título**: `[BUG-10]` — `ProfileController._init` borra `userProfile` a `null` ante refrescos de token o cambios de sesión
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/profile_controller.dart:60-71`
- **Problema / Causa raíz**: El listener de `onAuthStateChange` ignora el parámetro `AuthState` (`event`) y solo evalúa `loggedInNow && userProfile == null`. Cuando el usuario ya está autenticado con su perfil cargado (`loggedInNow == true && userProfile != null`) y Supabase emite `AuthChangeEvent.tokenRefreshed`, `AuthChangeEvent.userUpdated` o `AuthChangeEvent.initialSession`, la condición `if` resulta falsa y ejecuta el bloque `else`, asignando `userProfile = null` y notificando a `ProfileScreen`. Esto vacía en vivo el nombre, avatar, banner, XP y oculta/rompe widgets dependientes de `userProfile` hasta reiniciar o forzar un refresco. Además, en cierre de sesión (`signedOut`), solo limpia `userProfile` y deja residuales `wishlistGames`, `beatenGames`, `hallOfFame`, `ratings`, `stories`, etc.
- **Solución propuesta**:
  1. Inspeccionar `authState.event`:
     - Si `authState.event == AuthChangeEvent.signedOut`: resetear todos los campos (`userProfile = null`, listas vacías, contadores a `0`, `hallOfFame = List.filled(5, null)`, `hasError = false`, `isLoading = false`) y llamar `notify()`.
     - Si `authState.event == AuthChangeEvent.signedIn` (o `initialSession`) y `userProfile == null`: poner `isLoading = true; notify(); fetchProfileData();`.
     - Si `authState.event == AuthChangeEvent.userUpdated` o `tokenRefreshed`: no borrar `userProfile` (en todo caso refrescar en segundo plano en `userUpdated`).

### [BUG-11] — Divergencia severa entre las 3 copias del cálculo de progreso de logros/sagas y exclusión de `'completed'`
- **ID y Título**: `[BUG-11]` — Divergencia severa entre las 3 copias del cálculo de progreso de logros/sagas y exclusión de `'completed'`
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/profile/profile_achievements_tab.dart:145-159, 316-819`, `lib/screens/profile/achievements/achievements_controller.dart:197-544`, `lib/screens/profile/achievement_games_screen.dart:125-489`
- **Problema / Causa raíz**: La lógica de matching por saga/estudio se copió y editó independientemente en tres pantallas/controladores sin única fuente de verdad:
  1. `ProfileAchievementsTab._achievementIgdbIds` (`profile_achievements_tab.dart:27-70`) incluye `naughty_dog`, `cd_projekt`, `remedy`, `team_ninja`, `dark_souls`, `call_of_duty`, `doom`, `metro`, `dead_space`, `xenoblade`, pero `ProfileAchievementsTab._calculateSagaProgress` (`316-819`) **omite las 10 sagas**, dejando su `_currentProgress` permanentemente en `0` aunque el usuario haya completado sus juegos.
  2. Inversamente, `ProfileAchievementsTab._calculateSagaProgress` calcula `ubisoft`, `ea`, `sony`, `atlus`, `sega`, `gta`, `metal_gear`, `fallout`, `witcher`, `street_fighter`, `mortal_kombat`, `tekken`, `far_cry`, `need_for_speed`, `crash_bandicoot`, `spyro`, `ratchet`, `uncharted`, `dragon_quest`, `tales_of`, todas **ausentes** en `AchievementsController.calculateSagaProgress` (`197-544`) y `AchievementGamesScreen` (`165-481`).
  3. `ProfileAchievementsTab` (`145-159`) no lee `ach['saga_target']` (que `AchievementsController:73` sí lee) y hardcodea `_all` solo para 4 prefijos, devolviendo `target = 1` para cualquier otro logro `_all`.
  4. `AchievementGamesScreen` (`126`) filtra `if (item['status'] != 'beaten') continue;`, descartando juegos con `status == 'completed'`, mientras `AchievementsController:48` y `ProfileAchievementsTab:121` sí incluyen `'completed'`.
  5. En `AchievementsController:394` y `ProfileAchievementsTab:478`, `dev.contains('enix')` genera falsos positivos con desarrolladores como `"Phoenix Labs"`; `title.contains('halo')` con `"Thalos"`; `title.contains('doom')` con `"Doomsday"`.
- **Solución propuesta**:
  1. Extraer un único servicio/utilidad pura (ej. `AchievementMatcher` en `lib/utils/achievement_utils.dart`) que exponga `matchesAchievement(String groupId, Map<String, dynamic> game)` y `calculateSagaProgress(List<dynamic> beatenItems)`.
  2. Aceptar tanto `'beaten'` como `'completed'` (y `'terminado'`) en las 3 pantallas y usar límites de palabra (`RegExp(r'\b...\b')`) para tokens ambiguos (`enix`, `halo`, `doom`, `mario`, `control`).
  3. Unificar lectura de `saga_target` en `ProfileAchievementsTab` reutilizando `AchievementsController` o el mismo parser del repositorio.

### [BUG-12] — Colisión de nombre de canal Realtime en `CurrentlyPlayingBadge` y tormenta de suscripciones al hacer scroll
- **ID y Título**: `[BUG-12]` — Colisión de nombre de canal Realtime en `CurrentlyPlayingBadge` y tormenta de suscripciones al hacer scroll
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/profile/currently_playing_badge.dart:36-86`, `lib/screens/profile/widgets/profile_mobile_header.dart:50, 128`, `lib/screens/profile/profile_screen.dart:304-334, 708-712`
- **Problema / Causa raíz**:
  1. `currently_playing_badge.dart:42-43` usa `.channel('public:users:${widget.userId}')` con un nombre de canal determinista sin identificador de instancia, y `dispose()` (`66-85`) ejecuta `Supabase.instance.client.removeChannel(channel)`. Si existen dos instancias simultáneas para el mismo `userId` (p. ej. al abrir el perfil desde un sub-push o al cruzar el umbral de scroll/resizing), al hacer `dispose()` una instancia elimina el canal compartido y rompe las actualizaciones en vivo de la otra instancia.
  2. `profile_mobile_header.dart:50, 128` (`final showPlaying = t < 0.35 && userProfile != null;`) monta y desmonta `CurrentlyPlayingBadge` cada vez que `collapseProgress` cruza `0.35` al hacer scroll, creando/destruyendo canales Realtime contra el WebSocket de Supabase en cada rebote, agravado porque `profile_screen.dart:304-334` pasa closures anónimas forzando `shouldRebuild == true`.
  3. `CurrentlyPlayingBadge` no implementa `didUpdateWidget`: si `initialProfile` o `userId` cambia tras un `fetchProfileData()`, `_appId`/`_appName` y la suscripción quedan obsoletos.
- **Solución propuesta**:
  1. Mover la suscripción Realtime de `currently_playing_*` a `ProfileController` (un único canal por perfil con `ValueNotifier` o campo en el controller, o sufijo único por instancia en el nombre del canal `public:users:${widget.userId}:${identityHashCode(this)}`).
  2. Implementar `didUpdateWidget` en `CurrentlyPlayingBadge` para sincronizar `_appId`/`_appName` si cambia `widget.initialProfile` o `widget.userId`.
  3. En `ProfileMobileHeader`, usar `Visibility`/`AnimatedOpacity` o mantener montado el widget en el árbol en lugar de crear/destruir el widget en `t < 0.35`.

### [BUG-13] — `RangeError` sin comprobación de longitud en `ProfileHallOfFame`
- **ID y Título**: `[BUG-13]` — `RangeError` sin comprobación de longitud en `ProfileHallOfFame`
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/widgets/profile_hall_of_fame.dart:37-38`
- **Problema / Causa raíz**: `List.generate(5, (index) { final game = hallOfFame[index]; ... })` indexa `hallOfFame[index]` asumiendo que la lista siempre tiene exactamente 5 elementos. Si un estado inicial, error parcial o caller pasa una lista con menos de 5 elementos (p. ej. `[]`), `hallOfFame[index]` lanza `RangeError` y rompe el árbol completo del perfil.
- **Solución propuesta**:
  1. Sustituir `hallOfFame[index]` por `index < hallOfFame.length ? hallOfFame[index] : null`.
  2. Añadir un `assert(hallOfFame.length <= 5)` opcional o documentar el invariante en el constructor.

### [BUG-14] — `HeroShowcase` carece de `didUpdateWidget`: `RangeError` o datos obsoletos al actualizar `playingGames`
- **ID y Título**: `[BUG-14]` — `HeroShowcase` carece de `didUpdateWidget`: `RangeError` o datos obsoletos al actualizar `playingGames`
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/home/hero_showcase.dart:52-223` (especialmente `:109-167`)
- **Problema / Causa raíz**: `_HeroShowcaseState` inicializa `_currentGame`, `_currentGameIndex` y `_timer` únicamente en `initState` (líneas 109–117) y no implementa `didUpdateWidget`. Si `HomeScreen` recarga `p1.games` (p. ej. el usuario termina/quita un juego de "Jugando", reduciendo `playingGames.length` de 5 a 2) y `_currentGameIndex` ya valía 4, el siguiente tick del `Timer.periodic` ejecuta `widget.playingGames[_currentGameIndex]` en la línea 146 y lanza `RangeError`. Además, si `playingGames` cambia de elementos o `switchDuration` cambia, `_currentGame` sigue mostrando el juego anterior y el timer conserva la duración vieja.
- **Solución propuesta**:
  1. Implementar `didUpdateWidget(covariant HeroShowcase oldWidget)` en `_HeroShowcaseState`.
  2. Si `widget.playingGames != oldWidget.playingGames`, validar o reiniciar `_currentGameIndex` dentro de `0..widget.playingGames.length - 1` (o buscar el índice del `_currentGame` actual en la nueva lista), limpiar `_previousGame` si ya no existe, y si la lista estaba vacía y pasa a tener elementos, inicializar `_pickNextGame()` e iniciar `_timer`.
  3. Si `widget.switchDuration != oldWidget.switchDuration`, actualizar `_panController.duration` y recrear `_timer`.

### [BUG-15] — Carga duplicada en `HomeScreen` al iniciar + recargas completas ante refresco de JWT + pérdida de scroll/UI en `reload()`
- **ID y Título**: `[BUG-15]` — Carga duplicada en `HomeScreen` al iniciar + recargas completas ante refresco de JWT + pérdida de scroll/UI en `reload()`
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/home/home_screen.dart:74, 84-86, 138-141, 155-165`, `lib/screens/home/controller/home_controller.dart:76-90`
- **Problema / Causa raíz**:
  1. En `initState`, la línea 74 llama a `_controller.reload()`, y en la línea 84 se suscribe a `Supabase.instance.client.auth.onAuthStateChange.listen((_) { if (mounted) _controller.reload(); })` sin filtrar `AuthState.event`. En `supabase_flutter` v2, `onAuthStateChange` emite inmediatamente `AuthChangeEvent.initialSession`, provocando una **doble ejecución inmediata** de Fase 1 + Fase 2 cada vez que se abre `HomeScreen`, y recargando toda la pantalla en cada `tokenRefreshed` en segundo plano.
  2. `reload()` reemplaza `phaseOneFuture` y notifica (`home_controller.dart:79, 89`), lo que hace que `FutureBuilder` (`home_screen.dart:158`) entre en `ConnectionState.waiting` y destruya por completo el `CustomScrollView` (y `HeroShowcase`, posición de scroll y `RefreshIndicator`) mostrando un `CircularProgressIndicator` en cada `libraryUpdateNotifier`, refresco de token o pull-to-refresh.
  3. `_handleRefresh()` (línea 140) solo espera `phaseOneFuture`, cerrando el spinner del `RefreshIndicator` antes de que Fase 2 termine.
- **Solución propuesta**:
  1. Filtrar `onAuthStateChange` para reaccionar únicamente a `AuthChangeEvent.signedIn` y `AuthChangeEvent.signedOut` (ignorando `initialSession` y `tokenRefreshed`).
  2. Conservar en `HomeController` los últimos `HomePhaseOneData` válidos (`cachedPhaseOne`) y mostrar los datos previos mientras se recarga en segundo plano (sin reemplazar el `CustomScrollView` por un spinner salvo en la carga inicial sin datos).
  3. Hacer que `reload()` devuelva un `Future<void>` que espere Fase 1 y Fase 2 para que `_handleRefresh()` espere ambas.

### [BUG-16] — `IntegrationsScreen` queda bloqueada en carga infinita para usuarios invitados/sin sesión y oculta errores de red
- **ID y Título**: `[BUG-16]` — `IntegrationsScreen` queda bloqueada en carga infinita para usuarios invitados/sin sesión y oculta errores de red
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/settings/integrations_screen.dart:29, 43-65, 77-88`
- **Problema / Causa raíz**:
  1. `_isLoading` empieza en `true` (línea 29). En `_fetchUserData()`, si `userId == null` (línea 45: `if (userId == null) return;`), el método retorna sin poner `_isLoading = false`, dejando la pantalla atrapada en un `CircularProgressIndicator` infinito.
  2. En el `catch (e)` de `_fetchUserData()` (líneas 60-64), el error se silencia sin `debugPrint` ni estado de error: si falla la red, la pantalla muestra el formulario de "vincular cuenta" aunque el usuario ya tuviera Steam vinculado.
  3. En `_linkSteam()` (líneas 77-88), si `res.data` es `null` o `data['success'] != true`, no hay rama `else`: el botón deja de girar sin mostrar mensaje alguno al usuario. Además asume que `res.data` es indexable como `Map`.
- **Solución propuesta**:
  1. En `_fetchUserData()`, si `userId == null`, llamar a `setState(() => _isLoading = false)` antes de retornar (o mostrar aviso de login requerido).
  2. Capturar y exponer un estado `_loadError` con botón de reintento cuando falle la carga del perfil.
  3. En `_linkSteam()`, validar `if (data is Map && data['success'] == true)` y añadir una rama `else` que muestre `SnackBar` con `data?['error'] ?? 'No se pudo vincular la cuenta de Steam.'`.

### [BUG-17] — Crash por acceso inseguro `friendship['friend']['username']` / `['id']` en `FriendsScreen._removeFriend`
- **ID y Título**: `[BUG-17]` — Crash por acceso inseguro `friendship['friend']['username']` / `['id']` en `FriendsScreen._removeFriend`
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/social/friends_screen.dart:211-241` (contraste con `:558`)
- **Problema / Causa raíz**: En `_buildFriendsTab` (línea 558), el código protege el acceso con `final friend = friendship['friend'] as Map<String, dynamic>? ?? {};`. Sin embargo, `_removeFriend` (línea 217) accede directamente a `friendship['friend']['username']` y la línea 234 fuerza `friendship['friend']['id'] as String`. Si el join de Supabase devuelve `friend == null` o sin `id` (por usuario eliminado o RLS), se produce un `NoSuchMethodError` / `TypeError` no capturado en tiempo de ejecución. Además, tras `await showDialog` en línea 231, no se verifica `if (!mounted) return;` antes de lanzar `_repo.removeFriend`.
- **Solución propuesta**: Extraer `final friend = friendship['friend'] as Map<String, dynamic>?; final friendId = friend?['id'] as String?; final username = friend?['username'] as String? ?? 'usuario';`, salir temprano si `friendId == null || friendId.isEmpty`, y comprobar `if (confirmed != true || !mounted) return;` en la línea 231.

### [BUG-18] — Doble `overlayEntry.remove()`, cast inseguro `ach['id'] as String` y solapamiento de timers en `AchievementToast`
- **ID y Título**: `[BUG-18]` — Doble `overlayEntry.remove()`, cast inseguro `ach['id'] as String` y solapamiento de timers en `AchievementToast`
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/widgets/achievement_toast.dart:23-35, 50-56, 90-114, 171-176, 200-208`
- **Problema / Causa raíz**:
  1. En `_AnimatedAchievementToastState`, ni `_timer` (líneas 171-175) ni `onTap` (líneas 200-208) tienen guarda `_isDismissing`. Si el usuario pulsa el toast mientras el `_timer` está aguardando `await _controller.reverse()`, o pulsa dos veces seguidas, `widget.onDismissed()` -> `overlayEntry.remove()` (línea 32) se ejecuta dos veces lanzando `AssertionError` en Flutter (`OverlayEntry` ya desmontado). Además, tras `await _controller.reverse()` (línea 173) y en `.then((_)` (línea 204), falta comprobar `mounted` antes de invocar `widget.onDismissed()`.
  2. En `showFromList` (línea 52), `final String aId = ach['id'] as String;` realiza un cast no-nullable que lanza `TypeError` si `'id'` falta o es nulo (contrastando con líneas 53-56).
  3. En `showFromList` (líneas 50 y 113), `toastDelay` avanza `3700 ms`, pero cada toast dura `500 + 3500 + 500 = 4500 ms`, haciendo que dos logros seguidos se solapen durante ~800 ms en `Alignment.topCenter`; además los `Future.delayed` en cola no son cancelables.
- **Solución propuesta**:
  1. Añadir `bool _isDismissing = false;` y un método `_dismiss()` único: cancelar `_timer`, salir si `_isDismissing || !mounted`, marcar `_isDismissing = true`, ejecutar `await _controller.reverse()`, y solo si `mounted` invocar `widget.onDismissed()`.
  2. En `show`, verificar `if (overlayEntry.mounted) overlayEntry.remove();`.
  3. Cambiar `ach['id'] as String` por `(ach['id']?.toString() ?? '')` y aumentar el espaciado entre toasts a `>= 4600 ms` (o gestionarlos con una cola secuencial).

### [BUG-19] — `DeepRouteResolver.fetchAchievementGamesArgs` trunca IDs multi-palabra, ignora `saga_target` y descarta `userId`
- **ID y Título**: `[BUG-19]` — `DeepRouteResolver.fetchAchievementGamesArgs` trunca IDs multi-palabra, ignora `saga_target` y descarta `userId`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/routes/deep_route_resolver.dart:125-145, 206-284`, `lib/routes/corpus_router.dart:330-346`, `lib/screens/profile/achievement_games_screen.dart:14-38`
- **Problema / Causa raíz**:
  1. En `lib/routes/deep_route_resolver.dart:211`, `final groupId = achievementId.split('_').first;` toma solo el segmento previo al primer `_`. Para los 18+ logros cuyo nombre de saga contiene guiones bajos (ej. `dark_souls_1`, `resident_evil_3`, `final_fantasy_all`, `naughty_dog_3`, `god_of_war_3`, `call_of_duty_5`, `cd_projekt_1`), `groupId` queda truncado a `'dark'`, `'resident'`, `'final'`, etc. Esto corrompe tanto la consulta `.like('id', '$groupId%')` (L216) como la búsqueda `groupId.startsWith(entry.key)` sobre `AchievementUtils.achievementIgdbIds` (L227-235), dejando `companyId`, `collectionId` y `franchiseId` en `null` (compárese con `lib/screens/profile/achievements/achievements_controller.dart:68-71` que usa `RegExp(r'_(\d+|all)$')`).
  2. En L245-257 calcula `target` mediante regex y 4 prefijos hardcodeados (`fromsoftware`, `zelda`, `mario`, `dark_souls`) ignorando la columna `saga_target` devuelta por Supabase (usada en `achievements_controller.dart:73`), dejando cualquier otro `_all` con `target = 1`.
  3. En L240 `titleStr.split(' (').first` no limpia sufijos numéricos finales como `achievements_controller.dart:62-64`.
  4. En L125-145 y `lib/routes/corpus_router.dart:330-346`, `AchievementGamesArgs` transporta `userId`, pero nunca se pasa a `AchievementGamesScreen` (que tampoco acepta `userId` en `lib/screens/profile/achievement_games_screen.dart:14-38`), mostrando siempre los logros propios al visitar `/perfil/{userId}/logros/{achievementId}`.
- **Solución propuesta**:
  1. Reemplazar `split('_').first` en L211 por `RegExp(r'_(\d+|all)$')` igual que `AchievementsController`, y usar `AchievementUtils` para centralizar la extracción de `groupId` y el parseo de `saga_target`.
  2. Leer `(m['saga_target'] as num?)?.toInt()` con fallback al regex solo si es nulo.
  3. Añadir `final String? userId;` a `AchievementGamesScreen` y reenviar `args.userId` desde `DeepRouteResolver.buildRoute` y `CorpusRouter.route`.

### [BUG-20] — Condición de carrera en `handleBrowserPopState` y desincronización de `_replaying` / `_ignorePopSyncCount`
- **ID y Título**: `[BUG-20]` — Condición de carrera en `handleBrowserPopState` y desincronización de `_replaying` / `_ignorePopSyncCount`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/routes/app_navigation_controller.dart:41-43, 166-170, 326-377, 380-470, 472-538`, `lib/screens/main_screen.dart:127-131`
- **Problema / Causa raíz**:
  1. `MainScreen` (`lib/screens/main_screen.dart:127-131`) dispara `handleBrowserPopState` desde `webPopStateStream().listen(...)` sin esperar ni encolar llamadas. `_handleTypedPopState` (L380) y `_handleLegacyPopState` (L540) llaman a `await _rebuildStackFromUrl` -> `await DeepRouteResolver.buildRoute(subRoute)` (petición de red, L496). Si el usuario pulsa Atrás/Adelante dos veces seguidas, la primera ejecución puede terminar y ejecutar `finally { _replaying = false; }` (L468/L595) mientras la segunda sigue esperando la red; al reanudarse la segunda y llamar `navigator.push(route)` (L515), `_replaying` vale `false`, haciendo que `onNavigatorPush` ejecute `setWebPath(..., replace: false)` y corrompa el historial.
  2. En L416-432 y L570-579, `_stacks[tab]` se trunca antes de `navigator.pop()` y se incrementa `_ignorePopSyncCount++`. Si la ruta activa tiene un `PopScope(canPop: false)` que cancela el pop, `didPop` nunca se dispara: `_stacks[tab]` queda truncado erróneamente y `_ignorePopSyncCount` queda `>= 1`, provocando que el próximo pop real del usuario sea ignorado en `onNavigatorPop` (L166-169).
  3. En L452-460 (`depth > currentDepth`), si `tab == rootStackIndex` (`-1`), `publicPathForTabRoute(tab, subRoute)` llama a `AppRoutes.publicPathForTab(-1)` que devuelve `'/inicio'`, pisando la URL de la pestaña real.
- **Solución propuesta**:
  1. Serializar `handleBrowserPopState` con una cola secuencial (`Future<void> _popStateQueue`) y un contador de generación para descartar reconstrucciones obsoletas si llegó otro `popstate` mientras esperaba `DeepRouteResolver.buildRoute`.
  2. En lugar de pre-truncar `_stacks[tab]` e incrementar `_ignorePopSyncCount` a ciegas, actualizar `_stacks[tab]` solo al confirmarse `didPop`/`didRemove` o usar un flag por ruta/operación verificando el resultado real del `pop`.
  3. Manejar `tab == rootStackIndex` explícitamente en L442-460 usando la URL de la pestaña activa subyacente en lugar de `publicPathForTabRoute(-1, ...)`.

### [BUG-21] — `notificationclick` del Service Worker ignora `targetUrl` cuando la PWA ya está abierta y omite `/actividad/post/{id}`
- **ID y Título**: `[BUG-21]` — `notificationclick` del Service Worker ignora `targetUrl` cuando la PWA ya está abierta y omite `/actividad/post/{id}`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `web/firebase-messaging-sw.js:57-77`, `lib/routes/tab_deep_route.dart:91`
- **Problema / Causa raíz**:
  1. En L70-73: cuando existe una ventana/pestaña abierta (`clientList`), llama a `return client.focus();` sin navegar a `targetUrl` (`client.navigate(targetUrl)`) ni enviar un `postMessage` al cliente Flutter. Si el usuario tiene la app minimizada/en segundo plano en Web/PWA y pulsa una notificación push, la app solo recibe foco en la pantalla donde estaba, ignorando el recurso de la notificación.
  2. En L62-63: si `data.post_id` llega sin `review_id`, asigna `targetUrl = '/actividad'` en vez de `'/actividad/post/' + encodeURIComponent(data.post_id)` (ruta ya soportada por `GroupedPostDeepRoute` en `lib/routes/tab_deep_route.dart:91`). Además no contempla `data.game_id` (`'/buscar/' + encodeURIComponent(data.game_id)`).
- **Solución propuesta**:
  1. Mapear `data.post_id` a `'/actividad/post/' + encodeURIComponent(data.post_id)` y añadir fallback `data.game_id` -> `'/buscar/' + encodeURIComponent(data.game_id)`.
  2. Al encontrar un `client` abierto en `clients.matchAll`, si `targetUrl !== '/'` invocar `client.navigate(targetUrl)` (si está soportado) tras o antes de `client.focus()`, o implementar canal `navigator.serviceWorker.addEventListener('message', ...)` en Web para enrutar vía `DeepLinkService.handle(data)` sin recargar la página.

### [BUG-22] — `orderCommentsThreaded` lanza excepción con `created_at` nulo/inválido y anida menciones desconocidas al primer raíz
- **ID y Título**: `[BUG-22]` — `orderCommentsThreaded` lanza excepción con `created_at` nulo/inválido y anida menciones desconocidas al primer raíz
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/utils/comment_thread_utils.dart:18-23, 119-131, 148-154`
- **Problema / Causa raíz**:
  1. L20-22, L119 y L130 ejecutan `DateTime.parse(...['created_at'] as String)` directamente. Ante un comentario con `created_at == null` o formato inesperado, lanza `TypeError` o `FormatException` no capturada y rompe la renderización completa de la sección de comentarios.
  2. L148-154: cuando un comentario raíz empieza con `@mencion` pero no existe ningún comentario previo de ese usuario (`bestMatch == null`), el fallback lo adjunta como hijo del `firstRoot` del hilo en lugar de dejarlo como comentario raíz (`return null;`).
- **Solución propuesta**:
  1. Usar `DateTime.tryParse(comment['created_at']?.toString() ?? '')` con fallback a época UTC (`DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)`).
  2. Eliminar el fallback a `firstRoot` en L148-154 y devolver `null` cuando `bestMatch == null`.

### [BUG-23] — `openUrl` permite esquemas `javascript:` / `data:` sin validar
- **ID y Título**: `[BUG-23]` — `openUrl` permite esquemas `javascript:` / `data:` sin validar
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/utils/url_utils.dart:25-58`
- **Problema / Causa raíz**: `openUrl(String url)` pasa `url` directamente a `AnchorElement.href` y `.click()` en Web (L31-36) y a `Uri.parse(url)` -> `launchUrl` en nativo (L54-55) sin validar el esquema (`uri.scheme`). Si cualquier URL proveniente de IGDB, bundles o entrada de usuario comienza por `javascript:` o `data:`, puede ejecutar código o comportarse de forma insegura en Web.
- **Solución propuesta**: Parsear con `Uri.tryParse(url)` al inicio de `openUrl()` y permitir únicamente esquemas seguros (`http`, `https`, opcionalmente `mailto`), retornando `false` para cualquier otro esquema o URI inválida.

### [BUG-24] — Pérdida irreversible de imágenes en Storage cuando falla una mutación de BD y archivos huérfanos en `submitComment`
- **ID y Título**: `[BUG-24]` — Pérdida irreversible de imágenes en Storage cuando falla una mutación de BD y archivos huérfanos en `submitComment`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/repositories/review_repository.dart:503-574, 912-927, 987-1012`, `lib/repositories/activity_repository.dart:540-560, 563-571`
- **Problema / Causa raíz**:
  1. En `ReviewRepository.saveReview` (línea 535), se eliminan de Storage las imágenes quitadas (`removedUrls`) **antes** de ejecutar `.update(...)` en `reviews` (líneas 548-574). Si el `update` falla por red/RLS/constraint, las imágenes ya fueron borradas de Storage pero la fila en BD sigue apuntando a esas URLs rotas. Inversamente, si `uploadImages` (línea 504) sube imágenes nuevas y el `insert`/`update` falla, quedan archivos huérfanos en `user_uploads`.
  2. En `deleteFromLibrary` (línea 913 vs 917-927) y `deleteReviewForUser` (línea 988 vs 994-1011), se borran las imágenes de Storage **antes** de eliminar `reviews` y `user_games`.
  3. En `ActivityRepository.deleteComment` (línea 568 vs 570), se borra la imagen de Storage **antes** de borrar `review_comments`.
  4. En `ActivityRepository.submitComment` (línea 548 vs 552), si el `insert` falla, la imagen recién subida queda huérfana en Storage.
- **Solución propuesta**:
  1. En todas las operaciones de borrado (`deleteFromLibrary`, `deleteReviewForUser`, `deleteComment`), recopilar las URLs primero, ejecutar el `DELETE` en BD (y verificar éxito) y **después** invocar `_deleteImagesFromUrls(...)`.
  2. En `saveReview`, ejecutar primero el `UPDATE` en BD y solo después borrar `removedUrls`; si un `INSERT`/`UPDATE` falla tras subir `newImages`, hacer rollback best-effort llamando a `_deleteImagesFromUrls(uploaded)`.
  3. Igual rollback en `submitComment` en `catch` si el `insert` en `review_comments` falla tras `uploadBinary`.

### [BUG-25] — Crash en `ActivityRepository.fetchFriendsStrip` y `SocialRepository.fetchSentOrAcceptedIds` cuando el join `friend` es `null`
- **ID y Título**: `[BUG-25]` — Crash en `ActivityRepository.fetchFriendsStrip` y `SocialRepository.fetchSentOrAcceptedIds` cuando el join `friend` es `null`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/activity_repository.dart:242-245`, `lib/repositories/social_repository.dart:157-160`
- **Problema / Causa raíz**:
  1. En `ActivityRepository.fetchFriendsStrip` (líneas 243-244), `e['friend'] as Map<String, dynamic>` lanza `TypeError` si algún registro de amistad apunta a un usuario eliminado o bloqueado por RLS (`friend: null`).
  2. En `SocialRepository.fetchSentOrAcceptedIds` (línea 158), `f['friend']['id'] as String?` lanza `NoSuchMethodError` sobre `null` por la misma razón.
  3. Además, `fetchSentOrAcceptedIds` omite las solicitudes **recibidas** pendientes (`addressee_id == myId`), por lo que la búsqueda sigue mostrando el botón "Añadir" a usuarios que ya nos enviaron solicitud, provocando filas inversas duplicadas.
- **Solución propuesta**:
  1. Filtrar `where((e) => e['friend'] is Map)` y convertir con `Map<String, dynamic>.from(e['friend'] as Map)`.
  2. En `fetchSentOrAcceptedIds`, usar `final friendMap = f['friend']; if (friendMap is Map && friendMap['id'] != null) ...`, e incluir también `pendingReceived` (`addressee_id == myId, status == 'pending'`) o consultar `v_friend_pairs` + `friendships` en paralelo.

### [BUG-26] — `DateTime.parse` sin `tryParse` y cast inseguro en `AchievementsRepository.fetchAll` y `ReviewRepository.fetchStashReviewsLocal`
- **ID y Título**: `[BUG-26]` — `DateTime.parse` sin `tryParse` y cast inseguro en `AchievementsRepository.fetchAll` y `ReviewRepository.fetchStashReviewsLocal`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/achievements_repository.dart:66-71`, `lib/repositories/review_repository.dart:1212-1216`
- **Problema / Causa raíz**:
  1. `AchievementsRepository.fetchAll` (líneas 68-70) hace `row['achievement_id'] as String: DateTime.parse(row['unlocked_at'] as String)` sin validar nulidad ni formato. Una fila sin `unlocked_at` aborta las 5 consultas de logros.
  2. `ReviewRepository.fetchStashReviewsLocal` (línea 1213) usa `DateTime.parse(metaResponse['last_checked_at'])` (a diferencia de `fetchStashStatsLocal` en línea 1259 que usa `DateTime.tryParse` y `.toUtc()`). Además, compara `DateTime.now().difference(lastChecked).inDays <= _stashTtlDays` (línea 1214) mezclando hora local vs UTC y permitiendo hasta 7 días + 23h59m por truncamiento de `inDays` y `<=`.
- **Solución propuesta**:
  1. Usar `DateTime.tryParse(row['unlocked_at']?.toString() ?? '')` y omitir/fallback si es `null`.
  2. En `fetchStashReviewsLocal`, usar `DateTime.tryParse(metaResponse['last_checked_at'].toString())?.toUtc()`, comparar con `DateTime.now().toUtc()` usando `Duration(days: _stashTtlDays)` (`difference > const Duration(days: _stashTtlDays)`).

### [BUG-27] — `Review.fromMap` descarta silenciosamente `partners` y `user` si no son `Map<String, dynamic>` exactos, y tiene casts inseguros
- **ID y Título**: `[BUG-27]` — `Review.fromMap` descarta silenciosamente `partners` y `user` si no son `Map<String, dynamic>` exactos, y tiene casts inseguros
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/models/review.dart:93-148`
- **Problema / Causa raíz**:
  1. Líneas 95 y 103: `whereType<Map<String, dynamic>>()` y `if (userRaw is Map<String, dynamic>)` descartan silenciosamente los mapas de tipo `Map<dynamic, dynamic>` (frecuentes tras `jsonDecode`, caché local o mocks).
  2. Líneas 116-118: `id: map['id'] as String`, `userId: map['user_id'] as String`, `gameId: (map['game_id'] as num).toInt()` fallan ante nulos o `game_id` string/double.
  3. Líneas 111-113: si `image_urls` es un string JSON `'["url1"]'`, lo envuelve literal como `['["url1"]']` en vez de decodificarlo.
  4. Líneas 129-134, 142-147: `DateTime.tryParse(map[...] as String)` falla si no es `String`.
  5. Línea 139: `List<String>.from(map['partner_ids'] ?? [])` falla si `partner_ids` no es `List` o contiene `null`.
- **Solución propuesta**:
  1. Aceptar `is Map` y normalizar con `Map<String, dynamic>.from(...)`.
  2. Usar `?.toString() ?? ''` y `(map['game_id'] as num?)?.toInt() ?? int.tryParse(...) ?? 0`.
  3. Decodificar `rawImages` si empieza por `[` y parsear fechas con `?.toString()`.
  4. Mapear `partner_ids` de forma segura con `(map['partner_ids'] as List?)?.whereType<Object>().map((e) => e.toString()).toList() ?? const []`.

### [BUG-28] — `UserGame`, `Achievement`, `GameGroupItem`, `UserProfile` y `UserGamePlatform`: casts inseguros en `fromMap` y desajuste de esquema en `UserGame`
- **ID y Título**: `[BUG-28]` — `UserGame`, `Achievement`, `GameGroupItem`, `UserProfile` y `UserGamePlatform`: casts inseguros en `fromMap` y desajuste de esquema en `UserGame`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/models/user_game.dart:43, 51, 73-88, 107-112`, `lib/models/achievement.dart:33, 44`, `lib/models/game_group_item.dart:61, 72-74, 78`, `lib/models/user_profile.dart:37`, `lib/models/user_game_platform.dart:24`
- **Problema / Causa raíz**:
  1. `UserGame.fromMap` castea `as Map<String, dynamic>` en `games`, `game`, `partner` y elementos de `achievements`, además de `as String` en `last_played_at` y `updated_at`. Más grave aún: modela `partnerId` (`String?`) y `partner` (`UserProfile?`) en singular, cuando la tabla `user_games` y los repositorios (`ReviewRepository.fetchUserGame`, `ActivityRepository.fetchActivityPage`) usan `partner_ids` (lista) y `partners` (lista).
  2. `Achievement.fromMap` hace `(map['achievements'] as Map<String, dynamic>?) ?? map` y `map['unlocked_at'] as String`.
  3. `GameGroupItem.fromMap` hace `(map['game_id'] as num).toInt()` y `map['created_at'] as String`, y convierte `id`/`group_id` null en `"null"`.
  4. `UserProfile.fromMap` hace `id: map['id'] as String` (crashea si recibe el fallback `{'username': defaultUsername}` de `ProfileRepository.fetchUserProfile:111`).
  5. `UserGamePlatform.fromMap` hace `map['created_at'] as String`.
- **Solución propuesta**:
  1. Usar comprobaciones `is Map` + `Map<String, dynamic>.from(...)`, `?.toString()` para fechas antes de `DateTime.tryParse`, y `(num?)?.toInt()` para enteros en todos los modelos.
  2. Actualizar `UserGame` (si se va a adoptar) a `partnerIds` / `partners` o retirarlo si se consolida con `Review`.

### [BUG-29] — `ActivityRepository.fetchActivityPage` devuelve `nextOffset: offset + limit` y rompe paginación en límites de página / refresh
- **ID y Título**: `[BUG-29]` — `ActivityRepository.fetchActivityPage` devuelve `nextOffset: offset + limit` y rompe paginación en límites de página / refresh
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/repositories/activity_repository.dart:94-113, 199-211`
- **Problema / Causa raíz**:
  1. Línea 210 devuelve `nextOffset: offset + limit` en lugar de `offset + feedItems.length` (a diferencia de `NotificationsRepository.fetchNotificationsPage:84`). Si la página devuelve menos de `limit` elementos, `nextOffset` avanza más allá del tamaño real.
  2. La paginación por `offset` sobre un feed vivo ordenado por `created_at DESC` provoca duplicados cuando se insertan nuevas actividades mientras el usuario hace scroll.
  3. `_mergeActivityItems` (ventana 24h) solo corre sobre la página actual y no contra los elementos ya cargados, partiendo fusiones entre el final de una página y el inicio de la siguiente.
- **Solución propuesta**:
  1. Cambiar `nextOffset` a `offset + feedItems.length` como mitigación inmediata.
  2. Migrar a paginación por cursor (`(created_at, id) < (lastCreatedAt, lastId)`) para eliminar duplicados/huecos en feeds mutables.

### [BUG-30] — `_ActivityGroupBuilder.build()` descarta `_merged_post_ids`, `_merged_posts`, `_partners` y `_review` al agrupar y permite `title: null`
- **ID y Título**: `[BUG-30]` — `_ActivityGroupBuilder.build()` descarta `_merged_post_ids`, `_merged_posts`, `_partners` y `_review` al agrupar y permite `title: null`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/activity_repository.dart:1192-1242`
- **Problema / Causa raíz**:
  1. Cuando `_mergeActivityItems` absorbe posts previos en `_merged_post_ids` / `_merged_posts` dentro de un item `status_change` y luego `_groupActivityItems` agrupa 2+ items por `post_id`, `_ActivityGroupBuilder.build()` construye un mapa nuevo (líneas 1224-1242) que omite `_merged_post_ids`, `_merged_posts`, `_partners` y `_review`.
  2. En la línea 1215-1217, `'title': 'Juego desconocido'` se sobreescribe con `...?rawGameMap`: si `rawGameMap` trae `'title': null`, el título queda `null` en lugar de `'Juego desconocido'`.
  3. En las líneas 1208-1211 y 1222, si 2 eventos del mismo `post_id` pertenecen al mismo `gameId` (ej. dos cambios seguidos fuera de la ventana de 4 elementos), `games.length < 2` devuelve `first` sin agrupar y pierde el segundo `activity_id`.
- **Solución propuesta**:
  1. Preservar/unificar `_merged_post_ids` y `_merged_posts` de los `items` en el mapa agrupado devuelto por `build()`.
  2. Construir `gameMap` asegurando `title` no nulo: `if ((rawGameMap?['title'] as String?)?.isNotEmpty != true) 'title': 'Juego desconocido'`.

### [BUG-31] — `ReviewRepository.fetchFriendActivityForGame` usa `.maybeSingle()` sin `.limit(1)` (falla con PGRST116 en replays) y cast inseguro en `metadata`
- **ID y Título**: `[BUG-31]` — `ReviewRepository.fetchFriendActivityForGame` usa `.maybeSingle()` sin `.limit(1)` (falla con PGRST116 en replays) y cast inseguro en `metadata`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/review_repository.dart:1160-1180`
- **Problema / Causa raíz**:
  1. Línea 1160: `bestActivity['metadata'] as Map<String, dynamic>?` puede lanzar `TypeError` si es `Map<dynamic, dynamic>`.
  2. Líneas 1165-1170: cuando `reviewId == null`, ejecuta `query.eq('user_id', userId).eq('game_id', parsedGameId).maybeSingle()` **sin** `.order('created_at', ascending: false).limit(1)`. Si el amigo tiene 2+ reseñas (replays) del mismo juego, PostgREST devuelve error PGRST116 (múltiples filas), que el `catch` de línea 1177 silencia devolviendo `review: null` (en contraste con `ActivityRepository.fetchLatestReviewForUserAndGame:656-658`).
  3. No inyecta `partners` en `revMap`.
- **Solución propuesta**: Añadir `.order('created_at', ascending: false).limit(1)` al fallback, usar `is Map ? Map<String, dynamic>.from(...) : const {}` para `metadata` e invocar `injectPartners([revMap])`.

### [BUG-32] — `ReviewRepository.sanitizeReviewData` sobrescribe `created_at` al editar reseñas y borra imágenes/datos al cambiar temporalmente a `to_play`/`wishlist`
- **ID y Título**: `[BUG-32]` — `ReviewRepository.sanitizeReviewData` sobrescribe `created_at` al editar reseñas y borra imágenes/datos al cambiar temporalmente a `to_play`/`wishlist`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/repositories/review_repository.dart:172-215, 518-540`
- **Problema / Causa raíz**:
  1. Líneas 211-214: cuando `reviewDate != null` (incluyendo cuando `saveReview` en línea 524 lo autogenera al pasar de `playing` a `beaten`), `sanitizeReviewData` incluye `'created_at': reviewDate.toUtc().toIso8601String()`. En un `UPDATE` (`reviewId != null`), esto sobrescribe la fecha original de creación de la reseña.
  2. Línea 172 y 500-539: `to_play` recibe el mismo trato destructivo que `wishlist`, poniendo a `null`/`[]` comentarios, horas, plataforma, notas e **eliminando permanentemente** de Storage las fotos existentes de la reseña al editarla.
- **Solución propuesta**:
  1. Separar `isUpdate` en `sanitizeReviewData` (o no enviar `created_at` cuando `reviewId != null`).
  2. Confirmar regla de negocio para `to_play` y advertir o preservar datos si el cambio de estado es reversible, evitando borrar imágenes hasta confirmar `update`.

### [BUG-33] — `ProfileRepository.fetchProfileData`: definición inconsistente de `platinumGames`, reordenamiento erróneo por strings y casts inseguros
- **ID y Título**: `[BUG-33]` — `ProfileRepository.fetchProfileData`: definición inconsistente de `platinumGames`, reordenamiento erróneo por strings y casts inseguros
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/repositories/profile_repository.dart:203-223, 256-265, 329-360, 369, 397, 417`
- **Problema / Causa raíz**:
  1. **Definición de Platino (`platinumGames`)**: consulta `reviews` con `completion_type == '100_percent'` y luego trae `user_games` por `game_id` sin filtrar `status` (y sin consultar `user_games.status == 'completed'`, que según `GameStatus.completed` es `'Platino'`), pudiendo incluir juegos en `playing`/`on_hold` o excluir juegos marcados como `completed` sin reseña 100%. Además, `platinoGameIds.toList()` sin límite en `.inFilter(...)` puede exceder el límite de longitud URL de PostgREST.
  2. **Histograma `ratings` (líneas 256-259)**: incluye todas las reseñas (replays duplican el peso de un juego en el histograma) e ignora los sub-ratings (`rating_gameplay`, etc.) que `Review.effectiveRating` sí promedia.
  3. **Ordenamiento client-side corrupto (líneas 330-333 y 356-358)**: `_enrichList` reordena comparando `_sort_date` como `String` (sensible a formatos ISO/zonas horarias). Peor aún, para `beaten` (ordenado en BD por `last_played_at DESC NULLS LAST`), cuando `last_played_at` es `null` la línea 357 cae a `updated_at`, alterando localmente el orden devuelto por Supabase.
  4. **Casts inseguros**: línea 346 `(row['rating'] ?? 0).toDouble()` falla si no es `num` y convierte `null` en `0.0`; línea 352 `gameId as int`; línea 369 `row['pin_order'] as int?`; línea 397 `row['games'] as Map<String, dynamic>?`; línea 417 `(row['game_id'] as num).toInt()`.
- **Solución propuesta**:
  1. Unificar criterio de Platino (`status == 'completed'` o RPC dedicada) y paginar/limitar `platinoGameIds`.
  2. Respetar el orden de BD (eliminar `.sort` por string o parsear `DateTime.tryParse` respetando `nullsFirst: false`).
  3. Reemplazar casts estrictos por `(x as num?)?.toInt()` y `is Map`.

### [BUG-34] — Condición de carrera en `UserSettingsService._flush()` que descarta cambios recientes en memoria y puede pisar valores en Supabase
- **ID y Título**: `[BUG-34]` — Condición de carrera en `UserSettingsService._flush()` que descarta cambios recientes en memoria y puede pisar valores en Supabase
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/services/user_settings_service.dart:14, 112-119, 140-167`
- **Problema / Causa raíz**: `_flush()` no tiene lock/cola de ejecución. Si `push()` se llama mientras otro `_flush()` está esperando el `upsert` de Supabase (hasta 6s): (a) dos `_flush()` concurrentes pueden llegar fuera de orden a Supabase, dejando el valor antiguo en BD; (b) al finalizar el primer `_flush()`, la línea 159 ejecuta `_pending.removeWhere((k, _) => payload.containsKey(k))` comparando solo la existencia de la clave y **no su valor**, por lo que borra de `_pending` el valor nuevo escrito mientras la petición estaba en vuelo y marca `user_settings_dirty = false` (líneas 160-163); (c) en `push()`, `_dirtyFlagWrite` se sobrescribe sin esperar al anterior y se `await`ea fuera del `try/catch` en la línea 143.
- **Solución propuesta**:
  1. Serializar `_flush()` mediante un flag `_isFlushing` + `_flushAgain` (o `Future<void>? _activeFlush`), evitando múltiples `upsert` simultáneos.
  2. En la línea 159, eliminar cada clave solo si `_pending[k] == payload[k]` (o usando `const DeepCollectionEquality().equals` para listas).
  3. Mover `await _dirtyFlagWrite` dentro del bloque `try` o encadenarlo de forma segura.

### [BUG-35] — `UserSettingsService`: `tokenRefreshed` dispara pulls concurrentes, `resetLocalCacheToDefaults` descarta pendientes y `userId == null` borra `_pending`
- **ID y Título**: `[BUG-35]` — `UserSettingsService`: `tokenRefreshed` dispara pulls concurrentes, `resetLocalCacheToDefaults` descarta pendientes y `userId == null` borra `_pending`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/user_settings_service.dart:66-101, 129-138, 146-150`, `lib/main.dart:201-230`
- **Problema / Causa raíz**:
  1. En `main.dart:203, 228`, `onAuthStateChange` llama a `pullAndApplyToLocalCache()` en cada evento con sesión (incluyendo `tokenRefreshed`). Si coincide con un cambio local en curso, `_applyRemoteToLocal` (línea 97) sobrescribe `SharedPreferences`.
  2. `resetLocalCacheToDefaults()` (líneas 129-138) cancela `_debounce` y hace `_pending.clear()` sin intentar flush previo ni esperar a `_dirtyFlagWrite`, de modo que `_dirtyFlagWrite` pendiente puede completarse después y dejar `user_settings_dirty = true` tras cerrar sesión.
  3. En `_flush()` (líneas 147-149), si `userId == null` transitoriamente, ejecuta `_pending.clear()` dejando `user_settings_dirty = true` en disco.
- **Solución propuesta**:
  1. Guardar el último `userId` sincronizado o evitar `pullAndApplyToLocalCache()` en eventos `AuthChangeEvent.tokenRefreshed`.
  2. En `resetLocalCacheToDefaults()`, esperar `_activeFlush` / `_dirtyFlagWrite` antes de limpiar claves y fijar `user_settings_dirty = false`.
  3. Si `userId == null` en `_flush()`, retornar sin borrar `_pending` salvo en logout explícito.

### [BUG-36] — Inyección de sintaxis Apicalypse en `IGDBService.searchGameLenient` y exclusión involuntaria de juegos sin rating
- **ID y Título**: `[BUG-36]` — Inyección de sintaxis Apicalypse en `IGDBService.searchGameLenient` y exclusión involuntaria de juegos sin rating
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/igdb_service.dart:640-658`
- **Problema / Causa raíz**:
  1. A diferencia de `searchGames` (línea 242, que llama a `sanitizeApicalypseTerm`), `searchGameLenient` decodifica entidades HTML (`&quot;` -> `"`, línea 641) e interpola las palabras crudas directamente en `name ~ *"$w"*` (línea 650). Cualquier título con `"`, `;` o `\` rompe la sintaxis de Apicalypse (error 400) o permite inyectar cláusulas Apicalypse arbitrarias.
  2. La línea 657 añade `sort total_rating_count desc;` sin la cláusula `(total_rating_count != null | total_rating_count = null)`. En IGDB, ordenar por un campo excluye automáticamente los registros donde ese campo es `null`, contradiciendo el comentario de las líneas 653-654 y ocultando todos los juegos indie/DLC sin votos.
- **Solución propuesta**:
  1. Aplicar `.map(sanitizeApicalypseTerm).where((w) => w.isNotEmpty)` en la línea 647 (y verificar `words.isNotEmpty` antes de enviar la query).
  2. Añadir `& (total_rating_count != null | total_rating_count = null)` al `where` o eliminar el `sort total_rating_count desc` en búsquedas permisivas.

### [BUG-37] — `IGDBService`: truncamiento silencioso en `getUpcomingGamesByIds` (`limit 10` implícito) y `getGamesByIds` (`limit 50`), más juegos futuros en `getPopularGames`
- **ID y Título**: `[BUG-37]` — `IGDBService`: truncamiento silencioso en `getUpcomingGamesByIds` (`limit 10` implícito) y `getGamesByIds` (`limit 50`), más juegos futuros en `getPopularGames`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/igdb_service.dart:128-136, 278-286, 313-327, 344-356`
- **Problema / Causa raíz**:
  1. `getUpcomingGamesByIds` (líneas 131-136) no especifica `limit`, por lo que IGDB aplica su límite por defecto de `10`. Si la wishlist tiene >10 próximos lanzamientos, los demás se truncan silenciosamente.
  2. `getGamesByIds` (línea 349) fija `limit 50;` sin dividir en lotes si `igdbIds.length > 50`.
  3. `getPopularGames` (línea 319) ordena por `first_release_date desc` sin filtrar `first_release_date <= $now`, devolviendo juegos aún no lanzados con >10 votos previos.
  4. En `searchGames` (línea 278), `involvedCompanies != null || collections != null || franchises != null` no comprueba `.isNotEmpty`, aplicando el filtro restrictivo de logros aunque se pasen listas vacías `[]`.
- **Solución propuesta**:
  1. Añadir `limit 500;` (o chunking si supera 500) en `getUpcomingGamesByIds`.
  2. Usar chunking de `limit ${chunk.length}` en `getGamesByIds` o delegar en `getGamesByIdsFull` con proyección configurable.
  3. Añadir `& first_release_date <= $now` en `getPopularGames`.
  4. Comprobar `.isNotEmpty == true` en la línea 278.

### [BUG-38] — Fuga de `StreamSubscription`s en `NotificationService.init()` y crash si Firebase falló al inicializar
- **ID y Título**: `[BUG-38]` — Fuga de `StreamSubscription`s en `NotificationService.init()` y crash si Firebase falló al inicializar
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/notification_service.dart:35-36, 55-128, 326-353`, `lib/main.dart:80-102, 135`
- **Problema / Causa raíz**:
  1. Las suscripciones `FirebaseMessaging.onMessage.listen` (líneas 62 y 104) y `FirebaseMessaging.onMessageOpenedApp.listen` (línea 107) no se almacenan ni se cancelan nunca, y `NotificationService` carece de `dispose()`.
  2. En `main.dart:99-101`, si `Firebase.initializeApp()` falla, la app continúa; al ejecutarse `NotificationService().init()` (líneas 62, 70, 104, 107) o `sendTestNotification()` (líneas 327-333, **fuera** del `try` de la línea 336), `FirebaseMessaging.instance` lanza una excepción no capturada.
- **Solución propuesta**: Guardar las `StreamSubscription<RemoteMessage>` en campos privados y añadir `dispose()`; envolver el setup de FCM en `try/catch` (verificando `Firebase.apps.isNotEmpty`); mover `getToken()` de `sendTestNotification()` dentro del bloque `try`.

### [BUG-39] — `NotificationService.saveFcmToken()` / `deleteFcmToken()`: fallos de `onTokenRefresh`, `RangeError`, RLS cross-user y silencio en Web foreground
- **ID y Título**: `[BUG-39]` — `NotificationService.saveFcmToken()` / `deleteFcmToken()`: fallos de `onTokenRefresh`, `RangeError`, RLS cross-user y silencio en Web foreground
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/services/notification_service.dart:188-278, 366-390`, `lib/screens/settings_screen.dart:380-381`
- **Problema / Causa raíz**:
  1. En `saveFcmToken()` (líneas 208, 228-237): si `getToken()` devuelve `null` o falla la primera vez, `_tokenRefreshSub` nunca se registra en toda la sesión. Dentro del listener `onTokenRefresh` (líneas 228-237), el `upsert` a Supabase no tiene `try/catch`, generando excepciones asíncronas no capturadas si falla la red.
  2. La línea 224 llama `token.substring(0, 20)` sin `.clamp(0, token.length)`, arriesgando `RangeError`.
  3. En `deleteFcmToken()` (líneas 269-273): borra de `push_tokens` filtrando solo por `token` (sin `.eq('user_id', userId)`) y, si el `delete()` de Supabase falla (offline), nunca ejecuta `FirebaseMessaging.instance.deleteToken()` (línea 273). Si otro usuario inicia sesión en el mismo dispositivo con el mismo token huérfano, el `upsert(..., onConflict: 'token')` fallará contra RLS si la política restringe `UPDATE` a `user_id = auth.uid()`.
  4. `_onForegroundMessageWeb` (líneas 385-390) solo hace `debugPrint` — el usuario web nunca recibe aviso alguno en primer plano.
  5. `_onForegroundMessage` en Android (línea 368) hace `if (notification == null) return;`, descartando mensajes solo-`data` aunque `web/firebase-messaging-sw.js:40-42` sí soporta `data.title`/`data.body`. Además `id: message.hashCode` (línea 378) puede colisionar o ser negativo, y `showNotification` (línea 315) carece de `try/catch`.
- **Solución propuesta**: Registrar `_tokenRefreshSub` independientemente de `getToken()`, envolver el callback en `try/catch`, usar `substring(0, token.length.clamp(0, 20))`, filtrar `delete` por `user_id` y `token`, invocar `deleteToken()` en `finally` aunque falle la red, emitir evento/banner in-app en Web foreground y hacer fallback a `message.data['title']`/`['body']` en Android foreground.

### [BUG-40] — `DeepLinkService` + `MainScreen`: pérdida de cold-start push (`pendingTab`), `TypeError` en `game_id` y navegación sin verificar montaje/stack
- **ID y Título**: `[BUG-40]` — `DeepLinkService` + `MainScreen`: pérdida de cold-start push (`pendingTab`), `TypeError` en `game_id` y navegación sin verificar montaje/stack
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/deep_link_service.dart:24, 29-61, 70-77, 144, 163-168`, `lib/screens/main_screen.dart:138, 162-168`, `lib/main.dart:132-148, 343-347`
- **Problema / Causa raíz**:
  1. En arranque en frío (`main.dart:132-148`), si `getInitialMessage()` resuelve mientras `AuthGate` sigue en `ConnectionState.waiting` (`SizedBox.shrink()`, `main.dart:343-347`), `DeepLinkService.handle` para `new_bundle`/`bundle_expiring` fija `pendingTab.value = 1` (`deep_link_service.dart:167`) antes de que `MainScreen` exista. `MainScreen.initState` (`main_screen.dart:138`) registra `_onPendingTab` con `addListener`, pero **no comprueba el valor inicial pendiente**, y `_loadSavedTab()` puede sobrescribir la pestaña con `main_tab_index` guardado, perdiendo la navegación hacia Explorar. Lo mismo ocurre si `navigatorKey.currentState == null` en `_openReviewById`/`_openGroupedPostById`.
  2. `deep_link_service.dart:144` hace `int.tryParse(data['game_id'] ?? '')`, lo cual lanza `TypeError` si `data['game_id']` llega como `int` desde un payload JSON local en lugar de `String`. Lo mismo aplica a los casts `as String?` en las líneas 30, 40, 41, 55, 128, 130.
  3. En `deep_link_service.dart:71-72`, `ActivityRepository().resolvePostIdForReview(reviewId, create: false)` no tiene `try/catch` propio ni timeout: si falla, aborta el deep link en lugar de intentar `_openReviewById` / `fetchReviewById`.
  4. `_openBundles` cambia `pendingTab.value = 1` sin cerrar pantallas modales o de detalle empujadas previamente sobre `DeepLinkService.navigatorKey`.
- **Solución propuesta**:
  1. En `MainScreen.initState()`, programar un `addPostFrameCallback` que consuma `DeepLinkService.pendingTab.value` si no es nulo, y en `_loadSavedTab()` evitar sobrescribir la pestaña si hay `pendingTab.value != null`; esperar a `navigatorKey.currentState` en cold start.
  2. Cambiar `deep_link_service.dart:144` a `data['game_id']?.toString() ?? ''` y usar `?.toString()` en todos los campos de `data`.
  3. Envolver `resolvePostIdForReview` en `try/catch` con fallback a `fetchReviewById`.
  4. Hacer `navigatorKey.currentState?.popUntil((r) => r.isFirst)` en `_openBundles` si hay rutas sobre `MainScreen`.

### [BUG-41] — `StylePackMusicService`: import condicional incompatible con Wasm (`dart.library.html`), doble reproducción simultánea y falso `_playingPackId`
- **ID y Título**: `[BUG-41]` — `StylePackMusicService`: import condicional incompatible con Wasm (`dart.library.html`), doble reproducción simultánea y falso `_playingPackId`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/services/style_pack_music_service.dart:9-11, 20, 26-54, 61-94, 103-121`, `lib/main.dart:133-134`, `lib/screens/appearance_screen.dart:279-280, 312-313, 331-332`, `lib/screens/design/sections/design_style_packs_section.dart:13-16`, `lib/theme/app_theme.dart:108-114`
- **Problema / Causa raíz**:
  1. `style_pack_music_service.dart:10` usa `if (dart.library.html) 'style_pack_music_backend_web.dart'`, cuando `style_pack_music_backend_web.dart` usa `dart:js_interop` y `package:web/web.dart`. En compilación Wasm (`--wasm`), `dart.library.html` es `false` y se compila el backend IO (`audioplayers`), rompiendo Web/Wasm.
  2. `init()` llama a `_schedulePlaybackAttempt()` (línea 36) y `main.dart:134` vuelve a llamar inmediatamente `syncWithCurrentPack(force: true)` tras `await init(...)`. Además, `StylePackMusicService.init` registra `_onThemeChanged` como listener de `themeNotifier` (que ya llama a `syncWithCurrentPack(force: true)` cuando `themeNotifier.setStylePack(...)` notifica), pero `AppearanceScreen` (líneas 279-280, 312-313, 331-332) y `DesignStylePacksSection` (líneas 13-16) vuelven a invocar manualmente `syncWithCurrentPack(force: true)` justo después de `await themeNotifier.setStylePack(...)`. Sin lock de concurrencia, ambas ejecuciones corren en paralelo y reinician el audio dos veces.
  3. En el `catch` (`style_pack_music_service.dart:92`), asigna `_playingPackId = packId` aunque la reproducción haya fallado (ej. autoplay bloqueado en web), provocando que futuras llamadas con `force: false` retornen temprano en línea 74 creyendo que ya suena.
  4. En `didChangeAppLifecycleState` (líneas 109, 117), `_player.resume()` y `_player.pause()` se lanzan sin `unawaited`/manejo de errores. Si se llama a `dispose()` (línea 39) y luego a `init()`, `_player` (`final` en línea 20) ya fue destruido.
- **Solución propuesta**:
  1. Cambiar la condición a `if (dart.library.js_interop)`.
  2. Eliminar las llamadas redundantes en `main.dart:134`, `AppearanceScreen` y `DesignStylePacksSection` (o `_schedulePlaybackAttempt()`), y serializar `syncWithCurrentPack` internamente en `StylePackMusicService`.
  3. Limpiar `_playingPackId = null` en el `catch` (o usar un flag separado `_desiredPackId`) y recrear o mantener reutilizable `_player` tras `dispose()`.

### [BUG-42] — Invitados bloqueados de leer comentarios/likes en `PostThreadController` y botones de edición expuestos si `user_id` es nulo
- **ID y Título**: `[BUG-42]` — Invitados bloqueados de leer comentarios/likes en `PostThreadController` y botones de edición expuestos si `user_id` es nulo
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/activity/widgets/post_thread_controller.dart:80-85`, `lib/screens/activity/review_details_screen.dart:561-567`, `lib/screens/activity/activity_screen.dart:501-503`
- **Problema / Causa raíz**: `PostThreadController.fetchInteractions()` retorna en L81-85 si `_currentUserId == null`, dejando a cualquier usuario invitado sin ver comentarios ni conteo real de likes aunque la reseña/post sea pública. Adicionalmente, en `review_details_screen.dart:561-567` (`_currentReviewData['user_id'] == Supabase.instance.client.auth.currentUser?.id`) y `activity_screen.dart:503` (`myId == activityUserId`), si ambos valores son `null` la igualdad evalúa a `true`, mostrando acciones de dueño/autor ("Tú" o Editar/Eliminar) a invitados.
- **Solución propuesta**:
  1. Permitir en `PostThreadController.fetchInteractions()` consultar likes y comentarios pasando `userId ?? ''` (o parámetro nullable en el repositorio) para calcular `hasLiked = false` en invitados y cargar igualmente `likesCount` y `comments`.
  2. Cambiar las comparaciones de autoría a `currentUserId != null && currentUserId == targetUserId`.

### [BUG-43] — Desincronización de paginación (`hasMore`/`isLoadingMore`) entre `PaginatedScrollMixin` y `ActivityController` y bloqueo permanente tras error de red
- **ID y Título**: `[BUG-43]` — Desincronización de paginación (`hasMore`/`isLoadingMore`) entre `PaginatedScrollMixin` y `ActivityController` y bloqueo permanente tras error de red
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/activity/activity_screen.dart:37-38, 78-83, 1260, 1286`, `lib/screens/activity/activity_controller.dart:43-45, 126-190`
- **Problema / Causa raíz**: `ActivityScreen` usa `hasMore` del `PaginatedScrollMixin` en el `ListView.builder` (`itemCount` en L1286), mientras `ActivityController` gestiona su propio `hasMore`. Al iniciar con `< 30` ítems, `_controller.hasMore` pasa a `false` pero el `hasMore` del mixin sigue en `true` (spinner infinito abajo). Tras paginar hasta el final (`mixin.hasMore = false`), hacer pull-to-refresh (`activity_screen.dart:1260`) resetea `_controller.hasMore = true`, pero `mixin.hasMore` permanece `false`, rompiendo el scroll infinito. Además, en `activity_controller.dart:169`, cualquier error de red en `fetchActivity` fija `hasMore = false` permanentemente; en L131-145 `isRefresh: true` no invalida un `loadMore` en vuelo; y `refreshInPlace()` (L178-183) deja sin `await` el fallback cuando `_activities.isEmpty` y envía `limit: _offset` (si `_offset == 0`, `.range(0, -1)` falla en PostgREST).
- **Solución propuesta**:
  1. Eliminar el estado duplicado sobreescribiendo los getters `bool get hasMore => _controller.hasMore;` y `bool get isLoadingMore => _controller.isLoadingMore;` en `_ActivityScreenState` (o sincronizarlos en cada notificación).
  2. Añadir un contador de generación `_fetchEpoch` en `ActivityController` para descartar respuestas obsoletas de `loadMore` tras un `isRefresh`.
  3. En el `catch` de `fetchActivity`, mantener el estado previo de `hasMore` (sin forzar `false`) y exponer `error` con botón de reintento.
  4. En `refreshInPlace()`, hacer `return fetchActivity(isRefresh: true, silent: true);` si `_activities.isEmpty || _offset <= 0`.

### [BUG-44] — `_authSub` en `ActivityController` no limpia estado al cerrar sesión y `ActivityScreen` no hidrata `viewedStoryIdsNotifier` al iniciar
- **ID y Título**: `[BUG-44]` — `_authSub` en `ActivityController` no limpia estado al cerrar sesión y `ActivityScreen` no hidrata `viewedStoryIdsNotifier` al iniciar
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/activity/activity_controller.dart:70-93, 194-267`, `lib/screens/activity/activity_screen.dart:46-50, 147-155`
- **Problema / Causa raíz**:
  1. `ActivityController.init()` y `_authSub` llaman a `fetchFriendsStrip()` (que NO obtiene `viewedStoryIds`), y `ActivityScreen.initState()` nunca llama a `fetchFriendsStripWithViewed()`. Así, al abrir la app los anillos de historias ya vistas aparecen como no vistas hasta hacer pull-to-refresh.
  2. En `_authSub` (`activity_controller.dart:85`), si `_userId == null` (cierre de sesión), retorna sin vaciar `_activities`, `_friendsStrip`, `_userStories`, `_pendingRequestsCount`, ni remover `_realtimeChannel`.
  3. Si un invitado inicia sesión sin recrear `ActivityScreen`, `libraryUpdateNotifier` (`activity_screen.dart:46-48`) nunca queda suscrito.
- **Solución propuesta**:
  1. Unificar `fetchFriendsStrip` y `fetchFriendsStripWithViewed` en `ActivityController` devolviendo o almacenando `viewedStoryIds` y sincronizándolos en el controller al terminar `init()`, `_authSub` y `_triggerRealtimeRefresh()`.
  2. Al detectar `_userId == null` en `_authSub`, limpiar colecciones, remover `_realtimeChannel` y resetear `_isLoading = false`.
  3. Registrar siempre `libraryUpdateNotifier.addListener(_onLibraryUpdated)` en `ActivityScreen.initState` (filtrando dentro del callback si `_controller.isGuest`).

### [BUG-45] — Race condition en `ActivityController.toggleLike(int index)` por índice posicional y mutación in-place de `_grouped_items`
- **ID y Título**: `[BUG-45]` — Race condition en `ActivityController.toggleLike(int index)` por índice posicional y mutación in-place de `_grouped_items`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/activity/activity_controller.dart:271-297, 301-357`
- **Problema / Causa raíz**: `toggleLike(int index)` usa el índice posicional `index` antes y después de `await _repo.resolvePostIdForReview(...)` (L332) y `await _repo.toggleLike(...)` (L342). Si un evento Realtime o `refreshInPlace()` reordena o acorta `_activities` durante la petición, `_applyPostStats(index, ...)` modifica otro post o lanza `RangeError`. Además, carece de lock por `postId`/`activityId` contra doble tap concurrente, omite `if (isDisposed) return;` tras los `await`, y muta `review['_post']` / `groupedItems.first['_post']` in-place (L280-294) antes de copiar.
- **Solución propuesta**:
  1. Identificar el ítem objetivo por clave estable (`postId` o `activity['id']`) y resolver dinámicamente su índice actual tras cada `await` con `if (isDisposed) return;`.
  2. Mantener un `Set<String> _togglingLikes` para ignorar taps concurrentes sobre el mismo post.
  3. Realizar copias superficiales/inmutables de `review` y `_grouped_items` antes de aplicar `_post` optimista.

### [BUG-46] — Race conditions al deslizar rápidamente entre historias en `ActivityStoryViewer` (`_loadReviewInteractions`, `_toggleLike`, `_submitComment`)
- **ID y Título**: `[BUG-46]` — Race conditions al deslizar rápidamente entre historias en `ActivityStoryViewer` (`_loadReviewInteractions`, `_toggleLike`, `_submitComment`)
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/activity/activity_story_viewer.dart:129-172, 292-331, 333-366`
- **Problema / Causa raíz**:
  1. En `_loadReviewInteractions()` (L161-164), la guarda `(_currentPostId != postId && _currentReview?['id'] != reviewId)` falla cuando `reviewId == null`: ambos lados de `!=` para `reviewId` son `null`, dando `false` y permitiendo que una respuesta tardía sobrescriba `_likesCount` y `_hasLiked` del slide nuevo.
  2. En `_toggleLike()` (L292-331), no verifica tras `await` si el usuario sigue en el mismo slide (`groupIndex`/`activityIndex`/`postId`), revirtiendo el estado optimista sobre el slide equivocado.
  3. En `_submitComment()` (L333-366), si el usuario cambia de slide mientras se envía el comentario, L355 limpia `_commentController` del slide nuevo y recarga interacciones sobre el slide equivocado.
- **Solución propuesta**:
  1. Capturar una clave única del slide al inicio (`final slideKey = '$_groupIndex:$_activityIndex:$postId:$reviewId'`) y comprobar `if (!mounted || _currentSlideKey != slideKey) return;` tras cada `await`.
  2. En `_toggleLike()`, actualizar el mapa `_post` del `activity` específico capturado (y solo actualizar `_likesCount`/`_hasLiked` de estado si sigue activo el mismo slide).

### [BUG-47] — `focusComment: true` roto al abrir `ReviewDetailsScreen` y `GroupedPostDetailsScreen` + `requestFocus()` sin `mounted`
- **ID y Título**: `[BUG-47]` — `focusComment: true` roto al abrir `ReviewDetailsScreen` y `GroupedPostDetailsScreen` + `requestFocus()` sin `mounted`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/activity/review_details_screen.dart:69-75, 502-503, 1176`, `lib/screens/activity/grouped_post_details_screen.dart:80-90, 261, 486`
- **Problema / Causa raíz**: En ambos screens, `initState` dispara `fetchInteractions()` con `isLoading == true` inicial, mientras que `CommentComposer` (que recibe `_commentFocusNode`) solo se monta cuando `!isLoading` (`review_details_screen.dart:1176`, `grouped_post_details_screen.dart:486`). Por tanto, el `addPostFrameCallback` del primer frame ejecuta `_commentFocusNode.requestFocus()` cuando el `TextField` ni siquiera existe en el árbol, no abriendo el teclado nunca. Adicionalmente, `review_details_screen.dart:73` no verifica `if (mounted)` en el callback.
- **Solución propuesta**:
  1. Mantener `bool _pendingFocusComment = widget.focusComment;` y solicitar el foco en un `addPostFrameCallback` la primera vez que `!isLoading && _pendingFocusComment && mounted`, poniendo `_pendingFocusComment = false`.
  2. Añadir siempre `if (mounted)` antes de usar `_commentFocusNode`.

### [BUG-48] — `ReviewDetailsScreen._submitComment` ignora fallo/`false`, borra el borrador y llama a `setState` tras `await` sin `mounted`; `_toggleLike` sin `try/catch`
- **ID y Título**: `[BUG-48]` — `ReviewDetailsScreen._submitComment` ignora fallo/`false`, borra el borrador y llama a `setState` tras `await` sin `mounted`; `_toggleLike` sin `try/catch`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/activity/review_details_screen.dart:86-88, 90-119`
- **Problema / Causa raíz**:
  1. `_submitComment()` (L99-111) no recoge el `bool` de retorno de `_controller.submitComment(...)`: si devuelve `false` (invitado, envío concurrente o `postId == null`), igualmente limpia `_commentController`, imagen, juego y respuesta, perdiendo el comentario del usuario sin aviso. Tampoco verifica `if (!mounted) return;` antes de `_commentController.clear()` y `setState(...)`.
  2. `_toggleLike()` (L86-88) hace `await _controller.toggleLike();` sin `try/catch`, pero `PostThreadController.toggleLike()` relanza errores (`rethrow` en `post_thread_controller.dart:151`), generando excepciones asíncronas no capturadas.
- **Solución propuesta**:
  1. Capturar `final sent = await _controller.submitComment(...);`, comprobar `if (!mounted) return;` y solo limpiar campos si `sent == true` (mostrando aviso si `sent == false`).
  2. Envolver `_controller.toggleLike()` en `try/catch` con `if (!mounted) return;` y `SnackBar` de error (como hace `GroupedPostDetailsScreen`).

### [BUG-49] — `PostThreadController.toggleLike()` sin lock de concurrencia ni `.clamp(0, ...)` (conteo `-1`) y `submitComment` enmascara fallos
- **ID y Título**: `[BUG-49]` — `PostThreadController.toggleLike()` sin lock de concurrencia ni `.clamp(0, ...)` (conteo `-1`) y `submitComment` enmascara fallos
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/activity/widgets/post_thread_controller.dart:124-153, 155-196`
- **Problema / Causa raíz**:
  1. Dos taps rápidos en `toggleLike()` antes de resolver `_ensurePostId()` o `_repo.toggleLike()` ejecutan peticiones en paralelo con estados invertidos; si la primera falla y resta `-1` cuando ya estaba en `0`, `_likesCount` pasa a `-1` al faltar `.clamp(0, 1 << 30)`.
  2. En `submitComment()` (L185), tras insertar en BD llama a `await fetchInteractions()`, cuyo `try/catch` interno (L117-121) silencia errores sin relanzar; así `submitComment` devuelve `true` aunque la lista de comentarios siga desactualizada.
  3. `deleteComment()` (L193-196) no previene doble ejecución concurrente sobre el mismo `commentId`.
- **Solución propuesta**:
  1. Añadir `bool _isTogglingLike = false;` y `final Set<String> _deletingCommentIds = {};` para serializar/bloquear mutaciones concurrentes sobre el mismo recurso.
  2. Aplicar `.clamp(0, 1 << 30)` en todas las actualizaciones/reversiones de `_likesCount`.
  3. Re-lanzar o señalar estado de error si `fetchInteractions()` falla tras `submitComment()`, o insertar el comentario devuelto por Supabase localmente.

### [BUG-50] — `CommentComposer` sin `try/catch` en `_pickImage`, falta `context.mounted` tras `pushSearch`, e ignore de `isSubmitting`/IME en tecla Enter
- **ID y Título**: `[BUG-50]` — `CommentComposer` sin `try/catch` en `_pickImage`, falta `context.mounted` tras `pushSearch`, e ignore de `isSubmitting`/IME en tecla Enter
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/activity/widgets/comment_composer.dart:48-57, 66-74, 118-127, 250-260`
- **Problema / Causa raíz**:
  1. `_pickImage()` (L48-57) no envuelve `picker.pickImage(...)` en `try/catch` (lanzará `PlatformException` sin capturar si se deniegan permisos) ni verifica `context.mounted` antes de `onImageChanged(file)`.
  2. En `_pickGame()` (L68 y L120), tras `await context.pushSearch(isSelectionMode: true)` no se verifica `context.mounted` antes de invocar `onGameChanged(normalized)` (que llama `setState` en el padre).
  3. En desktop (`Focus.onKeyEvent`, L250-260), pulsar `Enter` llama `onSubmit()` incluso cuando `isSubmitting == true` o mientras `controller.value.composing.isValid` (confirmación de tildes/IME).
- **Solución propuesta**:
  1. Pasar `BuildContext` a `_pickImage(BuildContext context)`, envolver en `try/catch` con `SnackBar` de error y validar `if (!context.mounted) return;`.
  2. Añadir `if (!context.mounted) return;` después de ambos `await context.pushSearch(...)`.
  3. Añadir `!isSubmitting && !controller.value.composing.isValid` a la condición de `onKeyEvent`.

### [BUG-51] — `ReviewDetailsController.saveReviewModal` falla si `currentReviewData['id']` es nulo, `deleteReview` engaña al UI en guest, y `fetchPartner` castea sin validar
- **ID y Título**: `[BUG-51]` — `ReviewDetailsController.saveReviewModal` falla si `currentReviewData['id']` es nulo, `deleteReview` engaña al UI en guest, y `fetchPartner` castea sin validar
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/activity/review_details/review_details_controller.dart:53-62, 94-104, 173-184`
- **Problema / Causa raíz**:
  1. En `saveReviewModal()` (L173-176), `currentReviewData['id'] as String` lanza `TypeError` si `id` no es `String` o ignora el parámetro `reviewId` pasado al modal; además L183 lanza `unawaited(postThread.fetchInteractions(...))` sin capturar errores mientras `finally` ya desactiva `_isSavingReview`.
  2. En `deleteReview()` (L97), si `currentUserId == null` retorna sin lanzar excepción, haciendo que `ReviewDetailsScreen._deleteReview` muestre `'Reseña eliminada'`, incremente `libraryUpdateNotifier` y haga pop aunque no se eliminó nada.
  3. `fetchPartner()` (L53-62) es `Future<void>` sin `async` real y hace `List<Map<String, dynamic>>.from(partners)` pudiendo fallar con mapas sin tipar (`Map<dynamic, dynamic>`).
- **Solución propuesta**:
  1. Resolver `final targetReviewId = reviewId ?? currentReviewData['id'] as String?;` y verificar nulidad antes de llamar `fetchUpdatedReview`, esperando `await postThread.fetchInteractions(resolveLatestReviewPost: true)` dentro de un `try/catch` controlado.
  2. Lanzar `StateError('User not authenticated')` si `currentUserId == null` en `deleteReview`.
  3. Usar `partners.whereType<Map>().map(Map<String, dynamic>.from).toList()` en `fetchPartner`.

### [BUG-52] — `ActivityScreen` usa `context` desmontado tras `await` en `handleStatusChangeTap` y `_openFriendsScreen`, y `.then` sin `catchError`
- **ID y Título**: `[BUG-52]` — `ActivityScreen` usa `context` desmontado tras `await` en `handleStatusChangeTap` y `_openFriendsScreen`, y `.then` sin `catchError`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/activity/activity_screen.dart:135-145, 194, 212, 308, 550, 560, 578, 598, 608-626, 962`
- **Problema / Causa raíz**:
  1. En `handleStatusChangeTap` (L608-625), tras `await ActivityRepository().fetchLatestReviewForUserAndGame(...)`, si `review == null` o `!mounted`, L625 llama incondicionalmente a `openGameDetails()` usando `context` desmontado, provocando excepción `Looking up a deactivated widget's ancestor is unsafe`.
  2. En `_openFriendsScreen` (L139-143), tras `await _controller.fetchFriendsStripWithViewed()` falta `if (!mounted) return;` antes de mutar `viewedStoryIdsNotifier`.
  3. Nueve llamadas `.then((_) => _controller.refreshInPlace())` son `unawaited` sin `catchError`.
- **Solución propuesta**:
  1. Añadir `if (!mounted) return;` inmediatamente después de `await ActivityRepository()...` (idealmente moviendo el método al controller) y antes de `openGameDetails()`.
  2. Añadir `if (!mounted) return;` tras `await _controller.fetchFriendsStripWithViewed()`.
  3. Usar `async/await` o `.catchError(...)` en callbacks post-navegación.

### [BUG-53] — Desincronización post-guardado y condición de carrera en `GameDetailsController.saveReview`
- **ID y Título**: `[BUG-53]` — Desincronización post-guardado y condición de carrera en `GameDetailsController.saveReview`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/library/game_details/game_details_controller.dart:789-805`
- **Problema / Causa raíz**: En `saveReview`, tras persistir en repositorio, se actualizan optimísticamente `inLibrary`, `status` y los `rating*`, pero en las líneas `798-799` se disparan `fetchReviews();` y `fetchUserData();` **sin `await`** ni manejo de errores propio. Si el usuario reabre el modal o pulsa eliminar inmediatamente después de guardar, `reviews` y `partnersData` aún contienen el estado previo (o sin `id` de la nueva reseña). Además, si el usuario borra el juego justo después (`deleteFromLibrary`), un `fetchUserData()` tardío puede resolver después y sobreescribir `inLibrary = true` y `status`.
- **Solución propuesta**:
  1. Hacer `await Future.wait([fetchReviews(), fetchUserData()]);` antes de retornar `result` (o antes de liberar `isSaving`), verificando `if (isDisposed) return result;`.
  2. Usar un contador de versión de mutación para descartar respuestas de fetches previos si ocurrió una mutación posterior (`deleteFromLibrary`/`deleteReview`).

### [BUG-54] — `LibraryScreen` dispara `_fetchMyGames()` en cada `build()`, castea `games` sin null-safety y carece de `mounted` check en `FAB`
- **ID y Título**: `[BUG-54]` — `LibraryScreen` dispara `_fetchMyGames()` en cada `build()`, castea `games` sin null-safety y carece de `mounted` check en `FAB`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/library/library_screen.dart:22-31, 39-48, 51-55, 59-61, 128-130, 144-151`
- **Problema / Causa raíz**:
  1. **Fetch en `build()` (`59-61`)**: `FutureBuilder(future: _fetchMyGames(), ...)` crea un `Future` nuevo en cada reconstrucción del widget, re-ejecutando la consulta `user_games` + `games(*)` a Supabase ante cualquier rebuild del árbol padre o cambio de `MediaQuery` y mostrando un spinner de nuevo.
  2. **Cast inseguro (`128-130`)**: `Game.fromMap(userGame['games'] as Map<String, dynamic>)` lanza `TypeError` en runtime si una fila huérfana de `user_games` tiene `games == null`.
  3. **`setState` sin `mounted` (`146-150`)**: tras `await context.pushSearch()`, se llama `setState(() {})` sin `if (!mounted) return;`, lanzando excepción si la pantalla fue desmontada.
  4. **Logout incompleto (`51-55`)**: cierra sesión sin `try/catch`, sin verificar `mounted` y sin llamar a `resetAllGlobalState()` (`globals.dart:108`), pudiendo filtrar ajustes en memoria de una cuenta a la siguiente. Además, no escucha `libraryUpdateNotifier` y el botón de búsqueda (`39-48`) es un stub con SnackBar.
- **Solución propuesta**:
  1. Almacenar `late Future<List<Map<String, dynamic>>> _gamesFuture;` en `initState` y renovarlo explícitamente en un método `_reloadGames()` (suscrito también a `libraryUpdateNotifier`).
  2. Filtrar elementos donde `userGame['games'] is! Map<String, dynamic>` antes de construir `Game`.
  3. Añadir `if (!mounted) return;` después de `await context.pushSearch()`.
  4. En logout, envolver en `try/catch` y llamar `await resetAllGlobalState();` antes de `signOut()`.

### [BUG-55] — `SearchScreen`: estado roto al abrir con `initialQuery`, condición de carrera en paginación, `Future` sin `try/catch` y `DateTime.parse`
- **ID y Título**: `[BUG-55]` — `SearchScreen`: estado roto al abrir con `initialQuery`, condición de carrera en paginación, `Future` sin `try/catch` y `DateTime.parse`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/library/search_screen.dart:64-75, 83-89, 123-174, 192, 198, 201, 224-251, 255-282, 286-351, 484-512`
- **Problema / Causa raíz**:
  1. **Exploración vacía tras `initialQuery` (`64-75`)**: si `ExploreNavigation.targetQuery.value` o `widget.initialQuery` no están vacíos, `initState` NO llama a `_fetchPopularGames` ni `_fetchBundles`. `_isBundlesLoading` permanece `true` para siempre (`55`). Si el usuario borra el texto para volver a Explorar, `_buildExploreBody()` muestra "Tendencias" vacío y un `CircularProgressIndicator` infinito en "Bundles".
  2. **Paginación bloqueada / carrera (`123-174`, `286-351`)**: `_fetchPopularGames` no tiene token de versión como `_searchVersion`, y comparte `hasMore`/`isLoadingMore` de `PaginatedScrollMixin` con `_performSearch`. Además, si se inicia `_performSearch(isInitial: true)` mientras una página `isInitial: false` estaba en curso, el `finally` de la petición antigua omite resetear `isLoadingMore` porque `version != _searchVersion` (`341`), y `isInitial: true` tampoco resetea `isLoadingMore = false` (`297`), dejando `isLoadingMore == true` permanentemente y bloqueando todo scroll infinito futuro (`287`).
  3. **Errores de búsqueda ocultados como "sin resultados" (`333-339`, `484-501`)**: `_performSearch` no guarda `_searchError`; ante un fallo de red, muestra `'No se encontraron resultados...'` sin opción de reintentar.
  4. **`_fetchUserGamesCache` sin `try/catch` (`224-251`)**: si falla Supabase o está offline, lanza excepción no capturada y hace fallar `Future.wait` en `_refreshExplore` (`507-511`). Tampoco escucha `libraryUpdateNotifier` ni `onAuthStateChange`.
  5. **Faltan checks de `mounted` y cancelación de debouncer (`83-89`, `268-282`)**: `_openFilters` llama `setState` tras `await Navigator.push` sin comprobar `mounted`; `_onExternalSearch` no comprueba `mounted` ni cancela `_debouncer`, permitiendo que un debounce pendiente pise la búsqueda externa 500ms después.
  6. **`DateTime.parse` sin `tryParse` (`192, 198, 201`)**: una fecha malformada en `active_bundles` rompe toda la carga de bundles.
- **Solución propuesta**:
  1. Cargar `_fetchBundles()` y `_fetchPopularGames(isInitial: true)` bajo demanda la primera vez que se entra a `_buildExploreBody()` si aún no se han cargado.
  2. Separar el estado de paginación de populares vs búsqueda (o resetear `isLoadingMore = false` al iniciar `isInitial: true` y versionar `_fetchPopularGames` igual que `_searchVersion`).
  3. Añadir `_searchError` y mostrar vista de error con botón de reintento.
  4. Envolver `_fetchUserGamesCache` en `try/catch` con `if (mounted)`, añadir `if (!mounted) return;` en `_openFilters` y `_onExternalSearch`, y cancelar `_debouncer` en `_onExternalSearch` y al limpiar con el botón X (`406`).
  5. Usar `DateTime.tryParse` en `_fetchBundles`.

### [BUG-56] — `GameDetailsScreen._navigateToOriginalGame`: navegación/diálogo inseguro tras `async`, posible pop erróneo de ruta y doble disparo
- **ID y Título**: `[BUG-56]` — `GameDetailsScreen._navigateToOriginalGame`: navegación/diálogo inseguro tras `async`, posible pop erróneo de ruta y doble disparo
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/library/game_details_screen.dart:190-324`
- **Problema / Causa raíz**:
  1. Tras `await Supabase...maybeSingle()` (`237-241`), si `localDbGame == null`, `showDialog` (`249-255`) se muestra sin `PopScope(canPop: false)`. En Android, pulsar el botón físico Atrás cierra el diálogo; luego al terminar `await IGDBService.getGameById(id)` (`256`), `Navigator.of(context, rootNavigator: true).pop()` (`258`, `296`) cierra la pantalla `GameDetailsScreen` subyacente.
  2. No existe flag de bloqueo contra doble tap rápido, pudiendo lanzar dos peticiones paralelas, dos spinners y dos navegaciones consecutivas.
  3. Líneas `268-274`: `Supabase.instance.client.from('games').update(...).catchError((_) {})` es un `Future` sin `await` con `catchError` vacío silencioso que además realiza un `UPDATE` directo desde el cliente sujeto a RLS.
- **Solución propuesta**:
  1. Añadir un flag `_isNavigatingToGame` para prevenir taps concurrentes.
  2. Envolver el diálogo de carga en `PopScope(canPop: false, ...)` o almacenar el `BuildContext` del diálogo y usar `Navigator.of(dialogContext).pop()` solo si `dialogContext.mounted`.
  3. Delegar el lookup y backfill al controlador/repositorio (`_controller` / `ReviewRepository.backfillCoverUrl`) en lugar de consultar/mutar Supabase directamente desde la UI con `catchError((_) {})`.

### [BUG-57] — `GameDetailsController`: `authSub` no limpia ni recarga estado al cerrar o cambiar de sesión; `autoOpenReview` puede re-dispararse
- **ID y Título**: `[BUG-57]` — `GameDetailsController`: `authSub` no limpia ni recarga estado al cerrar o cambiar de sesión; `autoOpenReview` puede re-dispararse
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/library/game_details/game_details_controller.dart:140-148`, `lib/screens/library/game_details_screen.dart:91-93`
- **Problema / Causa raíz**:
  1. El listener `_authSub` (`game_details_controller.dart:140-148`) hace `return` temprano si `currentUser == null` o si `userData != null`. Si el usuario cierra sesión mientras `GameDetailsScreen` permanece en el stack, `userData`, `reviews`, `inLibrary`, `friendsWithGame` y `stashReviews` de la cuenta anterior siguen visibles; si inicia sesión con otra cuenta, `userData != null` impide recargar los datos del nuevo usuario.
  2. `autoOpenReview` (`game_details_screen.dart:91-93`) no tiene flag `_hasAutoOpenedReview`: si un invitado abre la pantalla con `autoOpenReview: true` y luego inicia sesión, `_authSub` dispara `_fetchUserBatch` y abre el modal inesperadamente.
- **Solución propuesta**:
  1. En `_authSub`, detectar cambios de `currentUser?.id` respecto al último `userId` cargado: en sign-out limpiar `userData`, `reviews`, `friendsWithGame`, `inLibrary`, `status` y ratings y notificar; en sign-in con otro usuario reiniciar estado y lanzar `_fetchUserBatch`.
  2. Añadir `bool _didAutoOpenReview = false;` en `_GameDetailsScreenState`.

### [BUG-58] — `GameHeroSection` hardcodea `Colors.white` en AppBar colapsado (ilegible en tema claro) y silencia errores en `DateTime.parse` / `PopScope`
- **ID y Título**: `[BUG-58]` — `GameHeroSection` hardcodea `Colors.white` en AppBar colapsado (ilegible en tema claro) y silencia errores en `DateTime.parse` / `PopScope`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/library/game_details/game_hero_section.dart:164-197, 677-695, 733, 774, 964-971, 1172-1188`
- **Problema / Causa raíz**:
  1. Al hacer scroll hacia abajo (`titleOpacity -> 1.0`), la barra superior se pinta con `theme.scaffoldBackgroundColor.withValues(alpha: titleOpacity * 0.9)` (`1173`), que en tema claro es blanca/clara, pero tanto el icono de retroceso (`967`) como `CorpusPackAwareTitle` (`1184`) tienen `color: Colors.white` hardcodeado, volviéndose invisibles en modo claro.
  2. Línea `695`: `try { final date = DateTime.parse(...); ... } catch (_) {}` usa un `catch (_)` vacío silencioso.
  3. Líneas `733` y `774`: `developerId as int` y `publisherId as int` pueden lanzar `TypeError` si llegan como `double`/`num` o `String` desde `enrichedData`.
  4. Líneas `164-197` (`_showFriendGameActivity`): diálogo `barrierDismissible: false` sin `PopScope` que usa `Navigator.of(context, rootNavigator: true).pop()`, expuesto al cierre accidental de la pantalla padre si el usuario pulsa Atrás durante la carga.
- **Solución propuesta**:
  1. Interpolar el color del icono y título entre `Colors.white` (expandido sobre el banner oscuro) y `theme.colorScheme.onSurface` (colapsado sobre `scaffoldBackgroundColor`) usando `Color.lerp(Colors.white, theme.colorScheme.onSurface, titleOpacity)`.
  2. Reemplazar `try/catch (_)` por `DateTime.tryParse(rawReleaseDate.toString())`.
  3. Parsear IDs con `(id is num) ? id.toInt() : int.tryParse(id.toString())`.
  4. Proteger el loading dialog con `PopScope(canPop: false, ...)`.

### [BUG-59] — Condición de carrera en `_refresh()` / `loadMore()` de las 3 pestañas paginadas del perfil
- **ID y Título**: `[BUG-59]` — Condición de carrera en `_refresh()` / `loadMore()` de las 3 pestañas paginadas del perfil
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/profile_games_grid_tab.dart:84-94, 223-278, 366`, `lib/screens/profile/profile_journal_tab.dart:129-182, 332`, `lib/screens/profile/profile_reviews_tab.dart:70-119, 214`
- **Problema / Causa raíz**: En los tres archivos, `_refresh()` borra `_games`/`_reviews`, pone `_page = 0`, `hasMore = true` y llama `await loadMore()`, mientras `loadMore()` inicia con `if (isLoadingMore || !hasMore) return;`. No existe token de versión de petición (`_loadVersion`) ni cancelación lógica. Si una página anterior está en curso (`isLoadingMore == true`) y el usuario escribe en el buscador, cambia un chip de estado o aplica un filtro:
  1. La nueva llamada a `loadMore()` retorna inmediatamente porque `isLoadingMore` sigue siendo `true`, dejando la pantalla cargando indefinidamente (`_isInitialLoading = true`) o vacía.
  2. Cuando la petición anterior termina, añade resultados obsoletos a la lista recién vaciada e incrementa `_page`.
  3. Además falta `if (!mounted) return;` dentro de `_debouncer.run(...)` (`profile_games_grid_tab.dart:366`, `profile_journal_tab.dart:332`, `profile_reviews_tab.dart:214`).
- **Solución propuesta**:
  1. Añadir `int _requestVersion = 0;` en cada tab.
  2. En `_refresh()`, incrementar `_requestVersion++`, resetear `isLoadingMore = false` y la lista/página antes de invocar `loadMore()`.
  3. En `loadMore()`, capturar `final int reqVersion = _requestVersion;` antes de los `await` y descartar respuesta + evitar mutar `isLoadingMore`/`_page` si `!mounted || reqVersion != _requestVersion`.
  4. Añadir `if (!mounted) return;` dentro de `_debouncer.run(...)`.

### [BUG-60] — Desincronización de paginación (huecos o duplicados) en `_refreshInPlace()` de Diario y Reseñas
- **ID y Título**: `[BUG-60]` — Desincronización de paginación (huecos o duplicados) en `_refreshInPlace()` de Diario y Reseñas
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/profile_journal_tab.dart:184-209`, `lib/screens/profile/profile_reviews_tab.dart:121-143`
- **Problema / Causa raíz**: Al volver de `ReviewDetailsScreen` o `GameDetailsScreen`, `_refreshInPlace()` solicita `from: 0, to: _reviews.length - 1` y reemplaza `_reviews`, pero **no actualiza `_page` ni `hasMore`**. Si el usuario tenía cargada 1 página (`25` en Diario / `15` en Reseñas, `_page == 1`) y dentro de `ReviewDetailsScreen` elimina esa reseña o cambia su estado a `wishlist`, `newItems` devuelve `24` (o `14`) elementos. La siguiente llamada a `loadMore()` usa `from = _page * _pageSize` (`25` / `15`), saltándose permanentemente el elemento en el índice `24` / `14` (hueco en paginación). Si en cambio añadió una reseña desde `GameDetailsScreen`, la siguiente página duplica un elemento. Además, en `ProfileJournalTab._refreshInPlace()` nunca se llama a `_fetchAvailableYears()`, dejando obsoleto el selector de años.
- **Solución propuesta**:
  1. Recargar un múltiplo exacto de `_pageSize` (`to: (_page * _pageSize) - 1`) o recalcular `hasMore = newItems.length >= _page * _pageSize` y ajustar el offset usando `_reviews.length` en lugar de `_page * _pageSize` (deduplicando por `review['id']` al añadir nuevas páginas).
  2. Llamar a `_fetchAvailableYears()` tras `_refreshInPlace()` en `ProfileJournalTab`.

### [BUG-61] — `AchievementGamesScreen` borra los resultados paginados al volver de `GameCard`, pierde estado de scroll y tiene `setState` tras `dispose`
- **ID y Título**: `[BUG-61]` — `AchievementGamesScreen` borra los resultados paginados al volver de `GameCard`, pierde estado de scroll y tiene `setState` tras `dispose`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/profile/achievement_games_screen.dart:59-61, 105, 121, 490-493, 519-529, 542-598, 635-656`
- **Problema / Causa raíz**:
  1. Líneas 59-61: `_fetchUserGamesCache().then((_) { _performSearch(isInitial: true); });` — sin comprobar `if (!mounted) return;` antes de `_performSearch`, que ejecuta `setState(() { _isLoading = true; })` en la línea 527 sin verificar `mounted`.
  2. Líneas 650-652: `onReturn: () { _fetchUserGamesCache(); }` — línea 492 sobrescribe `_results = List.from(_injectedBeatenGames);` sin reiniciar `_searchOffset` ni volver a lanzar `_performSearch(isInitial: true)`, borrando todos los juegos paginados de IGDB que ya se habían cargado y dejando la paginación desalineada.
  3. Líneas 542-586 y 655-656: si IGDB devuelve 35 juegos pero `cleanGames` filtra 30 (quedan 5), `_hasMoreSearchResults` permanece `true` y `childCount` añade 1 slot extra (`CircularProgressIndicator` en una celda 3:4 del grid, línea 635-638). Si el total no llena el alto de pantalla, el `ScrollController` nunca alcanza `maxScrollExtent - 500` y el spinner queda girando eternamente.
  4. Línea 105: `[...reviewsResp, ...userGamesResp]` — si un juego tiene reseña `'beaten'` y entrada en `user_games` con otro estado (p. ej. replay `'playing'`), `uniqueGames[gameId] = item` sobrescribe `'beaten'` con `'playing'`.
  5. Línea 121: `item['games']['igdb_id'] as int: item['status'] as String` — cast inseguro si `status` es `null`.
  6. Línea 648: `userRating: 0.0` fijo en `GameCard` ignorando la valoración real del usuario.
- **Solución propuesta**:
  1. Comprobar `if (!mounted) return;` dentro del `.then(...)` de `initState` y al inicio de `_performSearch`.
  2. Separar el refresco de caché de usuario (`_refreshUserStatusOnly()`) de `_results`: al volver de `GameCard` (`onReturn`), actualizar `_userGamesStatus`, `_completedGamesCount`, re-inyectar los nuevos `beaten` que falten en `_results` y ejecutar `_sortResults()` sin destruir los resultados IGDB ya paginados.
  3. Usar `PaginatedScrollMixin` (o `triggerScrollCheck` tras `addPostFrameCallback`) cuando `cleanGames` deje pocos resultados, y solo mostrar la celda de `CircularProgressIndicator` cuando `_isLoading` sea `true`.
  4. Al fusionar `reviewsResp` y `userGamesResp`, priorizar `'beaten'`/`'completed'`, usar `(item['status'] as String?) ?? ''` y pasar la nota real del usuario a `GameCard`.

### [BUG-62] — Desajuste entre columna de ordenación/filtro (`created_at`) y fecha de agrupación (`effectiveDate`) en `ProfileJournalTab`
- **ID y Título**: `[BUG-62]` — Desajuste entre columna de ordenación/filtro (`created_at`) y fecha de agrupación (`effectiveDate`) en `ProfileJournalTab`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/profile/profile_journal_tab.dart:50-51, 113-125, 256-272`, `lib/repositories/review_repository.dart:1492-1550`
- **Problema / Causa raíz**: `_orderColumn` es `'created_at'` (línea 50-51), por lo que Supabase filtra por año y ordena páginas usando `reviews.created_at`. Sin embargo, `_effectiveDate(r)` (líneas 113-125) prioriza `r['effective_date'] ?? r['played_until'] ?? r['played_from'] ?? r['created_at']`, y `_flatten()` (líneas 256-272) inserta cabeceras de mes cada vez que cambia `${d.year}-${d.month}` de `_effectiveDate(r)`. Si un usuario registra hoy (`created_at` = Nov 2026) un juego que terminó en Enero 2024 (`played_until` = 2024-01-15), Supabase devuelve la fila en medio de Noviembre 2026 (y solo bajo el filtro `2026`), pero `_flatten()` rompe la agrupación generando cabeceras fragmentadas repetidas (`Noviembre, 2026` -> `Enero, 2024` -> `Noviembre, 2026`) y oculta el juego al filtrar por `2024`.
- **Solución propuesta**: Alinear la BD y la UI: completar la migración de `effective_date` (columna generada `COALESCE(played_until, played_from, created_at)`) y usar `_orderColumn = 'effective_date'`, o bien ordenar/filtrar en `ReviewRepository` con `COALESCE` / RPC.

### [BUG-63] — `EditProfileScreen` silencia fallos de subida de imagen y guarda datos sin el nuevo avatar/banner mintiendo al usuario
- **ID y Título**: `[BUG-63]` — `EditProfileScreen` silencia fallos de subida de imagen y guarda datos sin el nuevo avatar/banner mintiendo al usuario
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/edit_profile_screen.dart:153-255, 273-292, 347-350`
- **Problema / Causa raíz**: `_uploadImageToStorage` (líneas 229-255) captura cualquier excepción y devuelve `null`. En `_saveProfile` (líneas 275-292), si `uploadedUrl == null`, continúa igualmente con `update` en `users` usando el `_avatarUrl` / `_bannerUrl` antiguo y muestra `'Perfil guardado correctamente'` (línea 349). Además, `ImageCompressor.compressImage` (`lib/utils/image_compressor.dart:22`) convierte siempre a `CompressFormat.jpeg`, pero `_pickImage` (`209-214`) mantiene la extensión original (`.png`, `.webp`) y sube bytes JPEG con `contentType: 'image/png'` (línea 245).
- **Solución propuesta**:
  1. Hacer que `_uploadImageToStorage` lance (o devuelva un resultado con error) si falla la subida, abortando `_saveProfile` y mostrando un `SnackBar` claro de error sin cerrar la pantalla.
  2. Forzar `ext = 'jpeg'` (o `'jpg'`) tras `ImageCompressor.compressImage`, alineado con `CompressFormat.jpeg`.

### [BUG-64] — `ProfileScreen`: gestión incorrecta de `libraryUpdateNotifier` en invitados/perfiles ajenos, falta `didUpdateWidget` y fallback `SizedBox.shrink()` inválido en `CustomScrollView`
- **ID y Título**: `[BUG-64]` — `ProfileScreen`: gestión incorrecta de `libraryUpdateNotifier` en invitados/perfiles ajenos, falta `didUpdateWidget` y fallback `SizedBox.shrink()` inválido en `CustomScrollView`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/profile_screen.dart:93-115, 889-1015`
- **Problema / Causa raíz**:
  1. Líneas 96-98: `if (!_controller.isGuestProfile) { libraryUpdateNotifier.addListener(_onLibraryUpdated); }`: si el usuario abre el tab Perfil siendo **invitado** (`isGuestProfile == true`) y luego inicia sesión, el listener nunca se registra y editar su biblioteca no refrescará su perfil; inversamente, si abre el perfil de **otro usuario** (`widget.userId != null`), `isGuestProfile` es `false` y sí registra `libraryUpdateNotifier`, provocando recargas inútiles del perfil ajeno cada vez que el usuario actual edita su propia biblioteca.
  2. Falta `didUpdateWidget`: si `ProfileScreen` se reconstruye con otro `widget.userId`, `_controller` conserva el `userId` original.
  3. Línea 1014: `_buildCurrentTabContent()` devuelve `return const SizedBox.shrink();` como fallback dentro de `CustomScrollView.slivers` (donde solo se permiten slivers, no `RenderBox`).
- **Solución propuesta**:
  1. Registrar `libraryUpdateNotifier` únicamente cuando `_controller.isOwnProfile` sea `true` (o escucharlo siempre y filtrar en `_onLibraryUpdated` con `if (mounted && _controller.isOwnProfile && !_controller.isGuestProfile)`).
  2. Devolver `const SliverToBoxAdapter(child: SizedBox.shrink())` en la línea 1014.
  3. Implementar `didUpdateWidget` si `widget.userId != oldWidget.userId`.

### [BUG-65] — Fuga de memoria de `TextEditingController` en diálogo de edición de colección en `GroupDetailScreen`
- **ID y Título**: `[BUG-65]` — Fuga de memoria de `TextEditingController` en diálogo de edición de colección en `GroupDetailScreen`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/my_games/group_detail_screen.dart:295-353`
- **Problema / Causa raíz**: En `_editCollection()` (líneas 295-296) se instancian `final nameCtrl = TextEditingController(text: group.name);` y `final descCtrl = TextEditingController(text: group.description ?? '');`, pero nunca se llama a `.dispose()` al cerrarse `showDialog` ni al terminar el método (línea 354 hace `return` temprano si `saved != true || !mounted`). Cada apertura del diálogo fuga dos controladores con sus listeners nativos.
- **Solución propuesta**: Envolver la llamada a `showDialog` en un bloque `try { ... } finally { nameCtrl.dispose(); descCtrl.dispose(); }` después de leer `nameCtrl.text.trim()` y `descCtrl.text.trim()`, o extraer un `StatefulWidget` de diálogo reutilizando `_GroupFormDialog` de `groups_tab.dart` que ya implementa `dispose()` en su `State`.

### [BUG-66] — Desbordamiento horizontal (`RenderFlex overflow`) en `@username` dentro de `ProfileMobileHeader`
- **ID y Título**: `[BUG-66]` — Desbordamiento horizontal (`RenderFlex overflow`) en `@username` dentro de `ProfileMobileHeader`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/widgets/profile_mobile_header.dart:113-136`
- **Problema / Causa raíz**: En la fila del handle (`Row`, línea 113), `Text('@$username', maxLines: 1, overflow: TextOverflow.ellipsis)` (líneas 115-124) es hijo directo del `Row` sin estar envuelto en `Flexible` ni `Expanded`. Aunque `CurrentlyPlayingBadge` sí está en `Flexible` (líneas 127-133), un `username` largo o con fuente grande excederá el ancho disponible y producirá `RenderFlex overflowed` en vez de truncarse con elipsis.
- **Solución propuesta**:
  1. Envolver `Text('@$username', ...)` en `Flexible(child: Text(...))`.
  2. Asegurar que si `CurrentlyPlayingBadge` está presente, ambos compartan el ancho sin provocar overflow (p. ej. `Flexible` para `@$username` y `Flexible` con `flex` o `ConstrainedBox` para el badge).

### [BUG-67] — Crash potencial por cast nulo en `userProfile!['id']` y accesibilidad de texto en `ProfileMobileHeader`
- **ID y Título**: `[BUG-67]` — Crash potencial por cast nulo en `userProfile!['id']` y accesibilidad de texto en `ProfileMobileHeader`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/widgets/profile_mobile_header.dart:125-133, 154-215`
- **Problema / Causa raíz**:
  1. Línea 129 pasa `userId: userProfile!['id']` asumiendo que `'id'` siempre es `String` no nulo; si el mapa `userProfile` llega incompleto o con `'id': null`, lanza `TypeError` en runtime.
  2. `MobileProfileHeaderDelegate` fija `_expandedProfileHeight = 120.0` y `_collapsedProfileHeight = 60.0` dentro de `SizedBox(height: profileHeight, child: ClipRect(...))` (líneas 156-158, 204-207). Con escalado de texto del sistema (`textScaler` > 1.2x), la `Column` de `ProfileMobileHeader` supera 60px/120px y provoca overflow/recorte.
- **Solución propuesta**:
  1. Validar `final userId = userProfile?['id'] as String?;` antes de renderizar `CurrentlyPlayingBadge` (`if (showPlaying && userId != null && userId.isNotEmpty)`).
  2. Ajustar `minExtent`/`maxExtent` considerando `MediaQuery.textScalerOf(context)` o usar `FittedBox`/`Flexible` en los elementos del header para tolerar escalado de fuente sin overflow.

### [BUG-68] — Desbordamiento horizontal (`RenderFlex overflow`) de `FilterChip`s en `BulkAddToShelfSheet`
- **ID y Título**: `[BUG-68]` — Desbordamiento horizontal (`RenderFlex overflow`) de `FilterChip`s en `BulkAddToShelfSheet`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/widgets/bulk_add_to_shelf_sheet.dart:266-286`
- **Problema / Causa raíz**: Los dos `FilterChip` (`'Solo de esta plataforma'` y `'Ocultar en estantería'`) están dentro de un `Row` sin `Wrap` ni `SingleChildScrollView` horizontal. En pantallas móviles de 320-360px de ancho (menos 40px de padding horizontal), la suma de ambos chips (~340px) excede el ancho disponible y produce `RenderFlex overflowed`.
- **Solución propuesta**: Reemplazar `Row` en línea 266 por `Wrap(spacing: 8, runSpacing: 4, children: [...])` o un `SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(...))`.

### [BUG-69] — `setSheetState` llamado tras `await` sin verificar `ctx.mounted` y salto visual en hojas de reordenamiento
- **ID y Título**: `[BUG-69]` — `setSheetState` llamado tras `await` sin verificar `ctx.mounted` y salto visual en hojas de reordenamiento
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/my_games/groups_tab.dart:190-197`, `lib/screens/my_games/group_detail_screen.dart:236-243, 287`
- **Problema / Causa raíz**:
  1. En `groups_tab.dart:190-197` y `group_detail_screen.dart:236-243`, `onReorderItem` hace `await _controller.reorderGroups(...)` / `await _onReorder(...)` y después llama `setSheetState(() { ... })`. Si el usuario cierra el bottom sheet mientras la petición de red está en curso, `setSheetState` se ejecuta sobre un `StatefulBuilder` desmontado y lanza `setState() called after dispose()`.
  2. Además, en ambos archivos la lista local `groups`/`items` del sheet no se actualiza optimísticamente *antes* del `await`, provocando que el elemento arrastrado rebote visualmente a su posición anterior hasta que responde Supabase.
  3. En `group_detail_screen.dart:287`, al cerrar la hoja de reordenar siempre ejecuta `await _load();` aunque no se haya reordenado ningún elemento.
- **Solución propuesta**:
  1. Actualizar `groups` / `items` optimísticamente en `setSheetState` *antes* de llamar a `_controller.reorderGroups` / `_onReorder`.
  2. Tras el `await`, verificar `if (!ctx.mounted) return;` antes de invocar `setSheetState`.
  3. Mantener un flag `bool reordered = false;` en `_openReorderSheet` y solo llamar `_load()` al cerrar si `reordered && mounted`.

### [BUG-70] — Desincronización optimista y errores silenciosos en `GameGroupsController` y `GroupDetailScreen`
- **ID y Título**: `[BUG-70]` — Desincronización optimista y errores silenciosos en `GameGroupsController` y `GroupDetailScreen`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/my_games/game_groups_controller.dart:24-26, 84, 104-118, 140, 151, 159-171`, `lib/screens/my_games/group_detail_screen.dart:164-183`
- **Problema / Causa raíz**:
  1. `GameGroupsController.load` (línea 25) retorna inmediatamente con `if (isDisposed || _isLoading) return;`. Sin embargo, `updateGroup` (84), `reorderGroups` en error (116), `addGameToGroup` (140) y `removeGameFromGroup` (151) llaman a `await load(silent: true);`: si el `load()` inicial o uno previo sigue en vuelo, el refresco silencioso se descarta y la lista queda desactualizada.
  2. `GameGroupsController.reorderItems` (líneas 159-171) captura cualquier excepción con `debugPrint` y retorna `void` sin propagar error ni devolver `bool`.
  3. En `GroupDetailScreen._onReorder` (líneas 169-183), se reordena `_group` optimísticamente en UI y se llama `await _repository.reorderItems(...)` sin `try/catch`, sin guard de concurrencia y sin `mounted`: si falla la red, lanza excepción no capturada y la UI permanece desincronizada respecto a Supabase; si se arrastran varios ítems rápido, las peticiones `Future.wait` concurrentes se pisan entre sí.
  4. En `GroupDetailScreen._removeItem` (líneas 164-166), `await _repository.removeGameFromGroup(item.id)` carece de `try/catch` y de `if (!mounted) return;`.
- **Solución propuesta**:
  1. Añadir un flag `_pendingReload` o esperar a la petición en curso en `GameGroupsController.load` cuando `silent: true` (o actualizar `groups` en memoria con la respuesta de `updateGroup`/`addGameToGroup`/`removeGameFromGroup`).
  2. Serializar los reordenamientos (cola o token de versión) y hacer que `reorderItems` devuelva `Future<bool>` o relance error para que `GroupDetailScreen._onReorder` haga rollback de `_group` en un `try/catch` y muestre `showCorpusSnackBar` de error.
  3. Envolver `_removeItem` en `try/catch`, comprobar `mounted` tras cada `await` y notificar errores al usuario.

### [BUG-71] — `setState()` síncrono dentro de `initState()` y mutación Fire-and-Forget en `PlatformPickerSheet`
- **ID y Título**: `[BUG-71]` — `setState()` síncrono dentro de `initState()` y mutación Fire-and-Forget en `PlatformPickerSheet`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/widgets/platform_picker_sheet.dart:71-103`
- **Problema / Causa raíz**:
  1. `initState()` invoca `_resolveMissingPlatforms(widget.gameId!)` sin `await` (línea 72), y la primera línea de `_resolveMissingPlatforms` (línea 77) llama síncronamente a `setState(() => _resolvingPlatforms = true);` mientras `initState()` aún no ha terminado, violando el ciclo de vida de `State`.
  2. Líneas 88-93 ejecutan `Supabase.instance.client.from('games').update(...).then((_) {}).catchError((_) {})` sin `await`, silenciando errores y acoplando un diálogo de UI con escritura directa al catálogo global `games`.
  3. Línea 96 (`catch (_) {}`) silencia cualquier error de `IGDBService.getGameById`.
- **Solución propuesta**:
  1. Asignar `_resolvingPlatforms = true;` directamente en `initState()` antes de lanzar `unawaited(_resolveMissingPlatforms(...))` y evitar `setState` síncrono en `initState`.
  2. Mover la resolución y persistencia de plataformas IGDB a `CollectionRepository`, registrando errores con `debugPrint` en lugar de `catchError((_) {})`.

### [BUG-72] — Errores silenciosos (`catch (_)`) sin estado de error ni reintento en modales de estantería
- **ID y Título**: `[BUG-72]` — Errores silenciosos (`catch (_)`) sin estado de error ni reintento en modales de estantería
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/widgets/add_game_to_shelf_sheet.dart:68-70, 178-190`, `lib/screens/profile/widgets/bulk_add_to_shelf_sheet.dart:73-75, 338-353`
- **Problema / Causa raíz**: Tanto `_AddGameToShelfSheetState._load()` como `_BulkAddToShelfSheetState._loadLibrary()` capturan errores en `catch (_) { if (mounted) setState(() => _loading = false); }` sin guardar un mensaje `_error`. Cuando falla la carga, `_options` queda `null` y `_filtered` devuelve `[]`: `add_game_to_shelf_sheet.dart:181` evalúa `_options?.isEmpty == true` (que es `false` porque `_options == null`) y muestra engañosamente `'Sin resultados'`, mientras `bulk_add_to_shelf_sheet.dart:341-346` muestra `'Ningún juego de tu biblioteca coincide...'` en lugar de un error con botón `'Reintentar'`.
- **Solución propuesta**: Añadir `String? _error;` en ambos estados, limpiarlo al iniciar carga, rellenarlo en `catch (e)` (con `debugPrint`), y renderizar un `CorpusEmptyState` con botón `'Reintentar'` cuando `_error != null`.

### [BUG-73] — Posible condición de carrera en `_load()` y ausencia de manejo de errores en `_editItemPlatforms()` de `CollectionTab`
- **ID y Título**: `[BUG-73]` — Posible condición de carrera en `_load()` y ausencia de manejo de errores en `_editItemPlatforms()` de `CollectionTab`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/my_games/collection_tab.dart:96-122, 144-185`
- **Problema / Causa raíz**:
  1. `_load()` (líneas 96-122) no tiene token de secuencia ni flag anti-solapamiento: dos llamadas concurrentes (`libraryUpdateNotifier` + pull-to-refresh + `GameCard.onReturn`) pueden resolverse fuera de orden y sobrescribir `_items` con datos viejos. Además, `catch (_)` oculta la excepción sin log.
  2. `_editItemPlatforms` (líneas 144-185) ejecuta dos `await` previos al sheet (`fetchOwnedPlatforms` y `fetchLibraryForShelf`) sin indicador de carga ni guard de concurrencia (el usuario puede pulsar varias veces abriendo múltiples sheets) y sin `try/catch` en ningún punto (ni antes del sheet ni en `setPlatformsForGame`).
- **Solución propuesta**:
  1. Introducir un contador `int _loadRequestId = 0;` en `_load()` para descartar respuestas obsoletas y registrar el error con `debugPrint`.
  2. Añadir un guard `_openingEditor` + `try/catch` con `showCorpusSnackBar` en `_editItemPlatforms`.

### [BUG-74] — Estado perdido en cambio de usuario/sesión, listener faltante de invitado a autenticado y falta de feedback en `MyGamesScreen` y `GroupsTab`
- **ID y Título**: `[BUG-74]` — Estado perdido en cambio de usuario/sesión, listener faltante de invitado a autenticado y falta de feedback en `MyGamesScreen` y `GroupsTab`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/my_games/my_games_screen.dart:31-38, 98`, `lib/screens/my_games/collection_tab.dart:35-65`, `lib/screens/my_games/games_tab.dart:30-54`, `lib/screens/my_games/groups_tab.dart:29-59, 487-495, 919-953`, `lib/screens/my_games/group_detail_screen.dart:344`
- **Problema / Causa raíz**:
  1. En `MyGamesScreen.initState()` (líneas 34-36), si el usuario entra como invitado (`_isGuest == true`), `libraryUpdateNotifier.addListener(_onLibraryUpdated)` nunca se registra; si inicia sesión después mientras la pantalla vive en el stack, el listener sigue sin existir.
  2. Ninguna de las tres pestañas hijas (`GamesTab`, `CollectionTab`, `GroupsTab`) implementa `didUpdateWidget`: si `widget.userId` cambia tras un cambio de cuenta, las pestañas siguen mostrando datos del `userId` anterior.
  3. En `groups_tab.dart:487-495`, si `_controller.deleteGroup(group.id)` devuelve `false`, no muestra ningún mensaje de error.
  4. En `groups_tab.dart:919-927` (`_GroupFormDialog`) y `group_detail_screen.dart:344`, pulsar Crear/Guardar con el nombre vacío no hace nada silenciosamente sin indicar error de validación en el `TextField`.
- **Solución propuesta**:
  1. Registrar `libraryUpdateNotifier.addListener` incondicionalmente en `MyGamesScreen.initState()` y comprobar `if (_isGuest || !mounted) return;` dentro de `_onLibraryUpdated`.
  2. Implementar `didUpdateWidget` en `GamesTab`, `CollectionTab` y `GroupsTab` (recreando/recargando cuando `oldWidget.userId != widget.userId`), o usar `ValueKey(userId)` en `MyGamesScreen`.
  3. Mostrar `showCorpusSnackBar` de error cuando `deleteGroup` devuelva `false`, y usar `Form` / `errorText` en los diálogos de creación/edición de colección.

### [BUG-75] — Condición de carrera sin epoch/requestId en `HomeController.reload()` y error no capturado en `_fetchPhaseTwo()`
- **ID y Título**: `[BUG-75]` — Condición de carrera sin epoch/requestId en `HomeController.reload()` y error no capturado en `_fetchPhaseTwo()`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/home/controller/home_controller.dart:76-90, 140-150, 261-281`
- **Problema / Causa raíz**:
  1. `reload()` no mantiene un contador monotónico (`_reloadEpoch`). Si se llama dos veces seguidas (`initState` + `onAuthStateChange` o `libraryUpdateNotifier` durante pull-to-refresh), el primer `_fetchPhaseTwo()` puede resolver después que el segundo y sobrescribir `phaseTwoData` con datos obsoletos.
  2. La línea 82 encadena `_fetchPhaseTwo().then(...)` sin `.catchError(...)`: si algo fuera de los bloques `try` internos lanza una excepción, queda como error asíncrono no manejado y `phaseTwoLoaded` permanece `false` indefinidamente (dejando `_SectionShimmer` animándose para siempre).
  3. En `_fetchPhaseOne` (líneas 141, 144, 149), `r['game_id'] as num` y `g['game_id'] as int` no están dentro de `try/catch` ni filtran IDs negativos (juegos solo de Steam `< 0`, ver `steam_import_progress_screen.dart:115`) antes de llamar a `IGDBService.getGamesByIds(igdbIds)`.
- **Solución propuesta**:
  1. Añadir `int _loadGeneration = 0;` en `HomeController`; incrementarlo en `reload()` y descartar resultados de `_fetchPhaseTwo` si `gen != _loadGeneration || isDisposed`.
  2. Añadir `.catchError` a `_fetchPhaseTwo()` para establecer `phaseTwoLoaded = true` (con listas vacías) y registrar el error, evitando shimmers infinitos.
  3. Filtrar `igdbIds` con `.whereType<int>().where((id) => id > 0)` antes de consultar IGDB.

### [BUG-76] — `ImportPreviewScreen`: la `TabBar` desaparece al filtrar/resolver la última duda y `Navigator.pop` doble rompe el stack
- **ID y Título**: `[BUG-76]` — `ImportPreviewScreen`: la `TabBar` desaparece al filtrar/resolver la última duda y `Navigator.pop` doble rompe el stack
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/settings/import_preview_screen.dart:49-55, 69-123, 127-143, 210-219, 270, 347-373, 442-489`
- **Problema / Causa raíz**:
  1. `hasTabs` (línea 127) evalúa `ambiguousRows.isNotEmpty || notFoundRows.isNotEmpty`, usando los getters **filtrados** por `_searchQuery` y `_statusFilter` (líneas 49-55). Si el usuario está en "Dudas" o "No encontrados" y busca sin coincidencias (o resuelve la última fila ambigua en línea 371), `hasTabs` cambia a `false`, destruyendo el `TabBar` y `TabBarView` en mitad de la interacción.
  2. En `_importData()` (líneas 78-113): el diálogo de carga no bloquea el botón físico "Atrás" de Android (`PopScope(canPop: false)` ausente). Si el usuario pulsa Atrás durante `saveImportedGames`, se cierra el diálogo; al terminar, la línea 94 `Navigator.of(context, rootNavigator: true).pop()` cierra `ImportPreviewScreen` y la línea 106 `Navigator.pop(context)` cierra `IntegrationsScreen`. Además falta guard `_isImporting` contra doble pulsación.
  3. En `_editRow()` (líneas 442-489): pasa `currentRatingGameplay..Visuals` como `0.0`, omite `row.completionType`, `row.platform` y `row.playTimeHours`, y en `onSave` descarta silenciosamente `isReplay`, `replayNumber`, `playedFrom`, `playedUntil`, `progressPercent`, `reviewDate`, `newImages`, `existingImages` y `partnerIds`.
  4. Casts inseguros en `_buildAmbiguousTab`: `(cand['first_release_date'] as int)` (línea 363), `row.candidates[cIdx] as Map<String, dynamic>` (línea 347) y `coverId as String?` (líneas 270, 353).
- **Solución propuesta**:
  1. Calcular `hasTabs` sobre el conteo sin filtrar (o mantener las 3 pestañas mientras existan dudas/no encontrados iniciales y mostrar estado vacío dentro de la pestaña).
  2. Envolver el diálogo de carga en `PopScope(canPop: false)`, guardar `NavigatorState` / bandera `dialogOpen` y añadir `_isImporting`.
  3. Usar `(cand['first_release_date'] as num?)?.toInt()` y `Map<String, dynamic>.from(...)` en lugar de casts directos.

### [BUG-77] — `SteamImportProgressScreen`: carrera entre Realtime y polling de Edge Function, `PopScope` ausente y riesgo de `TypeError` / bucle infinito
- **ID y Título**: `[BUG-77]` — `SteamImportProgressScreen`: carrera entre Realtime y polling de Edge Function, `PopScope` ausente y riesgo de `TypeError` / bucle infinito
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/settings/steam_import_progress_screen.dart:42-83, 85-171, 205-206`
- **Problema / Causa raíz**:
  1. `_subscribeToProgress()` escucha `PostgresChangeEvent.all` filtrado solo por `user_id` en `steam_import_jobs` (líneas 48-56) y muta `_isError` y `_isDone` (líneas 65-72). Si existe una fila previa fallida/completada del mismo usuario o si el evento Realtime `completed` llega antes que la última respuesta HTTP de `steam-library-import`, `_isError = true` aborta el `while` (línea 87) o la UI marca completado prematuramente.
  2. Si `userId == null`, `_subscribeToProgress()` retorna en línea 44 pero `_runImportLoop()` sigue invocando la Edge Function igualmente.
  3. `automaticallyImplyLeading: _isDone || _isError` (líneas 205-206) oculta la flecha de la `AppBar`, pero falta `PopScope(canPop: _isDone || _isError)` permitiendo salir con el gesto/botón Atrás dejando la importación a medias.
  4. El `while (!done && !_isError && mounted)` carece de límite de iteraciones y `.timeout()` en `functions.invoke`. Además, `cg['igdb_id'] == gameId` hace búsqueda lineal `O(N*M)` y `(gameId as int? ?? 0) < 0` / `ug['steam_playtime_minutes'] as int?` (líneas 114-115) lanzan `TypeError` si llegan como `num`. Si `data['done'] == true` con `_accumulatedRows` vacío, navega igualmente a `ImportPreviewScreen` con 0 juegos.
- **Solución propuesta**:
  1. Devolver un `jobId` en la primera respuesta de `steam-library-import` y filtrar el canal Realtime por `job_id` (o usar HTTP como fuente autoritativa de finalización y Realtime solo para progreso).
  2. Envolver el `Scaffold` en `PopScope(canPop: _isDone || _isError)`.
  3. Indexar `catalogList` en un `Map<int, Map<String, dynamic>>` (`O(N+M)`), usar `(val as num?)?.toInt()`, añadir máximo de iteraciones/timeout y mostrar mensaje claro si `_accumulatedRows.isEmpty`.

### [BUG-78] — `NotificationsScreen`: carrera en guardado optimista sin rollback, errores en `sendTestNotification` y estado en invitados
- **ID y Título**: `[BUG-78]` — `NotificationsScreen`: carrera en guardado optimista sin rollback, errores en `sendTestNotification` y estado en invitados
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/settings/notifications_screen.dart:41-130, 242-286`, `lib/services/notification_service.dart:326-361`
- **Problema / Causa raíz**:
  1. `_toggle()` (líneas 103-130) cambia el booleano localmente y llama `await _savePreferences()` sin serialización ni debounce. Pulsar dos switches rápido lanza dos `upsert` concurrentes en carrera y resetea `_isSaving = false` al terminar el primero.
  2. Si el `upsert` falla (líneas 91-96), muestra `SnackBar` de error pero **no revierte el estado del switch**, dejando la UI desincronizada respecto a Supabase.
  3. En invitados (`userId == null`, líneas 43-45 y 75-76), muestra todos los switches activos y deja pulsarlos mientras `_savePreferences()` retorna en silencio sin guardar nada.
  4. En los botones de prueba/permisos (líneas 243-286): `FilledButton` siempre muestra `'Solicitud de notificaciones procesada.'` aunque el usuario deniegue el permiso; `OutlinedButton` llama `await NotificationService().sendTestNotification()` sin `try/catch` (si `getToken()` lanza o la Edge Function falla en `NotificationService:350`, muestra falsamente `'Notificación de prueba enviada.'`).
- **Solución propuesta**:
  1. Guardar el valor previo antes de mutar en `_toggle()` y revertirlo en el `catch` si falla el `upsert`; serializar o aplicar debounce de 300 ms en `_savePreferences()`.
  2. Si `userId == null`, deshabilitar los switches o mostrar prompt de inicio de sesión.
  3. Hacer que `requestPermissions()` y `sendTestNotification()` devuelvan un resultado/estado (`bool` o enum) y envolver las llamadas de botón en `try/catch`.

### [BUG-79] — Uso de `BuildContext` tras `Navigator.pop(context)` en `HomeScreen._showFullReviewSheet` y `SteamImportSetupScreen._startImport`
- **ID y Título**: `[BUG-79]` — Uso de `BuildContext` tras `Navigator.pop(context)` en `HomeScreen._showFullReviewSheet` y `SteamImportSetupScreen._startImport`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/home/home_screen.dart:713-727`, `lib/screens/settings/steam_import_setup_screen.dart:19-24`
- **Problema / Causa raíz**:
  1. En `home_screen.dart:715`, dentro del `builder` del bottom sheet, se ejecuta `Navigator.pop(context)` (lo que desmonta el sheet y desactiva su `context`) y justo en la línea 718 se llama a `context.pushGameDetails(...)` usando ese mismo `context` cerrado.
  2. En `steam_import_setup_screen.dart:22-23`, `_startImport()` llama `Navigator.pop(context)` (cerrando el modal bottom sheet) y seguidamente `context.pushSteamImportProgress(minPlaytimeMinutes)` sobre el `context` ya desmontado.
- **Solución propuesta**:
  1. En `home_screen.dart`, usar el `context` del estado padre (`_HomeScreenState`, comprobando `mounted`) o capturar el `NavigatorState` / `CorpusRouter` antes de `pop()`.
  2. En `steam_import_setup_screen.dart`, devolver `minPlaytimeMinutes` con `Navigator.pop(context, minPlaytimeMinutes)` y navegar desde `IntegrationsScreen` tras el `await showModalBottomSheet<int>(...)` comprobando `if (mounted && result != null)`.

### [BUG-80] — Flujos Auth: validación incompleta, `.trim()` en contraseñas, doble envío con `onSubmitted` y mutación prematura de `main_tab_index`
- **ID y Título**: `[BUG-80]` — Flujos Auth: validación incompleta, `.trim()` en contraseñas, doble envío con `onSubmitted` y mutación prematura de `main_tab_index`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/auth/login_screen.dart:22-39, 117`, `lib/screens/auth/register_screen.dart:22-65, 138, 144`, `lib/screens/auth/forgot_password_screen.dart:22, 24-38, 118`, `lib/screens/auth/reset_password_screen.dart:27-59, 135`
- **Problema / Causa raíz**:
  1. `onSubmitted` en las 4 pantallas (`login_screen.dart:117`, `register_screen.dart:144`, `forgot_password_screen.dart:118`, `reset_password_screen.dart:135`) invoca la acción directamente sin comprobar `if (_isLoading) return;`, permitiendo envíos duplicados al pulsar Enter repetidamente aunque el botón esté deshabilitado.
  2. `LoginScreen` (línea 30), `RegisterScreen` (línea 38) y `ResetPasswordScreen` (líneas 28-29) aplican `.trim()` sobre la contraseña, alterando silenciosamente contraseñas válidas con espacios iniciales/finales.
  3. `LoginScreen` no valida email/contraseña vacíos antes de llamar a Supabase. `RegisterScreen` solo valida `username.isEmpty` (no valida email ni longitud mínima de contraseña) y además muestra `'mínimo 6 caracteres'` (línea 138) mientras `ResetPasswordScreen:35` exige mínimo **8** caracteres.
  4. `LoginScreen:25-26` y `RegisterScreen:33-34` sobrescriben `prefs.setInt('main_tab_index', 0)` **antes** de que `signInWithPassword`/`signUp` tengan éxito; si el login falla o requiere confirmación por correo, ya corrompieron la preferencia local.
  5. `RegisterScreen:64` llama `Navigator.pop(context)` sin `canPop()`. `ResetPasswordScreen:58` llama `popUntil((r) => r.isFirst)`. `ForgotPasswordScreen:22` y `RegisterScreen:41` hardcodean `_appUrl = 'https://corpus-games.vercel.app'`.
- **Solución propuesta**:
  1. Añadir `if (_isLoading) return;` al principio de `_signIn`, `_signUp`, `_sendResetEmail` y `_updatePassword`.
  2. Dejar de hacer `.trim()` en contraseñas; unificar validación de email, longitud mínima (8 caracteres) y `username` usando `Form` + `TextFormField`.
  3. Mover `prefs.setInt('main_tab_index', 0)` para después de confirmar sesión exitosa.
  4. Comprobar `canPop()` antes de `pop` y mover la URL de redirección a `Env` / configuración por plataforma.

### [BUG-81] — Fuga de canales Realtime (`.unsubscribe()` sin `removeChannel`) y ausencia de guarda `_disposed` en `MainScreenController`
- **ID y Título**: `[BUG-81]` — Fuga de canales Realtime (`.unsubscribe()` sin `removeChannel`) y ausencia de guarda `_disposed` en `MainScreenController`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/main/main_screen_controller.dart:21-23, 41-46, 54-79, 100-109, 120-150, 159-235`
- **Problema / Causa raíz**:
  1. `dispose()` (líneas 42-46) solo llama a `.unsubscribe()` sobre `_friendshipsChannel`, `_activityFeedChannel` y `_notificationsChannel`, pero nunca llama a `_client.removeChannel(channel)` (a diferencia de `lib/main.dart:293`). Los objetos `RealtimeChannel` permanecen registrados con nombres estáticos (`'pending_friend_requests'`, `'main_activity_feed_badge'`, `'unread_notifications_badge'`), provocando acumulación/colisión de canales al recrearse `MainScreen` tras cambiar de usuario o cerrar sesión.
  2. `MainScreenController` no posee bandera `_disposed`. Al cerrar sesión, las peticiones asíncronas en vuelo (`fetchInitialBadges()` líneas 54-79, `fetchNotificationsCount()` líneas 100-109, o `.then()` en líneas 125-127) pueden resolverse después de `dispose()` y sobrescribir los `ValueNotifier` globales con datos de la sesión anterior.
- **Solución propuesta**:
  1. Añadir `bool _disposed = false;` al controller y comprobar `if (_disposed) return;` antes y después de cada `await` / `.then()` / callback Realtime.
  2. En `dispose()`, fijar `_disposed = true;` y ejecutar `_client.removeChannel(ch)` para los tres canales, anulando sus referencias.
  3. Incluir `myId` en los nombres de canal (p. ej. `'pending_friend_requests_$myId'`).

### [BUG-82] — Desincronización de badges en `MainScreen` y `MainScreenController` (solicitudes fantasma, actividad al reconectar, solo `INSERT`, evicción `.clear()`)
- **ID y Título**: `[BUG-82]` — Desincronización de badges en `MainScreen` y `MainScreenController` (solicitudes fantasma, actividad al reconectar, solo `INSERT`, evicción `.clear()`)
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/main_screen.dart:116, 143-158, 198, 219, 284-298`, `lib/screens/main/main_screen_controller.dart:72-78, 132-208`
- **Problema / Causa raíz**:
  1. **Badge de solicitudes fantasma**: `MainScreen._onTabTapped` (líneas 295–298) limpia `unreadFriendRequestsCount.value = 0` al tocar la pestaña Perfil sin abrir `FriendsScreen`, pero `onTabSwitchedByBrowser` (línea 116) y `_loadSavedTab` (líneas 198, 219) no lo hacen, y cada `resumed` (línea 154) o reconexión Realtime (`main_screen_controller.dart:200`) vuelve a restaurar `unreadFriendRequestsCount.value = res.length`.
  2. **Badge de Actividad reapareciendo dentro de la propia pestaña**: `fetchInitialBadges()` (`main_screen_controller.dart:74-75`) asigna `unreadActivityCount.value` sin comprobar `isOnActivityTab()`, reactivando el badge en arranque directo en tab 2 o tras reconexión Realtime.
  3. **Solo `INSERT` en `_friendshipsChannel`**: líneas 134–148 solo escuchan `PostgresChangeEvent.insert`, ignorando cancelaciones (`DELETE`) o aceptaciones/rechazos remotos (`UPDATE`).
  4. **Evicción brusca en `_recentActivityGames` y `_countedPostIds`**: al superar 50/100 elementos (`175-177, 186-189`), `.clear()` borra todo el historial permitiendo doble conteo inmediato; además `_activityFeedChannel` no filtra por amigos.
  5. **`resumed` en pestaña 2** (`145–149`): omite refrescar `unreadFriendRequestsCount`.
- **Solución propuesta**:
  1. Actualizar `unreadActivityCount.value` en `fetchInitialBadges()` solo si `!isOnActivityTab()`.
  2. Unificar criterio del badge de solicitudes (limpiar al abrir `FriendsScreen` o persistir `last_seen`) y escuchar `PostgresChangeEvent.all` en `_friendshipsChannel`.
  3. Reemplazar `.clear()` en `_recentActivityGames` y `_countedPostIds` por eliminación FIFO (`LinkedHashSet`).

### [BUG-83] — Cierre de sesión en `SettingsScreen` hace `Navigator.pop` antes de completar `signOut()` y sin manejo de errores ni `flushNow()`
- **ID y Título**: `[BUG-83]` — Cierre de sesión en `SettingsScreen` hace `Navigator.pop` antes de completar `signOut()` y sin manejo de errores ni `flushNow()`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/settings_screen.dart:376-382`, `lib/services/user_settings_service.dart:129-138`, `lib/main.dart:233-241`
- **Problema / Causa raíz**: Al pulsar `'Cerrar sesión'`:
  1. Se ejecuta `Navigator.pop(context)` inmediatamente (línea 377) saltándose `AppNavigationController.instance.requestBack(context)` y antes de ejecutar los `await` (`_prefsFuture`, `deleteFcmToken()`, `signOut()`).
  2. No hay `try/catch`, indicador de carga ni bloqueo anti doble-pulsación: si `signOut()` falla por red, el usuario ya fue devuelto a `ProfileScreen` sin aviso de error y con `main_tab_index` sobrescrito a `0`.
  3. `UserSettingsService().flushNow()` no se invoca antes de `signOut()`, descartando ajustes recientes aún en el debounce de 600ms cuando `AuthGate` ejecuta `resetLocalCacheToDefaults()`.
- **Solución propuesta**: Añadir flag `_isSigningOut`, envolver en `try/catch`: `await UserSettingsService().flushNow()`, `await NotificationService().deleteFcmToken()`, actualizar `main_tab_index`, y `await Supabase.instance.client.auth.signOut()`, dejando que `AuthGate` desmonte `MainScreen` o mostrando `SnackBar` si falla.

### [BUG-84] — `CircleAvatar(backgroundImage: NetworkImage(...))` sin `onBackgroundImageError` en `InfoScreen` y `UserFriendsScreen` (y fallo con `""`)
- **ID y Título**: `[BUG-84]` — `CircleAvatar(backgroundImage: NetworkImage(...))` sin `onBackgroundImageError` en `InfoScreen` y `UserFriendsScreen` (y fallo con `""`)
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/info_screen.dart:85-89, 112-116`, `lib/screens/social/user_friends_screen.dart:52-59`
- **Problema / Causa raíz**:
  1. En `InfoScreen`, `CircleAvatar` usa `NetworkImage('https://avatars.githubusercontent.com/...')` sin `onBackgroundImageError` ni fallback visual; sin conexión o con rate-limit de GitHub lanza excepción de imagen no controlada.
  2. En `UserFriendsScreen._buildUserAvatar` (líneas 52–59), solo comprueba `avatarUrl != null` (sin `.isNotEmpty`), de modo que un `avatar_url == ""` pasa `NetworkImage("")` provocando error inmediato de carga/codec, y tampoco define `onBackgroundImageError`.
- **Solución propuesta**: Validar `avatarUrl != null && avatarUrl.isNotEmpty`, añadir `onBackgroundImageError: (_, _) {}` o migrar a `CorpusNetworkImage` / `CachedNetworkImageProvider` con caché en disco.

### [BUG-85] — Captura silenciosa de errores (`catch (e)`) en `FriendsScreen` y `UserFriendsScreen` generando falsos estados vacíos
- **ID y Título**: `[BUG-85]` — Captura silenciosa de errores (`catch (e)`) en `FriendsScreen` y `UserFriendsScreen` generando falsos estados vacíos
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/social/friends_screen.dart:93-95, 115-117`, `lib/screens/social/user_friends_screen.dart:46-49`
- **Problema / Causa raíz**: `_loadRequests` (`friends_screen.dart:93-95`), `_loadFriends` (`115-117`) y `_loadData` (`user_friends_screen.dart:46-49`) capturan excepciones limpiando `_isLoading* = false` sin almacenar un `_error` (y en `FriendsScreen` sin siquiera `debugPrint(e)`). Ante cualquier fallo de red, la UI muestra `'Sin solicitudes pendientes'`, `'Todavía no tienes amigos en Corpus'` o `'@user aún no tiene amigos'`, sin botón de reintento ni `RefreshIndicator` en `UserFriendsScreen`.
- **Solución propuesta**: Añadir estado `String? _requestsError` / `_friendsError` / `_loadError`, registrar el fallo con `debugPrint`, y renderizar estado de error con botón `'Reintentar'` (como `NotificationsFeedScreen:380-408`).

### [BUG-86] — Desincronización optimista, falta de bloqueo anti doble-pulsación, IDs vacíos, `initialIndex` sin clamp y ausencia de estado invitado en `FriendsScreen`
- **ID y Título**: `[BUG-86]` — Desincronización optimista, falta de bloqueo anti doble-pulsación, IDs vacíos, `initialIndex` sin clamp y ausencia de estado invitado en `FriendsScreen`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/social/friends_screen.dart:53-62, 76-118, 178-262, 288-586`
- **Problema / Causa raíz**:
  1. `_sendRequest(targetId)` (178–184) añade `targetId` a `_sentOrAccepted`, pero nunca actualiza `_sentRequests` dejando desincronizada la pestaña `'Enviadas'`.
  2. `_sendRequest`, `_acceptRequest`, `_rejectRequest`, `_cancelSentRequest` y `_removeFriend` no registran IDs en vuelo (`_inFlightIds`) permitiendo doble ejecución concurrente; `_acceptRequest` muestra `'¡Ahora sois amigos!'` antes de recargar listas secuencialmente.
  3. Líneas 443 y 487 usan `?? ''`; si faltase el ID, enviar `''` produce error de sintaxis UUID en Postgres.
  4. Invitados ven listas vacías en lugar de `GuestLoginPrompt`.
  5. Escribir `'   '` deja `_searchController.text.isNotEmpty == true` (línea 332) mostrando `'No se encontraron usuarios'` sin buscar; `TabController(..., initialIndex: widget.initialIndex)` (línea 56) carece de `.clamp(0, 2)`.
- **Solución propuesta**: Mostrar `GuestLoginPrompt` cuando `_repo.currentUserId == null`; mantener `Set<String> _pendingActionIds`; deshabilitar botones si `requesterId.isEmpty` / `addresseeId.isEmpty`; usar `_searchController.text.trim().isNotEmpty` y `widget.initialIndex.clamp(0, 2)`.

### [BUG-87] — Navegación directa sin `CorpusRouter` en `UserFriendsScreen` (rompe sincronización de URL web y throttle)
- **ID y Título**: `[BUG-87]` — Navegación directa sin `CorpusRouter` en `UserFriendsScreen` (rompe sincronización de URL web y throttle)
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/social/user_friends_screen.dart:64, 118-123`, `lib/routes/tab_url_sync.dart:31-91`, `lib/routes/app_navigation_controller.dart:253-268`
- **Problema / Causa raíz**: `UserFriendsScreen` navega al perfil de un amigo con `Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: friendId)))` (líneas 118–123) en lugar de `context.pushProfile(userId: friendId)`. Al faltar `RouteSettings`, `TabUrlSyncObserver` (`deepRouteFromRouteSettings`) devuelve `null`, dejando congelada la URL web, saltándose el throttle de navegación y usando `BackButton` por defecto (línea 64) en vez de `AppNavigationController.instance.requestBack(context)`.
- **Solución propuesta**: Sustituir `Navigator.push` por `context.pushProfile(userId: friendId)` y usar `AppNavigationController.instance.requestBack(context)` en el `leading` del `AppBar`.

### [BUG-88] — `markAllRead()` sin `await`, doble-tap sin bloqueo en `_onNotificationTap` y carrera de paginación en `NotificationsFeedScreen`
- **ID y Título**: `[BUG-88]` — `markAllRead()` sin `await`, doble-tap sin bloqueo en `_onNotificationTap` y carrera de paginación en `NotificationsFeedScreen`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/social/notifications_feed_screen.dart:66-166, 168-219, 281`
- **Problema / Causa raíz**:
  1. Línea 113 pone `unreadNotificationsCount.value = 0;` y línea 114 llama `_repo.markAllRead();` sin `await`: al volver de segundo plano o fallar red, el badge remoto se restaura > 0.
  2. `_onNotificationTap` (190–210) ejecuta hasta 2 consultas secuenciales sin `_isNavigating` ni feedback cuando `nav == null`.
  3. Si se pulsa `'Reintentar'` (`_loadFirstPage`) mientras `loadMore()` sigue en vuelo, no se resetea `isLoadingMore = false` ni existe `_loadGen`, corrompiendo `_offset`/`hasMore`; falta `RefreshIndicator`.
  4. Línea 104 guarda `n['id'].toString()`, pero línea 281 consulta `_unreadAtOpen.contains(n['id'])` sin `.toString()`.
- **Solución propuesta**: Esperar `await _repo.markAllRead()`, envolver el `ListView` en `RefreshIndicator`, añadir `bool _isNavigating = false` + `SnackBar` si `nav == null`, introducir `int _requestGen = 0` en `_loadFirstPage`, y normalizar `n['id']?.toString()` en línea 281.

### [BUG-89] — `EdgeSwipeBackDetector` dispara múltiples retrocesos en un solo gesto y evalúa posición incorrecta
- **ID y Título**: `[BUG-89]` — `EdgeSwipeBackDetector` dispara múltiples retrocesos en un solo gesto y evalúa posición incorrecta
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/widgets/edge_swipe_back_detector.dart:22-35`
- **Problema / Causa raíz**: `GestureDetector` solo usa `onHorizontalDragUpdate` comprobando `details.globalPosition.dx < 20 && details.primaryDelta != null && details.primaryDelta! > 10`. Al dispararse en cada frame del arrastre sin flag de disparo único, un swipe rápido llama múltiples veces a `AppNavigationController.instance.requestBack(context)` haciendo pop de varias pantallas. Además, evaluar `globalPosition.dx < 20` en `update` (y no en `onHorizontalDragStart`) falla si el dedo ya superó `x = 20` en el primer frame rápido y genera falsos positivos al arrastrar desde el centro hacia el borde izquierdo y rebotar.
- **Solución propuesta**: Convertir `EdgeSwipeBackDetector` a `StatefulWidget` con `_startedAtEdge` (evaluado en `onHorizontalDragStart`) y `_triggered` (activado una sola vez en `update` y reseteado en `End`/`Cancel`).

### [BUG-90] — `HorizontalGameRow` dispara `onEndReached` repetidamente por frame, pierde estado al cambiar lista y omite `Key` en `GameCard`
- **ID y Título**: `[BUG-90]` — `HorizontalGameRow` dispara `onEndReached` repetidamente por frame, pierde estado al cambiar lista y omite `Key` en `GameCard`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/widgets/horizontal_game_row.dart:47-51, 70-78, 122-143`
- **Problema / Causa raíz**:
  1. `_onScroll()` (líneas 70-78) llama `widget.onEndReached!()` en cada notificación mientras `_scrollController.offset >= max - 80`, disparando decenas de peticiones paginadas duplicadas.
  2. `didUpdateWidget` (línea 47) solo comprueba `oldWidget.games.length != widget.games.length`; si el contenido cambia conservando longitud, las flechas de scroll no se recalculan.
  3. `GameCard` (línea 134) no recibe `key`, desincronizando `_GameCardState._isHovered` al actualizarse la lista.
- **Solución propuesta**: Guardar `double _lastNotifiedMaxExtent = -1;` para disparar `onEndReached()` una sola vez por umbral, comprobar `oldWidget.games != widget.games` en `didUpdateWidget`, y pasar `key: ValueKey(game.igdbId)` a `GameCard`.

### [BUG-91] — `ExploreBundleRow` usa `DateTime.parse` sin manejo de error (crash por `FormatException`)
- **ID y Título**: `[BUG-91]` — `ExploreBundleRow` usa `DateTime.parse` sin manejo de error (crash por `FormatException`)
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/widgets/explore_bundle_row.dart:170-188, 202-203`
- **Problema / Causa raíz**: `_timeRemaining` (línea 172) y `_timeColor` (línea 183) llaman a `DateTime.parse(endDateStr)` directamente (parseando dos veces la misma fecha por cada `build()`). Si `end_date` llega vacío `""` o malformado desde Supabase/API, lanza `FormatException` no capturada rompiendo todo el árbol de la pantalla.
- **Solución propuesta**: Reemplazar ambos métodos por un único helper `(String text, Color color) _computeRemaining(String? endDateStr)` usando `DateTime.tryParse(endDateStr)`.

### [BUG-92] — `FriendshipButton`: ausencia de `didUpdateWidget`, race condition en `_checkStatus` y falta de guardas/feedback
- **ID y Título**: `[BUG-92]` — `FriendshipButton`: ausencia de `didUpdateWidget`, race condition en `_checkStatus` y falta de guardas/feedback
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/widgets/friendship_button.dart:30-33, 35-138, 148-154`
- **Problema / Causa raíz**:
  1. `_FriendshipButtonState` solo llama `_checkStatus()` en `initState()` (línea 32) y no implementa `didUpdateWidget`: al reutilizar el widget con otro `targetUserId`, muestra el estado del usuario previo.
  2. `_checkStatus()` carece de token `_requestSeq`, permitiendo que una respuesta lenta sobreescriba el estado más reciente.
  3. `_sendRequest`, `_cancelRequest`, `_acceptRequest` y `_removeFriend` (líneas 77-138) no comprueban `if (_isProcessing || _myId.isEmpty) return;`, hacen cast no-nullable `res['status'] as String` (línea 59), silencian errores al usuario con solo `debugPrint`, y al cambiar a `_isProcessing` (líneas 148-154) colapsan el botón a `24x24` produciendo saltos de layout.
- **Solución propuesta**: Añadir `didUpdateWidget` + `int _checkSeq = 0`, guarda `if (_isProcessing || _myId.isEmpty) return;` en todas las mutaciones, `res['status'] as String? ?? ''`, `showCorpusSnackBar` en `catch` y ancho/alto mínimo estable durante `_isProcessing`.

### [BUG-93] — `shouldRepaint` incompleto en `_RadarPainter` y `_MilestoneBarPainter` + división por cero / `flex <= 0` en `MilestoneProgressBar`
- **ID y Título**: `[BUG-93]` — `shouldRepaint` incompleto en `_RadarPainter` y `_MilestoneBarPainter` + división por cero / `flex <= 0` en `MilestoneProgressBar`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/widgets/genre_radar_chart.dart:20-42, 189-190`, `lib/widgets/milestone_progress_bar.dart:50-58, 124-136, 156, 236-240`
- **Problema / Causa raíz**:
  1. `_RadarPainter.shouldRepaint` (líneas 189-190) solo evalúa `oldDelegate.stats != stats`, ignorando `fillColor`, `strokeColor`, `gridColor` y `labelStyle` al cambiar de tema/Style Pack; además `onTapUp` (líneas 29-41) compara contra `anchor` sin reflejar el desplazamiento de `origin` aplicado en líneas 177-182.
  2. `_MilestoneBarPainter.shouldRepaint` (líneas 236-240) ignora `oldDelegate.milestones != milestones`.
  3. En `MilestoneProgressBar` (líneas 50-58, 135-157), si algún hito tiene `target <= prevTarget` (`gap <= 0`), `Expanded(flex: gap)` falla con `flex < 0` y la línea 156 `(current - prevTarget) / gap` divide por cero (`NaN`/`Infinity`). Los casts `as int` (50, 51, 124, 135) tampoco son null-safe.
- **Solución propuesta**: Comparar todos los campos en ambos `shouldRepaint`, alinear hit-test con `origin` en `_RadarPainter`, validar `(m['target'] as int? ?? 0)` y usar `gap = (target - prevTarget).clamp(1, 1 << 30)`.

### [BUG-94] — `TypewriterText`, `P5rRansomTitle`, `VerticalTierLabel` y `CorpusHeroTitle`: timer no cancelado, `onComplete` sin `mounted`, corrupción UTF-16 y colores invisibles
- **ID y Título**: `[BUG-94]` — `TypewriterText`, `P5rRansomTitle`, `VerticalTierLabel` y `CorpusHeroTitle`: timer no cancelado, `onComplete` sin `mounted`, corrupción UTF-16 y colores invisibles
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/widgets/typewriter_text.dart:76, 84-86, 106-111, 165-222, 237-243, 258, 269-270, 280`, `lib/widgets/p5r_ransom_title.dart:31-32, 290-310`, `lib/widgets/vertical_tier_label.dart:28`, `lib/widgets/corpus_section_title.dart:245, 264, 285-291`
- **Problema / Causa raíz**:
  1. `TypewriterText` línea 84-86 llama `widget.onComplete?.call()` en `addPostFrameCallback` sin verificar `if (mounted)`.
  2. En `didUpdateWidget` (206-221), si el texto es igual y `widget.instant` cambia a `true`, NO cancela `_timer`, disparando incrementos y `onComplete` tardíos; en líneas 185 y 203 no reinicia `_cursorController.repeat(reverse: true)`.
  3. `TypewriterText` (106, 242, 270), `P5rRansomTitle` (`word[i]`, 303), `VerticalTierLabel` (`text[i]`, 28) y `_splitHeroVisible` (`corpus_section_title.dart:285-291`) indexan/cortan por código UTF-16 en lugar de grafemas (`Characters`), rompiendo emojis en `\uFFFD`.
  4. `P5rRansomTitle` línea 31-32: `''.split(RegExp(r'\s+'))` retorna `['']` renderizando filas vacías para strings en blanco.
  5. `TypewriterText` (258, 280) y `CorpusHeroTitle` (245, 264) usan `Colors.white` hardcodeado, invisible en modo claro.
- **Solución propuesta**: Comprobar `if (mounted)` en `addPostFrameCallback`, cancelar `_timer` cuando `widget.instant` es true, usar `package:characters` (`Characters`), comprobar `text.trim().isEmpty` en `P5rRansomTitle` y sustituir `Colors.white` por `Theme.of(context).colorScheme.onSurface`.

### [BUG-95] — `CorpusTabs` crash de altura infinita (`isScrollable: false`), `CorpusTextArea` ignora `minLines`, `CorpusSlider` clamp peligroso y `CorpusDropdown` destruye foco
- **ID y Título**: `[BUG-95]` — `CorpusTabs` crash de altura infinita (`isScrollable: false`), `CorpusTextArea` ignora `minLines`, `CorpusSlider` clamp peligroso y `CorpusDropdown` destruye foco
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/widgets/design/corpus_tabs.dart:131-148`, `lib/widgets/design/corpus_text_field.dart:66-69, 105-130`, `lib/widgets/design/corpus_slider.dart:60`, `lib/widgets/design/corpus_dropdown.dart:50-52`
- **Problema / Causa raíz**:
  1. `CorpusTabs` cuando `isScrollable == false` (131-148) usa `Row(crossAxisAlignment: CrossAxisAlignment.stretch)` sin `IntrinsicHeight` (a diferencia de la línea 110); dentro de `Column`/`ListView`, falla con `BoxConstraints forces an infinite height`.
  2. `CorpusTextArea` (105, 114, 121-129) recibe `minLines` (default `3`), pero ni `CorpusTextField` tiene parámetro `minLines` ni `CorpusTextArea` lo reenvía; además `CorpusTextField:66` no usa `corpusInputPrefixIcon(...)` (estiramiento de SVG en web) y línea 68 deja `onSuffixTap` activo estando `enabled == false`.
  3. `CorpusSlider:60` ejecuta `value.clamp(min, max)` antes de validar `min < max`, lanzando `ArgumentError`.
  4. `CorpusDropdown:51` usa `key: ValueKey<Object?>(value)` en `DropdownButtonFormField`, destruyendo `FormFieldState` y perdiendo foco/validación al cambiar valor.
- **Solución propuesta**: Envolver `isScrollable == false` de `CorpusTabs` en `IntrinsicHeight`; añadir `minLines`, `corpusInputPrefixIcon` y guarda `enabled ? onSuffixTap : null` en `CorpusTextField`; proteger `min >= max` en `CorpusSlider`; eliminar `ValueKey(value)` en `CorpusDropdown`.

### [BUG-96] — Errores de estado/tema/nulos en `lib/widgets/`: `MentionText` en dark mode, `FullScreenGallery` bordes/gestos, `GameCard.onReturn` sin `mounted`, estados disabled/hover y `NetworkImage` sin validar
- **ID y Título**: `[BUG-96]` — Errores de estado/tema/nulos en `lib/widgets/`: `MentionText` en dark mode, `FullScreenGallery` bordes/gestos, `GameCard.onReturn` sin `mounted`, estados disabled/hover y `NetworkImage` sin validar
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/widgets/mention_text.dart:27-30, 59-61`, `lib/widgets/corpus_primary_button.dart:48-70`, `lib/widgets/design/corpus_chip.dart:35-112`, `lib/widgets/design/corpus_button.dart:45-48, 100-109`, `lib/widgets/design/corpus_icon_button.dart:32, 60-63`, `lib/widgets/full_screen_gallery.dart:28-29, 81-108`, `lib/widgets/game_card.dart:137-139`, `lib/widgets/activity_story_ring.dart:35-38`, `lib/widgets/coop_badge.dart:50-62`
- **Problema / Causa raíz**:
  1. `MentionText` (27) con `style` sin `color` pasa `baseStyle` a `RichText` (59), que no hereda `DefaultTextStyle` (texto negro ilegible en tema oscuro).
  2. `CorpusPrimaryButton` (rama P5R) y `CorpusChip` ignoran visualmente `onPressed == null` / `onTap == null`; `CorpusButton` y `CorpusIconButton` no limpian `_hovered`/`_pressed` en `didUpdateWidget` al deshabilitarse.
  3. `FullScreenGallery` no valida `imageUrls.isEmpty` ni hace `initialIndex.clamp(...)`, carece de `SafeArea` para el botón cerrar, y el `GestureDetector(onTap: pop)` envuelve el `InteractiveViewer`.
  4. `GameCard:139` invoca `widget.onReturn()` tras `pushGameDetails` sin verificar `if (mounted)`.
  5. `ActivityStoryRing:35` y `CoopBadge:50` usan `NetworkImage(avatarUrl!)` sin verificar `.trim().isNotEmpty` ni manejar errores de carga.
- **Solución propuesta**: Combinar `DefaultTextStyle.of(context).style.merge(style)` en `MentionText`; aplicar opacidad/estilo disabled y reset de hover/press en `didUpdateWidget`; validar `imageUrls` y usar `SafeArea` + fondo separado en `FullScreenGallery`; comprobar `if (mounted) widget.onReturn();` en `GameCard`; migrar `ActivityStoryRing` y `CoopBadge` a `CorpusNetworkImage` / `CachedNetworkImageProvider` validando `isNotEmpty`.

### [BUG-97] — Uso inseguro de `Theme.of(context).extension<CorpusThemeExtension>()!` sin fallback en más de 55 archivos de pantallas y widgets
- **ID y Título**: `[BUG-97]` — Uso inseguro de `Theme.of(context).extension<CorpusThemeExtension>()!` sin fallback en más de 55 archivos de pantallas y widgets
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**:
  - `lib/screens/activity/activity_screen.dart:190, 556, 725, 896, 930`; `activity_story_viewer.dart:370, 456, 750, 904, 1063`; `grouped_post_details_screen.dart:434, 448, 461, 517, 560`; `review_details_screen.dart:373, 405, 432, 671, 713, 893, 935, 962, 1121, 1146`; `comment_composer.dart:133, 187, 339`; `comment_thread_section.dart:43, 144, 253, 361`; `post_action_bar.dart:52, 78`
  - `lib/screens/profile/widgets/add_game_to_shelf_sheet.dart:145`; `bulk_add_to_shelf_sheet.dart:235`; `profile_sidebar_info.dart:54, 138-140`; `lib/screens/my_games/collection_tab.dart:222, 559, 658`; `games_tab.dart:217, 314`; `groups_tab.dart:271, 311, 530, 716`; `group_detail_screen.dart:435`; `game_search_picker_sheet.dart:135`
  - `lib/screens/home/anticipated_games_section.dart:123-124, 315-317`; `hero_showcase.dart:652-654, 887-929`; `home_screen.dart:894-898, 1158-1160`; `lib/screens/settings/home_appearance_screen.dart:300-351`; `info_tab_appearance_screen.dart:186-236`; `integrations_screen.dart:321, 619`; `notifications_screen.dart:266-295, 330-362`; `lib/screens/auth/forgot_password_screen.dart:74`; `login_screen.dart:72`; `register_screen.dart:99`; `reset_password_screen.dart:88`
  - `lib/screens/appearance_screen.dart:166-168, 223-225, 235-237, 362-364, 376-378, 422-424, 473-475, 547`; `info_screen.dart:78-80, 157-159`; `main_screen.dart:385, 533`; `settings_screen.dart:397`; `friends_screen.dart:308-310`; `design_screen.dart:56`; `design_foundations_section.dart:13`
  - `lib/widgets/achievement_toast.dart:300`; `coop_badge.dart:39`; `corpus_primary_button.dart:39`; `corpus_section_title.dart:26, 100, 145, 182`; `level_progress_bar.dart:26, 55`; `p5r_styled_panel.dart:120`; y 16 archivos de `lib/widgets/design/` (`corpus_badge.dart:41`, `corpus_button.dart:52`, `corpus_card.dart:23`, `corpus_chip.dart:33`, `corpus_dialog.dart:48`, `corpus_dropdown.dart:42`, `corpus_empty_state.dart:30`, `corpus_icon_button.dart:36`, `corpus_list_tile.dart:30`, `corpus_loading.dart:21`, `corpus_section.dart:21`, `corpus_slider.dart:29`, `corpus_snackbar.dart:15`, `corpus_switch.dart:23`, `corpus_tabs.dart:34`, `corpus_text_field.dart:46`)
- **Problema / Causa raíz**: El operador force-unwrap (`!`) sobre `Theme.of(context).extension<CorpusThemeExtension>()` se repite en más de 90 invocaciones across pantallas y widgets (en contraste con `activity_screen.dart:222-223`, `game_card.dart:144`, `notifications_feed_screen.dart:275` y `main_screen.dart:908,1042` que usan `?.` con fallback). Si cualquier widget o pantalla se renderiza bajo un `ThemeData` de test (`TestWidgetsFlutterBinding`) o una ruta sin la extensión registrada, lanza `Null check operator used on a null value`.
- **Solución propuesta**: Definir `static CorpusThemeExtension of(BuildContext context)` en `CorpusThemeExtension` (o `extension CorpusThemeContext on BuildContext`) que retorne `Theme.of(context).extension<CorpusThemeExtension>() ?? CorpusThemeExtension.fromPack(StylePack.defaultPack())` y reemplazar todos los `!`.

### [BUG-98] — `resetAllGlobalState` omite `tabScrollToTopNotifiers` y `recordTabSwitch` puede quedar obsoleto o abortar tras 5 frames
- **ID y Título**: `[BUG-98]` — `resetAllGlobalState` omite `tabScrollToTopNotifiers` y `recordTabSwitch` puede quedar obsoleto o abortar tras 5 frames
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/globals.dart:55-58, 108-124`, `lib/routes/app_navigation_controller.dart:56-63, 599-630`
- **Problema / Causa raíz**:
  1. `resetAllGlobalState()` (`lib/globals.dart:108-124`) resetea todos los notificadores globales excepto `tabScrollToTopNotifiers` (L55-58).
  2. `recordTabSwitch` (`app_navigation_controller.dart:599-630`) reprograma un `addPostFrameCallback` hasta 5 veces si `_stacks[toTab]` está vacío; si tras 5 frames sigue vacío (L602-608), aborta dejando la URL de la pestaña anterior en el navegador. Además, si el usuario cambia rápido de pestaña o cierra sesión (`resetForSessionChange()`, L56-63) antes del siguiente frame, un callback con `retries == 0` no verifica si `toTab == currentTabIndexNotifier.value`.
- **Solución propuesta**: En `resetAllGlobalState()`, reiniciar también `tabScrollToTopNotifiers`; en `recordTabSwitch()`, verificar `if (toTab != currentTabIndexNotifier.value) return;` al ejecutarse el callback y sincronizar la URL raíz `AppRoutes.publicPathForTab(toTab)` como fallback tras 5 reintentos.

### [BUG-99] — `formatDateRelative` muestra `"hace 1 día"` desde las 12h y `formatDateRange` omite `.toLocal()`
- **ID y Título**: `[BUG-99]` — `formatDateRelative` muestra `"hace 1 día"` desde las 12h y `formatDateRange` omite `.toLocal()`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/utils/format_utils.dart:77-95, 104-115`
- **Problema / Causa raíz**:
  1. En L80, `final int days = (difference.inHours / 24).round();` redondea `12..23` horas (`0.5..0.96` días) a `1`, por lo que comentarios de hace 12 horas muestran `"hace 1 día"` en vez de `"hace 12 horas"` (y 36 horas muestran `"hace 2 días"`).
  2. En L107 y L110, `formatDateRange` parsea las fechas sin `.toLocal()`, a diferencia de `formatDateLong` (L49) y `formatDateShort` (L61), provocando discrepancias de fecha en husos horarios distintos a UTC.
- **Solución propuesta**: Usar `difference.inDays` (comparando primero `difference.inHours < 24`) en L80, y añadir `.toLocal()` en `formatDateRange` (L107 y L110).

### [BUG-100] — `GenreRadarCalculator.aggregate` ordena por `gameCount` contradiciendo su contrato de horas
- **ID y Título**: `[BUG-100]` — `GenreRadarCalculator.aggregate` ordena por `gameCount` contradiciendo su contrato de horas
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/utils/genre_radar_calculator.dart:20-59`
- **Problema / Causa raíz**: La documentación de `aggregate` (L20-21) indica `"Agrega horas por género... ordenados de mayor a menor horas"`, pero L57 ordena únicamente por `b.gameCount.compareTo(a.gameCount)` sin usar `totalHours` ni como criterio principal ni como desempate.
- **Solución propuesta**: Alinear ordenación y contrato: ordenar por `b.totalHours.compareTo(a.totalHours)` (con desempate por `b.gameCount.compareTo(a.gameCount)`), o actualizar el contrato si el criterio intencional es `gameCount` usando `totalHours` como desempate determinista.

### [BUG-101] — `IgdbConstants.resolveCategory` ignora `hasParentGame` y produce falsos positivos por subcadena (`'royal'`, `'golden'`)
- **ID y Título**: `[BUG-101]` — `IgdbConstants.resolveCategory` ignora `hasParentGame` y produce falsos positivos por subcadena (`'royal'`, `'golden'`)
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/utils/igdb_constants.dart:84-92, 107-151`
- **Problema / Causa raíz**:
  1. El parámetro `bool hasParentGame = false` (L110) no se utiliza en todo el cuerpo de `resolveCategory()` (L107-151).
  2. `_expandedKeywords` (L84-92) contiene `'royal'` y `'golden'` comprobados con `lowerTitle.contains(k)` (L132), clasificando erróneamente títulos base como *Golden Sun*, *GoldenEye 007*, *Battle Royale* o *Royal Crown* como categoría `10` (`Ed. Expandida`) si IGDB devuelve `0`/`null`.
- **Solución propuesta**: Utilizar `hasParentGame` para priorizar categoría `1` (DLC/Expansión) cuando no coincidan keywords de Remake/Remaster, y restringir `'royal'` y `'golden'` a coincidencias contextuales (sufijo de edición o `hasVersionParent == true`).

### [BUG-102] — `ImageCompressor.compressImage` duplica la lectura del archivo en fallback, conserva EXIF/GPS al fallar y rompe transparencias PNG
- **ID y Título**: `[BUG-102]` — `ImageCompressor.compressImage` duplica la lectura del archivo en fallback, conserva EXIF/GPS al fallar y rompe transparencias PNG
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/utils/image_compressor.dart:8-37`
- **Problema / Causa raíz**:
  1. L10 lee el archivo completo en `bytes`, pero en el `catch` (L35) vuelve a ejecutar `await file.readAsBytes()`, leyendo el archivo dos veces en memoria.
  2. En plataformas donde `flutter_image_compress` no tiene implementación (ej. Windows desktop) o falla, el fallback sube los bytes originales con metadatos EXIF/GPS intactos (contraviniendo SEC-08 documentado en L14).
  3. L22 fuerza `CompressFormat.jpeg` siempre, perdiendo transparencia alfa en PNGs.
- **Solución propuesta**: Devolver `bytes` directamente en el fallback sin re-leer `file.readAsBytes()`, detectar PNG con transparencia si aplica, y sanitizar/recodificar EXIF en plataformas sin soporte nativo de `flutter_image_compress`.

### [BUG-103] — Debounce global compartido y casts inseguros en `CorpusRouter` y `TabUrlSync`
- **ID y Título**: `[BUG-103]` — Debounce global compartido y casts inseguros en `CorpusRouter` y `TabUrlSync`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/routes/corpus_router.dart:191-394, 430-450`, `lib/routes/tab_url_sync.dart:21, 49-65`
- **Problema / Causa raíz**:
  1. `_lastPushTime` (`corpus_router.dart:430`) es una variable global de biblioteca compartida entre todas las pestañas. Cualquier segundo `pushRoute` antes de 600ms retorna `Future.value(null)` silenciosamente, bloqueando navegaciones legítimas entre pestañas o programáticas.
  2. 12 rutas de `CorpusRouter.route` hacen `settings.arguments! as ...` sin comprobación defensiva.
  3. `tab_url_sync.dart:21` accede a `Supabase.instance.client` sin guard (falla en widget tests donde Supabase no está inicializado), y L52-64 aceptan cadenas vacías `""` como IDs válidos produciendo URLs rotas (`/actividad/resena/`).
- **Solución propuesta**: Ligar el throttle a la ruta/contexto actual evitando bloquear pushes distintos, validar `arguments` con `is` devolviendo ruta de error controlada, proteger `_currentUserId()` en `tab_url_sync.dart` y verificar `.isNotEmpty` en `id`.

### [BUG-104] — `ensureCropperJsLoaded` ignora errores de carga CDN y `setWebPath` elimina query parameters de auth/deep-link
- **ID y Título**: `[BUG-104]` — `ensureCropperJsLoaded` ignora errores de carga CDN y `setWebPath` elimina query parameters de auth/deep-link
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/utils/web_js.dart:65-82, 134-164`, `web/index.html:163-198`
- **Problema / Causa raíz**:
  1. `__loadCropperJs()` en `web/index.html:184,194` resuelve `false` en caso de error de red/SRI, pero `ensureCropperJsLoaded()` (`web_js.dart:65-82`) retorna `Future<void>` ignorando el booleano devuelto por `promiseToFuture` y dejando continuar al flujo de recorte sin `window.Cropper`.
  2. `setWebPath()` (`web_js.dart:141-155`) solo preserva `?style=` / `?=`, descartando cualquier otro parámetro de consulta en `window.location.search` (por ejemplo `?code=` de OAuth PKCE si `TabUrlSync` corre antes de procesarse).
- **Solución propuesta**: Cambiar `ensureCropperJsLoaded()` para retornar `Future<bool>` comprobando `js_util.hasProperty(html.window, 'Cropper')`, y preservar parámetros de auth/OAuth en `setWebPath()` hasta que sean consumidos.

### [BUG-105] — `AuthGate` invoca `saveFcmToken()` en cada `resumed` de app y omite `deleteFcmToken()` al expirar/cerrar sesión
- **ID y Título**: `[BUG-105]` — `AuthGate` invoca `saveFcmToken()` en cada `resumed` de app y omite `deleteFcmToken()` al expirar/cerrar sesión
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/main.dart:233-241, 246-260, 299-307`
- **Problema / Causa raíz**:
  1. Al pasar la app a segundo plano (`paused`, L303-305) se limpia `_presenceChannel = null`, y al volver (`resumed`, L301-302) `_setupPresence()` vuelve a llamar `notifService.saveFcmToken()` (L259), disparando `FirebaseMessaging.getToken()` + `upsert` en `push_tokens` en cada cambio de app.
  2. En el cierre/expiración de sesión en `AuthGate` (L233-241) no se limpia el token FCM (solo se hace en `settings_screen.dart:380`), pudiendo quedar el dispositivo asociado al usuario anterior si la sesión caduca fuera de Ajustes.
- **Solución propuesta**: Separar el registro inicial de `saveFcmToken()` (una sola vez por `userId`) de la reconexión del canal de presencia en `resumed`, y desvincular/limpiar el token FCM al detectar transición de autenticado a `signedOut`.

### [BUG-106] — Ventana fija de 4 elementos en `ActivityRepository._mergeActivityItems` y mutación in-place de mapas de entrada
- **ID y Título**: `[BUG-106]` — Ventana fija de 4 elementos en `ActivityRepository._mergeActivityItems` y mutación in-place de mapas de entrada
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/activity_repository.dart:405-411, 808-871`
- **Problema / Causa raíz**:
  1. Línea 808 limita la búsqueda hacia atrás a `i >= merged.length - 4`. Si un usuario cambia el estado de 5 juegos diferentes en menos de 24h y luego reseña el primero, no se fusionan.
  2. Líneas 408-409 mutan in-place los mapas dentro de `reviewsById` (`rev['_current_post_id']`, `rev['_post']`), y líneas 827-835 mutan `prev` directamente; además, línea 832 sobrescribe `prevMeta['status']` con `null` si `item['metadata']` no trae `'status'`.
- **Solución propuesta**: Iterar mientras `prevDate` esté dentro de 24 horas (haciendo `break` temprano al superar 24h), clonar `reviewsById[id]` antes de mutar y asignar `status` solo si es no nulo.

### [BUG-107] — `NotificationsRepository.fetchNotificationsPage` con paginación por offset sin desempate ni manejo de desplazamiento
- **ID y Título**: `[BUG-107]` — `NotificationsRepository.fetchNotificationsPage` con paginación por offset sin desempate ni manejo de desplazamiento
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**: `lib/repositories/notifications_repository.dart:53-86`
- **Problema / Causa raíz**: Ordena únicamente por `.order('created_at', ascending: false)` sin desempate `.order('id', ascending: false)` y usa `.range(from, to)` por offset, produciendo duplicados o saltos cuando llegan notificaciones nuevas entre páginas o hay timestamps idénticos.
- **Solución propuesta**: Añadir `.order('id', ascending: false)` inmediatamente y evolucionar a cursor `(created_at, id)`.

### [BUG-108] — `NotificationsRepository.fetchReviewForNavigation` falla silenciosamente por casts `as Map<String, dynamic>?` y no inyecta `partners` ni `_post`
- **ID y Título**: `[BUG-108]` — `NotificationsRepository.fetchReviewForNavigation` falla silenciosamente por casts `as Map<String, dynamic>?` y no inyecta `partners` ni `_post`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/notifications_repository.dart:123-156`
- **Problema / Causa raíz**:
  1. Líneas 140-143: `reviewData.remove('users') as Map<String, dynamic>?` y `games` lanzan `TypeError` si el mapa es `Map<dynamic, dynamic>`, el `catch` en línea 150 lo traga y devuelve `null` rompiendo la navegación desde notificaciones.
  2. No llama a `injectPartners` ni carga `_post` (`PostStats`), dejando la reseña incompleta al abrir `ReviewDetailsScreen`.
- **Solución propuesta**: Normalizar `users`/`games` con `is Map ? Map<String, dynamic>.from(...) : {}` e inyectar partners/stats si la pantalla destino lo requiere.

### [BUG-109] — `ReviewRepository.deleteReviewForUser` sufre condición de carrera en doble lectura de `reviews` y `deleteReview` ignora silenciosamente usuario invitado
- **ID y Título**: `[BUG-109]` — `ReviewRepository.deleteReviewForUser` sufre condición de carrera en doble lectura de `reviews` y `deleteReview` ignora silenciosamente usuario invitado
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/review_repository.dart:955-1014, 1019-1033`
- **Problema / Causa raíz**:
  1. `deleteReviewForUser` consulta `reviews` para `(gameId, userId)` antes del borrado (líneas 957-962) para decidir `deletesUserGame`, borra imágenes de comentarios huérfanos, borra la reseña y vuelve a consultar `reviews` después (líneas 998-1002). Si se crea otra reseña concurrentemente en esa ventana, `deletesUserGame` habrá borrado imágenes compartidas erróneamente.
  2. `deleteReview` (líneas 1024-1025) devuelve `false` silenciosamente si `currentUser == null` (mismo valor que cuando quedan otras reseñas).
- **Solución propuesta**: Mover la limpieza de `user_games` e imágenes huérfanas a una transacción/RPC en PostgreSQL (o trigger `AFTER DELETE`) y lanzar `StateError` si `currentUser == null`.

### [BUG-110] — `ProfileRepository.fetchUserProfile` crea fallback sin `id` ni sanitización de `username`
- **ID y Título**: `[BUG-110]` — `ProfileRepository.fetchUserProfile` crea fallback sin `id` ni sanitización de `username`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/profile_repository.dart:100-113`
- **Problema / Causa raíz**: Si `insert` falla (por colisión de `username` único derivado de `email.split('@')[0]`, ya que no añade sufijo único ni sanitiza caracteres), el `catch` devuelve `{'username': defaultUsername}` omitiendo `'id': userId`. Cualquier consumidor (como `UserProfile.fromMap`) que espere `id` fallará con `TypeError`.
- **Solución propuesta**: Sanitizar `defaultUsername`, añadir sufijo aleatorio/determinista si colisiona o reintentar, e incluir siempre `'id': userId` en el mapa fallback.

### [BUG-111] — `ReviewRepository.fetchJournalPage` y `fetchJournalYears`: inconsistencia de zona horaria en filtro por año y falta de stats/partners
- **ID y Título**: `[BUG-111]` — `ReviewRepository.fetchJournalPage` y `fetchJournalYears`: inconsistencia de zona horaria en filtro por año y falta de stats/partners
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**: `lib/repositories/review_repository.dart:1492-1550`
- **Problema / Causa raíz**:
  1. `fetchJournalPage` filtra en UTC (`$year-01-01T00:00:00.000Z` a `$year-12-31T23:59:59.999Z`), mientras `fetchJournalYears` (línea 1542) toma `DateTime.parse(dateStr.toString()).year`. Dependiendo del huso horario, un registro de fin/inicio de año puede aparecer en el selector de años y desaparecer al filtrar la página.
  2. `fetchJournalYears` usa `try { DateTime.parse(...) } catch (_) {}` silencioso en vez de `DateTime.tryParse`.
  3. `fetchJournalPage` no inyecta `_post` (`_injectReviewPostStats`) ni `partners` (a diferencia de `fetchProfileReviewsPage:1487`).
- **Solución propuesta**: Usar un RPC en PostgreSQL con `EXTRACT(YEAR FROM ...)` para `fetchJournalYears`, unificar límites UTC/fecha y usar `DateTime.tryParse`.

### [BUG-112] — Condiciones de carrera en `CollectionRepository.setPlatformsForGame`, `GameGroupRepository` (`sort_order`) y `ActivityRepository.toggleLike`
- **ID y Título**: `[BUG-112]` — Condiciones de carrera en `CollectionRepository.setPlatformsForGame`, `GameGroupRepository` (`sort_order`) y `ActivityRepository.toggleLike`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**: `lib/repositories/collection_repository.dart:102-132`, `lib/repositories/game_group_repository.dart:104, 146-158, 258, 281-293`, `lib/repositories/activity_repository.dart:510-527`
- **Problema / Causa raíz**:
  1. `setPlatformsForGame` lee las plataformas actuales y luego lanza `upsert` + N `delete` concurrentes; dos pulsaciones rápidas provocan race condition y estado parcial si una petición falla.
  2. `createGroup` y `addGameToGroup` calculan `max(sort_order) + 1` en cliente antes de insertar; llamadas simultáneas obtienen el mismo `sort_order`. Además, si `sort_order` en BD fuera `null`, `(null ?? 0) + 1 = 1` colisionaría con el segundo elemento.
  3. `toggleLike` usa `.insert(...)` sin `ignoreDuplicates` ni manejo de error `23505`; un doble toque o estado optimista desincronizado lanza excepción de clave duplicada.
- **Solución propuesta**: Mover `setPlatformsForGame` a una RPC transaccional (o `inFilter` para deletes), calcular `sort_order` en trigger/RPC `BEFORE INSERT`, y usar `.upsert(..., onConflict: 'user_id,post_id', ignoreDuplicates: true)` en `toggleLike`.

### [BUG-113] — Silenciamiento de errores en mutaciones y lecturas críticas de repositorios y modelos
- **ID y Título**: `[BUG-113]` — Silenciamiento de errores en mutaciones y lecturas críticas de repositorios y modelos
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/notifications_repository.dart:101-119`, `lib/repositories/activity_repository.dart:152-156, 193-195, 315-319, 356-360, 429-432, 453-456`, `lib/repositories/game_group_repository.dart:234-249`, `lib/repositories/review_repository.dart:417-419, 439-441, 1268-1285, 1298-1358`, `lib/models/game.dart:271, 286`, `lib/models/game_status.dart:94`
- **Problema / Causa raíz**:
  1. `markAllRead` y `markRead` devuelven `Future<void>` y tragan errores en `catch`, desincronizando el badge optimista.
  2. `upsertGame` y `ensureGameInCatalog` tragan errores y dejan continuar a `saveReview` / `addGameToGroup`, provocando fallos tardíos de FK (`23503`).
  3. `uploadImages` silencia errores por archivo individual y devuelve solo las imágenes que no fallaron.
  4. `fetchPostStats`/`fetchReviewPostStats` y `fetchFriendsForCoopPicker` devuelven `{}`/`[]` en error sin distinguir "sin datos" de "fallo de red".
  5. `refreshStashReviews` no captura errores de `functions.invoke` y verifica `status != 200`, mientras `refreshStashStats` captura el invoke pero no verifica `status != 200` ni la relectura.
- **Solución propuesta**: Propagar errores en mutaciones (`markRead`, `markAllRead`, `upsertGame`, `ensureGameInCatalog`, `uploadImages`), unificar manejo de errores en `refreshStash*`, y registrar en `debugPrint` los `catch (_)` de `Game._parse*` y `GameStatus.fromStringOrDefault`.

### [BUG-114] — Falta de guardas de usuario invitado (`guest`) y validación de sesión en repositorios
- **ID y Título**: `[BUG-114]` — Falta de guardas de usuario invitado (`guest`) y validación de sesión en repositorios
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/notifications_repository.dart:101-119`, `lib/repositories/achievements_repository.dart:39`, `lib/repositories/collection_repository.dart:42-155`, `lib/repositories/game_group_repository.dart:98-315`, `lib/repositories/activity_repository.dart:510-571`, `lib/repositories/review_repository.dart:448-1014`
- **Problema / Causa raíz**: Varios repositorios asumen `userId` válido y no comprueban `_client.auth.currentUser != null` ni `userId.isNotEmpty` antes de enviar mutaciones o consultas personales (ej. `NotificationsRepository.markAllRead` / `markRead`, a diferencia de `fetchNotificationsPage` y `fetchUnreadCount`). Si un usuario invitado o con sesión expirada dispara una acción, falla con error crudo de PostgREST/RLS.
- **Solución propuesta**: Centralizar una comprobación `requireAuthUserId()` en repositorios para mutaciones y retornar vacío temprano en lecturas opcionales de invitado.

### [BUG-115] — `GameGroupRepository.updateGroup` falla con HTTP 400 si no recibe campos a actualizar y no permite limpiar `coverGameId`
- **ID y Título**: `[BUG-115]` — `GameGroupRepository.updateGroup` falla con HTTP 400 si no recibe campos a actualizar y no permite limpiar `coverGameId`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/game_group_repository.dart:160-185`, `lib/models/game_group.dart:154-162`
- **Problema / Causa raíz**: Si todos los parámetros opcionales de `updateGroup` son `null`, `updates` queda `{}` y `.update({})` provoca error 400 en PostgREST. Además, `if (coverGameId != null) updates['cover_game_id'] = coverGameId;` impide restablecer `cover_game_id` a `null` tanto en `updateGroup` como en `GameGroup.toUpdateMap()`.
- **Solución propuesta**: Añadir parámetro `bool clearCover = false`, retornar el estado actual o lanzar `ArgumentError` si `updates.isEmpty`, y soportar limpiar `cover_game_id: null`.

### [BUG-116] — Asimetría entre `Game.fromMap` / `Game.toMap`, pérdida de `collection.id`/`franchise.id` y de `is_steam_only: false`
- **ID y Título**: `[BUG-116]` — Asimetría entre `Game.fromMap` / `Game.toMap`, pérdida de `collection.id`/`franchise.id` y de `is_steam_only: false`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**: `lib/models/game.dart:189-232, 254, 273, 298-354`, `lib/repositories/review_repository.dart:361-388`
- **Problema / Causa raíz**:
  1. `Game.toMap()` serializa `collection` como `String` y `franchises` como `List<String>`. Al pasar `game.toMap()` a `ReviewRepository.upsertGame`, las líneas 369-388 pierden los `id` de colección y franquicia que venían de IGDB.
  2. `Game.toMap()` omite `is_steam_only` cuando es `false` (línea 209); al combinar mapas `{...a.toMap(), ...b.toMap()}`, un `true` previo no se limpia.
  3. `Game._parseStringList` (línea 254): si la lista contiene `null`, `e.toString()` genera `"null"`, que pasa `s.isNotEmpty`; en línea 273, `"   "` devuelve `["   "]`.
  4. `Game._parseInvolvedCompanies` (línea 299) no soporta recibir un string JSON codificado.
- **Solución propuesta**: Filtrar `e == null` y recortar espacios en `_parseStringList`, incluir `'is_steam_only': isSteamOnly`, soportar JSON string en `_parseInvolvedCompanies` y preservar IDs en `upsertGame`.

### [BUG-117] — Extensión y Content-Type incorrecto al subir imágenes comprimidas (JPEG guardado como `.png`/`.heic`/sin extensión)
- **ID y Título**: `[BUG-117]` — Extensión y Content-Type incorrecto al subir imágenes comprimidas (JPEG guardado como `.png`/`.heic`/sin extensión)
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/activity_repository.dart:541-546`, `lib/repositories/review_repository.dart:430-435`, `lib/screens/profile/edit_profile_screen.dart:209-214, 245`, `lib/utils/image_compressor.dart:22`
- **Problema / Causa raíz**: `ImageCompressor.compressImage` convierte siempre a `CompressFormat.jpeg` (salvo fallo en `catch`, que devuelve bytes originales). Sin embargo, `submitComment`, `uploadImages` y `EditProfileScreen._pickImage` conservan la extensión de `file.name.split('.').last`: una foto `.png`, `.webp`, `.heic` o un nombre sin punto (`"photo"` -> `".photo"`) se sube con bytes JPEG bajo extensión y `contentType: 'image/png'` erróneos en Supabase Storage. Además, `Random().nextInt(1000)` tiene riesgo de colisión en subidas en paralelo.
- **Solución propuesta**: Hacer que `ImageCompressor` devuelva bytes + extensión/`contentType` real (`jpg`/`image/jpeg` cuando comprime a JPEG), y usar un UUID o contador + timestamp en el nombre de archivo.

### [BUG-118] — Rama muerta en `IGDBService.searchGames`: `sortClause.contains('rating')` intercepta `aggregated_rating`
- **ID y Título**: `[BUG-118]` — Rama muerta en `IGDBService.searchGames`: `sortClause.contains('rating')` intercepta `aggregated_rating`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/igdb_service.dart:198-211`
- **Problema / Causa raíz**: En la línea 205, `else if (sortClause.contains('rating') && sortClause.contains('desc'))` evalúa `true` para `'sort aggregated_rating desc;'` porque `'aggregated_rating'` contiene la subcadena `'rating'`. Como resultado, la rama `else if (sortClause.contains('aggregated_rating') ...)` de las líneas 207-210 es código inalcanzable y ordena mal excluyendo juegos con `aggregated_rating = null`.
- **Solución propuesta**: Comprobar `aggregated_rating` **antes** que `rating`, o usar `sortBy == 'aggregated_rating'` / `RegExp(r'\brating\b')` en lugar de `.contains('rating')`.

### [BUG-119] — `IGDBService.getGamesBySteamIds`: sobrescritura arbitraria de IDs duplicados, fallo total en `getGamesByIdsFull` y `int.parse` sin guardia
- **ID y Título**: `[BUG-119]` — `IGDBService.getGamesBySteamIds`: sobrescritura arbitraria de IDs duplicados, fallo total en `getGamesByIdsFull` y `int.parse` sin guardia
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/igdb_service.dart:305-309, 322-326, 668-752, 756-796`
- **Problema / Causa raíz**:
  1. `steamAppIds` no se deduplica antes de paginar en chunks de 50 (línea 682).
  2. Un Steam AppID puede devolver múltiples filas en `external_games`, pero la línea 704 hace `steamIdToIgdbId[uid] = ...` sobrescribiendo con la última fila recibida arbitrariamente, y `int.parse(gameId.toString())` (línea 706) puede lanzar `FormatException`.
  3. `getGamesByIdsFull` (línea 770) no captura errores por lote: un fallo transitorio en el último lote aborta toda la importación de Steam. Además en líneas 305-309 y 322-326 los `else throw Exception` nunca se alcanzan porque `_postQuery` lanza ante status != 200.
- **Solución propuesta**: Deduplicar `steamAppIds.toSet().toList()`, usar `int.tryParse`, `putIfAbsent`, y envolver cada batch de `getGamesByIdsFull` en `try/catch` registrando fallos parciales.

### [BUG-120] — `ImportService`: pérdida de decimales con coma europea, pérdida de caracteres Windows-1252 y `fixEncoding` roto con emojis
- **ID y Título**: `[BUG-120]` — `ImportService`: pérdida de decimales con coma europea, pérdida de caracteres Windows-1252 y `fixEncoding` roto con emojis
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/import_service.dart:54-65, 107-136, 163-180`
- **Problema / Causa raíz**:
  1. `ImportService.fixEncoding` (líneas 54-65) falla cuando una cadena mezcla mojibake con emojis/caracteres `> 255` (`latin1.encode` lanza `ArgumentError` y el `catch (_)` devuelve la cadena rota), y puede intentar decodificar palabras portuguesas válidas con `Ã`/`Â`, divergiendo de `StashJsonToCsvConverter.fixEncoding`.
  2. `double.tryParse(rawRating)` (línea 109) y `double.tryParse(rawPlayTimeHours)` (línea 133) no reemplazan `,` por `.`, descartando notas/horas regionales (`"8,5"`).
  3. `parseCsv` decodifica con `utf8.decode(fileBytes, allowMalformed: true)` (línea 164): los CSVs exportados por Excel en ANSI/Windows-1252 pierden todas las tildes/ñ convirtiéndolas en `\uFFFD`.
  4. Si ningún header coincide con `title`/`name`, `titleIdx` cae a `0` aunque la columna 0 sea `id` o `status` (línea 180).
- **Solución propuesta**: Reutilizar `StashJsonToCsvConverter.fixEncoding`; normalizar `,` a `.` en floats; detectar UTF-8 inválido y usar fallback `latin1`/`windows-1252`; mapear más alias o lanzar error descriptivo si falta columna de título.

### [BUG-121] — `_WebStylePackMusicBackend`: listeners globales en `document` permanentes, `resume()` reproduce audio detenido tras `stop()` y `Future` sin capturar
- **ID y Título**: `[BUG-121]` — `_WebStylePackMusicBackend`: listeners globales en `document` permanentes, `resume()` reproduce audio detenido tras `stop()` y `Future` sin capturar
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/style_pack_music_backend_web.dart:19-57, 70-127`
- **Problema / Causa raíz**:
  1. `init()` (línea 22) registra 3 listeners globales en `web.document` (`pointerdown`, `keydown`, `touchstart`) incluso cuando no hay música que reproducir. Al pulsar cualquier tecla o clic en la app, `onUserGesture` (líneas 42-50) ve `_audio!.paused == true` y llama a `resume()` sobre un `<audio>` sin `src`, falla en `play()` (línea 121), vuelve a registrar los listeners en `catch` (línea 124) y se repite en cada interacción de por vida.
  2. `stop()` (líneas 101-109) no llama a `_removeUnlockListeners()` ni limpia `audio.src`, así que el siguiente clic reactiva la música detenida vía `resume()`.
  3. `onUserGesture` invoca `playAsset(asset)` (línea 46) sin `await` ni `catchError`.
  4. `playAsset` (línea 73) antepone `'assets/'` sin verificar si `assetPath` ya empieza por `'assets/'`.
- **Solución propuesta**: Registrar unlock listeners solo tras fallo por autoplay en `playAsset`; en `stop()` llamar `_removeUnlockListeners()` y limpiar `audio.src`; comprobar `_currentSrc != null` y añadir `.catchError(...)` en `onUserGesture`.

### [BUG-122] — Posible `RangeError` en `CommentThreadSection` (`displayName[0]`) y `NoSuchMethodError` por `gameData['cover']?['image_id']`
- **ID y Título**: `[BUG-122]` — Posible `RangeError` en `CommentThreadSection` (`displayName[0]`) y `NoSuchMethodError` por `gameData['cover']?['image_id']`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/activity/widgets/comment_thread_section.dart:111-116, 135-139, 167-168, 345-349`, `lib/screens/activity/widgets/comment_composer.dart:321-325, 342-347`
- **Problema / Causa raíz**:
  1. En `comment_thread_section.dart:135-139, 168`, si `display_name` está vacío y `username` es `""`, `displayName` resulta `""` y `displayName[0].toUpperCase()` lanza `RangeError`.
  2. En `comment_thread_section.dart:347-348` y `comment_composer.dart:323-324`, `gameData['cover']?['image_id']` lanza `NoSuchMethodError` si `gameData['cover']` es un `int` (ID IGDB sin expandir) en lugar de `Map`. Además en `comment_composer.dart:344` `NetworkImage(coverUrl)` no tiene `onError`.
  3. En `_confirmDelete` (`comment_thread_section.dart:111-115`) falta comprobar `context.mounted` tras `await showDialog` y verificar `comment['id'] is String`.
- **Solución propuesta**: Usar `displayName.trim().isNotEmpty ? displayName.trim()[0].toUpperCase() : '?'` con fallback `'Usuario'`; comprobar `cover is Map`; usar `CorpusNetworkImage` y verificar `context.mounted && comment['id'] is String`.

### [BUG-123] — `ActivityFormatters.displayName` devuelve `""` si `display_name == ""`, y `formatRelativeDate` trata fechas futuras como `'Ahora mismo'`
- **ID y Título**: `[BUG-123]` — `ActivityFormatters.displayName` devuelve `""` si `display_name == ""`, y `formatRelativeDate` trata fechas futuras como `'Ahora mismo'`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/activity/activity_formatters.dart:9-36, 125-129`
- **Problema / Causa raíz**: `displayName` usa `userData['display_name'] as String? ?? ...` sin verificar `.trim().isNotEmpty`, devolviendo `""` si el usuario borró su `display_name`. En `formatRelativeDate`, `if (diff.inMinutes < 1)` retorna `'Ahora mismo'` para cualquier fecha futura (`diff.isNegative`), y usa `try { DateTime.parse } catch (_) {}` silencioso.
- **Solución propuesta**: Validar `trim().isNotEmpty` secuencialmente sobre `display_name` y `username` antes de retornar `'Usuario'`; reemplazar `try/catch (_)` por `DateTime.tryParse` y manejar `diff.isNegative || diff.inMinutes < 1`.

### [BUG-124] — Overlay de `GestureDetector` y `Focus` en `ActivityStoryViewer` interceptan teclas de cursor del `TextField` y taps sobre contenido
- **ID y Título**: `[BUG-124]` — Overlay de `GestureDetector` y `Focus` en `ActivityStoryViewer` interceptan teclas de cursor del `TextField` y taps sobre contenido
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/activity/activity_story_viewer.dart:184-192, 465-478, 554-656`
- **Problema / Causa raíz**:
  1. El `Focus(autofocus: true, onKeyEvent: ...)` raíz (L465-478) captura `arrowLeft`/`arrowRight` incluso cuando `_commentFocusNode.hasFocus` es `true`, impidiendo mover el cursor en el `TextField` de comentarios.
  2. El `GestureDetector` con tercios izquierda/centro/derecha (L609-655) está apilado **encima** del `SingleChildScrollView` en el `Stack` (L554-656), interceptando taps sobre carátulas de juegos o bordes del botón `"Ver reseña completa"`.
  3. `markStoriesViewed` (L184-192) silencia fallos con `.catchError((_) {})` y muta `viewedStoryIdsNotifier` en `addPostFrameCallback` sin verificar `mounted`.
- **Solución propuesta**: Ignorar eventos de teclado en L468 cuando `_commentFocusNode.hasFocus` sea `true`, colocar el `GestureDetector` detrás de los widgets interactivos centrales y comprobar `if (mounted)` en `addPostFrameCallback`.

### [BUG-125] — Errores de layout/tipos en `ReviewDetailsScreen`, `GroupedPostDetailsScreen` y `ActivityScreen` (`280px` en `140px`, `@\w+`, casts y botón Share)
- **ID y Título**: `[BUG-125]` — Errores de layout/tipos en `ReviewDetailsScreen`, `GroupedPostDetailsScreen` y `ActivityScreen` (`280px` en `140px`, `@\w+`, casts y botón Share)
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/activity/review_details_screen.dart:142-145, 163-166, 233, 437, 492-499, 543, 550, 868-898, 938`, `lib/screens/activity/grouped_post_details_screen.dart:101-129, 192-199, 213-216`, `lib/screens/activity/activity_screen.dart:811, 898, 932`
- **Problema / Causa raíz**:
  1. En `review_details_screen.dart:868-898`, cuando `isDesktop == true`, `SizedBox(height: 140)` recorta las imágenes de `CorpusNetworkImage(height: 280)` a la mitad.
  2. En `review_details_screen.dart:437, 543, 550`, ignora `display_name` y `_currentReviewData['users']` tras editar; en líneas 492-499, el botón `Share` muestra `'Compartir próximamente'`.
  3. `RegExp(r'^@\w+\s*')` (`review_details_screen.dart:143,164`, `grouped_post_details_screen.dart:193,214`) rompe usernames con `.` o `-`, borra menciones manuales y activa `_replyToUsername` aunque `comment['id']` sea `null`.
  4. `grouped_post_details_screen.dart:101-129` (`_loadPostItems()`) falla silenciosamente sin estado de error ni reintento.
  5. Casts directos `imageUrls[idx] as String`, `(review!['play_time_hours'] as num)` y `e['id'] as String`.
- **Solución propuesta**: Ajustar `SizedBox(height: isDesktop ? 280 : 140)`, leer `display_name` desde `_currentReviewData['users'] ?? widget.userData`, ocultar `Share` hasta implementarlo, usar `_replyPrefix` exacto verificando `comment['id'] is String`, añadir estado de error en `GroupedPostDetailsScreen` y sanitizar casts.

### [BUG-126] — Desbordamiento/salto de pestaña activa en `GameDetailsScreen` si `hasMedia` cambia tras enriquecer
- **ID y Título**: `[BUG-126]` — Desbordamiento/salto de pestaña activa en `GameDetailsScreen` si `hasMedia` cambia tras enriquecer
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/library/game_details_screen.dart:40, 646-703`
- **Problema / Causa raíz**: `_selectedMainTabIndex` es un `int` posicional (`0..N`) cuyos índices (`mediaTabIdx`, `relatedTabIdx`, `linksTabIdx`) se recalculan dinámicamente (`647-652`) según `hasMedia` y `hasLinks`. Si el usuario pulsa "Relacionado" (`_selectedMainTabIndex = 2`) antes de llegar screenshots/videos de `enrichGameData`, al llegar media `relatedTabIdx` pasa a `3` y la pantalla cambia silenciosamente de pestaña.
- **Solución propuesta**: Reemplazar `int _selectedMainTabIndex` por un `enum _GameDetailsTab { info, community, media, related, links }` con fallback a `_GameDetailsTab.info`.

### [BUG-127] — `ReviewModal`: `applyStatusChange` pisa `'story'` a `'none'`, falta de validaciones en formulario, sliders sin clamp y errores no capturados
- **ID y Título**: `[BUG-127]` — `ReviewModal`: `applyStatusChange` pisa `'story'` a `'none'`, falta de validaciones en formulario, sliders sin clamp y errores no capturados
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/library/review_modal.dart:208-210, 268-283, 322-330, 604-615, 651-659, 764-817, 830, 883-886, 1012, 1474, 1679-1707, 1730-1783`
- **Problema / Causa raíz**:
  1. `reviewCompletionType` arranca en `'story'` (208–210), pero `applyStatusChange` (329) siempre lo sobrescribe a `'none'` al pulsar `'beaten'`, o borra el valor previo en edición.
  2. `_pickImages` (268–283) carece de `try/catch`; `Slider` (830, 1012, 1474) carece de `.clamp(...)` arriesgando `AssertionError`; no valida `playedFrom <= playedUntil`, horas negativas ni `replayNumber <= 0`.
  3. En desktop con `wishlist`/`to_play` (1679–1707), ambas columnas del `Row` renderizan vacío; `CircleAvatar` de amigos (607, 654) usa `NetworkImage` sin `onBackgroundImageError`; `widget.onSave(...)` (1732) carece de `try/finally` dejando `isLocalSaving` bloqueado ante excepciones.
- **Solución propuesta**: Preservar `reviewCompletionType` válido al cambiar a `'beaten'`, añadir `try/catch` en `_pickImages` y `try/finally` en `onSave`, aplicar `.clamp(...)` y validaciones de fechas/horas/replays, y usar `CorpusNetworkImage` en avatares.

### [BUG-128] — Casts inseguros, `catch (_)` vacíos y manejo de errores deficiente en sub-tabs de `GameDetails`, `GroupGamesScreen` y `FilterOptionScreen`
- **ID y Título**: `[BUG-128]` — Casts inseguros, `catch (_)` vacíos y manejo de errores deficiente en sub-tabs de `GameDetails`, `GroupGamesScreen` y `FilterOptionScreen`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/library/game_details/game_links_tab.dart:241, 255-258, 270, 324, 330`, `lib/screens/library/game_details/game_related_tab.dart:81-83, 120-123, 193`, `lib/screens/library/game_details/game_info_tab.dart:243-245, 640, 700-720`, `lib/screens/library/game_details/game_stash_tab.dart:74-77`, `lib/screens/library/game_details/game_reviews_card.dart:192-199, 261-266`, `lib/screens/library/group_games_screen.dart:60, 74`, `lib/screens/library/filter_option_screen.dart:52-53, 140, 198`
- **Problema / Causa raíz**:
  1. `game_links_tab.dart:255-258` usa `try { Uri.parse(...); } catch (_) {}` y si `link['url']` es `null` abre `'null'`.
  2. `game_related_tab.dart:121` castea `(g['first_release_date'] as int)` y línea 193 imprime `'null'`.
  3. `game_info_tab.dart:243-245` castea conteos como `as int?`, línea 640 llama `.toString()` sobre mapas en `platformsList` y líneas 700-720 muestran sección `'hltb'` con `'--'` aunque `timeToBeat == null`.
  4. `game_stash_tab.dart:74-77` castea `(review['rating'] ?? 0).toDouble()` sin validar `num`.
  5. `game_reviews_card.dart:192-199` abre `ReviewDetailsScreen` con `review.id.isEmpty` y líneas 261-266 tiñen PNGs de plataforma con `color: pColor`.
  6. `group_games_screen.dart:60, 74` expone `e.toString()` sin reintento; `filter_option_screen.dart:140` omite `syncBrowserHistoryAfterProgrammaticPop()`.
- **Solución propuesta**: Reemplazar casts por parsing seguro (`num`/`tryParse`), usar `Uri.tryParse`, ocultar `'hltb'` si `timeToBeat == null`, bloquear tap si `review.id.isEmpty`, quitar `color: pColor`, añadir reintento en `GroupGamesScreen` y sincronizar historial en `FilterOptionScreen`.

### [BUG-129] — `GameDetailsController.fetchTimeToBeat` sin `try/catch` y desajuste `remake_of`/`remaster_of` vs `remakes`/`remasters`
- **ID y Título**: `[BUG-129]` — `GameDetailsController.fetchTimeToBeat` sin `try/catch` y desajuste `remake_of`/`remaster_of` vs `remakes`/`remasters`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/library/game_details/game_details_controller.dart:121-127, 323-358, 424, 452, 516-517`, `lib/services/igdb_service.dart:333`
- **Problema / Causa raíz**:
  1. `fetchTimeToBeat()` (323–358) es lanzado en `init()` (121–127) dentro de `Future.wait` sin `try/catch`, generando excepciones asíncronas no manejadas si `SharedPreferences` o `DuracionDeService` fallan.
  2. `enrichGameData` (516–517) busca `game['remake_of']` y `game['remaster_of']`, pero `IGDBService.getGameById` solicita `remakes, remasters`, por lo que nunca llegan en `enrichedData`. Además `452` sombrea `this.game` y `424` pasa `currentCoverUrl: null` al usar la caché en RAM aunque `this.game.coverUrl` exista.
- **Solución propuesta**: Envolver `fetchTimeToBeat()` en `try/catch`, pasar `currentCoverUrl: this.game.coverUrl` en `424`, renombrar la variable local en `452` a `igdbGame` y alinear los campos `remakes`/`remasters`.

### [BUG-130] — Callbacks `.then(...)` tras navegación sin comprobar `mounted` disparan recargas sobre pantallas desmontadas de `profile/`
- **ID y Título**: `[BUG-130]` — Callbacks `.then(...)` tras navegación sin comprobar `mounted` disparan recargas sobre pantallas desmontadas de `profile/`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/profile_screen.dart:328-330, 451, 608, 741-743, 1044`, `lib/screens/profile/achievements_screen.dart:596-598`, `lib/screens/profile/profile_achievements_tab.dart:1050`, `lib/screens/profile/edit_profile_screen.dart:1029-1033`, `lib/screens/profile/profile_games_grid_tab.dart:281-297`
- **Problema / Causa raíz**: Al volver de rutas empujadas, los `.then(...)` llaman a `_controller.fetchProfileData()`, `_controller.load()`, `_fetchAchievements()`, `_refreshHallOfFame()` y `setState(() { _filters = result; })` (`profile_games_grid_tab.dart:292-296`) sin comprobar `if (!mounted) return;`, arriesgando `setState() called after dispose()` y peticiones inútiles tras cerrar sesión o cambiar de pestaña.
- **Solución propuesta**: Añadir `if (!mounted) return;` antes de `setState`, `_refresh()` y las recargas en todos los puntos indicados.

### [BUG-131] — Excepciones asíncronas no capturadas, re-entrancia y `catch` silencioso en `_pickImage`, borrado HOF y `_WebCropperPage`
- **ID y Título**: `[BUG-131]` — Excepciones asíncronas no capturadas, re-entrancia y `catch` silencioso en `_pickImage`, borrado HOF y `_WebCropperPage`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/edit_profile_screen.dart:138, 153-227, 1079-1090, 1178-1193`
- **Problema / Causa raíz**:
  1. `_pickImage` (153–227) carece de `try/catch` y guard `_isPickingImage` ante doble toque o denegación de permisos/fallo de `ensureCropperJsLoaded()`.
  2. El borrado en `_buildHallOfFameEditor` (1079–1090) hace `delete()` sin `try/catch`, sin guard de doble tap y sin comprobar `mounted` antes de `_refreshHallOfFame()`.
  3. `_WebCropperPage` (1187–1191) tiene `catch (e)` silencioso sin feedback; `_refreshHallOfFame` (138) castea `row['pin_order'] as int` sin nulabilidad.
- **Solución propuesta**: Envolver `_pickImage`, borrado HOF y `widget.crop()` en `try/catch` con `SnackBar` de error y guard booleano contra concurrencia; validar `mounted` y usar `(row['pin_order'] as num?)?.toInt()`.

### [BUG-132] — Falta de control de concurrencia en `ProfileController.fetchProfileData()` y `AchievementsController.load()`, y reseteo de `currentXp`
- **ID y Título**: `[BUG-132]` — Falta de control de concurrencia en `ProfileController.fetchProfileData()` y `AchievementsController.load()`, y reseteo de `currentXp`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/profile_controller.dart:80-137`, `lib/screens/profile/achievements/achievements_controller.dart:34-40, 183-188`, `lib/screens/profile/profile_screen.dart:204`
- **Problema / Causa raíz**:
  1. `ProfileController.fetchProfileData()` carece de `_fetchVersion` y no comprueba `isDisposed` antes de mutar `viewedStoryIdsNotifier.value` (línea 121); en "Reintentar" (`profile_screen.dart:204`), no restaura `isLoading = true; hasError = false; notify();`; y en línea 92 pasa `isOwnProfile: userId == null` en lugar de `isOwnProfile`.
  2. `AchievementsController.load()` (36) resetea `currentXp = initialXp;` en cada recarga parpadeando al XP inicial al volver de `AchievementGamesScreen`, carece de `isDisposed`/`_loadVersion`, y silencia errores en `catch (e)` (183–186) sin exponer `hasError`.
- **Solución propuesta**: Añadir `int _fetchVersion = 0;` y comprobaciones `if (isDisposed || version != _fetchVersion) return;`, asignar `isOwnProfile: isOwnProfile`, mover `currentXp = initialXp` al constructor de `AchievementsController` y exponer `hasError` con botón reintentar.

### [BUG-133] — `_FriendsBadgeButton` recarga solicitudes antes de abrir/cerrar `FriendsScreen` y `CurrentlyPlayingBadge` omite `try/catch` al pulsar
- **ID y Título**: `[BUG-133]` — `_FriendsBadgeButton` recarga solicitudes antes de abrir/cerrar `FriendsScreen` y `CurrentlyPlayingBadge` omite `try/catch` al pulsar
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/profile_screen.dart:439-443, 596-600, 1092-1143`, `lib/screens/profile/currently_playing_badge.dart:94-105`
- **Problema / Causa raíz**:
  1. `profile_screen.dart:1136-1139` llama `widget.onPressed(); _loadPendingCount();` sin esperar el `Future` de `context.pushFriends()`, recargando el contador *antes* de que el usuario acepte/rechace solicitudes.
  2. `currently_playing_badge.dart:94-105` ejecuta consulta a `games` en `onTap` sin `try/catch` ni guard contra doble tap.
- **Solución propuesta**: Cambiar `VoidCallback onPressed` a `Future<void> Function() onPressed` y hacer `await widget.onPressed();` antes de `_loadPendingCount()` (o reutilizar `unreadFriendRequestsCount`); añadir guard `_isOpening` y `try/catch` en `CurrentlyPlayingBadge.onTap`.

### [BUG-134] — Casts dinámicos inseguros (`as String`, `as int`) y `DateTime.parse` sin protección en pantallas de logros
- **ID y Título**: `[BUG-134]` — Casts dinámicos inseguros (`as String`, `as int`) y `DateTime.parse` sin protección en pantallas de logros
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/achievements_screen.dart:148, 160, 162, 165, 176, 179, 187, 224, 393, 396, 492, 507, 512, 617`, `lib/screens/profile/profile_achievements_tab.dart:101-103, 178-179, 259, 946, 949, 957, 994, 1161`, `lib/screens/profile/achievements/achievements_controller.dart:61, 65, 92, 93`
- **Problema / Causa raíz**: A diferencia de `achievements_controller.dart:73, 169` que usan `(val as num?)?.toInt() ?? ...`, estos puntos realizan casts directos no nulables (`as String`, `as int`) y `DateTime.parse(row['unlocked_at'])` (`profile_achievements_tab.dart:101-102`). Cualquier valor nulo o tipo `num` distinto aborta la carga o render de logros.
- **Solución propuesta**: Reemplazar por casts seguros `(x as String?) ?? ''`, `(x as num?)?.toInt() ?? 0` y `DateTime.tryParse(...)` con `if (dt != null)`.

### [BUG-135] — `HallOfFameSelectorScreen` excluye juegos `'completed'`, permite taps múltiples durante carga y tiene cast nulo en `_selectGame`
- **ID y Título**: `[BUG-135]` — `HallOfFameSelectorScreen` excluye juegos `'completed'`, permite taps múltiples durante carga y tiene cast nulo en `_selectGame`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/hall_of_fame_selector_screen.dart:43, 143, 196-197`
- **Problema / Causa raíz**: Línea 43 filtra `.eq('status', 'beaten')` excluyendo juegos `'completed'`; línea 143 mantiene `onPressed: _removeGame` habilitado con `_isLoading == true`; líneas 196–197 pasan `game['igdb_id'] ?? game['id']` sin comprobar `num?` no nulo.
- **Solución propuesta**: Usar `.inFilter('status', const ['beaten', 'completed'])`, deshabilitar `onPressed: _isLoading ? null : _removeGame` y validar `rawId as num?` antes de llamar `_selectGame(rawId.toInt())`.

### [BUG-136] — Manejo inconsistente de `didUpdateWidget` / `_isLoading` en pestañas de perfil (`ProfileAchievementsTab`, `ProfileJournalTab`, `ProfileReviewsTab`)
- **ID y Título**: `[BUG-136]` — Manejo inconsistente de `didUpdateWidget` / `_isLoading` en pestañas de perfil (`ProfileAchievementsTab`, `ProfileJournalTab`, `ProfileReviewsTab`)
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/profile_achievements_tab.dart:79-85`, `lib/screens/profile/profile_journal_tab.dart:82-87`, `lib/screens/profile/profile_reviews_tab.dart:55-59`
- **Problema / Causa raíz**: `ProfileAchievementsTab.didUpdateWidget` (79–85) llama a `_fetchAchievements()` sin poner `_isLoading = true` ni versión de petición, dejando visibles logros del perfil anterior durante la carga o en fallo; `ProfileJournalTab` y `ProfileReviewsTab` carecen de `didUpdateWidget` cuando cambia `widget.userId`.
- **Solución propuesta**: Añadir `_isLoading = true` + `_fetchVersion` en `ProfileAchievementsTab.didUpdateWidget` e implementar `didUpdateWidget` en `ProfileJournalTab` y `ProfileReviewsTab`.

### [BUG-137] — Envoltorio de línea roto en lomos de `ShelfGameBox` por restricciones sin límite de `FittedBox`
- **ID y Título**: `[BUG-137]` — Envoltorio de línea roto en lomos de `ShelfGameBox` por restricciones sin límite de `FittedBox`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/widgets/shelf_game_box.dart:155-175`
- **Problema / Causa raíz**: `SizedBox(width: constraints.maxHeight, height: constraints.maxWidth, child: FittedBox(fit: BoxFit.scaleDown, child: Text(title, maxLines: 6, ...)))` pasa restricciones *unbounded* (`0..∞`) al `Text` desde `FittedBox`, ignorando `maxLines: 6` y renderizando títulos largos en una sola línea microscópica e ilegible.
- **Solución propuesta**: Colocar `ConstrainedBox(constraints: BoxConstraints(maxWidth: constraints.maxHeight))` **dentro** de `FittedBox` envolviendo al `Text`, o calcular el escalado por `LayoutBuilder` permitiendo wrapping real multi-línea.

### [BUG-138] — Falta de manejo de errores, bloqueo de doble pulsación y uso frágil de `context` tras `pop` al guardar plataformas
- **ID y Título**: `[BUG-138]` — Falta de manejo de errores, bloqueo de doble pulsación y uso frágil de `context` tras `pop` al guardar plataformas
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/widgets/platform_picker_sheet.dart:342-365`, `lib/screens/profile/widgets/add_game_to_shelf_sheet.dart:82-93`, `lib/screens/profile/widgets/bulk_add_to_shelf_sheet.dart:156-167`
- **Problema / Causa raíz**:
  1. `pickAndSavePlatforms` (línea 359) y `_onTapOption` (línea 83) llaman `await repository.setPlatformsForGame(...)` sin `try/catch` ni guard `_saving` tras cerrarse el picker interno.
  2. En `bulk_add_to_shelf_sheet.dart:157-167`, `ScaffoldMessenger.of(context).showSnackBar(...)` se invoca *después* de `Navigator.pop(context)` sobre el `context` ya cerrado.
- **Solución propuesta**: Añadir guard `_saving`, progreso y `try/catch` en `_AddGameToShelfSheetState._onTapOption`, y capturar `ScaffoldMessenger.of(context)` antes de `Navigator.pop(context)` en `BulkAddToShelfSheetState._save`.

### [BUG-139] — Selección oculta inconsistente al cambiar filtros en `BulkAddToShelfSheet`
- **ID y Título**: `[BUG-139]` — Selección oculta inconsistente al cambiar filtros en `BulkAddToShelfSheet`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/widgets/bulk_add_to_shelf_sheet.dart:109-124, 268-286`
- **Problema / Causa raíz**:
  1. Al alternar `'Solo de esta plataforma'` (271–276), se invoca `_applySmartSelectionForPlatform(_platformId!)`, borrando todas las selecciones manuales previas (`_selectedGameIds.clear()`).
  2. Al activar `'Ocultar en estantería'` (282) o filtrar por texto `_query` (261), los juegos ocultos permanecen en `_selectedGameIds`, guardando elementos no visibles en el botón `'Añadir N juegos'`.
- **Solución propuesta**: Preservar selecciones manuales al cambiar chips de filtro y filtrar/mostrar claramente los juegos seleccionados que cumplen los filtros activos.

### [BUG-140] — `Image.asset` sin `errorBuilder` en `_PlatformMiniIcon` y `ProfileSidebarInfo` + casts inseguros de mapa
- **ID y Título**: `[BUG-140]` — `Image.asset` sin `errorBuilder` en `_PlatformMiniIcon` y `ProfileSidebarInfo` + casts inseguros de mapa
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/widgets/bulk_add_to_shelf_sheet.dart:569-576`, `lib/screens/profile/widgets/profile_sidebar_info.dart:23-24, 29, 38, 143`
- **Problema / Causa raíz**: `bulk_add_to_shelf_sheet.dart:570` y `profile_sidebar_info.dart:143` llaman `Image.asset` sin `errorBuilder` (a diferencia de `platform_picker_sheet.dart:328`); además `profile_sidebar_info.dart:23-24` usa `bio` como `dynamic` y `List<String>.from(userProfile?['platforms'] ?? [])` sin validar tipos.
- **Solución propuesta**: Añadir `errorBuilder` con icono fallback en ambos `Image.asset` y normalizar `bio?.toString()` y `(userProfile?['platforms'] as List?)?.whereType<String>().toList() ?? const []`.

### [BUG-141] — Omisión de `'Por jugar'` en móvil, índices mágicos y cursor de clic falso en `ProfileGiantStats`
- **ID y Título**: `[BUG-141]` — Omisión de `'Por jugar'` en móvil, índices mágicos y cursor de clic falso en `ProfileGiantStats`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/widgets/profile_giant_stats.dart:49-85, 104-107`
- **Problema / Causa raíz**: En `isMobile: true`, `if (!isMobile)` (línea 49) excluye `'Por jugar'` (`toPlayCount`) y líneas 73–82 acceden por índices fijos `stats[0]..stats[3]` (riesgo de `RangeError`). En línea 104, `MouseRegion(cursor: SystemMouseCursors.click)` se aplica siempre aunque `onTap == null` y `GestureDetector` carece de `behavior: HitTestBehavior.opaque`.
- **Solución propuesta**: Renderizar dinámicamente mediante `Wrap` o cuadrícula sin índices mágicos, y usar `cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic` con `HitTestBehavior.opaque`.

### [BUG-142] — Estado desactualizado de `ShelfGameBox` al volver de `GameDetailsScreen` (falta callback `onReturn`)
- **ID y Título**: `[BUG-142]` — Estado desactualizado de `ShelfGameBox` al volver de `GameDetailsScreen` (falta callback `onReturn`)
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/widgets/shelf_game_box.dart:52-63, 92`, `lib/screens/my_games/collection_tab.dart:734-739`
- **Problema / Causa raíz**: A diferencia de `GameCard` (`onReturn`), `ShelfGameBox` no acepta ni invoca un callback tras `context.pushGameDetails(widget.game)` (línea 92). Si el usuario edita o quita plataformas del juego desde `GameDetailsScreen` en vista lomo (`_spineView = true`), la estantería queda desincronizada hasta recargar manualmente.
- **Solución propuesta**: Añadir `final VoidCallback? onReturn;` en `ShelfGameBox`, encadenar `.then((_) => widget.onReturn?.call())` en `onTap` y pasar `_load` desde `CollectionShelfRow` / `CollectionTab`.

### [BUG-143] — Inconsistencia de estado `'completed'` (Platinos) y `mounted` faltante en `GameSearchPickerSheet` / `GroupDetailScreen`
- **ID y Título**: `[BUG-143]` — Inconsistencia de estado `'completed'` (Platinos) y `mounted` faltante en `GameSearchPickerSheet` / `GroupDetailScreen`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/my_games/widgets/game_search_picker_sheet.dart:88, 249-262, 298`, `lib/screens/my_games/group_detail_screen.dart:115-120`
- **Problema / Causa raíz**:
  1. `game_search_picker_sheet.dart:88` filtra únicamente `.eq('status', 'beaten')`, excluyendo los juegos en `'completed'` (Platinos), a diferencia de `CollectionRepository.fetchLibraryForShelf`.
  2. Si todos los juegos terminados están en `excludeGameIds`, muestra `'No tienes juegos terminados disponibles para añadir.'` sin distinguir que ya están en la colección.
  3. En `group_detail_screen.dart:115-118`, tras `await showGameSearchPicker(...)` falta `if (!mounted) return;`; en `game_search_picker_sheet.dart:298`, `game.coverUrl != null` no comprueba `.isNotEmpty`.
- **Solución propuesta**: Cambiar `.eq('status', 'beaten')` por `.inFilter('status', ['beaten', 'completed'])`, verificar `if (!mounted) return;` tras `showGameSearchPicker` y comprobar `game.coverUrl!.isNotEmpty`.

### [BUG-144] — `HomeAppearanceScreen` no notifica a `HomeScreen` al guardar, realiza escrituras `unawaited` concurrentes y fuerza `itemIcons[key]!`
- **ID y Título**: `[BUG-144]` — `HomeAppearanceScreen` no notifica a `HomeScreen` al guardar, realiza escrituras `unawaited` concurrentes y fuerza `itemIcons[key]!`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/settings/home_appearance_screen.dart:96-133, 184, 239, 311`, `lib/screens/settings/info_tab_appearance_screen.dart:92-128`
- **Problema / Causa raíz**: `_savePreferences()` no dispara ningún notificador hacia `HomeScreen` (que vive montado en `IndexedStack`), por lo que cambios de orden/visibilidad/cuenta atrás no se reflejan al volver a Inicio; se invoca sin `await` ni `try/catch` en varios handlers generando carreras de escritura en `SharedPreferences`; y `home_appearance_screen.dart:311` hace `itemIcons[key]!` sin fallback.
- **Solución propuesta**: Crear/usar un `homeSettingsUpdateNotifier` observado por `HomeScreen`, serializar escrituras con `try/catch` y usar `itemIcons[key] ?? CorpusIconKind.InfoOutline`.

### [BUG-145] — `HomeScreen`: `DateTime.parse` sin protección, contadores negativos y `TextPainter` sin `textScaler` en scroll
- **ID y Título**: `[BUG-145]` — `HomeScreen`: `DateTime.parse` sin protección, contadores negativos y `TextPainter` sin `textScaler` en scroll
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/home/home_screen.dart:335-351, 368-373, 657-669, 857-862`
- **Problema / Causa raíz**: `DateTime.parse(bundle['end_date'])` (línea 335) lanza excepción si `end_date` es nulo/malformado y muestra días/horas negativos al expirar. `_isTextTruncated` (657–669, llamado en `ListView.builder` línea 857) ejecuta `TextPainter(...).layout()` por cada tarjeta sin `textScaler: MediaQuery.textScalerOf(context)`.
- **Solución propuesta**: Usar `DateTime.tryParse` acotando `difference.isNegative`, y pasar `textScaler` / cachear medición fuera de `build`.

### [BUG-146] — `AnticipatedGamesSection` y `HeroShowcase`: casts inseguros de mapas/listas IGDB
- **ID y Título**: `[BUG-146]` — `AnticipatedGamesSection` y `HeroShowcase`: casts inseguros de mapas/listas IGDB
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/home/anticipated_games_section.dart:143, 170-176`, `lib/screens/home/hero_showcase.dart:121, 235-237, 359`
- **Problema / Causa raíz**: `anticipated_games_section.dart:143, 170-175` castea `first_release_date as int?` y accede a `artworks[0]['image_id']` / `cover['image_id']` sin verificar `is List`/`is Map`; `hero_showcase.dart:121, 235, 359` castea `screenshots_list as List<String>?`, multiplica `first_release_date * 1000` sin validar tipo y asume `Map<String, dynamic>` en `_currentGame!['games']`.
- **Solución propuesta**: Normalizar con `(val as num?)?.toInt()`, comprobaciones `is Map` / `is List` y `(game['screenshots_list'] as List?)?.whereType<String>().toList() ?? []`.

### [BUG-147] — `BundleDetailsScreen`: inconsistencia `isFanatical` rompe aplanado de tiers, falta `getBottomSpacer` y cast inseguro de `tier`
- **ID y Título**: `[BUG-147]` — `BundleDetailsScreen`: inconsistencia `isFanatical` rompe aplanado de tiers, falta `getBottomSpacer` y cast inseguro de `tier`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/bundles/bundle_details_screen.dart:47, 52-53, 91-97, 104, 182-189, 196, 240`
- **Problema / Causa raíz**:
  1. Línea 52 define `isFanatical = storeName.toLowerCase().contains('fanatical')`, pero línea 182 la sombrea con `?.toLowerCase() == 'fanatical'` impidiendo aplanar tiers para `'Fanatical Bundles'`.
  2. Líneas 196 y 240 castean `(tier as Map<String, dynamic>)` sin validar tipo y línea 186 llama `title.toLowerCase()` sin asegurar `String`.
  3. Línea 104 usa `EdgeInsets.all(24.0)` sin `getBottomSpacer(context)` tapando los últimos juegos tras la barra flotante; línea 91 muestra botón "Tienda" si `url == ""`.
- **Solución propuesta**: Reutilizar `isFanatical` exterior, validar `tier is Map` y `url.trim().isNotEmpty`, y usar `getBottomSpacer(context)`.

### [BUG-148] — `savedIndex` sin validar límites y conflicto de `rootToken` en `MainScreen._loadSavedTab()`
- **ID y Título**: `[BUG-148]` — `savedIndex` sin validar límites y conflicto de `rootToken` en `MainScreen._loadSavedTab()`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/main_screen.dart:210-233, 240-265`
- **Problema / Causa raíz**:
  1. Línea 213 asigna `prefs.getInt('main_tab_index') ?? 0` a `_currentIndex` y `_initializedTabs` sin comprobar `0..4`, arriesgando `RangeError` en `tabScrollToTopNotifiers` o aserción de barra inferior si el valor está corrupto.
  2. Líneas 220–231 llaman `setWebPath` usando `framesFor(savedIndex).firstOrNull?.token ?? 0` antes de construirse el `Navigator`, colisionando con el token creado por `TabUrlSyncObserver`.
  3. `_resolveAndPushSubRoute` (240–265) no verifica tras `await DeepRouteResolver.buildRoute` si el usuario cambió de pestaña antes de `nav.push(route)`.
- **Solución propuesta**: Validar rango `0..4` con fallback `0`, diferir `setWebPath` al construirse el `Navigator` y usar un epoch en `_loadSavedTab` para abortar pushes obsoletos.

### [BUG-149] — Badge de `LiquidGlassBottomNavBar` intercepta toques y `_navCollapseController` responde a sub-rutas sin expandirse en `_onTabTapped`
- **ID y Título**: `[BUG-149]` — Badge de `LiquidGlassBottomNavBar` intercepta toques y `_navCollapseController` responde a sub-rutas sin expandirse en `_onTabTapped`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/main_screen.dart:267-317, 621-663, 988-1008`
- **Problema / Causa raíz**:
  1. En líneas 621–627, `_buildLiquidGlassBadge(barWidth: barWidth)` se superpone sobre `LiquidGlassBottomNavBar` sin `IgnorePointer`, bloqueando taps justo sobre el círculo del badge.
  2. `_handleScrollNotification` (988–1000) envuelve los 5 `Navigator`s completos, colapsando la barra al scrollear pantallas secundarias y dejándola colapsada si se cambia de pestaña mediante `_onTabTapped` (que no llama `_setNavCollapsed(false)`).
- **Solución propuesta**: Envolver `_buildLiquidGlassBadge(...)` en `IgnorePointer` y llamar `_setNavCollapsed(false)` dentro de `_onTabTapped`.

### [BUG-150] — Race conditions en `_handleDebugClearAccount` y actualización incondicional de biblioteca en `SettingsScreen`
- **ID y Título**: `[BUG-150]` — Race conditions en `_handleDebugClearAccount` y actualización incondicional de biblioteca en `SettingsScreen`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/settings_screen.dart:36-153, 186-189, 266-288`
- **Problema / Causa raíz**:
  1. `context.pushAppearance().then((_) { libraryUpdateNotifier.value++; });` (186–189) dispara refresco completo de biblioteca incluso sin cambios o si el push fue throttled.
  2. `SwitchListTile.onChanged` (267, 282) lanza `prefs.setBool`/`setString` sin `await` ni manejo de error.
  3. En `_handleDebugClearAccount` (99, 125): `batchDelete('reviews')` omite `.eq('user_id', userId)`, y si `batchDeleteUserGames()` falla tras borrar reseñas, `libraryUpdateNotifier.value++` no corre desincronizando la UI; el diálogo (37–60) no sincroniza historial web al hacer `pop`.
- **Solución propuesta**: Devolver `bool` desde `AppearanceScreen` indicando cambios reales, añadir `.eq('user_id', userId)` en `batchDelete('reviews')` y mover `libraryUpdateNotifier.value++` a `finally`.

### [BUG-151] — Race condition en preferencias de `AppearanceScreen` y falta de bloqueo anti doble-importación
- **ID y Título**: `[BUG-151]` — Race condition en preferencias de `AppearanceScreen` y falta de bloqueo anti doble-importación
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/appearance_screen.dart:278-282, 310-355, 380-384, 410-414, 478-479, 502-505, 550-555, 649-654`
- **Problema / Causa raíz**:
  1. `_buildGridColumnSelector` (550–555) y `_buildFloatingNavSelector` (649–654) actualizan el `ValueNotifier` y lanzan `SharedPreferences` sin serializar: toques rápidos (`2 -> 4 -> 3`) pueden persistir valores fuera de orden.
  2. `_importPack()` (326–355) carece de flag `_isImporting` permitiendo abrir dos importaciones simultáneas.
  3. `themeNotifier.setTheme`/`setColor` (478, 503) no se esperan; `pushHomeAppearance().then(...)` / `pushInfoTabAppearance().then(...)` (381, 411) incrementan `libraryUpdateNotifier` incondicionalmente.
- **Solución propuesta**: Serializar la persistencia de preferencias leyendo el valor más reciente del `ValueNotifier`, añadir `bool _isImporting = false;` con `try/finally`, y propagar `bool?` real desde sub-pantallas.

### [BUG-152] — `GenreRadarSection`: race condition al cambiar `userId`, parámetro `dynamic` y navegación frágil tras `Navigator.pop`
- **ID y Título**: `[BUG-152]` — `GenreRadarSection`: race condition al cambiar `userId`, parámetro `dynamic` y navegación frágil tras `Navigator.pop`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/widgets/genre_radar_section.dart:40-70, 138, 187-206`
- **Problema / Causa raíz**:
  1. `_fetch()` carece de token de secuencia: al cambiar `widget.userId` en `didUpdateWidget` (42), una petición previa más lenta puede sobrescribir `_entries` y `_availableYears`.
  2. `_showGamesDialog(BuildContext context, dynamic stat)` (138) usa `dynamic` en vez de `GenreTimeStat`.
  3. Líneas 190–204 llaman `Navigator.pop(context)` sobre el contexto del diálogo y luego `Navigator.push(context, MaterialPageRoute(...))` usando ese mismo contexto desmontado sin `CorpusRouter`.
- **Solución propuesta**: Añadir `int _fetchId = 0`, tipar `GenreTimeStat stat`, y usar `parentContext.pushGameDetails(...)` tras cerrar `dialogContext`.

### [BUG-153] — `PaginatedScrollMixin`: fuga de `_internalScrollController` cuando se pasa `externalController`
- **ID y Título**: `[BUG-153]` — `PaginatedScrollMixin`: fuga de `_internalScrollController` cuando se pasa `externalController`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/widgets/paginated_scroll_mixin.dart:30-53`
- **Problema / Causa raíz**: `_internalScrollController` se instancia siempre en la línea 31 aunque se use `initPagination(externalController: ...)`. En `disposePagination()` (50–52), si `_externalScrollController != null`, `_internalScrollController.dispose()` nunca se ejecuta; además re-invocar `initPagination` no remueve el listener previo.
- **Solución propuesta**: Declarar `ScrollController? _internalScrollController;`, instanciarlo solo si `externalController == null`, limpiar el listener previo y llamar `_internalScrollController?.dispose()`.

### [BUG-154] — `P5rDynamicBackground` / `P5rStaticBackground`: borde amputado por `ClipPath` y falta de `didUpdateWidget`
- **ID y Título**: `[BUG-154]` — `P5rDynamicBackground` / `P5rStaticBackground`: borde amputado por `ClipPath` y falta de `didUpdateWidget`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/widgets/p5r_dynamic_frame.dart:36-46, 65-78, 217-227`
- **Problema / Causa raíz**: `DecoratedBox` pinta `Border.all(...)` dentro de `ClipPath(clipper: _P5rShapeClipper(...))`, amputando el borde en los chaflanes diagonales de los frames 1–5; además `_P5rDynamicBackgroundState` carece de `didUpdateWidget` si cambia `interval`.
- **Solución propuesta**: Reemplazar `ClipPath` + `DecoratedBox` por `CustomPaint` que rellene y trace el borde directamente sobre el mismo `Path`, e implementar `didUpdateWidget` para reiniciar `_timer` cuando cambie `interval`.

### [BUG-155] — `CorpusCard`: `InkWell` oculto detrás del `Material` hijo (ripple invisible o crash sin ancestro `Material`)
- **ID y Título**: `[BUG-155]` — `CorpusCard`: `InkWell` oculto detrás del `Material` hijo (ripple invisible o crash sin ancestro `Material`)
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/widgets/design/corpus_card.dart:28-50`
- **Problema / Causa raíz**: En la rama estándar (`ext.useDynamicFrames == false`), `InkWell` envuelve por fuera a `Material(color: bg, ...)`, quedando tapado el ripple por el `Material` hijo opaco; en la rama P5R, `InkWell` envuelve `P5rStyledPanel` sin `borderRadius` y falla con `No Material widget found` si no hay `Material` ancestro.
- **Solución propuesta**: Mover `InkWell(onTap: onTap, borderRadius: ext.radiusMedium, child: Padding(...))` dentro de `Material` en la rama estándar y envolver con `Material(type: MaterialType.transparency, ...)` en la rama P5R.

### [BUG-156] — `StashJsonToCsvConverter.fixEncoding` omite mojibake Windows-1252, silencia errores HAR y `dateAdded` usa hora local
- **ID y Título**: `[BUG-156]` — `StashJsonToCsvConverter.fixEncoding` omite mojibake Windows-1252, silencia errores HAR y `dateAdded` usa hora local
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/utils/stash_json_to_csv_converter.dart:35-70, 145, 279`
- **Problema / Causa raíz**:
  1. L36 solo entra a `fixEncoding` si hay `[ÃÂ][\u0080-\u00BF]`, ignorando secuencias frecuentes (`â€™`, `â€œ`, `ðŸŽ®`) o mapeos Windows-1252 (`€`, `™`).
  2. L145 usa `catch (_) {}` silencioso al parsear entradas HAR.
  3. L279 usa `DateTime.fromMillisecondsSinceEpoch(ms)` en hora local en lugar de `isUtc: true` (usado en L219).
- **Solución propuesta**: Ampliar detección de mojibake, registrar entradas HAR corruptas sin silenciar totalmente y usar `isUtc: true` en L279.

### [BUG-157] — `GameStatus.fromString('onHold')` falla y `GameStatus.isFinished` excluye `completed` ("Platino")
- **ID y Título**: `[BUG-157]` — `GameStatus.fromString('onHold')` falla y `GameStatus.isFinished` excluye `completed` ("Platino")
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/models/game_status.dart:44, 72-82, 125-129`
- **Problema / Causa raíz**: Línea 44 normaliza `clean = value.toLowerCase().trim()`, convirtiendo `'onHold'` en `'onhold'`; el `switch` no tiene `case 'onhold':` y línea 80 compara `e.name == clean` (`'onHold' != 'onhold'`), lanzando `ArgumentError`. Además `isFinished` (128–129) excluye `completed`.
- **Solución propuesta**: Añadir `case 'onhold':` o comparar `e.name.toLowerCase() == clean` y alinear o retirar `isFinished`.

### [BUG-158] — `GameGroup.decodeRankedDescription` aplica `.trim()` de forma inconsistente según tenga marcador o no
- **ID y Título**: `[BUG-158]` — `GameGroup.decodeRankedDescription` aplica `.trim()` de forma inconsistente según tenga marcador o no
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/models/game_group.dart:83-103`
- **Problema / Causa raíz**: Cuando la descripción tiene marcador ranked (`[#ranked#]`), devuelve `rest` recortado con `.trim()` (líneas 91, 95); cuando no es ranked, devuelve `rawDescription` sin `.trim()` (línea 100).
- **Solución propuesta**: Devolver `rawDescription.trim()` en línea 100 para consistencia.

### [BUG-159] — `BundleService`: `_readPrice` recibe `{}` para el tier, detección de tienda por `toString()` y cast inseguro en `fromJson`
- **ID y Título**: `[BUG-159]` — `BundleService`: `_readPrice` recibe `{}` para el tier, detección de tienda por `toString()` y cast inseguro en `fromJson`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/bundle_service.dart:32-75, 213-219, 303`
- **Problema / Causa raíz**: En este módulo (actualmente código muerto en producción pero activo en tests unitarios), la línea 303 invoca `_readPrice({}, bundleMap)` anulando las comprobaciones por tier (110–115, 134–141); las líneas 213–217 detectan tienda buscando en `bundleMap.toString().toLowerCase()`; y `fromJson` (32–75) asume tipos no nulos.
- **Solución propuesta**: Eliminar `BundleService` si se confirma obsoleto (ver `[ARQ-13]`), o pasar el tier real y leer `store` explícitamente.

### [BUG-160] — Breakpoint desktop inconsistente (`>= 800` vs `> 800`) y salto de scroll en `ProfileScreen._scrollToTabs()`
- **ID y Título**: `[BUG-160]` — Breakpoint desktop inconsistente (`>= 800` vs `> 800`) y salto de scroll en `ProfileScreen._scrollToTabs()`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/profile_screen.dart:67, 79-87, 215`
- **Problema / Causa raíz**: Línea 67 usa `>= 800` mientras línea 215 y `globals.dart:8` usan `> 800`; además `_scrollToTabs()` (línea 82) anima a `210.0` hardcoded cuando con `hasCurrentlyPlaying == true` el rango de colapso es `232` y sin acotar a `maxScrollExtent`.
- **Solución propuesta**: Usar `MediaQuery.sizeOf(context).width > kDesktopBreakpoint` en ambas líneas y acotar con `.clamp(0.0, _scrollController.position.maxScrollExtent)`.

### [BUG-161] — `CollectionShelfScreen`: botón Recargar de la `AppBar` desincronizado y sin reacción a cambios de sesión
- **ID y Título**: `[BUG-161]` — `CollectionShelfScreen`: botón Recargar de la `AppBar` desincronizado y sin reacción a cambios de sesión
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/collection_shelf_screen.dart:20, 35, 82-87`
- **Problema / Causa raíz**: Línea 35 evalúa `_tabKey.currentState?.isLoading == true` en `build`, pero en el primer frame es `null` y no recibe notificación de cambios de `isLoading` para reconstruir la `AppBar`; línea 20 lee `auth.currentUser?.id` solo en `build` sin suscripción a auth.
- **Solución propuesta**: Pasar un callback `onLoadingChanged` desde `CollectionTab` o compartir estado de carga en un controller.

### [BUG-162] — Manejo inseguro de `NaN`/`Infinity` y tooltip de altura cero en `ProfileRatingsHistogram`
- **ID y Título**: `[BUG-162]` — Manejo inseguro de `NaN`/`Infinity` y tooltip de altura cero en `ProfileRatingsHistogram`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/widgets/profile_ratings_histogram.dart:15-25, 80-91`
- **Problema / Causa raíz**: Línea 15 filtra `r > 0` sin `r.isFinite`, arriesgando `UnsupportedError` en `r.floor()`; `r.floor() - 1` deja `9.5` en `9★` y `10★` solo para `10.0`; y cuando `count == 0`, `Container(height: 0)` impide que el `Tooltip` reciba hover/tap.
- **Solución propuesta**: Filtrar `r.isFinite && r > 0` y dar altura interactiva completa al `Tooltip`.

### [BUG-163] — `SteamImportSetupScreen`: variable muerta `_isStarting` y `getBottomSpacer` excesivo en modal
- **ID y Título**: `[BUG-163]` — `SteamImportSetupScreen`: variable muerta `_isStarting` y `getBottomSpacer` excesivo en modal
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/settings/steam_import_setup_screen.dart:16-17, 31, 111-114`
- **Problema / Causa raíz**: `_isStarting` nunca cambia de `false`, haciendo inalcanzable la rama del `CircularProgressIndicator` (113); línea 31 usa `getBottomSpacer(context)` (120px) dentro de un modal ya envuelto en `SafeArea`.
- **Solución propuesta**: Eliminar `_isStarting` y sustituir `getBottomSpacer(context)` por padding normal + `MediaQuery.paddingOf(context).bottom`.

### [BUG-164] — `InfoScreen._launchUrl` falla silenciosamente en builds release sin feedback al usuario
- **ID y Título**: `[BUG-164]` — `InfoScreen._launchUrl` falla silenciosamente en builds release sin feedback al usuario
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/info_screen.dart:11-14`
- **Problema / Causa raíz**: `_launchUrl(String urlString)` únicamente escribe `debugPrint('No se pudo abrir el enlace $urlString')` cuando `openUrl` devuelve `false`, sin mostrar aviso visual en compilaciones release.
- **Solución propuesta**: Pasar `BuildContext` a `_launchUrl(BuildContext context, String urlString)` y mostrar `SnackBar` si `!success && context.mounted`.

### [BUG-165] — Typo de idioma (`'Contenu'`) y dropdown/chip no reactivos en `lib/screens/design/sections/`
- **ID y Título**: `[BUG-165]` — Typo de idioma (`'Contenu'`) y dropdown/chip no reactivos en `lib/screens/design/sections/`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/design/sections/design_navigation_section.dart:35`, `lib/screens/design/sections/design_selection_section.dart:63-73, 100-113`
- **Problema / Causa raíz**: `design_navigation_section.dart:35` muestra `'Contenu ${_tab + 1}'` (francés) en lugar de `'Contenido ${_tab + 1}'`; `design_selection_section.dart:102-111` fija `value: 'rating'` con `onChanged: (_) {}` y el chip `'Co-op'` (65) ignora el cambio de estado.
- **Solución propuesta**: Corregir a `'Contenido ${_tab + 1}'` y respaldar el dropdown y el chip con variables de estado en `_DesignSelectionSectionState`.

---

## 2. Optimizaciones de Rendimiento y Red

### [OPT-01] — Parseo síncrono en el hilo principal de archivos CSV/JSON/HAR (hasta 25 MB) en `IntegrationsScreen`, `ImportService` y `StashJsonToCsvConverter`
- **ID y Título**: `[OPT-01]` — Parseo síncrono en el hilo principal de archivos CSV/JSON/HAR (hasta 25 MB) en `IntegrationsScreen`, `ImportService` y `StashJsonToCsvConverter`
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/settings/integrations_screen.dart:23, 266-270`, `lib/services/import_service.dart:163-255`, `lib/utils/stash_json_to_csv_converter.dart:87-90, 123-306`
- **Problema / Causa raíz**: `IntegrationsScreen._importFromStash()` acepta archivos `.csv`, `.json` y `.har` de hasta `25 MB` (`_maxStashImportBytes`) y ejecuta `ImportService.parseCsv(fileBytes)` o `ImportService.parseStashJson(fileBytes)` de forma **síncrona en el isolate principal**. Dicho flujo decodifica `Uint8List` a UTF-8, ejecuta `CsvToListConverter.convert` o `jsonDecode`, recorre `StashJsonToCsvConverter.extractRows` (con decodificación Base64 + `jsonDecode` por cada entrada HAR y múltiples `RegExp` de `fixEncoding`), congelando la animación del `LinearProgressIndicator` y bloqueando el hilo de UI (riesgo de ANR en Android y freeze en Web). Además, si `rows.isEmpty`, no corta el flujo ni avisa al usuario antes de abrir `ImportPreviewScreen`.
- **Solución propuesta**:
  1. Convertir `ImportService.parseCsv` y `ImportService.parseStashJson` en métodos `Future<List<CsvGameRow>>` que deleguen en `Isolate.run` en nativo (`compute` de `package:flutter/foundation.dart`, con fallback/chunking seguro en Web).
  2. En `IntegrationsScreen`, si `rows.isEmpty`, cerrar el diálogo de carga y mostrar un `SnackBar` informativo sin invocar `matchGamesWithIGDB` ni abrir `ImportPreviewScreen` vacía.

### [OPT-02] — Problema N+1 en `UserFriendsScreen`: `FriendshipButton` dispara una consulta Supabase individual por cada amigo visible
- **ID y Título**: `[OPT-02]` — Problema N+1 en `UserFriendsScreen`: `FriendshipButton` dispara una consulta Supabase individual por cada amigo visible
- **Severidad / Impacto**: Crítico
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/social/user_friends_screen.dart:76-127`, `lib/widgets/friendship_button.dart:30-53`
- **Problema / Causa raíz**: Por cada fila del `ListView.separated` (`itemBuilder`, líneas 101–106), `UserFriendsScreen` instancia `FriendshipButton(targetUserId: friendId, isIconOnly: true)` **sin `Key`**, cuyo `initState()` ejecuta un `SELECT` individual contra `friendships` (`friendship_button.dart:46-52`). Ver un perfil con 50 amigos genera **1 + 50 = 51 peticiones HTTP** a Supabase al abrir la pantalla (y consultas adicionales al hacer scroll si los ítems salen/entran del viewport y se destruye su estado).
- **Solución propuesta**:
  1. Añadir una consulta por lotes en `SocialRepository` (p. ej. `fetchFriendshipStatusesWith(List<String> targetIds)` o una sola query `or(requester_id.eq.myId,addressee_id.eq.myId)`) cargada junto a `fetchFriendsOf(widget.userId)` en `_loadData()`.
  2. Pasar el estado inicial resuelto a `FriendshipButton` (con `ValueKey(friendId)`) para evitar las N consultas individuales.

### [OPT-03] — Cache-busting accidental en `IGDBService` por interpolar `now` en segundos exactos (0% cache hit y 0% deduplicación)
- **ID y Título**: `[OPT-03]` — Cache-busting accidental en `IGDBService` por interpolar `now` en segundos exactos (0% cache hit y 0% deduplicación)
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/igdb_service.dart:41-59, 102, 130, 284, 502`
- **Problema / Causa raíz**: `_postQuery` usa `'$endpoint::$query'` como clave de `_queryCache` (TTL 10 min) y `_inFlightQueries` (línea 42). Sin embargo, `getMostAnticipatedGames` (línea 102), `getUpcomingGamesByIds` (línea 130), `searchGames` por compañía/saga (línea 284) y `getAchievementGames` (línea 502) interpolan `now` exacto al **segundo** (`millisecondsSinceEpoch ~/ 1000`) dentro de `query`. Cada segundo genera una query distinta, inutilizando por completo la caché LRU de 10 minutos y duplicando peticiones idénticas al navegar entre pestañas o pantallas.
- **Solución propuesta**: Cuantizar `now` a ventanas de 5 o 10 minutos (ej. `const bucket = 300; final now = (DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ bucket) * bucket;`) para que las consultas dentro de la misma ventana compartan la misma clave de caché.

### [OPT-04] — Doble serialización/deserialización JSON + UTF-8 en `IGDBService._postQuery` en el hilo principal
- **ID y Título**: `[OPT-04]` — Doble serialización/deserialización JSON + UTF-8 en `IGDBService._postQuery` en el hilo principal
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/services/igdb_service.dart:30-36, 41-98, 116, 141, 306, 323, 337, 353, 369, 397, 454, 477, 574, 603, 661, 696, 790`
- **Problema / Causa raíz**: `Supabase.functions.invoke` devuelve `res.data` ya parseado (cuando es JSON) o como `String`. `_postQuery` hace `jsonEncode(res.data)` (línea 70) -> `_jsonResponse` ejecuta `utf8.encode(bodyString)` (línea 32) -> crea un `http.Response` sintético -> cada método llamador ejecuta `jsonDecode(response.body)` (`utf8.decode` + `jsonDecode` de nuevo) en el hilo principal de UI. En cargas grandes (`getGamesByIdsFull`, `searchGames` con 35 juegos y subobjetos), genera picos de CPU y GC innecesarios en cada request y cache hit.
- **Solución propuesta**: Hacer que `_postQuery` devuelva directamente `dynamic` (el JSON ya decodificado, usando `Isolate.run`/`compute` si `res.data` viene como `String` grande) y cachear los datos decodificados, eliminando el wrapper `http.Response` y la dependencia de `package:http` en `IGDBService`.

### [OPT-05] — N+1 en `ImportService.saveImportedGames` (hasta 25 `UPDATE` secuenciales por lote) y falta de batching por `igdbId` en `matchGamesWithIGDB`
- **ID y Título**: `[OPT-05]` — N+1 en `ImportService.saveImportedGames` (hasta 25 `UPDATE` secuenciales por lote) y falta de batching por `igdbId` en `matchGamesWithIGDB`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/services/import_service.dart:275-282, 319, 514-527`
- **Problema / Causa raíz**:
  1. En `saveImportedGames` (líneas 521-527), por cada juego del lote con `cover_url`, ejecuta un `await supabase.from('games').update(...).eq('igdb_id', ...).isFilter('cover_url', null)` secuencial. Importar 500 juegos dispara 500 round-trips HTTP secuenciales solo para rellenar portadas nulas.
  2. En `matchGamesWithIGDB` (líneas 275-282), cuando `row.igdbId != null`, consulta `IGDBService.getGameById(row.igdbId!)` uno por uno (5 por chunk con `Future.delayed(200ms)` en línea 319 -> hasta 25 req/s superando el rate limit de 4 req/s de IGDB), en lugar de agrupar todos los `igdbId` conocidos en lotes de 200 con `IGDBService.getGamesByIdsFull`.
- **Solución propuesta**:
  1. Hacer **1** `SELECT igdb_id FROM games WHERE igdb_id IN (...) AND cover_url IS NULL` por lote (o un RPC bulk `fill_missing_covers`), actualizando únicamente los IDs con `cover_url == null`.
  2. En `matchGamesWithIGDB`, resolver primero en lote todos los `row.igdbId != null` mediante `IGDBService.getGamesByIdsFull` (chunks de 200) y reservar el loop secuencial (respetando 4 req/s) solo para búsquedas por texto.

### [OPT-06] — Overfetching masivo de columnas (`games(*)`, `users(*)`, `*`) en repositorios y pantallas
- **ID y Título**: `[OPT-06]` — Overfetching masivo de columnas (`games(*)`, `users(*)`, `*`) en repositorios y pantallas
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**:
  - `lib/repositories/achievements_repository.dart:45, 54, 57`; `lib/repositories/collection_repository.dart:45, 162`; `lib/repositories/game_group_repository.dart:16, 50`; `lib/repositories/profile_repository.dart:96, 122, 143, 158, 171, 184, 214`; `lib/repositories/activity_repository.dart:145, 308, 494, 600`; `lib/repositories/review_repository.dart:74, 120, 134, 1127, 1471, 1502`; `lib/repositories/notifications_repository.dart:72, 130-132`
  - `lib/screens/library/library_screen.dart:26-29`; `game_details_screen.dart:237-241`; `search_screen.dart:183-186`; `group_games_screen.dart:41-50`
  - `lib/screens/profile/achievement_games_screen.dart:94-102`; `profile_games_grid_tab.dart:100, 160-164, 238-241`; `hall_of_fame_selector_screen.dart:39-44`
  - `lib/screens/my_games/games_tab.dart:75-93`; `game_search_picker_sheet.dart:84-89`
  - `lib/screens/home/controller/home_controller.dart:113, 221-293`; `lib/screens/settings/notifications_screen.dart:51`
- **Problema / Causa raíz**: La tabla `games` contiene columnas pesadas (`summary`, `screenshots`, `artworks`, `videos`, `websites`, `involved_companies` JSONB) y `users` contiene campos extensos. Casi todas las vistas de estantería, grupos, logros, journal, reseñas, notificaciones, `HomeController` y `LibraryScreen` solicitan `games(*)` o `*` completo (y `GamesTab:89-92` descarga todas las filas de `reviews` sin filtrar por los `game_id` cargados; `LibraryScreen` y `GroupGamesScreen` carecen de paginación/límite), multiplicando el payload JSON y la decodificación en el hilo principal.
- **Solución propuesta**: Definir constantes de proyección acotadas por caso de uso (`kGameCardColumns`, `kPublicUserColumns`), aplicarlas en todos los `.select(...)`, filtrar `reviews` en `GamesTab` con `.inFilter('game_id', gameIds)` y paginar `LibraryScreen` / `GroupGamesScreen`.

### [OPT-07] — `GameGroupRepository.fetchGroups` descarga todos los `game_group_items` y `games(*)` de todas las listas para descartar todo salvo 4 portadas
- **ID y Título**: `[OPT-07]` — `GameGroupRepository.fetchGroups` descarga todos los `game_group_items` y `games(*)` de todas las listas para descartar todo salvo 4 portadas
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/repositories/game_group_repository.dart:12-35`, `lib/screens/my_games/game_groups_controller.dart:36`
- **Problema / Causa raíz**: `fetchGroups` pide `*, game_group_items(id, group_id, game_id, sort_order, games(*))` sin límite en la relación anidada ni en los grupos. Si un usuario tiene 15 listas con 100 juegos cada una, descarga 1,500 filas completas de `games(*)` solo para contar `rawItems.length` y hacer `.take(4)` en el cliente (línea 31).
- **Solución propuesta**: Crear una vista o RPC en Supabase (`get_user_game_groups_preview`) que devuelva `game_count` calculado en SQL y únicamente los primeros 4 `games(igdb_id, title, cover_url)` ordenados por `sort_order`.

### [OPT-08] — `ProfileRepository.fetchProfileData` ejecuta una cascada + 12 queries HTTP por cada carga de perfil
- **ID y Título**: `[OPT-08]` — `ProfileRepository.fetchProfileData` ejecuta una cascada + 12 queries HTTP por cada carga de perfil
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Grande (Refactor estructural)
- **Ubicación**: `lib/repositories/profile_repository.dart:131-250`
- **Problema / Causa raíz**:
  1. Primero espera secuencialmente `fetchUserProfile` (línea 135) antes de lanzar el `Future.wait`.
  2. Luego dispara 11 ramas concurrentes (12 queries reales contando la subconsulta de `platinumGamesRows`): para cada uno de los 4 estados (`wishlist`, `playing`, `to_play`, `beaten`) hace **2 queries** separadas (una para los 20 registros y otra para `.count(CountOption.exact)`).
  3. Además trae TODAS las filas de `reviews` del usuario sin límite (líneas 196-202) solo para histograma, `completion_type` y platinos.
- **Solución propuesta**: Incluir `fetchUserProfile` dentro del `Future.wait` inicial (cuando `!isOwnProfile`), combinar datos + conteo por estado en una única query (`count: CountOption.exact`) o un único RPC `get_profile_summary(p_user_id)`.

### [OPT-09] — `ActivityRepository.fetchInteractions` descarga toda la tabla de `review_likes` del post para contar y comprobar `hasLiked`
- **ID y Título**: `[OPT-09]` — `ActivityRepository.fetchInteractions` descarga toda la tabla de `review_likes` del post para contar y comprobar `hasLiked`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/activity_repository.dart:486-507`
- **Problema / Causa raíz**: Línea 491 ejecuta `_client.from('review_likes').select('user_id').eq('post_id', postId)` sin `.limit()`, descargando todos los `user_id` que han dado like para calcular `likes.length` y `likes.any(...)` en Dart. Asimismo, `review_comments` (líneas 492-496) no tiene paginación ni límite.
- **Solución propuesta**: Reutilizar la RPC existente `get_post_stats` (que ya devuelve `likes_count` y `liked_by_me`), o usar `.count(CountOption.exact)` + `.eq('user_id', currentUserId).maybeSingle()`, y añadir paginación/límite a `review_comments`.

### [OPT-10] — Operaciones N+1 en `CollectionRepository.setPlatformsForGame`, `GameGroupRepository.reorderGroups`/`reorderItems` y recargas completas tras mutación
- **ID y Título**: `[OPT-10]` — Operaciones N+1 en `CollectionRepository.setPlatformsForGame`, `GameGroupRepository.reorderGroups`/`reorderItems` y recargas completas tras mutación
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/repositories/collection_repository.dart:125-130`, `lib/repositories/game_group_repository.dart:223-231, 299-308`, `lib/screens/my_games/game_groups_controller.dart:84, 113, 140, 151, 164`
- **Problema / Causa raíz**:
  1. `setPlatformsForGame` lanza una petición `DELETE` individual por cada plataforma en `toRemove` dentro de un `for`.
  2. `reorderGroups` y `reorderItems` disparan N peticiones `UPDATE` HTTP individuales en `Future.wait` (una por cada grupo o juego de la lista).
  3. Además, `GameGroupsController` tras `updateGroup`, `addGameToGroup` y `removeGameFromGroup` ejecuta `await load(silent: true)` re-descargando todos los grupos y juegos tras cada edición puntual.
- **Solución propuesta**: En `setPlatformsForGame`, usar `.inFilter('platform_name', toRemove.toList())`; en `reorderGroups`/`reorderItems`, crear una RPC en Supabase (`UPDATE ... FROM unnest(...)`); y actualizar la lista `groups` en memoria con la respuesta de cada mutación puntual.

### [OPT-11] — Invocación redundante de Edge Function `igdb-proxy` (`backfill_game`) en CADA `saveReview`
- **ID y Título**: `[OPT-11]` — Invocación redundante de Edge Function `igdb-proxy` (`backfill_game`) en CADA `saveReview`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/review_repository.dart:399-416, 1365-1423`
- **Problema / Causa raíz**: `upsertGame` siempre llama a `backfillCoverUrl(..., currentCoverUrl: null)` cuando `resolvedCover != null` (línea 400). Como `currentCoverUrl` se pasa fijo en `null`, `missingCover` siempre es `true` en línea 1372, disparando la Edge Function `igdb-proxy` en **cada guardado o edición de reseña**, incluso si el juego ya tiene portada y metadatos completos en Supabase. Además, si `resolvedCover == null` pero hay `summary`/`platforms`/`genres`, línea 399 ni siquiera ejecuta el backfill.
- **Solución propuesta**: Comprobar primero si la fila en `games` realmente carece de `cover_url` o `platforms` (pasando `currentCoverUrl` real desde `gameData`/BD, o resolviendo el upsert solo cuando falten datos en la Edge Function).

### [OPT-12] — Consultas duplicadas/triplicadas en el arranque de `MainScreenController` (7 llamadas en lugar de 3)
- **ID y Título**: `[OPT-12]` — Consultas duplicadas/triplicadas en el arranque de `MainScreenController` (7 llamadas en lugar de 3)
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/main/main_screen_controller.dart:115-130, 153-158, 197-201, 211-216, 230-234`
- **Problema / Causa raíz**: Al llamar a `_badgeController.init()`: `_subscribeFriendRequests()` consulta `friendships` (120–125); `_subscribeActivityFeed()` llama a `fetchInitialBadges()` (157, consultando `friendships` 2.ª vez + `get_unread_activity_summary`); al emitirse `RealtimeSubscribeStatus.subscribed` en `_activityFeedChannel` (198–200) vuelve a llamar `fetchInitialBadges()` (`friendships` 3.ª vez + `get_unread_activity_summary` 2.ª vez); y `_subscribeNotifications()` llama `fetchNotificationsCount()` al iniciar (215) y otra vez en `subscribed` (232). En total dispara **7 llamadas** por cada arranque de `MainScreen`.
- **Solución propuesta**: Eliminar la query duplicada en `_subscribeFriendRequests()`, y distinguir el `subscribed` inicial de reconexiones reales mediante flags `_activitySubscribedOnce` / `_notificationsSubscribedOnce`.

### [OPT-13] — Pre-instanciación incondicional de `HomeScreen` (Tab 0) aunque el usuario arranque en otra pestaña
- **ID y Título**: `[OPT-13]` — Pre-instanciación incondicional de `HomeScreen` (Tab 0) aunque el usuario arranque en otra pestaña
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/main_screen.dart:62-64, 124, 183-234`
- **Problema / Causa raíz**: En línea 62 (`final Set<int> _initializedTabs = {0};`) y línea 124 (`_getScreen(0);`), `MainScreen` fuerza siempre la creación de `HomeScreen` síncronamente antes de que `_loadSavedTab()` determine la pestaña real por URL web (`/buscar/1942`, `/perfil`) o `main_tab_index`, disparando todas las consultas de red de `HomeScreen` en segundo plano innecesariamente.
- **Solución propuesta**: Comprobar síncronamente `getWebPathname()` en `initState()` para inicializar `_currentIndex` y `_initializedTabs` con `fromUrl` cuando aplique, o resolver `prefs` antes de montar las pestañas.

### [OPT-14] — Reconstrucciones completas de `MainScreen` por `MediaQuery.of`, doble `ValueListenableBuilder`, `AnimatedBuilder` sin `child` y `LiquidGlassBottomNavBar` sin `RepaintBoundary`
- **ID y Título**: `[OPT-14]` — Reconstrucciones completas de `MainScreen` por `MediaQuery.of`, doble `ValueListenableBuilder`, `AnimatedBuilder` sin `child` y `LiquidGlassBottomNavBar` sin `RepaintBoundary`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/main_screen.dart:586-618, 780-868, 1012, 1039-1073`
- **Problema / Causa raíz**:
  1. Línea 1012 usa `MediaQuery.of(context).size.width > 800`, reconstruyendo las 5 pestañas y la barra de navegación en cada frame de animación del teclado (`viewInsets`).
  2. `ValueListenableBuilder<bool>(floatingMobileNavNotifier)` (1039–1073) envuelve todo el `Scaffold` aunque el `body` no depende de ello (y `_buildSolidNavBar` tiene otro en línea 780).
  3. `AnimatedBuilder(animation: _navCollapseAnim)` (802–865) no usa `child:`, reconstruyendo `BottomNavigationBar` e ítems 60–120 veces/s.
  4. `LiquidGlassBottomNavBar` (586–618) aplica refracción + aberración cromática + `magnification: 1.25` sobre `extendBody: true` sin aislar el cuerpo en `RepaintBoundary`.
- **Solución propuesta**: Usar `MediaQuery.sizeOf(context).width > kDesktopBreakpoint`, acotar `ValueListenableBuilder` a `bottomNavigationBar`, pasar `child` estático a `AnimatedBuilder`, y envolver el cuerpo de `Navigator`s en `RepaintBoundary`.

### [OPT-15] — Uso de `NetworkImage` directo en lugar de `CorpusNetworkImage` / caché en disco y decodificación sin `cacheWidth` en avatares y portadas
- **ID y Título**: `[OPT-15]` — Uso de `NetworkImage` directo en lugar de `CorpusNetworkImage` / caché en disco y decodificación sin `cacheWidth` en avatares y portadas
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**:
  - `lib/screens/activity/activity_screen.dart:363, 659, 730`; `activity_story_viewer.dart:747`; `grouped_post_details_screen.dart:307`; `review_details_screen.dart:529, 720`; `comment_thread_section.dart:164`; `comment_composer.dart:344`
  - `lib/screens/library/game_details/game_hero_section.dart:312-314`; `review_modal.dart:607, 654`
  - `lib/screens/profile/profile_journal_tab.dart:515-540`; `profile_reviews_tab.dart:294-320`; `edit_profile_screen.dart:413-417, 484-487`
  - `lib/screens/social/friends_screen.dart:280`; `notifications_feed_screen.dart:298`; `user_friends_screen.dart:56`; `lib/screens/info_screen.dart:86, 113`
  - `lib/widgets/activity_story_ring.dart:35`; `lib/widgets/coop_badge.dart:50-52`
- **Problema / Causa raíz**: Todos estos puntos instancian `NetworkImage(url)` en `CircleAvatar.backgroundImage` o `DecorationImage`, omitiendo la caché persistente en disco (`CachedNetworkImage`) y el redimensionado de decodificación (`memCacheWidth`/`cacheWidth` salvo `activity_story_viewer.dart:744`) ni manejo `onError` en `DecorationImage`, causando re-descargas repetidas y consumo elevado de memoria de texturas GPU al hacer scroll.
- **Solución propuesta**: Crear un componente reutilizable `CorpusUserAvatar` / usar `CorpusNetworkImage` (o `CachedNetworkImageProvider` con `maxWidth` acotado por `devicePixelRatio` y `errorWidget` / `placeholder`).

### [OPT-16] — Decodificación de imágenes a resolución completa (`t_1080p` / sin `cacheWidth`) en `CorpusNetworkImage` y mosaico 2×2 sobredimensionado
- **ID y Título**: `[OPT-16]` — Decodificación de imágenes a resolución completa (`t_1080p` / sin `cacheWidth`) en `CorpusNetworkImage` y mosaico 2×2 sobredimensionado
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**:
  - `lib/widgets/corpus_network_image.dart:40-54, 75-86`
  - `lib/screens/library/game_details/game_media_tab.dart:111-128, 160-163, 196-213`; `game_reviews_card.dart:404-408, 437-442`; `game_stash_tab.dart:97-102`; `game_related_tab.dart:167-171`
  - `lib/screens/profile/widgets/add_game_to_shelf_sheet.dart:230-233`; `bulk_add_to_shelf_sheet.dart:595-598`; `lib/screens/my_games/widgets/game_search_picker_sheet.dart:296-299`; `groups_tab.dart:742`
  - `lib/widgets/genre_radar_section.dart:163-166`; `lib/widgets/full_screen_gallery.dart:94-97`
- **Problema / Causa raíz**: `CorpusNetworkImage` (`corpus_network_image.dart:49-54`) solo calcula `memCacheWidth` cuando `width != null && width!.isFinite && width! > 0`. En grids/listas/modales donde se envuelve en `SizedBox`, `AspectRatio`, `Expanded` o `width: double.infinity` sin pasar `cacheWidth`, `effectiveCacheWidth` resulta `null`, decodificando texturas `t_1080p` (~8 MB cada una) o carátulas completas en GPU para miniaturas de 32–40 px (`game_stash_tab`, sheets) o tiles de media (`game_media_tab`); inversamente `groups_tab.dart:742` fija `cacheWidth: 400` para celdas de ~70 px en mosaico 2×2. Además `CorpusNetworkImage` no soporta `memCacheHeight`/`maxWidthDiskCache` y `_empty(context)` ignora `width`/`height`.
- **Solución propuesta**: Pasar `cacheWidth` explícito en todos los call sites acorde al tamaño visual * `devicePixelRatio` (`~600` media, `~320` relacionados, `~96–120` miniaturas 32–40px, `~180` mosaico 2×2), y soportar `cacheHeight`/`maxWidthDiskCache` y dimensiones en `_empty` dentro de `CorpusNetworkImage`.

### [OPT-17] — `ListenableBuilder` envuelve el `Scaffold` entero en 3 pantallas de `activity/` y `sortFriendsStrip` corre en cada cambio de presencia
- **ID y Título**: `[OPT-17]` — `ListenableBuilder` envuelve el `Scaffold` entero en 3 pantallas de `activity/` y `sortFriendsStrip` corre en cada cambio de presencia
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/activity/activity_screen.dart:1057-1070, 1209-1310`, `lib/screens/activity/grouped_post_details_screen.dart:258-507`, `lib/screens/activity/review_details_screen.dart:472-1196`
- **Problema / Causa raíz**:
  1. En `ActivityScreen`, `GroupedPostDetailsScreen` y `ReviewDetailsScreen`, `ListenableBuilder` envuelve todo el `Scaffold`, reconstruyendo `AppBar`, cabeceras, portadas y listas completas cada vez que cambia un like, `isSubmitting` o un comentario.
  2. En `activity_screen.dart:1057-1070`, cada evento en `onlineUsersNotifier` o `viewedStoryIdsNotifier` dispara `ActivityRepository.sortFriendsStrip(...)` (copia y `sort` completo de todos los amigos) dentro del `builder` del `AnimatedBuilder`.
- **Solución propuesta**: Acotar `ListenableBuilder` / `AnimatedBuilder` únicamente a las secciones dependientes (barra de acciones, sección de comentarios, tira de amigos) y memoizar `sortedFriends` en el controller.

### [OPT-18] — Doble `Timer.periodic` de carrusel de screenshots provocando rebuild completo de `GameDetailsScreen` cada 10s
- **ID y Título**: `[OPT-18]` — Doble `Timer.periodic` de carrusel de screenshots provocando rebuild completo de `GameDetailsScreen` cada 10s
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/library/game_details/game_details_controller.dart:95-97, 176-215`, `lib/screens/library/game_details_screen.dart:95-105, 496-499`, `lib/screens/library/game_details/game_hero_section.dart:79-152, 977`
- **Problema / Causa raíz**: Tanto `GameDetailsController` como `GameHeroSection` mantienen su propio `Timer.periodic(10s)` y `selectedScreenshotUrl`. `GameHeroSection` renderiza únicamente su propio `_selectedScreenshotUrl` (`977`) e ignora `controller.selectedScreenshotUrl`. Sin embargo, el timer del controller dispara `notify()` cada 10s, forzando a `ListenableBuilder` (`game_details_screen.dart:496`) a reconstruir toda la pantalla sin efecto visual alguno; además el timer de `GameHeroSection` omite `kDisableCarouselForTests`, colgando `pumpAndSettle()` en tests.
- **Solución propuesta**: Unificar en un único `ValueNotifier<String?>` (con guarda `kDisableCarouselForTests`) escuchado únicamente por el fondo `AnimatedSwitcher` dentro de `GameHeroSection`, eliminando `notify()` general en el controller.

### [OPT-19] — Rebuilds masivos de `GameDetailsScreen` y `ReviewModal` por falta de granularidad
- **ID y Título**: `[OPT-19]` — Rebuilds masivos de `GameDetailsScreen` y `ReviewModal` por falta de granularidad
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/library/game_details_screen.dart:495-500, 540-635`, `lib/screens/library/game_details/game_details_controller.dart:120-165, 229-705`, `lib/screens/library/review_modal.dart:333-1821`
- **Problema / Causa raíz**:
  1. `GameDetailsScreen.build` envuelve todo el `Scaffold` en un único `ListenableBuilder(listenable: _controller)` (`496`), por lo que cada una de las ~8 respuestas asíncronas de `init()` reconstruye todo el `CustomScrollView`, `GameHeroSection`, `SliverPersistentHeader` y pestaña activa, re-asignando listas (`540-635`).
  2. `_ReviewModalContentState.build` (`review_modal.dart:333`) llama `setState` a nivel raíz al arrastrar cualquier `Slider` (60fps), reconstruyendo las 1,488 líneas del modal (`FutureBuilder<List<UserProfile>>`, `DropdownMenu`, `GridView.count`, `ListView`).
- **Solución propuesta**: Usar `ValueNotifier`s o selectores acotados por sección en `GameDetailsController`, y extraer sub-widgets independientes (con `ValueNotifier` para sliders) en `ReviewModal`.

### [OPT-20] — `ProfileAchievementsTab` usa `GridView.builder(shrinkWrap: true)` dentro de `SliverToBoxAdapter`
- **ID y Título**: `[OPT-20]` — `ProfileAchievementsTab` usa `GridView.builder(shrinkWrap: true)` dentro de `SliverToBoxAdapter`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/profile/profile_achievements_tab.dart:1090-1212`, `lib/screens/profile/profile_screen.dart:998-1012`
- **Problema / Causa raíz**: `ProfileScreen` envuelve `ProfileAchievementsTab` en `SliverToBoxAdapter` y `ProfileAchievementsTab` usa `GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics())`, obligando a medir, instanciar y maquetar todas las tarjetas de logros de golpe aunque estén fuera de pantalla, anulando el layout perezoso de `CustomScrollView`.
- **Solución propuesta**: Convertir `ProfileAchievementsTab` para devolver un `SliverMainAxisGroup` (`SliverToBoxAdapter` para el título + `SliverGrid` para los logros) y eliminar el `SliverToBoxAdapter` wrapper en `profile_screen.dart:1000`.

### [OPT-21] — Destrucción de pestañas y recarga completa en cada cambio de tab en `ProfileScreen` y `MyGamesScreen` + `shouldRebuild` en `MobileProfileHeaderDelegate`
- **ID y Título**: `[OPT-21]` — Destrucción de pestañas y recarga completa en cada cambio de tab en `ProfileScreen` y `MyGamesScreen` + `shouldRebuild` en `MobileProfileHeaderDelegate`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/profile/profile_screen.dart:298-336, 898-1015`, `lib/screens/profile/widgets/profile_mobile_header.dart:218-223`, `lib/screens/my_games/my_games_screen.dart:141-170`
- **Problema / Causa raíz**:
  1. `ProfileScreen._buildCurrentTabContent()` y `MyGamesScreen._buildTabContent()` devuelven únicamente un widget condicional según `_selectedTab`: cada cambio de sub-pestaña desmonta (`dispose()`) la pestaña previa (perdiendo filtros, búsqueda, vista `_spineView`, scroll y caché en memoria) y dispara todas las consultas Supabase/IGDB desde cero al volver.
  2. `MobileProfileHeaderDelegate` recibe closures inline nuevas en cada `build()`, haciendo que `shouldRebuild` devuelva `true` siempre.
- **Solución propuesta**: Cachear los datos por pestaña en controladores persistentes a nivel de `ProfileScreen` / `MyGamesScreen` (o usar `Offstage`/`PageStorage` con invalidación por `libraryUpdateNotifier`) y evitar comparar closures en `MobileProfileHeaderDelegate.shouldRebuild`.

### [OPT-22] — Consultas Supabase secuenciales en `ProfileAchievementsTab`, `AchievementGamesScreen`, `ProfileGamesGridTab` (por página) y `_FriendsBadgeButton`
- **ID y Título**: `[OPT-22]` — Consultas Supabase secuenciales en `ProfileAchievementsTab`, `AchievementGamesScreen`, `ProfileGamesGridTab` (por página) y `_FriendsBadgeButton`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/profile/profile_achievements_tab.dart:89-115`, `lib/screens/profile/achievement_games_screen.dart:94-102`, `lib/screens/profile/profile_games_grid_tab.dart:100, 160-164, 238-241`, `lib/screens/profile/profile_screen.dart:1113-1117`
- **Problema / Causa raíz**:
  1. `ProfileAchievementsTab` hace 4 `await` secuenciales en lugar de usar `AchievementsRepository.fetchAll` (paralelo).
  2. `AchievementGamesScreen` hace 2 `await` secuenciales (`reviews` + `user_games`).
  3. `ProfileGamesGridTab` repite la consulta completa de `reviews` (`completion_type = '100_percent'`) en **cada página** de scroll infinito cuando `_currentStatus == 'completed'`, y en `_page == 0` la lanza también para `wishlist`/`to_play`.
  4. `_FriendsBadgeButton` descarga todas las filas pendientes (`select('requester_id')`) en lugar de usar `.count(CountOption.exact)`.
- **Solución propuesta**: Reutilizar `AchievementsRepository.fetchAll`, paralelizar con `Future.wait` en `AchievementGamesScreen`, cachear `platinoGameIds`/`_completionTypeMap` en `ProfileGamesGridTab` omitiendo la query en `wishlist`/`to_play`, y usar `.count(CountOption.exact)` en `_FriendsBadgeButton`.

### [OPT-23] — Consultas N+1 secuenciales a IGDB y `setState` por cada ítem en `GamesTab._healIncompleteGames`
- **ID y Título**: `[OPT-23]` — Consultas N+1 secuenciales a IGDB y `setState` por cada ítem en `GamesTab._healIncompleteGames`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/my_games/games_tab.dart:128-175`
- **Problema / Causa raíz**: `_healIncompleteGames` recorre `incompleteItems.entries` haciendo `await IGDBService.getGameById(igdbId)` de forma estrictamente secuencial (N peticiones de red una tras otra), llama a `setState(() {})` dentro del bucle tras **cada** juego reparado (N rebuilds completos del tab), no persiste las carátulas reparadas y vuelve a ejecutarse en cada regreso al tab `Juegos`.
- **Solución propuesta**: Resolver en lote con `IGDBService.getGamesByIdsFull`, ejecutar un único `setState` al finalizar el lote y persistir/cachear los metadatos reparados.

### [OPT-24] — `CollectionTab._editItemPlatforms` descarga toda la biblioteca para editar un solo juego (6–7 queries)
- **ID y Título**: `[OPT-24]` — `CollectionTab._editItemPlatforms` descarga toda la biblioteca para editar un solo juego (6–7 queries)
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/my_games/collection_tab.dart:144-185`
- **Problema / Causa raíz**: Al pulsar editar un único `ShelfItem`, `_editItemPlatforms` llama a `fetchOwnedPlatforms` (1 query), luego `fetchLibraryForShelf` (3 queries de toda la biblioteca y reseñas del usuario), luego `setPlatformsForGame` (vuelve a llamar `fetchOwnedPlatforms` + upsert/delete), y finalmente `_load()` (recarga toda la estantería).
- **Solución propuesta**: Crear `fetchPlatformSuggestionsForGame(userId, gameId)` consultando únicamente la fila de `user_games` y `reviews` de ese `gameId`, pasar `owned` directamente y actualizar `_items` localmente.

### [OPT-25] — `HeroShowcase`, `GuestHeroShowcase` y `EmptyPlayingHero`: reconstrucción del árbol de imágenes y `ResizeImage` a 60 FPS durante el paneo
- **ID y Título**: `[OPT-25]` — `HeroShowcase`, `GuestHeroShowcase` y `EmptyPlayingHero`: reconstrucción del árbol de imágenes y `ResizeImage` a 60 FPS durante el paneo
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/home/hero_showcase.dart:278-351, 390, 408-410, 557-601, 823-871, 997-1028, 1171-1214`
- **Problema / Causa raíz**:
  1. `AnimatedBuilder(animation: Listenable.merge([_panController, _crossFadeController]))` llama a `_buildShowcaseLayer` -> `_buildPanningImageLayer` en cada frame (60 FPS continuos) para ambas capas, recreando `ClipRect`, `Stack`, `Container`, `ResizeImage.resizeIfNeeded(...)`, `Image` y closures `frameBuilder`.
  2. `HeroShowcase` (557) reconstruye todas las barras de progreso a 60 FPS aunque solo cambia la activa; `EmptyPlayingHero` (1214) omite `RepaintBoundary` alrededor de `TypewriterText`; `setState(() => _titleTyped = true)` (408–410) reconstruye todo `HeroShowcase`; y las imágenes de fondo de `GuestHeroShowcase`/`EmptyPlayingHero` no usan `precacheImage`.
- **Solución propuesta**: Construir cada capa `Image` fuera del `AnimatedBuilder` (pasándola como `child` que solo anima `Transform.translate`), aislar la barra de progreso activa y `TypewriterText` con `RepaintBoundary` + `ValueNotifier<bool>`, y precargar imágenes locales de invitado.

### [OPT-26] — `AnticipatedGamesSection`: timer cada 30s reconstruye tarjetas, `StatefulBuilder` pierde hover, `ColorFiltered` y `P5rDynamicFrame` multiplica timers
- **ID y Título**: `[OPT-26]` — `AnticipatedGamesSection`: timer cada 30s reconstruye tarjetas, `StatefulBuilder` pierde hover, `ColorFiltered` y `P5rDynamicFrame` multiplica timers
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/home/anticipated_games_section.dart:39-44, 69-83, 178-288, 320-338`, `lib/widgets/p5r_dynamic_frame.dart:40`
- **Problema / Causa raíz**:
  1. `_timer` dispara `setState(() => _now = DateTime.now())` cada 30s incluso cuando `countdownStyle == 'days_only'` o sin fechas futuras, ni respeta `kDisableCarouselForTests`, reconstruyendo toda la sección.
  2. `bool isHovered = false;` fuera de `StatefulBuilder` (178–180) se resetea en cualquier rebuild padre; `ColorFiltered(BlendMode.srcOver)` (205–215) añade capa extra por tarjeta.
  3. En tema P5R, cada tarjeta crea un `P5rStyledPanel` y hasta 6 `P5rDynamicFrame` con sus propios `ClipPath` y `Timer.periodic` dentro de un `GridView.builder(shrinkWrap: true)` (69–83).
- **Solución propuesta**: Extraer `_AnticipatedGameCard` con `ValueNotifier<DateTime>` acotado a los dígitos (desactivando timer en `days_only` o `kDisableCarouselForTests`), reemplazar `ColorFiltered` por `ColoredBox(color: Color(0x8C000000))` y usar `P5rStaticBackground` para dígitos pequeños en P5R.

### [OPT-27] — `CorpusTablerIcon` y `_friendsFilled` fuerzan `saveLayer` GPU por cada icono con `ColorFiltered(BlendMode.srcIn)` y `Opacity`
- **ID y Título**: `[OPT-27]` — `CorpusTablerIcon` y `_friendsFilled` fuerzan `saveLayer` GPU por cada icono con `ColorFiltered(BlendMode.srcIn)` y `Opacity`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/widgets/corpus_tabler_icon.dart:110-121`, `lib/widgets/corpus_tabler_icon_builders.dart:18-21`
- **Problema / Causa raíz**: Cada `CorpusTablerIcon` en toda la aplicación envuelve su widget SVG en `ClipRect -> SizedBox -> Center -> ColorFiltered(ColorFilter.mode(resolvedColor, BlendMode.srcIn))`. `BlendMode.srcIn` obliga a Skia/Impeller a asignar un render target offscreen (`saveLayer`) por cada icono en pantalla en cada frame de scroll; además `_friendsFilled` añade `Opacity(opacity: 0.65)` (un `saveLayer` anidado).
- **Solución propuesta**: Pasar el parámetro `color: resolvedColor` nativo a los iconos de `tabler_icons_next` (eliminando `ColorFiltered` y `ClipRect`) y usar `resolvedColor.withValues(alpha: 0.65)` en `_friendsFilled` en vez de `Opacity`.

### [OPT-28] — `GameCard`: `LayoutBuilder`, `MediaQuery.of`, 13 llamadas a `Theme.of`, sombras por ítem y cálculo síncrono en `build()`
- **ID y Título**: `[OPT-28]` — `GameCard`: `LayoutBuilder`, `MediaQuery.of`, 13 llamadas a `Theme.of`, sombras por ítem y cálculo síncrono en `build()`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/widgets/game_card.dart:122-169, 184-193, 214-231, 283-304, 370-384, 426-446, 516-526`
- **Problema / Causa raíz**: En cada ítem de `CorpusGameGrid`, `HorizontalGameRow` y `ExploreBundleRow`, `GameCard` instancia un `LayoutBuilder` (doble pase de layout), llama `MediaQuery.of(context).devicePixelRatio` (reconstruye todos los cards al abrir teclado), llama `Theme.of(context)` más de 13 veces, ejecuta `IgdbConstants.resolveCategory` en `build()`, aplica `Card(elevation: 4)` + múltiples `BoxShadow`, monta `MouseRegion` + `AnimatedScale` también en móvil y decodifica `assets/images/steam.png` sin `cacheWidth`.
- **Solución propuesta**: Usar `MediaQuery.devicePixelRatioOf(context)`, cachear `theme`/`cs`/`ext` al inicio de `build()`, aceptar `double? cacheWidthHint` para omitir `LayoutBuilder` por tarjeta, condicionar hover a desktop y añadir `cacheWidth: 28` al asset Steam.

### [OPT-29] — Construcción ansiosa en `ExploreBundleRow`, falta de `itemExtent` en filas horizontales y `GridView`/`ListView(shrinkWrap: true)` sin virtualización
- **ID y Título**: `[OPT-29]` — Construcción ansiosa en `ExploreBundleRow`, falta de `itemExtent` en filas horizontales y `GridView`/`ListView(shrinkWrap: true)` sin virtualización
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**:
  - `lib/widgets/explore_bundle_row.dart:84-168, 198, 293-303`; `lib/widgets/horizontal_game_row.dart:113-144`; `lib/widgets/corpus_game_grid.dart:115-138`
  - `lib/screens/activity/activity_screen.dart:424-450, 880-940`; `review_details_screen.dart:870-946`; `lib/screens/activity/widgets/comment_thread_section.dart:42, 53-66`; `lib/screens/activity/widgets/post_thread_controller.dart:35, 44, 113`
  - `lib/screens/library/game_details/game_media_tab.dart:100-109, 134-143, 185-194`; `game_related_tab.dart:102-113`; `game_reviews_card.dart:416-425`
  - `lib/screens/home/home_screen.dart:525`; `lib/screens/bundles/bundle_details_screen.dart:207-227, 255-275`
- **Problema / Causa raíz**:
  1. `ExploreBundleRow.build` llama `_buildRowItems(context)` (198) construyendo todos los `GameCard` de cada tier de golpe antes de pasarlos a `ListView.builder` (293–303), anulando la construcción perezosa.
  2. `HorizontalGameRow` y `ActivityScreen:424-450` conocen la altura fija y proporción `IgdbConstants.coverAspectRatio`, pero omiten `itemExtent` en `ListView.builder`.
  3. `CommentThreadSection.build()` ejecuta `orderCommentsThreaded(comments)` en cada rebuild (`lib/screens/activity/widgets/comment_thread_section.dart:42`) además de usar `ListView.separated(shrinkWrap: true)` (L53–66); `ActivityScreen` / `ReviewDetailsScreen` / `GameReviewsCard` (`GridView.builder(shrinkWrap: true)`), `GameMediaTab` / `GameRelatedTab` (dentro de `SliverToBoxAdapter`), `BundleDetailsScreen` y `CorpusGameGrid` fuerzan la medición y construcción ansiosa de todos sus hijos sin virtualización de slivers.
- **Solución propuesta**: Construir descriptores planos en `ExploreBundleRow` para que `ListView.builder` instancie cada `GameCard` bajo demanda; fijar `itemExtent` en `HorizontalGameRow` y tiras horizontales de `ActivityScreen`; precomputar y memoizar el resultado de `orderCommentsThreaded(_comments)` en `PostThreadController` al actualizar `_comments` en lugar de recalcularlo en cada `CommentThreadSection.build()`; y migrar `ReviewDetailsScreen`, `GroupedPostDetailsScreen`, `BundleDetailsScreen`, `GameMediaTab` y `GameRelatedTab` a `SliverList` / `SliverGrid` o `Wrap` ligero para 1–4 fotos.

### [OPT-30] — Precarga incondicional de CropperJS (CDN) y Service Worker con SDK Firebase Compat sin usar
- **ID y Título**: `[OPT-30]` — Precarga incondicional de CropperJS (CDN) y Service Worker con SDK Firebase Compat sin usar
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `web/index.html:209-211`, `web/firebase-messaging-sw.js:5-15`
- **Problema / Causa raíz**: `web/index.html:209-211` ejecuta `window.__loadCropperJs()` 2.5s después de `hideSplash()` para todos los usuarios (incluidos invitados), descargando `cropper.css` y `cropper.js` desde CDN en cada visita y contradiciendo el lazy-load de `web_js.dart:65`. Además, `web/firebase-messaging-sw.js:5-15` descarga `firebase-app-compat.js` y `firebase-messaging-compat.js` aunque los comentarios en L17-27 confirman que solo usa el listener nativo `push`.
- **Solución propuesta**: Eliminar el `setTimeout(..., 2500)` en `web/index.html` para cargar CropperJS bajo demanda, y retirar los `importScripts` / `firebase.initializeApp` del SW si solo maneja eventos nativos `push`/`notificationclick` (verificando compatibilidad con `getToken()`).

### [OPT-31] — Consultas `.select()` sin acotar columnas en `DeepRouteResolver`
- **ID y Título**: `[OPT-31]` — Consultas `.select()` sin acotar columnas en `DeepRouteResolver`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/routes/deep_route_resolver.dart:153-157, 166-170, 185-189, 213-217`
- **Problema / Causa raíz**: Los 4 métodos de fetch usan `.select()` completo (`*`), incluyendo `users!reviews_user_id_users_fkey(*)` en `fetchReviewById` (L187), descargando columnas innecesarias (y potenciales campos privados de `users`) en cada deep link web o notificación push.
- **Solución propuesta**: Especificar listas explícitas de columnas requeridas por `Game.fromMap`, `BundleDetailsScreen`, `ReviewDetailsScreen` y `achievements`.

### [OPT-32] — Complejidad cuadrática `O(N²)` y recompilación de `RegExp` en `orderCommentsThreaded`
- **ID y Título**: `[OPT-32]` — Complejidad cuadrática `O(N²)` y recompilación de `RegExp` en `orderCommentsThreaded`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/utils/comment_thread_utils.dart:18-37, 103-146` (invocado en cada `build()` desde `lib/screens/activity/widgets/comment_thread_section.dart:42`, ver `[OPT-29]`)
- **Problema / Causa raíz**: `orderCommentsThreaded` parsea `DateTime.parse` dentro del comparador de `.sort()` (`O(N log N)`), vuelve a recorrer toda la lista en `_inferParentId` parseando fechas por cada par (`O(N²)`), y crea un `RegExp(r'^@(\w+)')` nuevo en cada invocación de `_inferMentionedUsername` y `_inferParentId` (agravado porque `CommentThreadSection.build()` en `lib/screens/activity/widgets/comment_thread_section.dart:42` lo ejecuta en cada rebuild sin memoización en `PostThreadController`, ver `[OPT-29]`).
- **Solución propuesta**: Declarar `_mentionPrefixRegex` como `static final RegExp`, pre-parsear `created_at` una sola vez en un mapa `id -> DateTime`, construir un índice por `username.toLowerCase()` para resolver padres en `O(N log N)` y memoizar la lista ordenada en `PostThreadController` cuando `_comments` cambie (ver `[OPT-29]`).

### [OPT-33] — Subida secuencial de imágenes en `ReviewRepository.uploadImages`
- **ID y Título**: `[OPT-33]` — Subida secuencial de imágenes en `ReviewRepository.uploadImages`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/review_repository.dart:423-444`
- **Problema / Causa raíz**: El bucle `for (final file in files)` comprime y sube cada imagen secuencialmente (`await uploadBinary`), multiplicando la latencia por el número de adjuntos.
- **Solución propuesta**: Procesar y subir en paralelo (con concurrencia acotada, p. ej. bloques de 2–3 o `Future.wait`).

### [OPT-34] — Consultas secuenciales innecesarias en `SocialRepository`, `ReviewRepository` y `GameGroupRepository`
- **ID y Título**: `[OPT-34]` — Consultas secuenciales innecesarias en `SocialRepository`, `ReviewRepository` y `GameGroupRepository`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/social_repository.dart:126-147, 151-175`, `lib/repositories/review_repository.dart:1079-1088, 1320-1329`, `lib/repositories/game_group_repository.dart:39-53`
- **Problema / Causa raíz**: `asSender` y `asReceiver` (o `sent` y `received`), `groupRes` y `itemsRes` en `fetchGroupDetail`, y `pendingSent` tras `fetchMyFriends` en `fetchSentOrAcceptedIds` se esperan secuencialmente con `await` uno tras otro.
- **Solución propuesta**: Ejecutar las consultas independientes en paralelo con `Future.wait` y reutilizar consultas compartidas donde exista `v_friend_pairs`.

### [OPT-35] — Consulta redundante de `partners` en `ActivityRepository` y límite global `.limit(200)` truncando stories
- **ID y Título**: `[OPT-35]` — Consulta redundante de `partners` en `ActivityRepository` y límite global `.limit(200)` truncando stories
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**: `lib/repositories/activity_repository.dart:139-197, 275, 302-362`
- **Problema / Causa raíz**: Para la misma página de feed/stories, se lanzan en paralelo `ReviewRepository.injectPartners(reviewsList)` y una segunda tubería que consulta `user_games.partner_ids` y de nuevo `users` (sin `display_name`), duplicando consultas para `partner_ids` compartidos. Además `fetchRecentStoriesForUsers` tiene `.limit(200)` global (línea 275), truncando stories de otros amigos si unos pocos tuvieron mucha actividad.
- **Solución propuesta**: Unificar la recolección de `partner_ids` (de `reviews` + `user_games`) en una única consulta batch a `users` (incluyendo `display_name`), y limitar stories por usuario vía RPC/lateral join en SQL.

### [OPT-36] — Consultas sin `.limit()` (unbounded) en múltiples repositorios y cálculo de `fetchJournalYears` en cliente
- **ID y Título**: `[OPT-36]` — Consultas sin `.limit()` (unbounded) en múltiples repositorios y cálculo de `fetchJournalYears` en cliente
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**: `lib/repositories/achievements_repository.dart:45, 54, 57`, `collection_repository.dart:43-47, 160-175`, `game_group_repository.dart:13-20, 48-53`, `profile_repository.dart:196-201, 382-389`, `activity_repository.dart:217-235, 472-481, 491-496`, `review_repository.dart:132-137, 1530-1535`, `social_repository.dart:42-48, 58-64, 127-141`
- **Problema / Causa raíz**: Lecturas completas sin `.limit()` ni paginación; destaca `fetchJournalYears` (descarga todas las reseñas del usuario solo para extraer `Set<int>` de años en Dart) y `fetchFriendsStrip` (descarga todas las filas pendientes solo para `pending.length` en vez de `.count(CountOption.exact)`).
- **Solución propuesta**: Añadir `.count(CountOption.exact)` en `fetchFriendsStrip` para pendientes, RPC `SELECT DISTINCT EXTRACT(YEAR...)` para `fetchJournalYears` y límites/paginación razonables en colecciones grandes.

### [OPT-37] — Lectura completa en RAM y descompresión ZIP síncrona en el hilo principal en `StylePackImportService`
- **ID y Título**: `[OPT-37]` — Lectura completa en RAM y descompresión ZIP síncrona en el hilo principal en `StylePackImportService`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**: `lib/services/style_pack_import_service.dart:28-47`, `lib/theme/style_pack_registry.dart:141-190`
- **Problema / Causa raíz**: `FilePicker.pickFiles(..., withData: true)` (línea 31) carga todo el archivo `.corpuspack`/`.zip` (música y fuentes) en memoria como `Uint8List` sin límite de tamaño, y `StylePackRegistry.importFromBundle(bytes)` (línea 46) ejecuta `ZipDecoder().decodeBytes(bytes)` síncronamente en el hilo de UI.
- **Solución propuesta**: Validar tamaño máximo de archivo antes de procesar; en plataformas IO, leer desde `file.path` (`withData: false`) y ejecutar `ZipDecoder().decodeBytes` dentro de `Isolate.run`.

### [OPT-38] — `DuracionDeService`: ausencia de timeout, caché en memoria/deduplicación in-flight y query repetida en cada apertura
- **ID y Título**: `[OPT-38]` — `DuracionDeService`: ausencia de timeout, caché en memoria/deduplicación in-flight y query repetida en cada apertura
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/duracionde_service.dart:19-81`
- **Problema / Causa raíz**: Ni `_readCache` (40–44) ni `_callEdgeFunction` (69–72) tienen `.timeout(...)`, pudiendo colgar `GameDetailsController.fetchTimeToBeat` indefinidamente; tampoco existe caché en memoria ni deduplicación `_inFlight`, repitiendo consultas al reabrir la ficha de un juego.
- **Solución propuesta**: Añadir `.timeout(const Duration(seconds: 6))` / `Duration(seconds: 12)`, caché en memoria con TTL corto y mapa `_inFlight` por `igdbId`.

### [OPT-39] — `IGDBService.getGamesByIdsFull`: ráfagas sin throttling ante rate limit de IGDB (4 req/s)
- **ID y Título**: `[OPT-39]` — `IGDBService.getGamesByIdsFull`: ráfagas sin throttling ante rate limit de IGDB (4 req/s)
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/igdb_service.dart:761-793`
- **Problema / Causa raíz**: Lanza `concurrency = 3` peticiones en paralelo sin pausa entre iteraciones del bucle `for`. Para bibliotecas grandes (Steam import >800 juegos = 4–5 batches), dispara >4 req/s consecutivas y puede recibir HTTP 429 sin backoff ni reintento.
- **Solución propuesta**: Insertar retardo de 300–350ms entre batches y añadir reintento con backoff ante HTTP 429.

### [OPT-40] — Recargas completas en Realtime, re-agrupación `O(N log N)` en cada página y refetch total en cada comentario en `activity/`
- **ID y Título**: `[OPT-40]` — Recargas completas en Realtime, re-agrupación `O(N log N)` en cada página y refetch total en cada comentario en `activity/`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/activity/activity_controller.dart:151-156, 374-378`, `lib/screens/activity/widgets/post_thread_controller.dart:185, 195`
- **Problema / Causa raíz**:
  1. `ActivityController.fetchActivity` (153–156) re-ejecuta `groupActivityItems([..._activities, ...result.mergedActivities])` sobre toda la lista acumulada en cada página.
  2. `_triggerRealtimeRefresh()` (374–378) re-descarga desde `0` hasta `_offset` completo + `fetchFriendsStrip()` ante cualquier `INSERT` en `activity_feed`.
  3. `PostThreadController.submitComment` y `deleteComment` llaman a `fetchInteractions()` re-descargando todos los likes y comentarios sin actualización incremental.
- **Solución propuesta**: En paginación, re-agrupar solo la cola en la ventana de 60 minutos; refrescar en Realtime solo cuando el evento afecte a amigos/usuario visible; y actualizar comentarios localmente con la fila devuelta tras `submitComment`/`deleteComment`.

### [OPT-41] — `ImageFilter.blur` en transición de stories y `BoxShadow`/`ClipRRect` costosos en scroll de `activity/`
- **ID y Título**: `[OPT-41]` — `ImageFilter.blur` en transición de stories y `BoxShadow`/`ClipRRect` costosos en scroll de `activity/`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/activity/activity_story_viewer.dart:513-522, 699-718, 817, 947, 1078, 1210`, `lib/screens/activity/activity_screen.dart:733-741, 877, 893, 927`
- **Problema / Causa raíz**: `ActivityStoryViewer` aplica `ImageFilter.blur(sigmaX: 12, sigmaY: 12)` sobre la carátula en cada slide dentro de `AnimatedSwitcher` (costoso en GPU durante `SlideTransition`), junto con múltiples `BoxShadow` (`blurRadius: 10..16`) y `ClipRRect` alrededor del `LinearProgressIndicator` animado a 60–120fps; `ActivityScreen` también acumula múltiples `BoxShadow`/`ClipRRect` dentro de tarjetas en scroll.
- **Solución propuesta**: Reducir `sigmaX`/`sigmaY` o pre-cachear el fondo difuminado en `ActivityStoryViewer`, usar `BoxDecoration(borderRadius: ...)` en lugar de `ClipRRect` en las barras de progreso y limitar sombras en scroll.

### [OPT-42] — Caché `_sessionEnrichedData` sin cota, offset `+35` extra en `SearchScreen` y doble `SharedPreferences.getInstance()` en `GameDetailsController`
- **ID y Título**: `[OPT-42]` — Caché `_sessionEnrichedData` sin cota, offset `+35` extra en `SearchScreen` y doble `SharedPreferences.getInstance()` en `GameDetailsController`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/library/search_screen.dart:149, 329`, `lib/screens/library/game_details/game_details_controller.dart:26-27, 163, 283, 327, 415, 574`
- **Problema / Causa raíz**:
  1. En `SearchScreen`, el `offset` avanza siempre `+35` aunque IGDB devuelva `< 35` resultados, obligando a una petición HTTP extra vacía al final de la lista.
  2. `GameDetailsController._sessionEnrichedData` (`26-27`) es un `Map` estático sin límite máximo (LRU) ni limpieza al cerrar sesión, creciendo indefinidamente.
  3. `GameDetailsController` llama `SharedPreferences.getInstance()` dos veces en paralelo en `init()` (`283` y `327`), y retarda `fetchStashStats` con `Future.delayed(400ms)` (`163`).
- **Solución propuesta**: Fijar `hasMore = games.length == 35;` en `SearchScreen`, convertir `_sessionEnrichedData` en LRU acotada (máx. 50 entradas) limpiada en `resetAllGlobalState()`, y unificar la lectura de `SharedPreferences` en `init()`.

### [OPT-43] — Recompilación de 7 `RegExp` y 5 pasadas de filtrado en `GameLinksTab`, `shouldRebuild` siempre `true` en headers y `setState` por tecla en `SearchScreen`
- **ID y Título**: `[OPT-43]` — Recompilación de 7 `RegExp` y 5 pasadas de filtrado en `GameLinksTab`, `shouldRebuild` siempre `true` en headers y `setState` por tecla en `SearchScreen`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/library/game_details/game_links_tab.dart:28-73, 108-146, 324, 330`, `lib/screens/library/game_details/game_hero_section.dart:1178-1203`, `lib/screens/library/game_details/game_related_tab.dart:79-91`, `lib/screens/library/search_screen.dart:414-417`
- **Problema / Causa raíz**:
  1. `GameLinksTab._localizeUrlToSpain` instancia hasta 7 `RegExp` nuevos en cada llamada y se ejecuta 2 veces por enlace en `build` (`324`, `330`), filtrando `websitesList` cinco veces (`110-144`).
  2. `_GameDetailsHeaderDelegate.shouldRebuild` (`1197-1203`) compara instancias nuevas de `Widget` devolviendo `true` siempre, y `Opacity(opacity: titleOpacity)` (`1178`) fuerza `saveLayer`.
  3. `GameRelatedTab.build` (`79-91`) re-agrupa/re-ordena `relatedGames` en cada rebuild padre; `SearchScreen` (`414-417`) llama `setState(() {})` por cada pulsación de tecla solo para el botón limpiar.
- **Solución propuesta**: Elevar los `RegExp` y `Set<int>` a `static final`/`static const` y clasificar en un solo bucle; construir los hijos dentro del `SliverPersistentHeaderDelegate` y reemplazar `Opacity` por alfa en color; pre-agrupar `relatedGames` en el controller; y usar `ValueListenableBuilder` en `_searchController`.

### [OPT-44] — Parseo `Game.fromMap`, mutaciones in-place y búsquedas `O(N)` dentro de `build()` / `itemBuilder` en listas y grids
- **ID y Título**: `[OPT-44]` — Parseo `Game.fromMap`, mutaciones in-place y búsquedas `O(N)` dentro de `build()` / `itemBuilder` en listas y grids
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**:
  - `lib/screens/library/search_screen.dart:644`; `library_screen.dart:128`; `group_games_screen.dart:92`
  - `lib/screens/profile/profile_games_grid_tab.dart:498-536`; `achievement_games_screen.dart:640-653`
  - `lib/screens/profile/widgets/profile_games_overview.dart:188-198, 203-213`; `lib/screens/my_games/games_tab.dart:413-421`; `group_detail_screen.dart:626-633`; `collection_tab.dart:332-341`
  - `lib/widgets/horizontal_game_row.dart:123`; `lib/widgets/corpus_game_grid.dart:61`
- **Problema / Causa raíz**:
  1. Todas estas pantallas y widgets ejecutan `Game.fromMap(...)` dentro de `itemBuilder` / `SliverChildBuilderDelegate` en cada frame de scroll o rebuild, re-parseando listas, empresas y fechas en el hilo principal.
  2. `profile_games_grid_tab.dart:501-502` muta `gameData` durante `build()` y `527-535` inserta `SizedBox(height: screenHeight)` vacío; `achievement_games_screen.dart:644-649` aplica `ColorFiltered` (`saveLayer`) por cada tarjeta no completada.
  3. `GroupDetailScreen._buildGridView` ejecuta `allGroupItems.indexWhere(...)` en `itemBuilder` (`O(N²)`), y `CollectionTab.build` ejecuta `_items.where(...).length` por plataforma (`O(P×N)`).
- **Solución propuesta**: Pre-parsear `List<Game>` al recibir respuestas de red/BD, eliminar mutaciones en `build()`, sustituir `SizedBox(height: screenHeight)` por `SliverFillRemaining`, y precomputar `Map<String, int>` `rankByItemId` y `platformCounts`.

### [OPT-45] — Secuencialidad en `ProfileController.fetchProfileData()` y 2 `setState()` consecutivos en `ProfileGamesGridTab.loadMore()`
- **ID y Título**: `[OPT-45]` — Secuencialidad en `ProfileController.fetchProfileData()` y 2 `setState()` consecutivos en `ProfileGamesGridTab.loadMore()`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/profile_controller.dart:90-126`, `lib/screens/profile/profile_games_grid_tab.dart:250-262`
- **Problema / Causa raíz**: `ProfileController.fetchProfileData()` espera a `_repo.fetchProfileData(...)` antes de lanzar `_activityRepo.fetchRecentStoriesForUsers([targetUserId])`; y `ProfileGamesGridTab.loadMore()` ejecuta dos `setState()` seguidos (`250` y `254`), provocando 2 rebuilds completos del grid en página 0.
- **Solución propuesta**: Paralelizar `fetchRecentStoriesForUsers` junto con `fetchProfileData` vía `Future.wait` cuando `currentUserId != null`, y consolidar las actualizaciones en un único `setState()` al final de `loadMore()`.

### [OPT-46] — Re-filtrado de listas en `build()` / `itemBuilder`, `O(N*M)` y `RegExp` por tarjeta en logros, Hall of Fame y hojas de estantería
- **ID y Título**: `[OPT-46]` — Re-filtrado de listas en `build()` / `itemBuilder`, `O(N*M)` y `RegExp` por tarjeta en logros, Hall of Fame y hojas de estantería
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/achievements_screen.dart:390-400, 477-525, 609-642`, `lib/screens/profile/hall_of_fame_selector_screen.dart:127-132`, `lib/screens/profile/widgets/add_game_to_shelf_sheet.dart:73-80, 178, 194, 196`, `lib/screens/profile/widgets/bulk_add_to_shelf_sheet.dart:78-107, 291, 338, 357, 359`
- **Problema / Causa raíz**:
  1. `achievements_screen.dart:390-400` y `hall_of_fame_selector_screen.dart:127-132` recalculan `.where(...).toList()` con `.toLowerCase()` en cada `build()`.
  2. `achievements_screen.dart:477-525` compila `RegExp(r'_(\d+|all)$')` y recorre todo `_unlockedAchievements.entries` por cada tarjeta visible, además de envolver un `Builder` redundante (609–642).
  3. En `AddGameToShelfSheet` y `BulkAddToShelfSheet`, `_filtered` es un getter de 1–3 pasadas `.where(...).toList()` invocado repetidamente por `build()` y dentro de `itemBuilder` (`_filtered[index]`).
- **Solución propuesta**: Cachear listas filtradas y el mapa `groupId -> latestUnlockedDate` solo cuando cambien datos o búsqueda, mover `RegExp` a `static final`, eliminar el `Builder` redundante y calcular `final filtered = _filtered;` una vez fuera de `itemBuilder`.

### [OPT-47] — Doble recompresión / `MemoryImage` sin `ResizeImage`, archivos huérfanos en `EditProfileScreen` y `O(N²)` deduplicación en `AchievementGamesScreen`
- **ID y Título**: `[OPT-47]` — Doble recompresión / `MemoryImage` sin `ResizeImage`, archivos huérfanos en `EditProfileScreen` y `O(N²)` deduplicación en `AchievementGamesScreen`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/edit_profile_screen.dart:155-206, 237-250, 410, 482`, `lib/screens/profile/achievement_games_screen.dart:578-583`
- **Problema / Causa raíz**:
  1. `EditProfileScreen._pickImage` comprime en `ImagePicker` (`maxWidth: 1600, imageQuality: 85`), recorta con `ImageCropper` y vuelve a comprimir en `ImageCompressor.compressImage`; muestra `MemoryImage` sin `ResizeImage`; y al subir con timestamp nunca elimina el avatar/banner anterior de Supabase Storage.
  2. `AchievementGamesScreen` (`578-583`) hace `_results.any((r) => (r['id'] ?? r['igdb_id']) == gId)` por cada ítem nuevo (`O(N²)`).
- **Solución propuesta**: Evitar la recompresión redundante en `ImagePicker`, envolver `MemoryImage` en `ResizeImage.resizeIfNeeded`, borrar la ruta previa de Storage tras confirmar `update` en BD, y usar `Set<int> _seenResultIds` en `AchievementGamesScreen`.

### [OPT-48] — Coste de pintura/layout en scroll (`ClipRRect`, `BoxShadow`, `LayoutBuilder`, `ListView` sin `itemExtent`, listas eager) en `my_games/` y `profile/widgets/`
- **ID y Título**: `[OPT-48]` — Coste de pintura/layout en scroll (`ClipRRect`, `BoxShadow`, `LayoutBuilder`, `ListView` sin `itemExtent`, listas eager) en `my_games/` y `profile/widgets/`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/profile/widgets/shelf_game_box.dart:97-194`, `lib/screens/my_games/collection_tab.dart:317, 420-446, 496-501, 744-777`, `group_detail_screen.dart:661-666`, `groups_tab.dart:736, 810, 841`, `add_game_to_shelf_sheet.dart:192`, `bulk_add_to_shelf_sheet.dart:355, 508`, `platform_picker_sheet.dart:193`, `profile_games_overview.dart:184`
- **Problema / Causa raíz**: `ShelfGameBox` combina `BoxShadow` + `ClipRRect` + `LayoutBuilder` + `RotatedBox` + `FittedBox` por lomo; `CollectionTab`, `GroupDetailScreen` y `GroupsTab` apilan `BoxShadow` y `ClipRRect` en listas/grids; `add_game_to_shelf_sheet:192`, `bulk_add_to_shelf_sheet:355` y `profile_games_overview:184` carecen de `itemExtent`/`prototypeItem`; `_PlatformListSheet` y `_PlatformPickerSheet` usan `ListView(children: [...])` eagerly; y `ShelfSpineLayout.chunkIntoRows` recalcula en cada `build`.
- **Solución propuesta**: Sustituir `ClipRRect` por `BoxDecoration(borderRadius: ...)` donde aplique, añadir `RepaintBoundary` en `CollectionShelfRow`, fijar `itemExtent`/`prototypeItem` en `ListView.builder`, migrar listas de plataformas a `ListView.builder` y memoizar `chunkIntoRows`.

### [OPT-49] — Reconstrucciones excesivas por `ValueListenableBuilder`, `shouldRebuild` y listeners incondicionales de `TextEditingController` en `my_games/` y `profile/widgets/`
- **ID y Título**: `[OPT-49]` — Reconstrucciones excesivas por `ValueListenableBuilder`, `shouldRebuild` y listeners incondicionales de `TextEditingController` en `my_games/` y `profile/widgets/`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/widgets/profile_mobile_header.dart:59-80, 183-223`, `add_game_to_shelf_sheet.dart:103-112`, `platform_picker_sheet.dart:132-140`, `lib/screens/my_games/collection_tab.dart:56-58`, `games_tab.dart:45-47`, `groups_tab.dart:44-46`, `group_detail_screen.dart:58-60`
- **Problema / Causa raíz**:
  1. `_searchController.addListener(() => setState(...))` en 4 pantallas de `my_games/` dispara `setState` ante cambios de selección/foco sin cambiar el texto.
  2. `add_game_to_shelf_sheet:103` y `platform_picker_sheet:132` envuelven toda la hoja en `ValueListenableBuilder(floatingMobileNavNotifier)` en vez de solo el `Padding` inferior.
  3. `MobileProfileHeaderDelegate` reconstruye todo el header en cada píxel de `shrinkOffset`.
  4. `profile_mobile_header.dart:59-80` envuelve `ActivityStoryRing` en `ValueListenableBuilder<Set<String>>(valueListenable: viewedStoryIdsNotifier, ...)`, por lo que cualquier mutación global de `viewedStoryIdsNotifier` (incluso de historias de otros usuarios o cuando `stories.isEmpty` / `hasUnseenStory` para ese perfil no cambia) reconstruye el contenedor/anillo y recalcula `ActivityRepository.groupHasUnseenStory`.
- **Solución propuesta**: Comparar `if (next != _searchQuery)` en el listener del controller, acotar `ValueListenableBuilder(floatingMobileNavNotifier)` exclusivamente al espaciador inferior, y en `profile_mobile_header.dart:59-80` omitir la suscripción a `viewedStoryIdsNotifier` cuando `stories.isEmpty` o derivar un estado booleano acotado (`ValueNotifier<bool>` / selector) que solo reconstruya `ActivityStoryRing` cuando cambie `hasUnseenStory` para ese perfil.

### [OPT-50] — Re-ejecución completa de Fase 2 en `HomeController` ante `libraryUpdateNotifier` (sin caché ni separación de alcance)
- **ID y Título**: `[OPT-50]` — Re-ejecución completa de Fase 2 en `HomeController` ante `libraryUpdateNotifier` (sin caché ni separación de alcance)
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/home/controller/home_controller.dart:76-90, 221-293`, `lib/screens/home/home_screen.dart:77-80`
- **Problema / Causa raíz**: Cada incremento de `libraryUpdateNotifier` en `HomeScreen` ejecuta `reload()`, volviendo a lanzar las consultas globales de Fase 2 (`IGDBService.getMostAnticipatedGames`, `stash_community_reviews`, `active_bundles`) aunque únicamente haya cambiado la biblioteca personal del usuario (`playing` y `wishlist`).
- **Solución propuesta**: Separar un `reloadLibrarySections()` para `libraryUpdateNotifier` (actualizando solo Fase 1 y `wishlist`) de la recarga completa por pull-to-refresh, o cachear Fase 2 con un TTL corto en memoria.

### [OPT-51] — Ordenación/aplanado de bundles dentro de `PageView.builder` y 20 `AnimatedBuilder` en `_SectionShimmer` de `HomeScreen`
- **ID y Título**: `[OPT-51]` — Ordenación/aplanado de bundles dentro de `PageView.builder` y 20 `AnimatedBuilder` en `_SectionShimmer` de `HomeScreen`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/home/home_screen.dart:341-365, 508-552, 1086-1170`
- **Problema / Causa raíz**: `home_screen.dart:341-365` aplana `tiers` y ejecuta `allGames.sort(...)` dentro de `PageView.builder` en cada rebuild de `HomeScreen`; y `_SectionShimmer` (`1086-1170`) instancia 5 `AnimatedBuilder` independientes (hasta 20 simultáneos) que recalculan `Theme.of(context)` a 60 FPS por cada sección pendiente de Fase 2.
- **Solución propuesta**: Pre-aplanar y pre-ordenar los juegos de cada bundle en `HomeController` al recibir `active_bundles`, y unificar `_SectionShimmer` en un único `AnimatedBuilder` o `FadeTransition` por sección.

### [OPT-52] — Consulta duplicada de `fetchMyFriends()` y escaneo lineal `O(F)` en `FriendsScreen`
- **ID y Título**: `[OPT-52]` — Consulta duplicada de `fetchMyFriends()` y escaneo lineal `O(F)` en `FriendsScreen`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/social/friends_screen.dart:105-106, 346-348`, `lib/repositories/social_repository.dart:151-175`
- **Problema / Causa raíz**: `_loadFriends()` ejecuta `await _repo.fetchMyFriends()` (105) y luego `await _repo.fetchSentOrAcceptedIds()` (106), que vuelve a llamar `await fetchMyFriends()` internamente, duplicando las consultas de amistades en cada carga/refresco; además `_buildSearchTab()` (`346-348`) hace `_friends.any(...)` lineal por cada fila.
- **Solución propuesta**: Derivar `Set<String> _friendIds` desde `_friends` y consultar únicamente IDs pendientes enviados (o extraer método dedicado en `SocialRepository`), usando `_friendIds.contains(userId)` (`O(1)`).

### [OPT-53] — Proliferación de `Timer.periodic` en `P5rDynamicFrame`, triple renderizado de letras en `P5rRansomTitle` y parseo SVG por `build()` en `ProfileStatIcon`
- **ID y Título**: `[OPT-53]` — Proliferación de `Timer.periodic` en `P5rDynamicFrame`, triple renderizado de letras en `P5rRansomTitle` y parseo SVG por `build()` en `ProfileStatIcon`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**: `lib/widgets/p5r_dynamic_frame.dart:36-81`, `lib/widgets/p5r_styled_panel.dart:29-61`, `lib/widgets/p5r_ransom_title.dart:31, 226-318`, `lib/widgets/profile_stat_icon.dart:44-52`
- **Problema / Causa raíz**:
  1. Cada instancia de `P5rDynamicBackground` crea su propio `Timer.periodic(1800ms)` con `setState` + `ClipPath` independiente.
  2. `P5rRansomTitle` instancia `RegExp(r'\s+')` en cada `build()` y renderiza cada carácter 3 veces (`_LetterRow` x3 en `Stack`) con 15 widgets por letra (~25 veces/s junto a `TypewriterText` en `CorpusHeroTitle`).
  3. `ProfileStatIcon` ejecuta `SvgPicture.string(...)` en `build()` re-parseando XML SVG en cada rebuild.
- **Solución propuesta**: Sincronizar los frames P5R con un único `ValueNotifier<int>` compartido; mover `RegExp` a `static final` y usar `TextStyle.shadows` en `P5rRansomTitle`; y cachear `SvgStringLoader` estáticos en `ProfileStatIcon`.

### [OPT-54] — Reconstrucciones y asignaciones repetidas en `AppRoot`, `CorpusApp`, `globals.dart`, `IgdbConstants`, `ShelfPlatforms` y `GenreRadarCalculator`
- **ID y Título**: `[OPT-54]` — Reconstrucciones y asignaciones repetidas en `AppRoot`, `CorpusApp`, `globals.dart`, `IgdbConstants`, `ShelfPlatforms` y `GenreRadarCalculator`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/routes/app_root.dart:30-37`, `lib/main.dart:153-176`, `lib/globals.dart:81-103`, `lib/utils/igdb_constants.dart:144-145, 172-174`, `lib/utils/shelf_platforms.dart:394-404`, `lib/utils/genre_radar_calculator.dart:37`
- **Problema / Causa raíz**: `AppRoot.build` agenda `addPostFrameCallback((_) => dispatchCorpusReady())` en cada rebuild; `CorpusApp.build` recalcula ambos `ThemeData` cuando cambia `themeNotifier`; `getCorpusGridDelegate` instancia nuevos `SliverGridDelegate` en cada `build`; `IgdbConstants` instancia `RegExp(r'\bmod\b')` y mapea `categories` en cada acceso; `ShelfPlatforms.allIds`/`groupOrder` crean listas nuevas en cada getter; y `GenreRadarCalculator.aggregate` hace `list.any(...)` lineal por género.
- **Solución propuesta**: Mover `dispatchCorpusReady()` a un único disparo, cachear `RegExp` y listas constantes estáticas (`categories`, `allIds`, `groupOrder`) y usar `Set<int>` por género en `GenreRadarCalculator`.

### [OPT-55] — Instanciación innecesaria de `Game.fromMap` en `fetchGenreRadarEntries`, `jsonDecode` síncrono en `Game` y listas intermedias en `groupAndMergeByUser`
- **ID y Título**: `[OPT-55]` — Instanciación innecesaria de `Game.fromMap` en `fetchGenreRadarEntries`, `jsonDecode` síncrono en `Game` y listas intermedias en `groupAndMergeByUser`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Media
- **Ubicación**: `lib/repositories/profile_repository.dart:400`, `lib/models/game.dart:263, 284`, `lib/repositories/activity_repository.dart:1153-1157`
- **Problema / Causa raíz**:
  1. `ProfileRepository.fetchGenreRadarEntries` instancia un `Game` completo (`Game.fromMap`) solo para leer `genres` y `coverUrl`.
  2. `Game._parseStringList` y `_parseCollectionName` ejecutan `jsonDecode` síncronamente en el hilo de UI.
  3. `groupAndMergeByUser` reserva 3 listas intermedias (`take().toList().reversed.toList()`).
  4. Los repositorios carecen de caché en memoria / TTL / retry ante fallos transitorios (salvo Stash en BD).
- **Solución propuesta**: Extraer `genres` con un helper ligero sin instanciar `Game`, evitar listas intermedias en `groupAndMergeByUser` y evaluar `Isolate.run` para lotes grandes.

### [OPT-56] — `UserSettingsService.pullAndApplyToLocalCache`: `.select()` sin proyección de columnas
- **ID y Título**: `[OPT-56]` — `UserSettingsService.pullAndApplyToLocalCache`: `.select()` sin proyección de columnas
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/user_settings_service.dart:81-86`
- **Problema / Causa raíz**: Usa `.select()` sin columnas explícitas en lugar de `.select(syncKeys.join(','))`, transfiriendo columnas internas/extra innecesarias.
- **Solución propuesta**: Cambiar línea 83 a `.select(syncKeys.join(','))`.

### [OPT-57] — Múltiples `Shadow`s sobre texto en headers de perfil (`CurrentlyPlayingBadge` y `ProfileScreen`)
- **ID y Título**: `[OPT-57]` — Múltiples `Shadow`s sobre texto en headers de perfil (`CurrentlyPlayingBadge` y `ProfileScreen`)
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/currently_playing_badge.dart:128-149`, `lib/screens/profile/profile_screen.dart:1029-1035`
- **Problema / Causa raíz**: Ambos widgets aplican 4 objetos `Shadow` desplazados en diagonal para simular contorno negro sobre texto encima del banner.
- **Solución propuesta**: Sustituir las 4 sombras por un único `Shadow(blurRadius: 4, color: Colors.black87)` o un pill semitransparente detrás del badge.

### [OPT-58] — `ImportPreviewScreen`: recomputación múltiple de getters filtrados por cada `build()` y falta de `itemExtent`
- **ID y Título**: `[OPT-58]` — `ImportPreviewScreen`: recomputación múltiple de getters filtrados por cada `build()` y falta de `itemExtent`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/settings/import_preview_screen.dart:42-55, 127-140, 214-216, 235-237, 260, 422`
- **Problema / Causa raíz**: En cada `build()`, `ambiguousRows` y `notFoundRows` se invocan 3 veces y `allMatchedRows` 2 veces recorriendo `widget.rows` con `.toLowerCase()`; además `_buildMatchedTab` (260) y `_buildNotFoundTab` (422) usan `ListView.builder` sin `itemExtent`/`prototypeItem`.
- **Solución propuesta**: Calcular las listas filtradas una sola vez cuando cambien los filtros o al inicio de `build()`, y especificar `prototypeItem`/`itemExtent`.

### [OPT-59] — Triple `ListenableBuilder` sobre `themeNotifier` en `DesignScreen` / `DesignStylePacksSection` y `setState` redundante en `AppearanceScreen`
- **ID y Título**: `[OPT-59]` — Triple `ListenableBuilder` sobre `themeNotifier` en `DesignScreen` / `DesignStylePacksSection` y `setState` redundante en `AppearanceScreen`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/design/design_screen.dart:52-54`, `lib/screens/design/sections/design_style_packs_section.dart:20`, `lib/screens/appearance_screen.dart:281, 315, 334, 479, 504`, `lib/main.dart:153`
- **Problema / Causa raíz**: `CorpusApp` (`main.dart:153`) ya envuelve todo `MaterialApp` en `ListenableBuilder(listenable: themeNotifier)`, pero `DesignScreen` y `DesignStylePacksSection` añaden dos `ListenableBuilder` anidados al mismo `themeNotifier` y `AppearanceScreen` añade `setState(() {})` tras mutarlo, causando cascada redundante de rebuilds.
- **Solución propuesta**: Eliminar los `ListenableBuilder` y `setState(() {})` redundantes cuando el rebuild raíz ya propaga el nuevo tema.

### [OPT-60] — Asignaciones repetidas en `CustomPaint` (`_RadarPainter`, `_MilestoneBarPainter`), `GenreRadarSection` y `CorpusTabs`
- **ID y Título**: `[OPT-60]` — Asignaciones repetidas en `CustomPaint` (`_RadarPainter`, `_MilestoneBarPainter`), `GenreRadarSection` y `CorpusTabs`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/widgets/genre_radar_chart.dart:88-90, 144-171`, `lib/widgets/genre_radar_section.dart:105, 147`, `lib/widgets/milestone_progress_bar.dart:88, 149, 224-227`, `lib/widgets/design/corpus_tabs.dart:71-74, 110`
- **Problema / Causa raíz**: `_RadarPainter.paint()` instancia `Paint()` por vértice y `TextPainter` por etiqueta; `GenreRadarSection.build` recalcula `GenreRadarCalculator.aggregate(...)` en cada rebuild y usa `GridView.builder(shrinkWrap: true)` en el diálogo; `_MilestoneBarPainter.paint()` asigna `Paint()` en bucle y hace `save/clipPath/restore`; `CorpusTabs` usa `IntrinsicHeight` y `AnimatedSwitcher` mantiene dos subárboles de tab vivos durante la transición.
- **Solución propuesta**: Reutilizar `Paint` en ambos painters, memoizar `stats` en `_GenreRadarSectionState`, usar `ConstrainedBox` en lugar de `shrinkWrap` en el diálogo y simplificar la transición de `CorpusTabs`.

---

## 3. Mejoras Arquitectónicas y de Gran Escala

### [ARQ-01] — Acoplamiento directo masivo de la capa UI y Controllers a `Supabase.instance.client` y lógica de persistencia
- **ID y Título**: `[ARQ-01]` — Acoplamiento directo masivo de la capa UI y Controllers a `Supabase.instance.client` y lógica de persistencia
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Grande (Refactor estructural)
- **Ubicación**:
  - `lib/screens/activity/`: `activity_screen.dart:7, 47, 50, 114, 140, 281, 501, 608, 1235`; `activity_story_viewer.dart:11, 47, 132, 176, 185, 295, 338, 429`; `grouped_post_details_screen.dart:49, 223`; `review_details_screen.dart:4, 201, 306, 439, 562`; `review_details/review_details_controller.dart:15-16, 33` (`_reviewRepo.client`); `widgets/post_thread_controller.dart:57-58`
  - `lib/screens/library/`: `library_screen.dart:5, 22-31, 52-54`; `search_screen.dart:2, 183-186, 225-240`; `game_details_screen.dart:19, 237-241, 268-274`; `game_details/game_hero_section.dart:22, 172, 383`
  - `lib/screens/profile/`: `achievement_games_screen.dart:89, 94-102`; `collection_shelf_screen.dart:20`; `currently_playing_badge.dart:42, 96`; `edit_profile_screen.dart:97, 127, 131, 235, 240, 248, 263, 296, 316, 318, 333, 1080`; `hall_of_fame_selector_screen.dart:33, 39, 67, 74, 97, 104`; `profile_achievements_tab.dart:89-115`; `profile_games_grid_tab.dart:98-183, 238-241`; `profile_screen.dart:272, 314, 353, 469, 727, 893, 910, 1111, 1113`
  - `lib/screens/profile/widgets/` & `lib/screens/my_games/`: `platform_picker_sheet.dart:2, 88-93`; `games_tab.dart:3, 73-93`; `game_search_picker_sheet.dart:2, 67, 84-89`; `collection_tab.dart:2, 36, 50`; `groups_tab.dart:2, 35`; `group_detail_screen.dart:2, 40, 50`; `my_games_screen.dart:2, 29, 98`
  - `lib/screens/home/`, `settings/`, `auth/`: `home_controller.dart:60, 96, 106-127, 229-275`; `home_screen.dart:84`; `integrations_screen.dart:44-135`; `notifications_screen.dart:22, 42-100`; `steam_import_progress_screen.dart:43-92, 180`; `login_screen.dart:25-31`; `register_screen.dart:33-42`; `forgot_password_screen.dart:35`; `reset_password_screen.dart:46`
  - `lib/screens/main/` & `social/` & raíz: `settings_screen.dart:64, 91-121, 381`; `main_screen_controller.dart:19, 60-108, 120-234`; `notifications_feed_screen.dart:191`; `appearance_screen.dart:552-554, 651-653`
  - `lib/widgets/`: `friendship_button.dart:4, 23, 46-52, 80-84, 96-99, 111-114, 126-131`
- **Problema / Causa raíz**: Más de 40 pantallas, widgets hoja y controladores importan `supabase_flutter` directamente para ejecutar consultas SQL, mutaciones sobre tablas (`games`, `user_games`, `reviews`, `hall_of_fame`, `friendships`, `active_bundles`, `steam_import_jobs`), canales Realtime, Storage, `functions.invoke` y `SharedPreferences.getInstance()`, o instancian repositorios concretos inline (`ActivityRepository()`, `ReviewRepository()`). Esto rompe la separación UI ↔ Controller ↔ Repository, impide pruebas unitarias aisladas con mocks, dispersa el manejo de errores/timeouts y permite mutaciones directas sujetas a RLS desde la UI.
- **Solución propuesta**:
  1. Mover todas las consultas, mutaciones, Storage y Realtime a repositorios dedicados (`AuthRepository`, `HomeRepository`, `LibraryRepository`, `ProfileRepository`, `AchievementsRepository`, `IntegrationsRepository`, `NotificationsRepository`, `SocialRepository`).
  2. Inyectar repositorios y proveedor de `currentUserId` / sesión por constructor en controladores y pantallas (sin exponer `.client`), encapsulando también `SharedPreferences` dentro de `UserSettingsService`.

### [ARQ-02] — Estado global mutable en `lib/globals.dart` acoplado transversalmente a toda la aplicación
- **ID y Título**: `[ARQ-02]` — Estado global mutable en `lib/globals.dart` acoplado transversalmente a toda la aplicación
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Grande (Refactor estructural)
- **Ubicación**:
  - `lib/globals.dart:12-58, 75-78, 108-124`, `lib/main.dart:228-241`
  - `lib/screens/activity/`: `activity_screen.dart:46-50, 140, 1059-1060`
  - `lib/screens/library/`: `game_details_screen.dart:404`, `game_hero_section.dart:452`, `search_screen.dart:18-20, 64-89, 102-105, 616-617`, `review_modal.dart:1812-1816`
  - `lib/screens/profile/`: `profile_controller.dart:7, 121-124`, `profile_screen.dart:5, 97, 102, 108, 110, 149, 640, 969`, `profile_games_grid_tab.dart:8, 478, 481, 483`, `profile_reviews_tab.dart:7, 247`
  - `lib/screens/my_games/` & `profile/widgets/`: `my_games_screen.dart:35, 37, 42-43`, `collection_tab.dart:455`, `games_tab.dart:396`, `group_detail_screen.dart:610`, `profile_mobile_header.dart:60`, `add_game_to_shelf_sheet.dart:104`, `bulk_add_to_shelf_sheet.dart:630`, `platform_picker_sheet.dart:133`
  - `lib/screens/`: `settings_screen.dart:125, 187`, `main_screen_controller.dart:54-234`
  - `lib/widgets/`: `corpus_game_grid.dart:2, 113, 172`, `p5r_dynamic_frame.dart:6, 39`
- **Problema / Causa raíz**: Más de 15 `ValueNotifier` globales (`libraryUpdateNotifier`, `viewedStoryIdsNotifier`, `onlineUsersNotifier`, `unreadActivityCount`, `unreadFriendRequestsCount`, `unreadNotificationsCount`, `mobileGridColumnsNotifier`, `floatingMobileNavNotifier`, `tabScrollToTopNotifiers` con índices mágicos como `3`) y la variable mutable `kDisableCarouselForTests` viven como estado global sin contenedor de dependencias ni alcance de sesión. Esto crea acoplamiento oculto, provoca que algunas mutaciones olviden notificar (`deleteReview`), obliga a mantener manualmente `resetAllGlobalState()` y dificulta las pruebas unitarias.
- **Solución propuesta**: Migrar progresivamente a un contenedor de estado con ámbito de sesión (`SessionState` / `Provider` / `InheritedNotifier`) inyectado desde `CorpusApp`/`AuthGate` con `dispose()` automático al cerrar sesión, usar enums nominales para índices de pestañas, y pasar parámetros opcionales en widgets/tests en lugar de `kDisableCarouselForTests`.

### [ARQ-03] — Navegación Web personalizada frágil acoplada a `dart:html` y `dart:js_util` deprecados
- **ID y Título**: `[ARQ-03]` — Navegación Web personalizada frágil acoplada a `dart:html` y `dart:js_util` deprecados
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Grande (Refactor estructural)
- **Ubicación**: `lib/utils/web_js.dart:47-53`, `lib/utils/url_utils.dart:19`, `lib/utils/url_utils_stub.dart:1-53`, `lib/utils/js_util_stub.dart:1-11`, `lib/routes/app_navigation_controller.dart:12-633`, `pubspec.yaml:30`
- **Problema / Causa raíz**: Pese a tener `package:web: ^1.1.1` en `pubspec.yaml:30`, `web_js.dart` y `url_utils.dart` importan los obsoletos `dart:html` y `dart:js_util` junto con stubs manuales (`url_utils_stub.dart`, `js_util_stub.dart`), bloqueando la compilación Dart Wasm. Paralelamente, `AppNavigationController` replica manualmente el historial del navegador fuera de `RouterDelegate`/`go_router`.
- **Solución propuesta**: Migrar la capa de interoperabilidad Web a `package:web` + `dart:js_interop` (preservando el formato JSON-string de `history.state` mientras exista el router actual) y planificar la unificación hacia `MaterialApp.router` (`go_router` o `RouterDelegate` propio).

### [ARQ-04] — Riesgo de inyección en filtros PostgREST (`.or`, `orderColumn`) y comodines `ilike` sin escapar
- **ID y Título**: `[ARQ-04]` — Riesgo de inyección en filtros PostgREST (`.or`, `orderColumn`) y comodines `ilike` sin escapar
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/profile_repository.dart:230`, `lib/repositories/social_repository.dart:28, 186`, `lib/repositories/review_repository.dart:1477, 1494, 1507, 1511-1517, 1528-1535`, `lib/screens/profile/profile_games_grid_tab.dart:104`
- **Problema / Causa raíz**:
  1. Interpolación directa de `userId` / `friendId` en `.or('requester_id.eq.$userId,addressee_id.eq.$userId')` y `.or('and(requester_id.eq.$myId,addressee_id.eq.$friendId),...')`: si alguno contuviera `,`, `.`, `)` (p. ej. desde un deep link malicioso), podría alterar la expresión del filtro PostgREST.
  2. `searchQuery` y `query` no escapan `%`, `_` ni `\` en `.ilike(...)` (buscar `%` o `_` hace match con todos los registros), ni recortan `searchQuery.trim()` en `ReviewRepository`.
  3. `fetchJournalPage` y `fetchJournalYears` interpolan `orderColumn` sin validar contra una lista blanca de columnas permitidas.
- **Solución propuesta**: Validar formato UUID con `RegExp` antes de interpolar IDs en `.or(...)`, crear helper `escapeLikePattern(String input)` para `.ilike(...)` y validar `orderColumn` con un `enum` o `Set<String>` permitido (`{'created_at', 'updated_at', 'played_until'}`).

### [ARQ-05] — Riesgo de abuso en cliente: `NotificationService.sendTestNotification()` invoca `send-push-notification` pasando `tokens`, `title` y `body` arbitrarios
- **ID y Título**: `[ARQ-05]` — Riesgo de abuso en cliente: `NotificationService.sendTestNotification()` invoca `send-push-notification` pasando `tokens`, `title` y `body` arbitrarios
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Media
- **Ubicación**: `lib/services/notification_service.dart:326-353`
- **Problema / Causa raíz**: El cliente llama directamente a la Edge Function `send-push-notification` enviando `'tokens': [token]`, `'title'`, `'body'` y `'data'` en el cuerpo HTTP. Si dicha Edge Function confía en el array `tokens` proporcionado por el JWT del usuario autenticado (necesario para que este método funcione desde la app), cualquier usuario autenticado puede extraer su JWT y enviar notificaciones push arbitrarias/phishing a tokens FCM de terceros.
- **Solución propuesta**: Restringir `send-push-notification` al `service_role` (solo triggers/cron/backend) y crear una Edge Function dedicada `send-test-notification` (o validar en backend que el token pertenece a `auth.uid()` y fijar título/cuerpo en servidor).

### [ARQ-06] — Duplicación masiva móvil/escritorio (327 líneas) y widget extraído sin usar (`ReviewChoiceChip`) en `ReviewModal`
- **ID y Título**: `[ARQ-06]` — Duplicación masiva móvil/escritorio (327 líneas) y widget extraído sin usar (`ReviewChoiceChip`) en `ReviewModal`
- **Severidad / Impacto**: Alto
- **Escala del cambio**: Grande (Refactor estructural)
- **Ubicación**: `lib/screens/library/review_modal.dart:70, 118, 134, 340-478, 894-1197, 1350-1677`, `lib/screens/library/review_modal_widgets.dart:85-148`
- **Problema / Causa raíz**: `review_modal.dart` (1,822 líneas) define las funciones `buildTipoCompletadoSection`, `buildNotaSection`, `buildReseniaSection` y `buildInfoExtraSection` dentro de `build()` (`894-1197`) usadas únicamente en escritorio (`1678-1708`), mientras que la rama móvil (`1350-1677`) duplica exactamente el mismo código inline (con divergencias accidentales, como `ListView` horizontal vs `GridView.count` para imágenes). Además, `ReviewChoiceChip` fue extraído a `review_modal_widgets.dart:85-148`, pero `review_modal.dart` nunca lo usa y mantiene `chip(...)` (`340-392`), y `widget.isSaving` (`70, 118, 134`) está muerto.
- **Solución propuesta**: Descomponer `_ReviewModalContent` en sub-widgets privados compartidos entre móvil y escritorio, sustituir `chip(...)` por `ReviewChoiceChip` y eliminar el parámetro muerto `isSaving`.

### [ARQ-07] — Falta de validación cliente en mutaciones antes de enviar a Supabase y exposición de excepciones crudas en UI
- **ID y Título**: `[ARQ-07]` — Falta de validación cliente en mutaciones antes de enviar a Supabase y exposición de excepciones crudas en UI
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/social_repository.dart:70-79`, `lib/repositories/game_group_repository.dart:98-114, 160-175, 251-279, 310-315`, `lib/repositories/activity_repository.dart:530-560`, `lib/repositories/review_repository.dart:150-216`, `lib/repositories/collection_repository.dart:76-155`, `lib/screens/profile/edit_profile_screen.dart:295-330, 358-360, 603-615, 648-655`, `lib/screens/profile/hall_of_fame_selector_screen.dart:89, 119`
- **Problema / Causa raíz**:
  1. `sendFriendRequest` no impide `targetId == myId`; `createGroup`/`updateGroup` permiten `name.trim().isEmpty`; `submitComment` no recorta `content` ni valida contenido mínimo; `sanitizeReviewData` no acota `rating` (`1..10`), `progressPercent` (`0..100`), `playTimeHours >= 0`, `playedFrom <= playedUntil` ni `status` válido; `CollectionRepository` no valida `platformName.trim().isNotEmpty`.
  2. `EditProfileScreen` solo valida `username.length >= 3` sin espacios (permitiendo `/`, `@`, emojis) y `email.contains('@')`, y muestra excepciones crudas de `PostgrestException`/`AuthException` (`$e`) directamente en `SnackBar`.
- **Solución propuesta**: Añadir guardas de validación tipadas (`ArgumentError`/`FormatException` o `Form`) en repositorios y formularios (`username` con regex `^[a-zA-Z0-9_.-]{3,30}$`, email estándar), y mapear errores de Supabase/Auth a mensajes amigables ocultando `$e` en `debugPrint`.

### [ARQ-08] — Exposición potencial de columnas privadas de `users` mediante `select('*')`
- **ID y Título**: `[ARQ-08]` — Exposición potencial de columnas privadas de `users` mediante `select('*')`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/profile_repository.dart:96`, `lib/repositories/review_repository.dart:74, 120, 1127`, `lib/repositories/activity_repository.dart:494, 600`, `lib/repositories/notifications_repository.dart:131`
- **Problema / Causa raíz**: Cuando se consulta la tabla `users` para perfiles de terceros, comentarios o reseñas, `.select('*')` o `users(*)` descarga todas las columnas legibles por RLS (potencialmente `email`, `fcm_token`, `steam_id`, metadatos internos) en lugar de proyectar exclusivamente el perfil público.
- **Solución propuesta**: Restringir todas las lecturas de terceros sobre `users` a columnas públicas explícitas (`id, username, display_name, avatar_url, bio, xp, level`).

### [ARQ-09] — Duplicación extensa de lógica de negocio y consultas entre repositorios y modelos
- **ID y Título**: `[ARQ-09]` — Duplicación extensa de lógica de negocio y consultas entre repositorios y modelos
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Grande (Refactor estructural)
- **Ubicación**:
  - `partners`: `lib/repositories/review_repository.dart:86-114` vs `lib/repositories/activity_repository.dart:163-192, 326-355, 616-642` (omiten `display_name`)
  - Feed/stories: `lib/repositories/activity_repository.dart:115-197` vs `279-362`
  - `v_friend_pairs` + fallback `friendships`: `lib/repositories/review_repository.dart:1064-1097` vs `1305-1342` vs `lib/repositories/social_repository.dart:126-147` vs `lib/repositories/activity_repository.dart:216-245`
  - Upsert catálogo `games`: `lib/repositories/review_repository.dart:289-420` vs `lib/repositories/game_group_repository.dart:234-249`
  - Subida de imágenes: `lib/repositories/activity_repository.dart:540-550` vs `lib/repositories/review_repository.dart:423-444`
  - `effectiveRating`: `lib/models/review.dart:76-87` vs `lib/models/user_game.dart:58-69`
- **Problema / Causa raíz**: Cada repositorio reimplementa las mismas consultas, fallbacks y transformaciones con divergencias sutiles (omisión de `display_name`, diferencias en `upsertGame` vs `ensureGameInCatalog`, manejo de errores desigual).
- **Solución propuesta**: Extraer fuentes de datos/servicios compartidos (`FriendPairsDataSource`, `GameCatalogRepository`, `MediaUploadService`) e inyectarlos en los repositorios.

### [ARQ-10] — Violación de capas: `GameStatus` importa Flutter UI y uso generalizado de `Map<String, dynamic>` crudos en repositorios y widgets
- **ID y Título**: `[ARQ-10]` — Violación de capas: `GameStatus` importa Flutter UI y uso generalizado de `Map<String, dynamic>` crudos en repositorios y widgets
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Grande (Refactor estructural)
- **Ubicación**:
  - `lib/models/game_status.dart:1-2, 100-112, 154-173`
  - `lib/repositories/achievements_repository.dart:17, 23, 26`; `profile_repository.dart:23-38`; `activity_repository.dart:39, 48, 60, 685-1244`; `social_repository.dart:21, 38, 54, 126`; `notifications_repository.dart:22, 37-39`
  - `lib/screens/profile/widgets/profile_games_overview.dart:9-13, 203-213`; `profile_hall_of_fame.dart:11-12, 75-111`; `profile_mobile_header.dart:9, 35-37, 129-140`; `profile_sidebar_info.dart:8, 23-24`; `lib/screens/my_games/games_tab.dart:31-32`
- **Problema / Causa raíz**:
  1. `GameStatus` (en `lib/models/`) importa `package:flutter/material.dart` y `corpus_icon_kind.dart`, acoplando el dominio a widgets y `BuildContext`.
  2. Repositorios y widgets de perfil/`my_games` intercambian `Map<String, dynamic>` crudos con claves mágicas (`_post`, `_review`, `_partners`, `_is_group`, `_sort_date`, `'user_rating'`, `'completion_type'`, `'platforms'`), provocando crashes por casts. Además `ProfileHallOfFame` recibe `ProfileController` completo y replica la navegación.
- **Solución propuesta**: Mover `icon`/`color(BuildContext)` de `GameStatus` a una extensión UI (`lib/utils/game_status_ui.dart`), adoptar DTOs/modelos tipados (`UserProfile`, `Game`, `UserGame`) y desacoplar `ProfileHallOfFame` mediante `VoidCallback onReturn`.

### [ARQ-11] — Dependencia hardcodeada a `Supabase.instance.client` en repositorios y bypass de `_deleteImagesFromUrls` inyectado
- **ID y Título**: `[ARQ-11]` — Dependencia hardcodeada a `Supabase.instance.client` en repositorios y bypass de `_deleteImagesFromUrls` inyectado
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/repositories/achievements_repository.dart:36`, `lib/repositories/social_repository.dart:11`, `lib/repositories/activity_repository.dart:568`, `lib/repositories/review_repository.dart:535`
- **Problema / Causa raíz**: `AchievementsRepository` y `SocialRepository` no aceptan `SupabaseClient? client` en el constructor; y `ActivityRepository.deleteComment` / `ReviewRepository.saveReview` tienen `_deleteImagesFromUrls` inyectado para tests pero invocan `StorageUtils.deleteImagesFromUrls` estáticamente, impidiendo mocks en tests unitarios.
- **Solución propuesta**: Añadir `({SupabaseClient? client})` a ambos repositorios y reemplazar las llamadas estáticas en `activity_repository.dart:568` y `review_repository.dart:535` por `_deleteImagesFromUrls(...)`.

### [ARQ-12] — Violación de `@immutable` (listas mutables), `==`/`hashCode` incompletos o ausentes y `copyWith` incapaz de limpiar nulos en `lib/models/`
- **ID y Título**: `[ARQ-12]` — Violación de `@immutable` (listas mutables), `==`/`hashCode` incompletos o ausentes y `copyWith` incapaz de limpiar nulos en `lib/models/`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**: `lib/models/game.dart:61-67, 87-90, 94, 357-361`; `game_filters.dart:16-21`; `game_group.dart:28, 43-67`; `game_group_item.dart:33-53`; `review.dart:62, 65-66, 205-252, 255-260`; `user_game.dart:54`; `user_game_platform.dart`; `user_profile.dart:57-84`; `achievement.dart:63-67`; `genre_radar_entry.dart:22`; `genre_time_stat.dart:20`; `post_stats.dart:1`
- **Problema / Causa raíz**: Múltiples modelos anotados con `@immutable` almacenan listas mutables; `PostStats` omite `@immutable`; 8 modelos carecen de `==`/`hashCode` por valor; 4 modelos implementan `==` solo por `id` ocultando ediciones en diffs; y `copyWith` en 4 modelos no permite restablecer campos a `null`.
- **Solución propuesta**: Implementar igualdad por valor (`listEquals`) en `GameFilters` y `PostStats` (con `@immutable`), envolver listas en `List.unmodifiable` al construir desde `fromMap` y usar sentinels en `copyWith` o `freezed`.

### [ARQ-13] — Código muerto de alto volumen: `BundleService` (`lib/services/bundle_service.dart`) sin uso en producción
- **ID y Título**: `[ARQ-13]` — Código muerto de alto volumen: `BundleService` (`lib/services/bundle_service.dart`) sin uso en producción
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/bundle_service.dart:6-359`, `lib/screens/settings_screen.dart:334-335`
- **Problema / Causa raíz**: Todo `BundleService` (scraping HTTP directo a `https://barter.vg/bundles/json/` y caché `active_bundles_cache`) no tiene ningún caller en `lib/` (solo en `test/services/bundle_service_test.dart`), ya que la app migró a la tabla `active_bundles` en Supabase; además `settings_screen.dart:334-335` limpia claves obsoletas (`bundles_full_cache`).
- **Solución propuesta**: Deprecar/eliminar `lib/services/bundle_service.dart` y su test (o migrar helpers necesarios) y limpiar las claves obsoletas en `settings_screen.dart`.

### [ARQ-14] — Acoplamiento fuerte de `DeepLinkService` (`services/`) hacia UI (`screens/`), `NavigatorState` directo y duplicación con `DeepRouteResolver`
- **ID y Título**: `[ARQ-14]` — Acoplamiento fuerte de `DeepLinkService` (`services/`) hacia UI (`screens/`), `NavigatorState` directo y duplicación con `DeepRouteResolver`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**: `lib/services/deep_link_service.dart:8-11, 20-24, 81-168`, `lib/routes/deep_route_resolver.dart:179-204`
- **Problema / Causa raíz**: Un servicio en `lib/services/` importa 4 pantallas concretas (`search_screen.dart`, `grouped_post_details_screen.dart`, `review_details_screen.dart`, `game_details_screen.dart`), manipula `ExploreNavigation.targetQuery`, construye `MaterialPageRoute`s duplicando el ensamblaje de `DeepRouteResolver.buildRoute`, y empuja rutas a `navigatorKey` sin pasar por `CorpusRouter`.
- **Solución propuesta**: Unificar la construcción de rutas en `DeepRouteResolver` / `CorpusRouter` y hacer que `DeepLinkService` solo parsee el payload de notificación en un `TabDeepRoute` delegado al router.

### [ARQ-15] — `DuracionDeService`: falta de validación de entrada/sesión y cast inseguro de `response.data`
- **ID y Título**: `[ARQ-15]` — `DuracionDeService`: falta de validación de entrada/sesión y cast inseguro de `response.data`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/duracionde_service.dart:19-81`, `lib/screens/library/game_details/game_details_controller.dart:333-334`
- **Problema / Causa raíz**: `getTimeToBeat` no valida `igdbId > 0`, `title.trim().isNotEmpty` ni sesión; línea 75 castea `response.data as Map<String, dynamic>` sin comprobar `response.status == 200` ni soportar `String` JSON; líneas 46 y 49 hacen casts estrictos y comparan `DateTime.now().difference(checkedAt).inDays` sin normalizar a UTC ni proteger `diffDays < 0`; y el `try/catch` en 23–34 es redundante.
- **Solución propuesta**: Validar `igdbId > 0` y `title.trim().isNotEmpty`, comprobar `response.status == 200`, normalizar mapas y fechas UTC con `diffDays >= 0 && diffDays < _cacheDays`.

### [ARQ-16] — Validación de `pack.id` ausente en el flujo de importación de `StylePackImportService` / `StylePackRegistry`
- **ID y Título**: `[ARQ-16]` — Validación de `pack.id` ausente en el flujo de importación de `StylePackImportService` / `StylePackRegistry`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/style_pack_import_service.dart:40-47`, `lib/theme/style_pack_registry.dart:158-165`
- **Problema / Causa raíz**: Aunque `StylePackRegistry` valida las rutas internas del ZIP (`isSafeArchivePath`), `StylePackImportService` delega directamente en `importFromBundle` donde `installDir` se construye concatenando `pack.id` sin sanitizar (`p.join(base.path, 'style_packs', pack.id)`) y ejecuta `dir.delete(recursive: true)`. Un `manifest.json` malicioso con `"id": ".."` o caracteres de traversal podría intentar borrar/escribir fuera de `style_packs/`.
- **Solución propuesta**: Validar en `StylePackImportService` / `StylePackRegistry` que `pack.id` cumpla `RegExp(r'^[a-z0-9_-]{1,64}$')` antes de crear o borrar el directorio de instalación.

### [ARQ-17] — Override de estilos y rutas debug expuestos en builds de producción + config Firebase hardcodeada en Service Worker
- **ID y Título**: `[ARQ-17]` — Override de estilos y rutas debug expuestos en builds de producción + config Firebase hardcodeada en Service Worker
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**: `lib/utils/style_pack_url_override.dart:9-54`, `lib/theme/app_theme.dart:39, 72`, `lib/routes/corpus_router.dart:395-405`, `web/firebase-messaging-sw.js:8-15`
- **Problema / Causa raíz**: `StylePackUrlOverride` está documentado como `"Debug helper"`, pero `app_theme.dart` lo aplica sin comprobar `kDebugMode`, y `/style/<pack>` colisiona con `AppRoutes.tabIndexFromPublicPath`; `CorpusRouter` registra `AppRoutes.design` y `AppRoutes.privateCollection` sin guarda `kDebugMode`; y `web/firebase-messaging-sw.js:8-15` hardcodea credenciales de Firebase en vez de compartir fuente de configuración con `lib/env.dart`.
- **Solución propuesta**: Restringir `StylePackUrlOverride` y rutas debug con `kDebugMode` (o feature flag) y generar/inyectar la config del SW en build web.

### [ARQ-18] — Lógica de negocio de logros y mapeos de plataformas/estados duplicados entre `routes/`, `utils/`, `screens/` y `widgets/`
- **ID y Título**: `[ARQ-18]` — Lógica de negocio de logros y mapeos de plataformas/estados duplicados entre `routes/`, `utils/`, `screens/` y `widgets/`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**:
  - `lib/routes/deep_route_resolver.dart:206-284`, `lib/utils/achievement_utils.dart:3-48`, `lib/screens/profile/profile_achievements_tab.dart:27-70, 821-899, 938-996`, `lib/screens/profile/achievements_screen.dart:60-138, 168-226`
  - `lib/utils/igdb_constants.dart:343-466`, `lib/utils/shelf_platforms.dart:65-388`, `lib/screens/profile/widgets/profile_sidebar_info.dart:64-146`
  - `lib/screens/library/game_details/game_hero_section.dart:204-255, 480-502`, `lib/screens/library/game_details/game_reviews_card.dart:167-190`
- **Problema / Causa raíz**:
  1. `DeepRouteResolver`, `ProfileAchievementsTab`, `AchievementsScreen` y `AchievementsController` duplican `_achievementIgdbIds`, reglas de sagas/targets, mapeos de iconos/colores y parsing de `groupId`.
  2. La paleta e iconos de plataformas está duplicada con divergencias entre `IgdbConstants.getPlatformStyle`, `ShelfPlatforms.all` y `ProfileSidebarInfo._buildPlatformIcon`.
  3. `GameHeroSection` y `GameReviewsCard` reimplementan `switch` manuales de estado en vez de `GameStatus.colorForString`/`iconForString`/`labelForString` (omitiendo `'abandoned'` y `'on_hold'` en `_friendStatusColor`).
- **Solución propuesta**: Centralizar logros/sagas/estilos en `AchievementsRepository` + `AchievementUtils`, unificar metadatos de plataformas en `ShelfPlatforms`, y reutilizar `GameStatus` en toda la UI.

### [ARQ-19] — `ActivityStoryViewer` monolítico (1,334 líneas) sin controller dedicado
- **ID y Título**: `[ARQ-19]` — `ActivityStoryViewer` monolítico (1,334 líneas) sin controller dedicado
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Grande (Refactor estructural)
- **Ubicación**: `lib/screens/activity/activity_story_viewer.dart:43-1334`
- **Problema / Causa raíz**: `_ActivityStoryViewerState` mezcla en 1,334 líneas la navegación entre grupos/slides, animación de barra de progreso, persistencia de `story_views`, fetching de likes, envío optimista de likes/comentarios y el renderizado de 3 tipos de slides + barra inferior.
- **Solución propuesta**: Extraer `ActivityStoryController` (extendiendo `SafeChangeNotifier`) para estado/red/interacciones, y dividir los renderizadores de slide en widgets separados bajo `lib/screens/activity/widgets/`.

### [ARQ-20] — Duplicación extensiva de navegación adaptable de juegos, barras de acciones, respuestas y utilidades entre pantallas
- **ID y Título**: `[ARQ-20]` — Duplicación extensiva de navegación adaptable de juegos, barras de acciones, respuestas y utilidades entre pantallas
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**:
  - Navegación `GameDetailsScreen` (desktop push vs móvil modal): `activity_screen.dart:189-214, 555-580`, `activity_story_viewer.dart:368-393`, `game_related_tab.dart:15, 19, 126-159` vs `game_details_screen.dart:303-323, 694`, `hero_showcase.dart:15, 255-274`, `genre_radar_section.dart:7, 13, 25, 192-204`
  - Rutas Auth: `login_screen.dart:138-149` (`MaterialPageRoute(ForgotPasswordScreen)` vs `CorpusRouter`)
  - Barras de acción, respuestas y formatters: `grouped_post_details_screen.dart:188-218, 396-467, 516-539`, `review_details_screen.dart:138-168, 669-705, 1071-1152`, `activity_formatters.dart:9-36`, `comment_composer.dart:321-325`, `comment_thread_section.dart:345-349`
  - Parámetros/estado redundante en `GameDetails`: `game_hero_section.dart` (duplica 8 props de `controller`), `game_stash_tab.dart:32` vs `game_details_controller.dart:71` (`stashReviewLimit` perdido al cambiar tab), `game_details_controller.dart:851-866` (`UserSettingsService().push` sin `await`)
- **Problema / Causa raíz**:
  1. El patrón responsive desktop `pushGameDetails` vs móvil `showModalBottomSheet(GameDetailsScreen)` está copiado en 5 sitios distintos y `GameRelatedTab` ignora `onNavigateToGame`; `LoginScreen` navega con `MaterialPageRoute` a `ForgotPasswordScreen` saltándose `CorpusRouter`; y `GenreRadarSection` importa `GameDetailsScreen` directamente con un `AlertDialog` ad-hoc.
  2. `_startReply`, `_clearReplyTarget` y botones de Like/Comentario se duplican entre `ReviewDetailsScreen` y `GroupedPostDetailsScreen` pese a existir `PostActionBar`; la extracción de `coverUrl` se duplica entre `CommentComposer` y `CommentThreadSection`; y `ActivityFormatters.formatRelativeDate` duplica `formatDateRelative`.
  3. `GameHeroSection` recibe 8 parámetros ya presentes en `controller`, `GameStashTab` pierde `_stashReviewLimit` al desmontarse mientras `controller.stashReviewLimit` está muerto, y `reorderInfoTab`/`toggleInfoSection` disparan `UserSettingsService().push` sin `await`.
- **Solución propuesta**: Centralizar `openGameDetailsAdaptive(BuildContext, Game)` y `AppRoutes.forgotPassword` en `CorpusRouter`; reutilizar `PostActionBar` y estado de respuesta en `PostThreadController`; delegar `ActivityFormatters.formatRelativeDate` a `formatDateRelative`; y limpiar props redundantes en `GameHeroSection`/`GameStashTab`.

### [ARQ-21] — Privacidad y dependencia de punto único de fallo en proxy externo `images.weserv.nl` en `GameLinksTab`
- **ID y Título**: `[ARQ-21]` — Privacidad y dependencia de punto único de fallo en proxy externo `images.weserv.nl` en `GameLinksTab`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/library/game_details/game_links_tab.dart:315-316`
- **Problema / Causa raíz**: Todos los favicons de enlaces externos enrutan tráfico por el servicio público de terceros `images.weserv.nl` encadenado a `www.google.com/s2/favicons` (incluso cuando `domain` es `''`), introduciendo un punto único de fallo externo, latencia adicional y fuga de metadatos de navegación a terceros.
- **Solución propuesta**: Usar iconos locales (`CorpusTablerIcon(itemIcon)`) para tiendas/redes conocidas o servir favicons cacheados mediante una Edge Function propia de Supabase, evitando peticiones si `domain.isEmpty`.

### [ARQ-22] — Duplicación masiva de código entre los tres Heroes y entre las pantallas de apariencia
- **ID y Título**: `[ARQ-22]` — Duplicación masiva de código entre los tres Heroes y entre las pantallas de apariencia
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/home/hero_showcase.dart:33-604, 688-995, 1071-1291`, `lib/screens/settings/home_appearance_screen.dart:18-133, 293-359`, `lib/screens/settings/info_tab_appearance_screen.dart:19-128, 166-245`, `lib/screens/home/controller/home_controller.dart:177-203`
- **Problema / Causa raíz**: `HeroShowcase`, `GuestHeroShowcase` y `EmptyPlayingHero` duplican ~300 líneas casi idénticas (3 `AnimationController`, `Timer.periodic`, crossfade, layout portrait/landscape y degradado); y `HomeAppearanceScreen` + `InfoTabAppearanceScreen` + `HomeController` duplican `defaultOrder`, carga/guardado de `SharedPreferences` + `UserSettingsService` y tarjetas `ReorderableListView`.
- **Solución propuesta**: Extraer un widget base `_BaseHeroBackdrop` para el carrusel de fondo, y centralizar claves/`defaultOrder` y el editor de secciones reordenables.

### [ARQ-23] — Datos de perfil estáticos (`widget.userProfile` / `hallOfFame`) obsoletos en `SettingsScreen`
- **ID y Título**: `[ARQ-23]` — Datos de perfil estáticos (`widget.userProfile` / `hallOfFame`) obsoletos en `SettingsScreen`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Media
- **Ubicación**: `lib/screens/settings_screen.dart:14-15, 177-179`
- **Problema / Causa raíz**: `SettingsScreen` recibe `userProfile` y `hallOfFame` como mapas inmutables en el constructor y los reenvía a `context.pushEditProfile(widget.userProfile, widget.hallOfFame)` (178). Si el usuario edita su perfil, vuelve a `SettingsScreen` y vuelve a entrar en `'Cuenta'`, recibirá los datos antiguos del snapshot inicial.
- **Solución propuesta**: Retornar los datos actualizados desde `EditProfileScreen` para actualizar el estado en `SettingsScreen`, o cargar el perfil desde un repositorio/cache compartido.

### [ARQ-24] — Fragmentación del Design System y duplicación de componentes equivalentes en `lib/widgets/`
- **ID y Título**: `[ARQ-24]` — Fragmentación del Design System y duplicación de componentes equivalentes en `lib/widgets/`
- **Severidad / Impacto**: Medio
- **Escala del cambio**: Grande (Refactor estructural)
- **Ubicación**: `lib/widgets/corpus_primary_button.dart:1-124` vs `lib/widgets/design/corpus_button.dart:1-289`, `lib/widgets/design/corpus_card.dart:1-52` vs `lib/widgets/p5r_styled_panel.dart:104-149`, `lib/widgets/horizontal_game_row.dart:32-93, 145-196` vs `lib/widgets/explore_bundle_row.dart:23-76, 304-359`, `lib/widgets/design/corpus_badge.dart:22-37` vs `lib/widgets/game_card.dart:345, 456-529`, `lib/widgets/corpus_nav_icon.dart:2, 34-58`, `lib/widgets/guest_login_prompt.dart:56, 88`
- **Problema / Causa raíz**: Coexisten APIs paralelas para botones primarios (`CorpusPrimaryButton` usado por `GuestLoginPrompt`/`HeroShowcase`/`GameHeroSection` vs `CorpusButton`) y tarjetas (`CorpusCard` solo en demo vs `CorpusStyledPanel` en producción); `HorizontalGameRow` y `ExploreBundleRow` copian íntegramente las flechas de scroll en desktop; `GameCard` usa `Icons.*` de Material en vez de `CorpusTablerIcon` y duplica el badge de Metacritic con colores divergentes de `CorpusBadge.metacritic`; y `CorpusNavIcon` acopla `liquid_glass_easy` al catálogo de iconos.
- **Solución propuesta**: Unificar `CorpusPrimaryButton` en `CorpusButton`, unificar `CorpusCard` y `CorpusStyledPanel`, extraer `DesktopHorizontalScrollWrapper`, usar `CorpusBadge.metacritic` + `CorpusTablerIcon` en `GameCard` y separar `corpusNavTabItem` del archivo de iconos.

### [ARQ-25] — Código muerto detectado en `lib/models/` y `lib/widgets/`
- **ID y Título**: `[ARQ-25]` — Código muerto detectado en `lib/models/` y `lib/widgets/`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/models/user_game_platform.dart:1-37`, `lib/models/user_game.dart:1-140`, `lib/models/game_group.dart:142-162`, `lib/models/game_group_item.dart:85-92`, `lib/models/review.dart:151-173`, `lib/models/game_status.dart:128-129`, `lib/widgets/vertical_tier_label.dart:1-42`, `lib/widgets/explore_bundle_row.dart:10, 13`, `lib/widgets/tabler_icons.dart:153`, `lib/widgets/design/corpus_dialog.dart:51-55`
- **Problema / Causa raíz**: Existen modelos, métodos (`toInsertMap`/`toUpdateMap` desincronizado con `sanitizeReviewData`, `isFinished`), widgets (`VerticalTierLabel`), exports (`tabler.Users`) y ramas (`switch` en `CorpusDialog:51-55` con 3 ramas devolviendo `primary`) sin uso funcional en `lib/`.
- **Solución propuesta**: Adoptar los métodos de serialización que correspondan en repositorios o eliminar el código muerto tras validar cobertura en `test/`, y añadir variante destructiva real en `CorpusButton` eliminando el `switch` muerto de `CorpusDialog`.

### [ARQ-26] — Telemetría silenciosa de errores internos en `NotificationService.saveFcmToken()` hacia `client_error_log`
- **ID y Título**: `[ARQ-26]` — Telemetría silenciosa de errores internos en `NotificationService.saveFcmToken()` hacia `client_error_log`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/notification_service.dart:238-251`
- **Problema / Causa raíz**: Al fallar `saveFcmToken()`, inserta `e.toString()` en `client_error_log` incluso si `uid == null` o si el fallo fue falta de conectividad (disparando otra petición fallida), persistiendo mensajes sin truncar ni sanitizar.
- **Solución propuesta**: Solo registrar si `uid != null` y el error no es un fallo de red offline, truncando y sanitizando el mensaje.

### [ARQ-27] — `UserSettingsService`: claves sin validar en `push()` y duplicación de `defaults` respecto a `ThemeNotifier`/`globals.dart`
- **ID y Título**: `[ARQ-27]` — `UserSettingsService`: claves sin validar en `push()` y duplicación de `defaults` respecto a `ThemeNotifier`/`globals.dart`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Media
- **Ubicación**: `lib/services/user_settings_service.dart:16-63, 104-120`, `lib/globals.dart:120-121`, `lib/theme/app_theme.dart:18-19, 64-66`
- **Problema / Causa raíz**: `push(changedKeys)` no comprueba que las claves pertenezcan a `syncKeys`, pudiendo dejar `_pending` atascado reintentando columnas inexistentes (400); y los valores por defecto (`mobile_grid_columns: 3`, `floating_mobile_nav: true`, `style_pack_id: 'default'`) están duplicados en tres lugares.
- **Solución propuesta**: Filtrar `changedKeys` contra `syncKeys.toSet()` al inicio de `push()` y centralizar las constantes de defaults.

### [ARQ-28] — `IGDBService`: IDs mágicos hardcodeados para estudios (`developer = true`) y falta de invalidación de caché en producción
- **ID y Título**: `[ARQ-28]` — `IGDBService`: IDs mágicos hardcodeados para estudios (`developer = true`) y falta de invalidación de caché en producción
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/igdb_service.dart:15-19, 514-528`
- **Problema / Causa raíz**: Los 10 IDs `[37, 129, 1012, 26, 56, 305, 401, 908, 170, 769]` aparecen sin nombres ni constantes documentadas; y `clearCache()` tiene `@visibleForTesting` aunque podría requerirse en logout o pull-to-refresh.
- **Solución propuesta**: Extraer a un `const Map<int, String>` / `Set<int>` documentado (junto a `AchievementUtils.achievementIgdbIds`) y exponer limpieza de caché en recargas forzadas.

### [ARQ-29] — Duplicación de buscadores (`CorpusSearchField`), diálogos (`GroupFormDialog`), avatares (`CorpusUserAvatar`) y diseño de `DesignScreen`
- **ID y Título**: `[ARQ-29]` — Duplicación de buscadores (`CorpusSearchField`), diálogos (`GroupFormDialog`), avatares (`CorpusUserAvatar`) y diseño de `DesignScreen`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Media
- **Ubicación**:
  - Buscadores: `profile_games_grid_tab.dart:324-372`, `profile_journal_tab.dart:295-338`, `profile_reviews_tab.dart:176-220`, `add_game_to_shelf_sheet.dart:150-171`, `bulk_add_to_shelf_sheet.dart:240-262`, `collection_tab.dart:264-301`, `games_tab.dart:237-274`, `groups_tab.dart:332-369`, `group_detail_screen.dart:534-571`, `game_search_picker_sheet.dart:183-217`
  - Diálogo colección: `groups_tab.dart:878-979` vs `group_detail_screen.dart:295-353`
  - Avatares: `friends_screen.dart:275-286`, `notifications_feed_screen.dart:294-307`, `user_friends_screen.dart:52-59`
  - `DesignScreen`: `design_screen.dart:61-63`, `design_buttons_section.dart:26-108`, `design_feedback_section.dart:118`, `design_surfaces_section.dart:51, 57`
- **Problema / Causa raíz**: 10 pantallas replican el mismo `TextField` de búsqueda + `Debouncer`; `GroupDetailScreen` duplica `_GroupFormDialog` de `GroupsTab`; 3 pantallas sociales duplican `CircleAvatar` con validaciones divergentes; `DesignScreen` carece de `AppBar`/botón Atrás y sus demos usan callbacks `() {}` sin feedback.
- **Solución propuesta**: Extraer `CorpusSearchField`, `GroupFormDialog` y `CorpusUserAvatar` compartidos; añadir `AppBar` con `requestBack` y feedback breve en `DesignScreen`.

### [ARQ-30] — Constante de breakpoint duplicada (`800` vs `kDesktopBreakpoint`) y versión de la app hardcodeada en `InfoScreen`
- **ID y Título**: `[ARQ-30]` — Constante de breakpoint duplicada (`800` vs `kDesktopBreakpoint`) y versión de la app hardcodeada en `InfoScreen`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/globals.dart:87`, `lib/screens/appearance_screen.dart:110, 485`, `lib/screens/main_screen.dart:1012`, `lib/screens/design/design_screen.dart:58`, `lib/screens/library/game_details_screen.dart:303, 705`, `lib/screens/activity/` (7 archivos), `lib/screens/info_screen.dart:46, 195`
- **Problema / Causa raíz**: Pese a existir `kDesktopBreakpoint = 800.0` en `globals.dart:8`, más de una decena de archivos hardcodean `800` con comparadores inconsistentes (`<= 800`, `> 800`, `>= 800`); además `InfoScreen` hardcodea `'Versión 1.3.1'` (desfasable frente a `pubspec.yaml`) y usa `SizedBox(height: 100)` en lugar de `getBottomSpacer(context)`.
- **Solución propuesta**: Reemplazar todos los literales `800` por `kDesktopBreakpoint`, usar `getBottomSpacer(context)` en `InfoScreen:195` y obtener la versión desde `PackageInfo.fromPlatform()` o constante centralizada.

---

## 4. Micro-optimizaciones y Deuda Técnica

### [MICRO-01] — Inconsistencias en `CorpusIconKind` (UpperCamelCase y duplicados) y mapeo de `corpus_tabler_icon_builders.dart`
- **ID y Título**: `[MICRO-01]` — Inconsistencias en `CorpusIconKind` (UpperCamelCase y duplicados) y mapeo de `corpus_tabler_icon_builders.dart`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Media
- **Ubicación**: `lib/widgets/corpus_icon_kind.dart:3-220`, `lib/widgets/corpus_tabler_icon_builders.dart:34-255`
- **Problema / Causa raíz**: Los valores del enum usan `UpperCamelCase` en lugar de `lowerCamelCase` estándar en Dart; numerosos valores distintos mapean al mismo icono Tabler, y varias variantes `Outlined`/`Off` mapean a iconos rellenos o activos (`DeleteOutline` -> `TrashFilled`, `CancelOutlined` -> `CircleXFilled`, `PaletteOutlined` -> `PaletteFilled`, `VideogameAssetOff` -> `DeviceGamepad`).
- **Solución propuesta**: Consolidar variantes duplicadas en `CorpusIconKind`, corregir los mapeos outline/off para respetar su semántica visual y normalizar a `lowerCamelCase`.

### [MICRO-02] — `CorpusLogger` sin usar en todo el proyecto y sin silenciar niveles en release
- **ID y Título**: `[MICRO-02]` — `CorpusLogger` sin usar en todo el proyecto y sin silenciar niveles en release
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/utils/corpus_logger.dart:1-59`
- **Problema / Causa raíz**: `CorpusLogger` tiene 0 usos en todo `lib/`, mientras el proyecto sigue usando `debugPrint` directo. Además su documentación afirma erróneamente que `debugPrint` se elimina en release (solo `debug()` verifica `kDebugMode`, mientras `info`/`warning`/`error` imprimen también en release).
- **Solución propuesta**: Adoptar `CorpusLogger` progresivamente (o eliminarlo si no se usará) y proteger `_print` con `kDebugMode` / `kReleaseMode` según nivel.

### [MICRO-03] — Uso de `print()` en lugar de `debugPrint()` / `CorpusLogger` en servicios
- **ID y Título**: `[MICRO-03]` — Uso de `print()` en lugar de `debugPrint()` / `CorpusLogger` en servicios
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/bundle_service.dart:98`, `lib/services/igdb_service.dart:379, 481, 578, 607, 711`, `lib/services/import_service.dart:311`
- **Problema / Causa raíz**: Usan `print(...)` en producción violando la regla `avoid_print` en `analysis_options.yaml` en lugar de `debugPrint(...)` o `CorpusLogger` (cuyo comentario en `corpus_logger.dart:25` cita explícitamente `'BundleService'`).
- **Solución propuesta**: Reemplazar por `debugPrint` o `CorpusLogger`.

### [MICRO-04] — Código muerto en `AppNavigationController.syncBrowserHistoryAfterProgrammaticPop` y deuda menor en rutas, hashing, `StorageUtils`, `manifest.json` e `index.html`
- **ID y Título**: `[MICRO-04]` — Código muerto en `AppNavigationController.syncBrowserHistoryAfterProgrammaticPop` y deuda menor en rutas, hashing, `StorageUtils`, `manifest.json` e `index.html`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/routes/app_navigation_controller.dart:305-310`, `lib/main.dart:381`, `lib/routes/tab_deep_route.dart:153, 168`, `lib/routes/app_routes.dart:39`, `lib/utils/storage_utils.dart:9-37`, `web/manifest.json:9`, `web/index.html:7`
- **Problema / Causa raíz**:
  1. `syncBrowserHistoryAfterProgrammaticPop()` tiene 0 invocaciones y si se llamara dejaría `_isProgrammaticBack = true` rompiendo el siguiente `popstate`.
  2. `lib/main.dart:381` contiene un `catch (_) {}` vacío; `tab_deep_route.dart:153,168` devuelve `hashCode => 1;` constante en `FriendsDeepRoute` y `NotificationsFeedDeepRoute`; `app_routes.dart:39` mapea `'bundles' => 1`, pero `subSegmentsFromPublicPath('/bundles/<id>')` no coincide con `['bundle', '<id>']`.
  3. `StorageUtils` extrae paths con `split('/user_uploads/')` sin limpiar `#fragment` ni devolver `bool`; `web/manifest.json:9` fija `"orientation": "portrait-primary"` incluso en desktop/tablet; y `web/index.html:7` bloquea el zoom accesible (`maximum-scale=1.0, user-scalable=no`).
- **Solución propuesta**: Eliminar `syncBrowserHistoryAfterProgrammaticPop()` y `_isProgrammaticBack`, usar `runtimeType.hashCode`, normalizar legacy `/bundles/<id>`, usar `Uri.parse` + retorno `bool` en `StorageUtils`, y revisar orientación y zoom accesible.

### [MICRO-05] — Asignaciones innecesarias de listas en getters de `lib/models/` y `ReviewRepository`, casteos repetidos y reordenamiento redundante
- **ID y Título**: `[MICRO-05]` — Asignaciones innecesarias de listas en getters de `lib/models/` y `ReviewRepository`, casteos repetidos y reordenamiento redundante
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/models/review.dart:76-87`, `lib/models/user_game.dart:58-69, 134-135`, `lib/models/game_group.dart:31-41`, `lib/models/game.dart:6-8, 160-164, 175`, `lib/models/achievement.dart:58`, `lib/repositories/review_repository.dart:208, 1486, 1522`, `lib/repositories/profile_repository.dart:329-334, 394-395`, `lib/repositories/activity_repository.dart:15, 24-25, 1153-1157`, `lib/repositories/achievements_repository.dart:31`
- **Problema / Causa raíz**:
  1. `effectiveRating` (`review.dart`, `user_game.dart`) y `previewGames` (`game_group.dart`) crean listas en cada acceso; `game.dart:175` y `review_repository.dart:208` asignan `[]` no constante.
  2. `game.dart:6-8` tiene un comentario partido por `import 'dart:convert';` y líneas `160-164` buscan/castean `map['metacritic_user_score']` 4 veces; `achievement.dart:58` y `user_game.dart:134-135` usan `?.` redundantes tras null-check; `profile_repository.dart:394-395` y `review_repository.dart:1486, 1522` repiten filtros ya garantizados por PostgREST; y `achievements_repository.dart:31` dice "4 queries" cuando son 5.
  3. `ProfileRepository._enrichList` reordena en Dart listas ya ordenadas por Supabase; `activity_repository.dart` importa `post_stats.dart` directo en vez de `models/models.dart`.
- **Solución propuesta**: Sumar/contar sin `.toList()`, usar `const []`, extraer variables locales, eliminar `?.` y filtros redundantes, unificar import al barrel y corregir comentarios.

### [MICRO-06] — Import no utilizado `dart:async` en `DeepLinkService`, recompilación de `RegExp` y `.split(' ')` en `IGDBService` / `BundleService`
- **ID y Título**: `[MICRO-06]` — Import no utilizado `dart:async` en `DeepLinkService`, recompilación de `RegExp` y `.split(' ')` en `IGDBService` / `BundleService`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/deep_link_service.dart:1`, `lib/services/igdb_service.dart:216-241, 623, 629, 646`, `lib/services/bundle_service.dart:134-137`
- **Problema / Causa raíz**: `deep_link_service.dart:1` importa `dart:async` sin uso; `IGDBService.decodeHtmlEntities` (623, 629) y `BundleService._readPrice` (134–137) instancian `RegExp` en cada invocación; y `IGDBService.searchGames`/`searchGameLenient` (241, 646) usan `.split(' ')` que no separa tabuladores ni saltos de línea.
- **Solución propuesta**: Eliminar `import 'dart:async';`, mover los `RegExp` a `static final RegExp` y usar `.split(RegExp(r'\s+'))`.

### [MICRO-07] — `ImportService.matchGamesWithIGDB` ejecuta `Future.delayed(200ms)` tras el último lote y notifica progreso tras cancelar
- **ID y Título**: `[MICRO-07]` — `ImportService.matchGamesWithIGDB` ejecuta `Future.delayed(200ms)` tras el último lote y notifica progreso tras cancelar
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/import_service.dart:317-320`
- **Problema / Causa raíz**: Incluso al terminar el último chunk (`end == total`) o si `isCancelled()` pasó a `true` durante el `Future.wait`, llama a `onProgress` y espera 200ms innecesariamente.
- **Solución propuesta**: Comprobar `if (isCancelled != null && isCancelled()) return;` tras `Future.wait` y añadir `if (end < total) await Future.delayed(...)`.

### [MICRO-08] — Deuda menor en `NotificationService`, `IGDBService._getSteamSourceId()`, `DeepLinkService` y `BundleService`
- **ID y Título**: `[MICRO-08]` — Deuda menor en `NotificationService`, `IGDBService._getSteamSourceId()`, `DeepLinkService` y `BundleService`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/services/notification_service.dart:39-40, 82, 155-158, 286, 396-406`, `lib/services/igdb_service.dart:359-382`, `lib/services/deep_link_service.dart:58-60, 86, 147`, `lib/services/bundle_service.dart:89-101, 189-194, 354-357`
- **Problema / Causa raíz**:
  1. `NotificationService`: GUID placeholder en Windows Toast (`82`), `_isSupported` excluye `Platform.isIOS` pese a configurar parámetros iOS, y `showNotification` usa `id = 0` por defecto sobrescribiendo avisos previos.
  2. `IGDBService._getSteamSourceId()` castea `steamSource['id'] as int` sin guard `num`.
  3. `DeepLinkService` no muestra ningún feedback visual si el recurso ya no existe o falla la red.
  4. `BundleService.getCachedBundles()` carece de TTL (si no se elimina en `[ARQ-13]`).
- **Solución propuesta**: Verificar GUID de Windows y soporte iOS, usar ID único en `showNotification`, castear con `(steamSource['id'] as num?)?.toInt()`, y mostrar `SnackBar` discreto en `DeepLinkService` cuando falle la resolución.

### [MICRO-09] — Código muerto, comentarios obsoletos y parámetros/controladores sin usar en `screens/`
- **ID y Título**: `[MICRO-09]` — Código muerto, comentarios obsoletos y parámetros/controladores sin usar en `screens/`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**:
  - `lib/screens/activity/`: `post_thread_controller.dart:60-65` (`updatePostId`), `activity_controller.dart:218-219`, `activity_screen.dart:992`, `review_details_screen.dart:1199`
  - `lib/screens/library/`: `game_details_screen.dart:39, 42-43, 88-90, 114-115, 336, 343, 416, 636-644` (`_commentController`, `_ratingController`, `_isSaving`, `hasRelated`), `game_info_tab.dart:24, 48` (`developer`), `game_reviews_card.dart:19, 23, 30, 35` (`partnersData`, `onShowFriendActivity`), `game_details_controller.dart:71` (`stashReviewLimit`), `review_modal.dart:70, 118, 134` (`isSaving`), `library_screen.dart:39-48` (botón Buscar stub)
  - `lib/screens/profile/`: `achievements_controller.dart:199` y `profile_achievements_tab.dart:318` (parámetro `achievementsList` sin uso), `profile_screen.dart:887`
  - `lib/screens/my_games/`: `my_games_screen.dart:21, 50, 148-149` (`_refreshSeed`), `games_tab.dart:19, 24, 309` (`scrollController`, `totalCount`)
  - `lib/screens/home/` & `settings/`: `hero_showcase.dart:608` (`gameData`), `home_screen.dart:1087, 1149` (`label`, param `child`), `home_appearance_screen.dart:44-45, 152-169`, `import_preview_screen.dart:176-177` (APIs deprecadas `RadioListTile.groupValue`, `DropdownButtonFormField.value`), `home_controller.dart:179`
- **Problema / Causa raíz**: Restos de refactors previos dejaron métodos, controladores, parámetros, comentarios y `// ignore: deprecated_member_use` sin uso que provocan asignaciones y rebuilds innecesarios (`_refreshSeed`, `_commentController`, `_ratingController`).
- **Solución propuesta**: Eliminar código, campos, parámetros y comentarios muertos, y migrar `RadioListTile`/`DropdownButtonFormField` a `RadioGroup`/`initialValue`.

### [MICRO-10] — Uso de `MediaQuery.of(context)` completo en lugar de `MediaQuery.sizeOf` / `viewInsetsOf` / `paddingOf` / `devicePixelRatioOf`
- **ID y Título**: `[MICRO-10]` — Uso de `MediaQuery.of(context)` completo en lugar de `MediaQuery.sizeOf` / `viewInsetsOf` / `paddingOf` / `devicePixelRatioOf`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**:
  - `lib/screens/activity/`: `activity_screen.dart:190, 556`, `comment_composer.dart:133, 140`, `comment_thread_section.dart:43`, `grouped_post_details_screen.dart:517`, `review_details_screen.dart:432, 671`
  - `lib/screens/library/`: `game_details_screen.dart:303, 705`, `review_modal.dart:89, 338, 1206`, `game_hero_section.dart:961`, `game_info_tab.dart:251`, `game_related_tab.dart:136`
  - `lib/screens/profile/`: `achievements_screen.dart:235, 469`, `hall_of_fame_selector_screen.dart:199`, `profile_screen.dart:215, 217, 357, 473, 576, 592`, `profile_journal_tab.dart:585`, `profile_reviews_tab.dart:278-290`, `profile_achievements_tab.dart:1107, 1134`, `profile_games_grid_tab.dart:345, 451, 461, 532`, `lib/screens/profile/widgets/profile_hall_of_fame.dart:72`
  - `lib/screens/my_games/`: `collection_tab.dart:218`, `games_tab.dart:215`, `groups_tab.dart:309`, `group_detail_screen.dart:433`, `my_games_screen.dart:97, 202`
  - `lib/screens/home/`: `anticipated_games_section.dart:59`, `hero_showcase.dart:248`, `home_screen.dart:181, 689`
  - `lib/widgets/`: `full_screen_gallery.dart:110`
- **Problema / Causa raíz**: `MediaQuery.of(context)` suscribe al widget a *cualquier* propiedad de `MediaQueryData` (`viewInsets` del teclado, `textScaler`, brillo), disparando reconstrucciones completas innecesarias cuando solo se necesita tamaño, padding o DPR (y en consultas puntuales como `lib/screens/profile/widgets/profile_hall_of_fame.dart:72` acopla innecesariamente el lookup completo de `MediaQuery.of(context).size.width`).
- **Solución propuesta**: Reemplazar por `MediaQuery.sizeOf(context)` (incluyendo `lib/screens/profile/widgets/profile_hall_of_fame.dart:72`), `MediaQuery.viewInsetsOf(context)`, `MediaQuery.paddingOf(context)` y `MediaQuery.devicePixelRatioOf(context)`.

### [MICRO-11] — Llamadas repetidas a `Theme.of(context)` dentro de un mismo `build()` o en bucles/`itemBuilder`
- **ID y Título**: `[MICRO-11]` — Llamadas repetidas a `Theme.of(context)` dentro de un mismo `build()` o en bucles/`itemBuilder`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/library/review_modal_widgets.dart:37, 44, 57, 70, 107-110, 121, 130, 137, 143, 173`; `lib/screens/profile/widgets/profile_sidebar_info.dart:54, 138-140`; `lib/screens/home/anticipated_games_section.dart:123-124, 315-317`; `home_screen.dart:894-898, 1158-1160`; `home_appearance_screen.dart:300-351`; `info_tab_appearance_screen.dart:186-236`; `notifications_screen.dart:266-295, 330-362`; `lib/screens/info_screen.dart` (16 veces); `lib/widgets/game_card.dart:142-517` (13+ veces); `lib/widgets/coop_badge.dart:35-69` (6 veces); `lib/widgets/level_progress_bar.dart:25-65` (6 veces)
- **Problema / Causa raíz**: Múltiples lookups redundantes de `InheritedWidget` (`Theme.of(context)`) dentro del mismo `build()`, `itemBuilder` o `.map(...)`.
- **Solución propuesta**: Cachear `final theme = Theme.of(context); final cs = theme.colorScheme;` al inicio de cada `build()` y fuera de bucles.

### [MICRO-12] — Micro-asignaciones, hit-target y duplicaciones menores en `screens/activity/` y `screens/library/`
- **ID y Título**: `[MICRO-12]` — Micro-asignaciones, hit-target y duplicaciones menores en `screens/activity/` y `screens/library/`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**:
  - `lib/screens/activity/`: `activity_screen.dart:366, 662`, `activity_story_viewer.dart:802, 904, 1063, 1236`, `grouped_post_details_screen.dart:448, 544`, `review_details_screen.dart:231`, `review_details_controller.dart:88`, `comment_composer.dart:49`, `post_action_bar.dart:52, 78`
  - `lib/screens/library/`: `filter_screen.dart:237, 369`, `group_games_screen.dart:82`, `review_modal.dart:482-498, 1793`, `review_modal_widgets.dart:181-195`, `game_info_tab.dart:86-122`, `game_media_tab.dart:36-53, 116-118, 201-203`, `game_reviews_card.dart:397, 430`
- **Problema / Causa raíz**:
  1. En `activity/`: `Game.fromMap` dentro de `build` (`grouped_post_details_screen.dart:544`), `ImagePicker()` en cada tap, `<String, dynamic>{}` no `const`, `textShadows` triplicado, `widget.gameData.toMap()` redundante, `comments.length` en vez de `commentsCount`, `PostActionBar` sin `.clamp(0, 1 << 30)` y `const CorpusTablerIcon.user` faltante.
  2. En `library/`: `items.where(...)` lineal + último `Divider` sobrante en `FilterScreen`; falta `getBottomSpacer` en `GroupGamesScreen`; `monthAbbr` duplicado y `CircularProgressIndicator` sin tamaño fijo en `ReviewModal`; botón `X` de `RemovableImageCard` con área táctil `~20x20px < 48dp`; `Column` redundante en `scoreBadge` de `GameInfoTab`; reconstrucción de lista de URLs por tap en `GameMediaTab`; y `List<String>.from` innecesario en `GameReviewsCard`.
- **Solución propuesta**: Mover `const`/`static final` fuera de `build()`, añadir `getBottomSpacer`, centralizar `monthAbbr`, acotar spinner de guardado a `20x20`, ampliar hit target de `RemovableImageCard` y eliminar copias/wrappers redundantes.

### [MICRO-13] — `DateTime.now()` en bucles, `switch` gigante en `EditProfileScreen`, `RegExp` inline en `AchievementsScreen` y detalles menores en `profile/`
- **ID y Título**: `[MICRO-13]` — `DateTime.now()` en bucles, `switch` gigante en `EditProfileScreen`, `RegExp` inline en `AchievementsScreen` y detalles menores en `profile/`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/profile/achievements/achievements_controller.dart:212`, `profile_achievements_tab.dart:331`, `achievement_games_screen.dart:134`, `edit_profile_screen.dart:738-837`, `achievements_screen.dart:477`, `profile_screen.dart:272, 312, 351, 467, 507, 725, 890, 910`, `currently_playing_badge.dart:93`, `hall_of_fame_selector_screen.dart:136-138, 195-212`, `collection_shelf_screen.dart:8, 29-31`
- **Problema / Causa raíz**:
  1. `DateTime.now()` se instancia en cada iteración del bucle de juegos completados; `EditProfileScreen` usa un `switch` de 100 líneas por build del `ReorderableListView`; `AchievementsScreen:477` compila `RegExp(r'_(\d+|all)$')` por ítem.
  2. `ProfileScreen` recalcula `isMe`/`resolvedUserId` 7 veces (y `bannerUrl` asume `String` en desktop línea 507); `CurrentlyPlayingBadge` y `HallOfFameSelectorScreen` carecen de `MouseRegion(cursor: click)` (y `coverUrl.isEmpty` en HOF pinta caja vacía sin título); `CollectionShelfScreen` conserva doc comment de depuración y omite `CorpusScreenTitle`/`requestBack`.
- **Solución propuesta**: Elevar `now` fuera del `for`, extraer mapa constante de plataformas en `EditProfileScreen`, mover `RegExp` a `static final`, extraer `_resolvedUserId` en `ProfileScreen`, añadir `MouseRegion`/título fallback en HOF y actualizar `CollectionShelfScreen`.

### [MICRO-14] — Deuda técnica en `my_games/` y `profile/widgets/`: `try/catch` de flujo, `TextField` sin controller, barra comprimida e iconos inconsistentes
- **ID y Título**: `[MICRO-14]` — Deuda técnica en `my_games/` y `profile/widgets/`: `try/catch` de flujo, `TextField` sin controller, barra comprimida e iconos inconsistentes
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/my_games/collection_tab.dart:156-164`, `lib/screens/profile/widgets/add_game_to_shelf_sheet.dart:150-171`, `bulk_add_to_shelf_sheet.dart:240-262`, `lib/screens/my_games/widgets/game_search_picker_sheet.dart:141-142, 183-217`, `groups_tab.dart:326-429`, `profile_hall_of_fame.dart:146`, `shelf_game_box.dart:73-78, 288`
- **Problema / Causa raíz**:
  1. `CollectionTab._editItemPlatforms` usa `try { library.firstWhere(...); } catch (_)` como flujo normal.
  2. `AddGameToShelfSheet` y `BulkAddToShelfSheet` usan `TextField` sin `TextEditingController` ni botón Clear; `GameSearchPickerSheet` mezcla controller con `onChanged` y omite `getFloatingNavModalInset`.
  3. En `groups_tab.dart:328-428`, cuando `_canCreate && groups.length >= 2` en móviles estrechos, la barra de búsqueda comparte fila con dos botones quedando `< 160px`.
  4. `ProfileHallOfFame:146` usa `Icons.star` de Material en lugar de `CorpusTablerIcon`; `ShelfGameBox` recalcula `ShelfPlatforms.resolve` en cada hover y `_PlatformGlyph` omite `cacheWidth`/`cacheHeight`.
- **Solución propuesta**: Usar `firstWhere(..., orElse: ...)` o `for`, adoptar `CorpusSearchField` con `getFloatingNavModalInset`, ajustar botones en fila compacta en `GroupsTab`, cambiar `Icons.star` por `CorpusTablerIcon` y cachear layout + `cacheWidth` en `ShelfGameBox`.

### [MICRO-15] — Usabilidad en `LoginScreen` / `RegisterScreen` (visibilidad de contraseña, `AutofillGroup`) y detalles de `BundleDetailsScreen`
- **ID y Título**: `[MICRO-15]` — Usabilidad en `LoginScreen` / `RegisterScreen` (visibilidad de contraseña, `AutofillGroup`) y detalles de `BundleDetailsScreen`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/auth/login_screen.dart:97-118`, `lib/screens/auth/register_screen.dart:111-145`, `lib/screens/bundles/bundle_details_screen.dart:39-43, 63-67`
- **Problema / Causa raíz**: A diferencia de `ResetPasswordScreen`, `LoginScreen` y `RegisterScreen` carecen de toggle para ver contraseña y de `AutofillGroup`/`autofillHints`; y `BundleDetailsScreen` no llama `_scrollController.removeListener(_onScroll)` en `dispose()` y muestra `'Quedan 0 horas'` / `'1 días'`.
- **Solución propuesta**: Añadir `_obscurePassword` toggle y `AutofillGroup` en login/registro, remover explícitamente el listener en `BundleDetailsScreen.dispose()`, y corregir singular/plural y minutos cuando `days == 0 && hours == 0`.

### [MICRO-16] — Deuda menor en `screens/` raíz, `main/`, `social/` y `design/`
- **ID y Título**: `[MICRO-16]` — Deuda menor en `screens/` raíz, `main/`, `social/` y `design/`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/screens/social/notifications_feed_screen.dart:445-496`, `lib/screens/design/sections/design_foundations_section.dart:28, 31, 107`, `design_buttons_section.dart:97`, `design_selection_section.dart:19`, `design_inputs_section.dart:42-48`, `lib/screens/appearance_screen.dart:25, 160`, `lib/screens/settings_screen.dart:98, 115, 426`, `lib/screens/main/main_screen_controller.dart:243-251`
- **Problema / Causa raíz**: `NotificationsFeedScreen` duplica el `Scaffold` en `_isGuest` vs autenticado; `DesignFoundationsSection` repite swatch en `'Accent (pack)'` e indexa `label[0]` sin comprobar `isNotEmpty`; `DesignButtonsSection:97` usa `Row` sin `Wrap`; `DesignSelectionSection:19` y `AppearanceScreen:25` declaran listas mutables de instancia en lugar de `static const` (y `160` deja `SizedBox(height: 12)` vacío en debug); `DesignInputsSection` carece de controller de contraseña; `SettingsScreen` tiene casts `as List` y `const TextStyle()` redundantes; y `MainScreenController` importa `dart:io` con `try/catch` en lugar de `defaultTargetPlatform`.
- **Solución propuesta**: Unificar `Scaffold` en `NotificationsFeedScreen`, usar `static const` y `Wrap`, validar `label.isNotEmpty`, añadir controller en `DesignInputsSection`, eliminar redundancias en `SettingsScreen` y usar `defaultTargetPlatform` en `MainScreenController`.

### [MICRO-17] — Wrappers redundantes, duplicación de badge de rating en `GameCard`, accesibilidad (`Semantics`, `<48dp`) y detalles menores en `lib/widgets/`
- **ID y Título**: `[MICRO-17]` — Wrappers redundantes, duplicación de badge de rating en `GameCard`, accesibilidad (`Semantics`, `<48dp`) y detalles menores en `lib/widgets/`
- **Severidad / Impacto**: Bajo
- **Escala del cambio**: Pequeña (Quick Win)
- **Ubicación**: `lib/widgets/design/corpus_icon_button.dart:22, 58-68`; `corpus_tabs.dart:204-207, 241-251`; `corpus_button.dart:104, 183-185`; `corpus_chip.dart:107`; `corpus_switch.dart:35-63`; `corpus_snackbar.dart:23`; `corpus_text_field.dart:85-94`; `lib/widgets/corpus_primary_button.dart:77-83`; `p5r_ransom_title.dart:27`; `game_card.dart:310-343, 365-402, 441-446`; `explore_bundle_row.dart:173, 184`; `coop_badge.dart:30, 38-40`
- **Problema / Causa raíz**:
  1. `CorpusPointer` se anida sobre otro `MouseRegion` en `CorpusIconButton` y `_CorpusTabHeader`; `CorpusTabs` aplica `labelStyle` dos veces; `CorpusButton:183-185` tiene un ternario idéntico; `CorpusPrimaryButton` duplica `_labelStyle`; `P5rRansomTitle:27` define alias muerto `_maxWordsPerLine`.
  2. `GameCard` duplica el círculo negro de rating entre dos ramas y omite `cacheWidth`/`cacheHeight` en `steam.png`.
  3. `CorpusButton`, `CorpusIconButton` y `CorpusChip` carecen de `Semantics`; `CorpusIconButton` mide `40x40` (<48dp); `CorpusSwitch` con etiqueta no responde al tap en la fila completa.
  4. `ExploreBundleRow` llama `DateTime.now().toUtc()` dos veces por build; `showCorpusSnackBar` usa `ScaffoldMessenger.of` sin `maybeOf`/`hideCurrentSnackBar`; `CoopBadge` usa `BorderRadius.circular(20)` frente a `ext.radiusLarge`; y `CorpusTextField` omite `focusedErrorBorder`.
- **Solución propuesta**: Eliminar wrappers y ternarios redundantes, extraer `_buildRatingCircle` + `cacheWidth: 28` en `GameCard`, añadir `Semantics`/`ConstrainedBox(minWidth: 48, minHeight: 48)`/`InkWell` en `CorpusSwitch`, y aplicar los ajustes de `ExploreBundleRow`, `showCorpusSnackBar`, `CoopBadge` y `CorpusTextField`.

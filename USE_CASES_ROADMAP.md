# Roadmap de Casos de Uso — Tests de Integración Mockup (Corpus)

Este documento recopila el inventario exhaustivo de los flujos de usuario de **Corpus**: qué casos están ya cubiertos por la suite de integración con backend mock (`FakeSupabaseBackend`) y cuáles quedan pendientes para implementar en futuras sesiones.

## Resumen Ejecutivo

- **Tests E2E actuales:** `52` tests distribuidos en `16` archivos dentro de `test/integration/`
- **Casos de uso cubiertos:** `83` flujos comprobados (`- [x]`) — **100% del roadmap completado**
- **Casos de uso pendientes:** `0` (`- [ ]`)
- **Archivos de infraestructura mock:**
  - `test/integration/helpers/fake_supabase_backend.dart` (`FakeSupabaseBackend`)
  - `test/integration/helpers/integration_test_harness.dart` (`CorpusTestHarness`)

### Cómo ejecutar la suite actual

```powershell
flutter test test/integration/
```

Para salida detallada por test:

```powershell
flutter test --no-pub -r expanded test/integration/
```

---

## Inventario Completo por Módulo

### 1. Autenticación, Sesión y Deep Links

- [x] Estado invitado en **Perfil** (CTA para iniciar sesión / registrarse) — `test/integration/auth_flow_test.dart`
- [x] Error de login con credenciales inválidas (contraseña incorrecta) — `test/integration/auth_flow_test.dart`
- [x] Inicio de sesión válido y carga de perfil autenticado — `test/integration/auth_flow_test.dart`
- [x] Cierre de sesión desde **Ajustes** (`Cerrar sesión`) y retorno a estado invitado — `test/integration/auth_flow_test.dart`
- [x] Validación de nombre de usuario vacío en **Registro** (`El nombre de usuario es obligatorio`) — `test/integration/auth_flow_test.dart`
- [x] Registro de nuevo usuario con sesión activa inmediata y carga en **Perfil** — `test/integration/auth_flow_test.dart`
- [x] Validación de email inválido y contraseña corta/no coincidente en `register_screen.dart` y `reset_password_screen.dart` — `test/integration/auth_flow_test.dart`
- [x] Error de registro con email ya existente o username duplicado en `register_screen.dart` — `test/integration/auth_flow_test.dart`
- [x] Flujo de recuperación de contraseña en `forgot_password_screen.dart` — `test/integration/auth_flow_test.dart`
- [x] Flujo de restablecimiento de contraseña en `reset_password_screen.dart` (incluyendo evento `passwordRecovery`) — `test/integration/auth_flow_test.dart`
- [x] Refresh de token de sesión (`refreshSession` → `POST /auth/v1/token`) — `test/integration/auth_flow_test.dart`
- [x] Deep links entrantes hacia juego, reseña y bundles (`DeepLinkService`) — `test/integration/auth_flow_test.dart`
- [x] Resolución de rutas profundas (`DeepRouteResolver`): las 9 `TabDeepRoute`, retorno `null` en rutas inexistentes y scroll-to-top al re-pulsar pestaña activa — `test/integration/deep_routes_profile_settings_and_design_flow_test.dart`
- [x] Protección anti-rebotes (debounce de 600 ms en navegación) verificada ante doble pulsación en `CorpusRouter` — `test/integration/resilience_and_responsive_layouts_flow_test.dart`

---

### 2. Inicio (`HomeScreen`) y Descubrimiento

- [x] Navegación a la pestaña **Inicio** en viewport móvil (`412x915`, `floatingMobileNav: false`) sin desbordamientos — `test/integration/mobile_smoke_flow_test.dart`
- [x] Renderizado completo de `HeroShowcase` y apertura de ficha al pulsar el título destacado — `test/integration/home_explore_and_filters_flow_test.dart`
- [x] Carga de `AnticipatedGamesSection` (`Juegos más anticipados`) y navegación a detalles de próximos lanzamientos — `test/integration/home_explore_and_filters_flow_test.dart`
- [x] Apertura de detalles de bundle en `BundleDetailsScreen` desde **Inicio** (`Oportunidades Finales`) y **Explorar** (`Bundles`) — `test/integration/home_explore_and_filters_flow_test.dart`
- [x] Estado vacío / error de carga de IGDB en `lib/screens/home/home_screen.dart` y acción de reintento — `test/integration/home_library_and_groups_edge_cases_flow_test.dart`

---

### 3. Explorar, Búsqueda y Filtros Avanzados (`LibraryScreen`, `SearchScreen`, `FilterScreen`)

- [x] Búsqueda de juego por texto (`Elden Ring`, `Hollow Knight`) y apertura de `GameDetailsScreen` — `test/integration/search_review_and_comment_flow_test.dart`, `test/integration/mobile_smoke_flow_test.dart`
- [x] Búsqueda desde flujo móvil (`412x915`) sin overflows ni excepciones — `test/integration/mobile_smoke_flow_test.dart`
- [x] Navegación al catálogo en `lib/screens/library/library_screen.dart` y paginación / scroll infinito — `test/integration/home_library_and_groups_edge_cases_flow_test.dart`
- [x] Búsqueda con estado vacío (`No se encontraron resultados...`) y limpieza de búsqueda en `SearchScreen` — `test/integration/home_explore_and_filters_flow_test.dart`
- [x] Búsqueda con error de red (`500`) en `igdb-proxy` y recuperación posterior en `SearchScreen` — `test/integration/home_explore_and_filters_flow_test.dart`
- [x] Aplicación de filtros en `FilterScreen` y `FilterOptionScreen` (plataforma, género, ordenación y limpieza) — `test/integration/home_explore_and_filters_flow_test.dart`
- [x] Grupos filtrados desde navegación en `lib/screens/library/group_games_screen.dart` — `test/integration/home_library_and_groups_edge_cases_flow_test.dart`

---

### 4. Ficha de Juego (`GameDetailsScreen`) y Reseñas (`ReviewModal`)

- [x] Añadir juego a biblioteca desde `GameDetailsScreen` (`Añadir a Biblioteca`) con estado `Terminado`, rating slider y texto de reseña — `test/integration/search_review_and_comment_flow_test.dart`
- [x] Guardar juego como `Jugando` y verificar aparición en **Mis juegos** — `test/integration/search_review_and_comment_flow_test.dart`
- [x] Guardar juego en `Wishlist` en viewport móvil — `test/integration/mobile_smoke_flow_test.dart`
- [x] Editar reseña/estado existente (`Jugando` → `Terminado`) añadiendo texto desde la ficha — `test/integration/search_review_and_comment_flow_test.dart`
- [x] Eliminar juego de la biblioteca (`Opciones` → `Borrar juego` → confirmación) y verificar retirada — `test/integration/search_review_and_comment_flow_test.dart`
- [x] Cambiar entre estados soportados (`Por jugar`, `En Pausa`, `Abandonado`, rejugada y desglose de nota) en `ReviewModal` — `test/integration/game_details_and_review_flow_test.dart`
- [x] Pestaña **Información** (`GameInfoTab`): sinopsis, Metacritic (`get-metacritic-score`), Stash Stats y tiempos de duración — `test/integration/game_details_and_review_flow_test.dart`
- [x] Pestaña **Media** (`GameMediaTab`): galería de capturas, tráilers y artworks — `test/integration/game_details_and_review_flow_test.dart`
- [x] Pestaña **Relacionado** (`GameRelatedTab`): expansiones/DLCs y navegación a su ficha — `test/integration/game_details_and_review_flow_test.dart`
- [x] Pestaña **Links** (`GameLinksTab`): enlaces de tiendas y efecto de `Traducir enlaces de tiendas` — `test/integration/game_details_and_review_flow_test.dart`
- [x] Pestaña **Comunidad** (`GameStashTab`): reseñas de comunidad Stash — `test/integration/game_details_and_review_flow_test.dart`
- [x] Reabrir `GameDetailsScreen` tras recarga completa reflejando estado y reseña persistidos — `test/integration/game_details_and_review_flow_test.dart`
- [x] Selección de compañero cooperativo (`partner_ids`) en `ReviewModal` y visualización/navegación de `CoopBadge` en Actividad y Perfil — `test/integration/coop_rich_comments_and_post_isolation_flow_test.dart`

---

### 5. Actividad, Comentarios, Likes y Notificaciones

- [x] Verificar publicación automática de reseña propia en **Actividad** — `test/integration/search_review_and_comment_flow_test.dart`
- [x] Dar Like a una reseña desde el feed y verificar contador — `test/integration/search_review_and_comment_flow_test.dart`, `test/integration/social_and_collections_flow_test.dart`
- [x] Abrir `ReviewDetailsScreen` y publicar un comentario raíz — `test/integration/search_review_and_comment_flow_test.dart`, `test/integration/social_and_collections_flow_test.dart`
- [x] Responder a un comentario existente (hilo anidado) — `test/integration/search_review_and_comment_flow_test.dart`
- [x] Eliminar una respuesta propia con diálogo de confirmación — `test/integration/search_review_and_comment_flow_test.dart`
- [x] Quitar Like (`unlike`) y eliminar comentario raíz propio en `CommentThreadSection` — `test/integration/activity_stories_and_notifications_flow_test.dart`
- [x] Visor de historias (`ActivityStoryViewer`): abrir historia de amigo, avanzar/retroceder y registrar lectura en `story_views` — `test/integration/activity_stories_and_notifications_flow_test.dart`
- [x] Publicación agrupada (`GroupedPostDetailsScreen`): ver múltiples juegos agrupados, abrir ficha, comentar y dar like — `test/integration/activity_stories_and_notifications_flow_test.dart`
- [x] Badge de actividad no leída y marcado automático como leída (`get_unread_activity_summary` / `mark_activity_read`) en `ActivityScreen` — `test/integration/activity_stories_and_notifications_flow_test.dart`
- [x] Feed de notificaciones (`NotificationsFeedScreen`): contador no leído, marcado global (`mark_all_notifications_read`) y navegación al destino — `test/integration/activity_stories_and_notifications_flow_test.dart`
- [x] Citas enriquecidas de juegos en `CommentComposer` (búsqueda en `ReviewDetailsScreen` y sugeridos en `GroupedPostDetailsScreen`) — `test/integration/coop_rich_comments_and_post_isolation_flow_test.dart`
- [x] Aislamiento de hilos en publicaciones agrupadas (`20261113000000`): interacciones en post agrupado no se filtran a la reseña individual — `test/integration/coop_rich_comments_and_post_isolation_flow_test.dart`
- [x] Triggers automáticos de notificaciones (`like`, `comment`, `friend_request`) entre usuarios reales hacia `NotificationsFeedScreen` — `test/integration/coop_rich_comments_and_post_isolation_flow_test.dart`

---

### 6. Amigos y Perfiles Públicos (`FriendsScreen`, `UserFriendsScreen`, `ProfileScreen`)

- [x] Aceptar solicitud de amistad entrante en **Amigos → Solicitudes** (`nuevojugador`) — `test/integration/social_and_collections_flow_test.dart`
- [x] Buscar usuarios (`explorador`) en **Amigos → Buscar** y enviar solicitud (`Añadir` → `Enviado`) — `test/integration/social_and_collections_flow_test.dart`
- [x] Rechazar solicitud de amistad entrante y cancelar una solicitud enviada en `FriendsScreen` — `test/integration/friends_and_public_profile_flow_test.dart`
- [x] Eliminar a un amigo existente de la lista de amigos en `FriendsScreen` — `test/integration/friends_and_public_profile_flow_test.dart`
- [x] Visitar perfil público de amigo (`ProfileScreen`), ver colecciones y reseñas en solo lectura y abrir `UserFriendsScreen` — `test/integration/friends_and_public_profile_flow_test.dart`
- [x] Validar restricción de acceso a estantería privada (`/private/collection`) en modo invitado — `test/integration/friends_and_public_profile_flow_test.dart`

---

### 7. Mis Juegos, Colecciones y Estanterías (`MyGamesScreen`, `GroupDetailScreen`, `CollectionShelfScreen`)

- [x] Verificar juego añadido en pestaña **Mis juegos** — `test/integration/search_review_and_comment_flow_test.dart`
- [x] Crear nueva colección personalizada (`Favoritos RPG`) en **Mis juegos → Colecciones** — `test/integration/social_and_collections_flow_test.dart`
- [x] Abrir `GroupDetailScreen` y añadir juego (`Elden Ring`) mediante `GameSearchPickerSheet` — `test/integration/social_and_collections_flow_test.dart`
- [x] Filtrar y ordenar dentro de `lib/screens/my_games/games_tab.dart` (secciones `Jugando`/`Por jugar`, filtro rápido y apertura de ficha) — `test/integration/my_games_and_shelf_flow_test.dart`
- [x] Editar nombre/descripción/ranking de una colección, reordenar, quitar un juego y eliminar la colección completa en `lib/screens/my_games/group_detail_screen.dart` y `groups_tab.dart` — `test/integration/my_games_and_shelf_flow_test.dart`
- [x] Flujo completo de **Estantería / Colección física o por plataforma** en `lib/screens/my_games/collection_tab.dart` y `lib/screens/profile/collection_shelf_screen.dart`: añadir juego (`add_game_to_shelf_sheet.dart`), añadir en lote (`bulk_add_to_shelf_sheet.dart`), seleccionar plataforma (`platform_picker_sheet.dart`), alternar vista y eliminar ítem — `test/integration/my_games_and_shelf_flow_test.dart`

---

### 8. Perfil Personal, Diario, Hall of Fame y Logros

- [x] Editar nombre visible y biografía en `EditProfileScreen` y guardar (`Guardar Cambios`) — `test/integration/social_and_collections_flow_test.dart`
- [x] Validación de colisión de `username` duplicado y guardado de chips de plataformas en `EditProfileScreen` — `test/integration/deep_routes_profile_settings_and_design_flow_test.dart`
- [x] Navegar a **Perfil** en smoke test móvil (`412x915`) sin overflows — `test/integration/mobile_smoke_flow_test.dart`
- [x] Pestaña **Diario** (`lib/screens/profile/profile_journal_tab.dart`): historial cronológico agrupado por mes/año, filtro de año y apertura de entrada — `test/integration/profile_journal_hof_and_achievements_flow_test.dart`
- [x] Pestaña **Juegos** (`lib/screens/profile/profile_games_grid_tab.dart`) y **Reseñas** (`lib/screens/profile/profile_reviews_tab.dart`) — `test/integration/profile_journal_hof_and_achievements_flow_test.dart`
- [x] Estadísticas de perfil: `profile_giant_stats.dart`, histograma de notas (`profile_ratings_histogram.dart`), insignia `currently_playing_badge.dart` y `profile_sidebar_info.dart` — `test/integration/profile_journal_hof_and_achievements_flow_test.dart`
- [x] Configurar **Hall of Fame** (elegir, vaciar y destacar en hueco #1) en `lib/screens/profile/hall_of_fame_selector_screen.dart` y verificar renderizado/navegación en `profile_hall_of_fame.dart` — `test/integration/profile_journal_hof_and_achievements_flow_test.dart`
- [x] Ver **Logros** en `lib/screens/profile/profile_achievements_tab.dart`, `achievements_screen.dart` y `achievement_games_screen.dart` — `test/integration/profile_journal_hof_and_achievements_flow_test.dart`

---

### 9. Ajustes, Apariencia, Integraciones (Steam) y Resiliencia

- [x] Abrir **Ajustes** desde Perfil y alternar switch `Traducir enlaces de tiendas` — `test/integration/social_and_collections_flow_test.dart`
- [x] Cambiar tema, color/style pack y música/efectos en `lib/screens/appearance_screen.dart` (incluyendo `lib/services/style_pack_import_service.dart` y `style_pack_music_service.dart`) — `test/integration/settings_appearance_notifications_and_steam_flow_test.dart`
- [x] Personalizar **Inicio** (`lib/screens/settings/home_appearance_screen.dart`) y pestaña **Info** (`lib/screens/settings/info_tab_appearance_screen.dart`) — `test/integration/settings_appearance_notifications_and_steam_flow_test.dart`
- [x] Configurar preferencias de notificaciones en `lib/screens/settings/notifications_screen.dart` y envío de notificación de prueba (`send-test-notification` vía `lib/services/notification_service.dart`) — `test/integration/settings_appearance_notifications_and_steam_flow_test.dart`
- [x] Importación de biblioteca **Steam** de principio a fin: `steam_import_setup_screen.dart` → `steam_import_progress_screen.dart` → `import_preview_screen.dart` (resolviendo ID con `resolve-steam-id` e importando con `steam-library-import` / `lib/services/import_service.dart`) — `test/integration/settings_appearance_notifications_and_steam_flow_test.dart`
- [x] Pantalla de información / acerca de en `lib/screens/info_screen.dart` — `test/integration/settings_appearance_notifications_and_steam_flow_test.dart`
- [x] Tests de resiliencia ante errores HTTP (`500`, `401`, timeout) en carga inicial, guardado de reseña y acciones sociales — `test/integration/resilience_and_responsive_layouts_flow_test.dart`, `test/integration/home_explore_and_filters_flow_test.dart`
- [x] Cobertura de layout responsive en desktop/tablet (`1280x800`) y móvil compacto (`360x640`) en pantallas secundarias (`GameDetailsScreen`, `ReviewDetailsScreen`, `FriendsScreen`, `SettingsScreen`) — `test/integration/resilience_and_responsive_layouts_flow_test.dart`
- [x] Importación Stash CSV/JSON completa: validaciones (vacío, `> 25 MB`, cancelación de `FilePicker`), resolución en `Dudas`, `No encontrados`, filtros, edición en `ReviewModal` y guardado en `ImportPreviewScreen` — `test/integration/stash_csv_import_and_preview_flow_test.dart`
- [x] Activación de tiempos `DuracionDe` (`fetch-duracionde-time`) y acción `DEBUG: Vaciar cuenta` (eliminación de juegos y reseñas) en `SettingsScreen` — `test/integration/deep_routes_profile_settings_and_design_flow_test.dart`
- [x] Recorrido completo de las 8 categorías del sistema de diseño en `DesignScreen` (`/design`) sin errores ni desbordamientos — `test/integration/deep_routes_profile_settings_and_design_flow_test.dart`

---

## Plan Recomendado de Implementación (Por Lotes)

Para ir completando los casos pendientes hasta cerrar el 100% (`83/83`) del roadmap:

1. **Lote 1 — Auth completo y Deep Links** ✅ Completado (`test/integration/auth_flow_test.dart`)
   - Validaciones de registro (email, contraseña corta, duplicados), recuperación/reset de contraseña (`POST /auth/v1/recover`, `AuthChangeEvent.passwordRecovery`), `refreshSession` y `DeepLinkService` (juego, reseña y bundles).
2. **Lote 2 — Descubrimiento, Explorar y Filtros avanzados** ✅ Completado (`test/integration/home_explore_and_filters_flow_test.dart`)
   - `HomeScreen` (`HeroShowcase`, `Oportunidades Finales`, próximos lanzamientos), `BundleDetailsScreen`, `SearchScreen` (tendencias, estado vacío, limpieza, resiliencia `igdb-proxy`) y `FilterScreen` / `FilterOptionScreen`.
3. **Lote 3 — Ficha de juego completa y Colecciones/Estantería** ✅ Completado (`test/integration/game_details_and_review_flow_test.dart` + `test/integration/my_games_and_shelf_flow_test.dart`)
   - ✅ **Sección 4 completada**: pestañas `Información` (Metacritic, HLTB, Stash Stats), `Comunidad`, `Media`, `Relacionado`, `Links` (con toggle de localización), todos los estados de `ReviewModal` y persistencia tras recarga limpia.
   - ✅ **Sección 7 completada**: filtro rápido de `GamesTab`, edición/ranking/reordenación/borrado en `GroupDetailScreen` y `GroupsTab`, y estanterías físicas (`CollectionTab` + `CollectionShelfScreen` + sheets).
4. **Lote 4 — Social avanzado, Historias y Notificaciones** ✅ Completado (`test/integration/activity_stories_and_notifications_flow_test.dart` + `test/integration/friends_and_public_profile_flow_test.dart`)
   - ✅ **Sección 5 y Sección 6 completadas**: badge de actividad no leída, unlike, borrado de comentario raíz propio, visor de historias (`ActivityStoryViewer` + `story_views`), publicación agrupada (`GroupedPostDetailsScreen`), feed y navegación de notificaciones (`NotificationsFeedScreen`), rechazo/cancelación/eliminación en `FriendsScreen`, perfil público en solo lectura + `UserFriendsScreen` y bloqueo invitado en `/private/collection`.
5. **Lote 5 — Perfil avanzado, Hall of Fame y Logros** ✅ Completado (`test/integration/profile_journal_hof_and_achievements_flow_test.dart`)
   - ✅ **Sección 8 completada**: `ProfileGiantStats`, `ProfileRatingsHistogram`, `CurrentlyPlayingBadge`, `ProfileSidebarInfo`, `ProfileGamesGridTab`, `ProfileReviewsTab`, `ProfileJournalTab`, `HallOfFameSelectorScreen` + `ProfileHallOfFame`, `ProfileAchievementsTab`, `AchievementsScreen` y `AchievementGamesScreen`.
6. **Lote 6 — Descubrimiento/Catálogo límite, Apariencia, Importación Steam, Resiliencia y Responsive** ✅ Completado (`test/integration/home_library_and_groups_edge_cases_flow_test.dart` + `test/integration/settings_appearance_notifications_and_steam_flow_test.dart` + `test/integration/resilience_and_responsive_layouts_flow_test.dart`)
   - ✅ **Secciones 2, 3 y 9 completadas**: estado vacío/error IGDB + reintento en `HomeScreen`, `LibraryScreen` + paginación scroll infinito + `GroupGamesScreen`, `AppearanceScreen` + `HomeAppearanceScreen` + `InfoTabAppearanceScreen`, `NotificationsScreen` + `send-test-notification` + `InfoScreen`, flujo Steam completo (`resolve-steam-id` → `SteamImportSetupScreen` → `SteamImportProgressScreen` → `ImportPreviewScreen`), resiliencia HTTP (`500`, `401`, `TimeoutException`) y layouts responsive (`1280x800` y `360x640`).
7. **Lote 7 — Endurecimiento de Auditoría Carbon y Cobertura Exhaustiva Restante** ✅ Completado (`test/integration/stash_csv_import_and_preview_flow_test.dart` + `test/integration/coop_rich_comments_and_post_isolation_flow_test.dart` + `test/integration/deep_routes_profile_settings_and_design_flow_test.dart`)
   - ✅ **Infraestructura endurecida**: desactivación opt-in del debounce de navegación de 600 ms mediante `kDisablePushDebounceForTests` (con test explícito de doble pulsación en `CorpusRouter`), corrección de persistencia `floatingMobileNav` en `IntegrationTestHarness`, plataforma mock `_FakeFilePickerPlatform`, alineamiento del backend mock con migraciones SQL reales (`20261110000003`, `20261113000000`, `20261117000000`, `20261124164405`), triggers automáticos de notificaciones, sincronización de `partner_ids` y respuesta `fetch-duracionde-time`.
   - ✅ **Flujos restantes cerrados**: Stash CSV/JSON + validaciones de `FilePicker` + `Dudas`/`No encontrados`, cooperativo `partner_ids`/`CoopBadge`, citas enriquecidas de juegos en `CommentComposer`, aislamiento de hilos en posts agrupados, triggers automáticos de notificaciones, `DeepRouteResolver` (9 rutas) + scroll-to-top, colisión de username + chips de plataformas en `EditProfileScreen`, `DuracionDe` + `DEBUG: Vaciar cuenta` y recorrido completo de las 8 categorías de `DesignScreen` (`/design`).

---

## Correcciones de Producción Descubiertas y Verificadas (Lotes 1–7)

La ejecución sistemática de los tests de integración descubrió **13 fallos reales** en código de producción (`lib/`), todos corregidos y verificados:

1. **`lib/screens/library/game_details/game_info_tab.dart`**: desbordamiento horizontal en el bloque Metacritic; migrado de `Row` a `Wrap` adaptativo.
2. **`lib/screens/library/game_details/game_reviews_card.dart`**: desbordamiento en `_buildInfoBadge` con etiquetas largas; texto envuelto en `Flexible` con `TextOverflow.ellipsis`.
3. **`lib/screens/profile/achievements_screen.dart`**: `SliverGrid` con `childAspectRatio` variable reemplazado por `mainAxisExtent: 235` constante para evitar desbordamientos verticales en tarjetas de logros.
4. **`lib/screens/profile/profile_achievements_tab.dart`**: mismo ajuste a `mainAxisExtent: 235` en el grid de logros del perfil.
5. **`lib/screens/profile/widgets/bulk_add_to_shelf_sheet.dart`**: chips de filtrado en `Row` sustituidos por `Wrap(spacing: 8, runSpacing: 8)` para viewports compactos.
6. **`lib/screens/profile/widgets/profile_games_overview.dart`**: cabecera con títulos largos envuelta en `Flexible` y `TextOverflow.ellipsis`.
7. **`lib/screens/social/friends_screen.dart`**: mutación de `unreadFriendRequestsCount.value = 0` durante `initState` movida a `WidgetsBinding.instance.addPostFrameCallback` para evitar `setState()/markNeedsBuild()` durante build.
8. **`lib/screens/library/game_details_screen.dart`**: preservación de `widget.gameData.collectionId` y `widget.gameData.franchiseIds` cuando `GameDetailsController.enrichGameData()` retorna antes de completar enriquecimiento.
9. **`lib/screens/activity/widgets/comment_composer.dart` y `comment_thread_section.dart`**: soporte de `name ?? title` al normalizar juegos citados desde búsqueda (`Game.toMap()` usa clave `'title'`).
10. **`lib/widgets/design/corpus_tabs.dart`**: sustitución de `BorderRadius` + `Border` no uniforme (ilegal en `BoxDecoration`) por `_SelectedTabPainter` (`CustomPainter`) y envoltura del panel en `Material`.
11. **`lib/widgets/design/corpus_list_tile.dart`**: envoltura de `ListTile` en `Material(type: MaterialType.transparency)` para evitar crash `No Material widget found` cuando se usa fuera de un ancestro `Material`.
12. **`lib/screens/library/review_modal.dart`**: `DropdownButtonFormField<String>` de plataforma configurado con `isExpanded: true` y `TextOverflow.ellipsis` para evitar desbordamiento horizontal en la columna izquierda de escritorio (`320px`).
13. **`lib/widgets/coop_badge.dart`**: texto de `CoopBadge` envuelto en `Flexible` (`maxLines: 1, overflow: TextOverflow.ellipsis`) para evitar desbordamientos en barras laterales estrechas (`<= 224px`) como `GameReviewsCard`.

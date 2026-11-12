# Changelog

All notable changes to this project will be documented in this file.

## [1.3.1] - 2026-11-13

### Añadido
- **Hilos por post en el feed (`feed_posts`):** Cada evento del feed tiene ahora identidad propia (`feed_posts.id`), de modo que los likes y comentarios pertenecen a esa publicación concreta y no a la fila mutable de la reseña; al cambiar el estado de un juego se inicia un hilo nuevo conservando el enlace al hilo anterior.
- **Posts agrupados con interacción completa:** Las entradas consecutivas sin información adicional (`wishlist`, `to_play`, `playing`, `beaten`, `completed` en ventana de 60 minutos) comparten `post_id` asignado en base de datos, con barra de likes/comentarios, nueva pantalla `GroupedPostDetailsScreen` y ruta profunda `/post/{postId}`.
- **Componentes compartidos de hilo:** Extraídos `PostStats`, `PostThreadController`, `PostActionBar`, `CommentThreadSection` y `CommentComposer` para unificar reseñas individuales y publicaciones agrupadas.
- **Migraciones, backfill y tests SQL:** Migraciones incrementales e idempotentes con respaldo previo en esquema `backup`, reasignación por fecha de likes y comentarios históricos y suite SQL en `supabase/tests/feed_posts_test.sql`.
- **Mejoras de escritorio, historias y documentación de auditoría:** Flechas de scroll horizontal en filas de juegos y bundles en escritorio, ajuste dinámico inferior en modales móviles, mejoras en visor de historias/formateadores y documentación en `docs/audit/2026-11/`.

### Cambiado
- **Regla centralizada en PostgreSQL:** La detección de actividad sin información adicional (`is_bare_activity`) y los resúmenes de post (`post_summary`) se resuelven directamente en base de datos para feed, contador de no leídos y Edge Functions.
- **Notificaciones por `post_id`:** Actualizados los triggers (`notify_review_like`, `notify_review_unlike`, `notify_review_comment`) y las Edge Functions `notify-comment` y `notify-friend-activity` para enlazar y notificar tanto posts individuales como agrupados.
- **Diseño de comentarios:** Tarjetas de comentario con respuestas indentadas e iconos de acción (responder y eliminar) fijados en la esquina superior derecha.
- **Limpieza:** Eliminada la pantalla heredada sin uso `lib/screens/bundles/bundles_screen.dart`.

### Arreglado
- **Endurecimiento de seguridad y rutas:** Fijado `search_path = public, pg_temp` en las funciones `SECURITY DEFINER`, rate limiting por JWT verificado o IP real en Edge Functions (`_shared/rate-limit.ts`), limpieza garantizada de metadatos EXIF en imágenes pequeñas (`image_compressor.dart`), atributos `integrity` (SRI) para `cropperjs` en `web/index.html` y validación estricta de UUID en rutas de perfil/logros.
- **Likes en publicaciones (`42703`):** Separados los triggers `fill_interaction_refs` (likes) y `fill_comment_refs` (comentarios) sobre un helper compartido `resolve_interaction_refs`.

## [1.3.0] - 2026-11-09

### Añadido
- **Pestaña Mis Juegos (`my_games`):** Nueva sección centralizada en la navegación principal que agrupa la biblioteca en tres subpestañas dedicadas (Juegos, Estantería y Colecciones).
- **Estantería y Colección Física (`shelf_tab`):** Seguimiento multi-plataforma por juego (`user_game_platforms`), visualización de cajas por consola con lomo y logotipo oficial (`shelf_platforms.dart`), estadísticas por familia de plataformas y modales de añadido individual y en bloque (`add_to_shelf_sheet`, `bulk_add_to_shelf_sheet`).
- **Colecciones y Rankings (`groups_tab`):** Creación y gestión de listas personalizadas (`game_groups` y `game_group_items`) con reordenación, notas individuales por juego y modo Ranking numerado (`is_ranked`) con medallas para el Top 3.
- **Nuevo estado `Por jugar` (`to_play`):** Estado intermedio entre Wishlist y Jugando para organizar el backlog inmediato sin contaminar la lista de deseados ni el feed de actividad.
- **Sistema de iconos unificado:** Integración global de `tabler_icons_next` mediante wrappers tipados (`CorpusIconKind`, `CorpusTablerIcon`, `CorpusNavIcon`) en toda la interfaz.
- **Componentes y Utilidades:** Nuevo widget reutilizable `CorpusGameGrid` para grillas de juegos, logger estructurado `CorpusLogger` y pantalla de error de producción segura (`ErrorWidget.builder`) sin exposición de trazas internas.
- **Reglas de Logros en Base de Datos:** Nuevas tablas `achievement_rules` y `achievement_match_patterns` para gestionar reglas y patrones de desbloqueo de logros de forma declarativa.
- **Documentación y Configuración:** Añadidos ADRs de arquitectura (`docs/adr/001` y `docs/adr/002`) y plantilla `.env.json.example`.

### Cambiado
- **Sección de Bundles:** Reubicada e integrada directamente dentro de la pestaña Explorar (`ExploreBundleRow`), liberando espacio en la navegación principal para Mis Juegos.
- **ReviewModal descompuesto:** Extraídos los subcomponentes visuales a `review_modal_widgets.dart` para reducir el acoplamiento y mejorar el mantenimiento.
- **Seguridad en Base de Datos y Storage:** Añadido trigger `trg_protect_user_xp` en `public.users` para bloquear modificaciones directas de `xp` desde el cliente, y restringidas las políticas de `avatars` y `banners` en Supabase Storage a la carpeta del propio usuario autenticado.
- **Endurecimiento de Edge Functions:** Validación de autorización `service_role` y propiedad de tokens en `send-push-notification`, `notify-comment`, `notify-friend-activity` y `notify-bundle-expiring`, además de validación contra path traversal y symlinks en `style_pack_registry.dart`.

### Arreglado
- **CORS en Edge Functions (`_shared/cors.ts`):** Soporte completo para puertos efímeros en desarrollo local (`localhost`), despliegues preview de Vercel y cabeceras dinámicas `corsHeadersForRequest(req)` en respuestas `POST` y `OPTIONS`.
- **Activity Feed y Reseñas:** El trigger `on_review_upsert` y `ReviewRepository` excluyen ahora el estado `to_play` de la generación de reseñas fantasma en el feed, igualando su transición a la de `wishlist`.
- **Colecciones (`GameGroupRepository`):** Conservación de la descripción existente en base de datos al actualizar un grupo en modo fallback y añadido `RouteSettings` en la navegación al detalle de colección.
- **Estantería (`CollectionRepository`):** Inclusión tanto de `beaten` como de `completed` al recuperar juegos superados para sugerir en la estantería física.
- **Caché Web y Plataformas Nativas:** Ajustado `Cache-Control: no-cache` para `/main.dart.js` en `vercel.json` para evitar bundles desincronizados tras cada despliegue, y añadidos los permisos nativos requeridos en `macos/Runner/Release.entitlements` e `ios/Runner/Info.plist`.

## [1.2.4] - 2026-09-17

### Añadido
- **Arquitectura de Controllers:** Creados `ActivityController` y `SafeChangeNotifier` como base para desacoplar la lógica de negocio de los widgets. El feed de actividad (realtime, likes, stories, paginación) ahora se gestiona desde un controller independiente.
- **Repositorios centralizados:** Nuevo `SocialRepository` para queries de amigos y solicitudes. Migración de `ReviewDetailsController` a `ReviewRepository`. Centralización de queries inline de logros, journal y reseñas.
- **Utilidades:** `Debouncer` genérico con tests unitarios, `formatRating()` centralizado en `format_utils.dart`.
- **Game Card rediseñado:** Pill vertical con rating y badges de cápsula para el estado del juego.
- **Review images:** Grid de 2 columnas en móvil con ratio 16:9 y máximo 4 imágenes.
- **Friend badge mejorado:** Muestra rating del amigo y filtra wishlist/abandoned.
- **Datos IGDB:** Nuevas columnas `version_parent` y `game_type` en tabla `games`, mapeo del campo plural `collections` v2.

### Cambiado
- **ProfileScreen descompuesto (1861 → 1156 líneas):** Extraídos 5 widgets: `ProfileHallOfFame`, `ProfileRatingsHistogram`, `ProfileGiantStats`, `ProfileGamesOverview` y `ProfileSidebarInfo`.
- **ReviewModal migrado:** De `StatefulBuilder` a `StatefulWidget` propio (`_ReviewModalContent`), eliminando 32 llamadas a `setModalState`.
- **Carousel de screenshots** movido de `GameDetailsScreen` a `GameDetailsController`.
- **Dependencias actualizadas:** 42 paquetes minor/patch (incluyendo Supabase 2.16→2.17.2, sqflite, cache manager). Eliminadas `jwt_decode` y `retry` obsoletas.
- **Logo de navegación** ahora funciona como botón Home.
- **Category badges** redondeados y layout de profile navbar corregido.

### Arreglado
- **Navegación Web:** Desacoplamiento completo del routing de Flutter del `history.state` del navegador. Fixes de doble-pop, ghost modal entries, dead clicks, clicks rápidos de atrás y crashes en Firefox (JSON parsing, offstage ticker).
- **Activity Feed:** Backfill de `review_id` en eventos de status_change, backdate de entries históricas, sincronización de estado global tras updates de reviews.
- **IGDB:** Parse correcto de JSON stringificado en `collection`, separación de `parent_game`/`version_parent` en heurísticas de categoría.
- **Reviews:** Asignación correcta de partners en game details.

## [1.2.3] - 2026-09-03

### Añadido
- **Tipado Fuerte (Type Safety):** Migración completa de toda la aplicación (Router, Core, Modelos y todas las pantallas de UI) a modelos de juego fuertemente tipados (`Game`). Activada la regla de análisis estricta `avoid_dynamic` para evitar fallos inesperados.
- **Diario (Journal) e Interfaz:** Modernizada la pestaña del Diario, renovado el diseño de los iconos de plataformas (badges) y añadido un efecto de zoom al hacer hover en las carátulas grandes (Hero showcase).
- **Componentes de UI:** Nuevo widget `mention_text` para interactuar con nombres de usuario etiquetados, y sistema de *Scroll-to-top* integrado: pulsar en la pestaña activa del menú ahora hace que la pantalla se desplace al principio automáticamente.
- **Ajustes y Personalización:** Preparada la infraestructura del servicio de preferencias y ajustes del usuario, junto a un rediseño de logos y recursos gráficos (assets).

### Cambiado
- **Iconos del Sistema y PWA:** Sustitución global de iconos adaptativos en Android, iOS, Windows, macOS y Web. La PWA instalada usa ahora el isotipo alargado completo, mientras que el *favicon* en la pestaña web mantiene el diseño reducido.

### Arreglado
- **Navegación Web (Router & History):** Arreglado un *crash* del motor interno de Flutter Web originado por un objeto de estado del historial vacío (`serialCount`); se ha estabilizado la sincronización entre el estado interno y el historial del navegador.
- **Doble Navegación:** Implementado un escudo `debounce` global en las llamadas directas e indirectas de `Navigator.push` para bloquear las transiciones dobles al tocar múltiples veces un elemento rápido.
- **Modo Claro (Accesibilidad):** Se han eliminado sombras invasivas y corregido el color del texto superpuesto en las cabeceras de juegos (`Game Hero Section`) para garantizar su legibilidad en temas claros.
- **Modal de Reseñas:** Los campos de fecha ahora reaccionan lógicamente a los cambios de estado del juego, borrándose o ajustándose automáticamente según corresponda.
- **Logros:** Refactorizada la arquitectura interna de la gestión de Logros y subsanados los errores de contexto en sus ventanas emergentes (`Toasts`).
- **Rendimiento y Limpieza:** Arregladas fugas de memoria (`AnimationController` mal desechado en `main_screen`), y reducida la memoria RAM asignada al demonio de Gradle (`gradle.properties`) para solucionar bloqueos por falta de memoria virtual (`C2 CompilerThread out of memory`) en sistemas de desarrollo en Windows.

## [1.2.2] - 2026-09-01

### Añadido
- **Navegación Móvil:** Barra de navegación móvil sólida, opaca y flotante, que incluye una animación para ocultarse al hacer scroll y un botón para los Ajustes.
- **Bundles:** Nueva pantalla de detalles de paquete (`BundleDetailsScreen`). Además, se han aplanado los niveles (Tiers) para Fanatical y Humble Choice.
- **Navegación Web (AppNavigationController):** Creado un motor de navegación e historial completamente personalizado, capaz de interpretar rutas profundas (`deep routes`) en versión Web de manera robusta.
- **Feed de Notificaciones:** Interfaz (UI) y repositorio propio para el centro de notificaciones.
- **Historias:** Ahora puedes ver tus propias historias desde el perfil de usuario.

### Cambiado
- **Interfaz y Portadas:** El encabezado de detalles del juego emplea ahora una AppBar nativa para lograr un alineamiento perfecto. Se han unificado los bordes y mejorado los colores de títulos, así como la usabilidad del Hall of Fame.

### Arreglado
- **Gestos y Botón Atrás (Web/PWA):** Subsanado el bucle en cascada de los gestos "Atrás" (`PopScope`). También se han evitado fallos relacionados con la historia (History API) y la caché estática en Vercel.
- **Notificaciones Push:** Solucionado íntegramente el fallo con las notificaciones PWA en iOS y Vercel empleando el evento Push nativo del *service worker*.
- **Historias (Stories):** Arreglados 4 bugs críticos que involucraban ordenamiento, navegación incorrecta y estados residuales (state leaks).
- **Logros (Achievements):** Reparadas las URLs de deep-linking para los juegos con logros, y ajustados los filtros de exclusión (Nintendo Land, sagas) junto a los cálculos de experiencia.
- **Reseñas:** El modal de reseñas de la biblioteca ahora inicializa el número de rejugada (`replayNumber`) sin errores.

## [1.2.1] - 2026-08-30

### Añadido
- **Notificaciones Globales y Badges:** Implementado un sistema de globos de notificación (badges) en tiempo real con persistencia en base de datos para la pestaña de Actividad.
- **Enlaces a IGDB:** Se añadió el enlace permanente hacia la página original de IGDB en la pestaña de enlaces de cada juego.
- **Hito Actual en Perfil:** Ahora se muestra tu Hito actual (Milestone) en progreso de forma claramente visible en la pantalla del perfil.

### Cambiado
- **Juegos en Pausa:** Los juegos marcados explícitamente como "En pausa" ya no aparecerán rellenando el carrusel de Jugando de la pantalla de Inicio.

### Arreglado
- **Navegación de "Quién lo tiene":** Corregido el fallo crítico al navegar por las listas de amigos, permitiendo ver correctamente el perfil y los amigos de otro usuario.
- **Iconos de Enlaces (CORS y `.ico`):** Solucionado el problema con los iconos de plataformas (Steam, PlayStation, Facebook, etc.) en la versión web integrando el proxy `images.weserv.nl`.
- **Puntuaciones de Metacritic:** Normalizadas las notas de los usuarios (User Score) y garantizado el formateo correcto en la interfaz para prevenir discrepancias numéricas.
- **Timestamps del Feed (Viajes en el tiempo):** Solucionado el bug de zona horaria (timezone) que causaba que los eventos recientes del Feed de Actividad aparecieran con fechas en el futuro.
- **Errores de Base de Datos:** Arreglado el error `PGRST200` al cargar juegos del perfil y solucionada la `PostgrestException` al recuperar la actividad social de los amigos.
- **Estabilidad Web:** Solventado un `duplicate dispose` en la pantalla principal que provocaba cuelgues silenciosos al compilar el proyecto para la web.
- **Estética de Comentarios:** Corregida la indentación visual de las respuestas a comentarios y el formateo de las fechas.

## [1.2.0] - 2026-08-26

### Añadido
- **Sistema de Amigos Integral:** Nueva lista de amigos interactiva en el perfil de usuario. Ahora puedes aceptar solicitudes, ver el estado de tus amigos (ordenados por su actividad más reciente) y navegar directamente a sus perfiles.
- **Autenticación (Flujo de Contraseña):** Añadida la opción de recuperar/restablecer contraseña desde la pantalla de login, además de inicio de sesión (auto-login) automático y transparente al registrar una nueva cuenta.
- **Plataformas e Iconos Extendidos:** Agregado soporte nativo e iconos personalizados para Wii U, 3DS, DS, Switch 2, VR y FireTV.
- **Editoras (Publishers):** La pantalla de información de los juegos ahora recupera y muestra el nombre de las editoras (publishers) importadas directamente desde IGDB.
- **Sistema de Diseño Base (Design System):** Se han cimentado las bases de toda la interfaz (`Corpus Button`, `Chip`, `Slider`, tipografía `Syne`, etc.), unificando el estilo y haciéndolo modular.

### Cambiado
- **Radar de Géneros Interactivo:** Rediseño del gráfico radial de géneros en el perfil de usuario. Ahora es interactivo; al tocar los bordes del radar se despliega la lista de juegos completados de ese género.
- **Mejoras en el Activity Feed (Historias):** El carrusel de Historias fluye ahora en un orden cronológico natural, el temporizador de visualización dura 10 segundos, y *todos* los estados de juego disponen de sistema de comentarios y "Likes", eliminando la limitación a solo juegos completados.
- **Detección Inteligente de DLCs y Remakes:** Mejora en el motor de lectura de metadatos de IGDB para categorizar infaliblemente DLCs, Remakes, Remasters o Mods usando cruce de variables (`gameType` y `parentGame`).
- **Filtros de Biblioteca Avanzados (Estilo Stash):** Las plataformas en los modales de filtrado ahora aparecen ordenadas de forma inteligente por sus familias (Nintendo, PlayStation, Xbox, etc.) e incluyen consolas clásicas para búsquedas mucho más orgánicas.
- **Motor de Navegación:** Transición interna completa a un sistema de router centralizado (`app_routes`) para garantizar transiciones estables y un enrutamiento por rutas nombradas.

### Arreglado
- **Notificaciones Web Push en iOS:** Resuelto el problema crítico de entrega de notificaciones en Safari (iOS) y añadido un globo rojo numérico (badge) a la campana para notificaciones no leídas.
- **Cálculo Desincronizado de XP:** Reparado un desajuste en los Triggers de la base de datos que fallaban al calcular la Experiencia (XP) al marcar juegos completados y se han cerrado brechas de seguridad (RLS) en los logros de usuarios.
- **Importador de CSV a Prueba de Balas:** Reparado el parser de la herramienta de importación, el cual ahora evita inyectar juegos duplicados en tu base de datos cuando se suben archivos antiguos o conflictivos.
- **Precisión del Activity Feed:** Subsanado un error que insertaba eventos fantasma de reseñas vacías al poner un juego en "Wishlist", se sanearon los disparadores obsoletos y se vinculó la eliminación en cascada.
- **Perfeccionamiento Visual (UI):** Ajustada la proporción (AspectRatio) para que las portadas del Hall of Fame no se deformen, centrado en monitores ultrawide corregido, y solventada la recuperación manual de *Covers* perdidas por la base de datos externa.

## [1.1.3] - 2026-08-14

### Añadido
- **Estilos Dinámicos (Stylepacks):** Nuevo sistema de personalización inspirado en Persona 5 Royal, incluyendo efecto de tipeo animado en el título de la portada y música de fondo interactiva.
- **Deep Linking de Notificaciones:** Las notificaciones push ahora son inteligentes y te llevan directamente al contenido (un bundle específico, el post de actividad de tu amigo o a la respuesta de un comentario).
- **Control de Fecha en Reseñas:** Se ha incorporado la opción de elegir manualmente la fecha de finalización o revisión en la esquina superior del modal al editar reseñas.
- **Juegos Abandonados:** Nueva sección de juegos *'Dropped'* en el perfil para seguir el rastro de esos títulos que no te terminaron de enganchar.
- **Cobertura de Tests:** Se han añadido más de 50 test unitarios robustos cubriendo los Modelos base de Corpus para garantizar su solidez futura.

### Cambiado
- **Perfil de Usuario (UI/UX):** La botonera superior de estadísticas (GiantStats) se adapta de forma inteligente a móviles usando un formato grid (2x2), y las pestañas de navegación quedan ancladas a la zona superior (Sticky Tabs) al hacer scroll.
- **Rendimiento e Imágenes:** Implementación global de `CorpusNetworkImage` con caché persistente en disco (evita parpadeos y descargas innecesarias al deslizar listas).
- **Hero de Portada:** La carátula del juego actual se ha rediseñado para que destaque visualmente en móviles, rompiendo limpiamente los márgenes e integrándose con el fondo (y ocultando los límites del banner).
- **Bajo el Capó (Clean Architecture):** Gran refactorización extrayendo repositorios y controladores (`ProfileController`, `GameDetailsController`, etc.). Las llamadas a IGDB ahora pasan por el backend, ocultando por completo las claves secretas en la app.
- **Filtros e Iconos:** Renombrado el estado de "100% Completado" a "Platino" (con icono nuevo), los chips de filtros en el perfil ganan iconos, y se limpia la lectura de puntuaciones (quitando el ".0" innecesario).

### Arreglado
- **Scroll Fantasma en Perfil:** Corregido el destructivo salto de scroll que ocurría al volver de ver los detalles de un juego en tu biblioteca (ahora la lista se refresca *in-place*).
- **Notificaciones Fantasma (Android):** Subsanado un fallo (famoso drop de FCM) que impedía mostrar notificaciones push en ciertos móviles Android por falta del resource del icono.
- **Carátulas y Emojis:** Solucionado el problema con la codificación de emojis al importar librerías externas, e implementado un sistema de re-llenado (backfill) para las carátulas perdidas en la migración.
- **Overflows Visuales:** Exterminadas las bandas amarillas y negras de error de RenderFlex que aparecían en las `GameCard` muy estrechas y en el Hero con pantallas chatas/web.
- **Optimización de Actividad:** Corregidos los bugs de PWA (transiciones de carga en iOS), los enlaces rotos en navegadores Firefox, y silenciado el exceso masivo de actividad en el Feed al realizar importaciones completas de Stash.

## [1.2.0] - 2026-08-08

### Añadido
- **Hall of Fame:** Nuevo buscador en la pantalla de selección de pines para filtrar la colección rápidamente.
- **Feed de Stash:** Sistema de "Leer más" en el carrusel de actividad de inicio. Las reseñas largas se truncan de forma inteligente y abren una ventana flotante (Bottom Sheet) interactiva para leer el texto completo y acceder al juego.

### Cambiado
- **Diseño de Puntuaciones:** La insignia de puntuación de usuarios (User Score) de Metacritic ahora utiliza un formato circular, alineándose con el diseño de la web oficial.
- **Estadísticas de Comunidad:** Eliminado el contador total de reseñas de Stash para simplificar las métricas mostradas en la portada.

### Arreglado
- **Scraper de Metacritic:** Reescrita la extracción de datos para adaptarse a la nueva arquitectura de Metacritic. Ahora se consumen los metadatos estructurados (`application/ld+json`) logrando recuperar correctamente la puntuación de la comunidad y la cantidad de reseñas.
- **Buscador de Bundles:** Resuelto un problema de concurrencia que impedía que el buscador filtrase automáticamente al redirigir al usuario desde la pantalla principal.
- **Soporte Móvil nativo:** Añadido espaciado seguro (Safe Area padding) en la edición de perfil y en el visor de reseñas completas para evitar que los elementos colisionen con los controles del sistema (notch / barra de gestos).

## [1.1.1] - 2026-08-05

### Añadido
- **UI/UX:** Swipe horizontal en el carrusel de Juegos Esperados para móviles.
- **Base de Datos:** Eliminación en cascada en Supabase para las reseñas (`reviews`), permitiendo el borrado de usuarios sin errores de integridad referencial.

### Cambiado
- **Sincronización de Bundles:** El Cron Job automático que actualiza los paquetes de Humble Bundle y Fanatical ahora se ejecuta cada hora (en lugar de cada 4 horas).

### Arreglado
- **Modo Claro (Light Mode):** Pulido visual intensivo para garantizar una experiencia 100% nativa en Modo Claro:
  - Suavizado del degradado del Hero Showcase.
  - Sombra flotante e iconos/texto adaptables en la barra de navegación inferior.
  - Estandarización de botones de Ajustes y Enlaces de Juego (contenedores redondeados con bordes en vez de cajas que tocan los extremos de la pantalla).
  - Corregidos errores de `Ink Splash` (animaciones de toque en botones invisibles).
  - Cajas de comentarios y etiquetas de estado en la Modal de Reseñas ahora adaptan su fondo al tema claro correctamente, evitando textos invisibles.
  - Los indicadores de paginación de los carruseles ya no se vuelven invisibles en fondos blancos.

## [1.1.0] - 2026-08-04

### Añadido
- Nuevo sistema de Bundles Activos con logos oficiales y menús desplegables.
- Sección de "Última oportunidad" (Juegos que salen pronto de suscripciones o tiendas).
- Cuadrícula adaptada a móviles para la interfaz de inicio.
- Modelo de `Game` y `UserGame` mejorado con logros.

### Cambiado
- Refactorización de componentes principales para utilizar el modelo `Game`.
- Optimizaciones de rendimiento (DB aggregation para los logros de usuario y carga cacheada de Metacritic).

### Arreglado
- Comportamiento de "swipe-to-go-back" nativo restaurado en la web para móviles.
- Resoluciones de linter, limpieza de imports y eliminación de declaraciones duplicadas.
- Solución al splash screen nativo en PWA de iOS (eliminación del wordmark en los tags).

# Changelog

All notable changes to this project will be documented in this file.

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

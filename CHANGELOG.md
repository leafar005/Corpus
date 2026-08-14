# Changelog

All notable changes to this project will be documented in this file.

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

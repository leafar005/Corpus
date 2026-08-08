# Changelog

All notable changes to this project will be documented in this file.

## [1.2.0] - 2026-08-08

### Added
- **Hall of Fame:** Nuevo buscador en la pantalla de selección de pines para filtrar la colección rápidamente.
- **Feed de Stash:** Sistema de "Leer más" en el carrusel de actividad de inicio. Las reseñas largas se truncan de forma inteligente y abren una ventana flotante (Bottom Sheet) interactiva para leer el texto completo y acceder al juego.

### Changed
- **Diseño de Puntuaciones:** La insignia de puntuación de usuarios (User Score) de Metacritic ahora utiliza un formato circular, alineándose con el diseño de la web oficial.
- **Estadísticas de Comunidad:** Eliminado el contador total de reseñas de Stash para simplificar las métricas mostradas en la portada.

### Fixed
- **Scraper de Metacritic:** Reescrita la extracción de datos para adaptarse a la nueva arquitectura de Metacritic. Ahora se consumen los metadatos estructurados (`application/ld+json`) logrando recuperar correctamente la puntuación de la comunidad y la cantidad de reseñas.
- **Buscador de Bundles:** Resuelto un problema de concurrencia que impedía que el buscador filtrase automáticamente al redirigir al usuario desde la pantalla principal.
- **Soporte Móvil nativo:** Añadido espaciado seguro (Safe Area padding) en la edición de perfil y en el visor de reseñas completas para evitar que los elementos colisionen con los controles del sistema (notch / barra de gestos).

## [1.1.1] - 2026-08-05

### Added
- **UI/UX:** Swipe horizontal en el carrusel de Juegos Esperados para móviles.
- **Base de Datos:** Eliminación en cascada en Supabase para las reseñas (`reviews`), permitiendo el borrado de usuarios sin errores de integridad referencial.

### Changed
- **Sincronización de Bundles:** El Cron Job automático que actualiza los paquetes de Humble Bundle y Fanatical ahora se ejecuta cada hora (en lugar de cada 4 horas).

### Fixed
- **Modo Claro (Light Mode):** Pulido visual intensivo para garantizar una experiencia 100% nativa en Modo Claro:
  - Suavizado del degradado del Hero Showcase.
  - Sombra flotante e iconos/texto adaptables en la barra de navegación inferior.
  - Estandarización de botones de Ajustes y Enlaces de Juego (contenedores redondeados con bordes en vez de cajas que tocan los extremos de la pantalla).
  - Corregidos errores de `Ink Splash` (animaciones de toque en botones invisibles).
  - Cajas de comentarios y etiquetas de estado en la Modal de Reseñas ahora adaptan su fondo al tema claro correctamente, evitando textos invisibles.
  - Los indicadores de paginación de los carruseles ya no se vuelven invisibles en fondos blancos.

## [1.1.0] - 2026-08-04

### Added
- Nuevo sistema de Bundles Activos con logos oficiales y menús desplegables.
- Sección de "Última oportunidad" (Juegos que salen pronto de suscripciones o tiendas).
- Cuadrícula adaptada a móviles para la interfaz de inicio.
- Modelo de `Game` y `UserGame` mejorado con logros.

### Changed
- Refactorización de componentes principales para utilizar el modelo `Game`.
- Optimizaciones de rendimiento (DB aggregation para los logros de usuario y carga cacheada de Metacritic).

### Fixed
- Comportamiento de "swipe-to-go-back" nativo restaurado en la web para móviles.
- Resoluciones de linter, limpieza de imports y eliminación de declaraciones duplicadas.
- Solución al splash screen nativo en PWA de iOS (eliminación del wordmark en los tags).

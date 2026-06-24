
---

| Campo                | Valor                     |
| -------------------- | ------------------------- |
| **Título**           | Corpus                    |
| **Nº de revisión**   | 1.0                       |
| **Fecha de validez** | 24/06/2026                |
| **Autor**            | Rafael Casado San Segundo |

---

## Índice

1. [Introducción](#1-introducción)
   - 1.1 [Propósito del sistema](#11-propósito-del-sistema)
   - 1.2 [Alcance](#12-alcance)
   - 1.3 [Visión del producto](#13-visión-del-producto)
     - 1.3.1 [Perspectiva del producto](#131-perspectiva-del-producto)
     - 1.3.2 [Funciones del producto](#132-funciones-del-producto)
     - 1.3.3 [Características de usuario](#133-características-de-usuario)
     - 1.3.4 [Limitaciones](#134-limitaciones)
   - 1.4 [Definiciones](#14-definiciones)
2. [Referencias](#2-referencias)
3. [Requisitos específicos](#3-requisitos-específicos)
   - 3.1 [Interfaces externas](#31-interfaces-externas)
   - 3.2 [Funciones](#32-funciones)
   - 3.4 [Requisitos de rendimiento](#34-requisitos-de-rendimiento)
   - 3.6 [Límites de diseño](#36-límites-de-diseño)
   - 3.7 [Atributos del sistema software](#37-atributos-del-sistema-software)
   - 3.8 [Información de soporte](#38-información-de-soporte)
4. [Apéndices](#5-apéndices)
   - 4.1 [Asunciones y dependencias](#51-asunciones-y-dependencias)
   - 4.2 [Acrónimos y abreviaciones](#52-acrónimos-y-abreviaciones)

---

## 1. Introducción

### 1.1 Propósito del sistema

Este documento constituye la Especificación de Requisitos Software (SRS) de **Corpus**, una aplicación multiplataforma de gestión personal y social de videojuegos. Su objetivo es describir de forma suficientemente detallada el sistema para que cualquier equipo de desarrollo que no conozca el proyecto pueda implementarlo sin necesidad de información adicional.

La audiencia de este documento son desarrolladores, colaboradores técnicos y cualquier interesado que deba comprender el alcance y los requisitos del sistema.

### 1.2 Alcance

**Corpus** es una aplicación multiplataforma construida con Flutter que permite a grupos reducidos de amigos gestionar su biblioteca de videojuegos de forma privada, compartir actividad, escribir reseñas desglosadas y sincronizar automáticamente datos de comunidades externas.

El sistema **incluye**:
- Gestión de biblioteca personal (listas de estado, puntuaciones, notas).
- Feed social en tiempo real entre usuarios del grupo.
- Integración con APIs externas de datos de videojuegos.
- Gamificación mediante XP, niveles y logros.
- Scraping automatizado de reseñas de comunidades públicas.

El sistema **no incluye**:
- Una red social pública abierta a cualquier usuario.
- Venta, alquiler o recomendación comercial de videojuegos.
- Funcionalidades de streaming o reproducción de contenido multimedia.

La necesidad de este proyecto surge de la ausencia de herramientas que combinen el seguimiento privado y detallado de una biblioteca personal con la dimensión social de un grupo cerrado de amigos, ofreciendo además análisis propios (reseñas por categoría, tiempos de finalización, sagas) de forma gratuita.

### 1.3 Visión del producto

Corpus se posiciona como una herramienta privada y orientada al detalle para jugadores que desean registrar su historial de videojuegos, compartirlo con su círculo cercano y enriquecerlo con datos agregados de la comunidad global, todo desde una única aplicación multiplataforma y de coste cero.

#### 1.3.1 Perspectiva del producto

El sistema opera en el ecosistema de aplicaciones móviles y de escritorio. Se apoya en los siguientes servicios externos:

- **Supabase** actúa como backend principal (base de datos PostgreSQL, autenticación y funciones en la nube).
- **IGDB** provee metadatos técnicos y portadas de videojuegos.
- **HowLongToBeat (HLTB)** provee tiempos estimados de finalización a través del wrapper npm no oficial `howlongtobeat`, que abstrae las peticiones a la web pública.
- **Stash** es la fuente de reseñas de la comunidad. Sus páginas de reseñas individuales son HTML público renderizado en servidor (ej: `stash.games/games/{slug}/reviews/{usuario}`), lo que permite extraer usuario, puntuación, texto y fecha mediante scraping directo desde la Edge Function.
- **Vercel** alojará la versión web en fases posteriores.

El sistema no requiere ningún servidor propio en esta fase; toda la infraestructura se sustenta en los niveles gratuitos de los servicios mencionados.

#### 1.3.2 Funciones del producto

A continuación se lista el conjunto exhaustivo de funcionalidades que ofrece el sistema:

**Biblioteca**
- Gestión de listas de estado: Wishlist, Playing, Beaten, Abandoned, On Hold.
- Visualización de portada y metadatos del juego (título, fecha de lanzamiento, tiempo HLTB).
- Seguimiento de sagas con barra de progreso agrupada por `collection_id` de IGDB.

**Reseñas y puntuación**
- Puntuación global del juego.
- Reseña desglosada por categorías: Gameplay, Banda Sonora (OST), etc.
- Campo de comentario libre.
- Adjuntar fotos a la reseña.

**Social**
- Feed de actividad en tiempo real de los amigos del grupo.
- Selector de compañero Co-op vinculado a un registro de juego compartido.
- Hall of Fame: vitrina de 5 juegos destacados en el perfil de usuario.
- **"¿Quién lo tiene?":** al buscar o visualizar un juego, el sistema muestra qué miembros del grupo lo tienen en su biblioteca y en qué estado.
- **Actividad en directo:** indicador "jugando ahora" en el perfil de un usuario cuando ha marcado un juego como `playing` en las últimas 24 h.

**Perfil de usuario**
- Avatar y banner personalizables.
- Lista de juegos abandonados con etiqueta de motivo.
- Estadísticas personales: total de juegos, XP y nivel.
- **Mapa de géneros:** visualización gráfica de la biblioteca personal desglosada por géneros obtenidos de IGDB, que muestra los géneros más jugados, completados y abandonados.

**Gamificación**
- Sistema de XP y niveles calculado mediante triggers de base de datos.
- Sistema de logros de juego (Achievements) evaluado por hitos (ej: "10 juegos terminados").
- **Logros meta:** logros sobre el uso de la propia app, independientes de los juegos (ej: "llevas 6 meses registrando actividad", "has escrito más de 50 reseñas", "nunca has abandonado un juego de más de 20 h de historia principal").

**Comunidad**
- Visualización de reseñas externas agregadas de Stash y Steam en la ficha del juego.
- Crawler automatizado en Edge Functions que sincroniza reseñas periódicamente.

**Interfaz**
- Dashboard con lista "Jugando ahora", feed del grupo y botón rápido de añadir juego.
- Ficha de juego con pestañas: "Mi Opinión" | "Grupo" | "Comunidad".
- Versión web (Fase 6) y compilación para Windows y móvil.

#### 1.3.3 Características de usuario

El sistema está orientado a un único tipo de usuario final:

**Usuario jugador**
- Perfil: persona joven-adulta (18-35 años) aficionada a los videojuegos.
- Nivel tecnológico: medio-alto; familiarizado con apps móviles y servicios de streaming/gaming.
- Motivación: llevar un registro personal detallado de su experiencia con videojuegos y compartirlo con un grupo cerrado de amigos.
- No se requieren conocimientos técnicos para el uso de la aplicación.
- El sistema no contempla usuarios con roles diferenciados (no hay administradores ni moderadores en esta fase).

#### 1.3.4 Limitaciones

- **Protección de datos (RGPD/LOPDGDD):** el sistema almacena datos personales de usuarios (nombre, avatar, actividad). Deberá cumplir con la normativa europea de protección de datos. En esta fase, al tratarse de un proyecto personal con usuarios conocidos, se aplica el principio de minimización de datos.
- **Términos de servicio de APIs externas:** el uso de IGDB está sujeto a los términos de Twitch/IGDB. Las reseñas de Stash se obtienen por scraping de páginas HTML públicas; la integración con HLTB se realiza a través del wrapper npm `howlongtobeat`. Ambas deben respetar un uso razonable (bajo volumen, delays entre peticiones) para no vulnerar las condiciones de uso de cada plataforma.
- **Capacidad de almacenamiento:** los niveles gratuitos de Supabase imponen límites de almacenamiento (base de datos y Storage para imágenes). El diseño debe contemplar esta restricción.
- **Disponibilidad de servicios de terceros:** el sistema depende de la disponibilidad de Supabase, IGDB y HLTB. Una caída de estos servicios puede afectar a funcionalidades clave.

### 1.4 Definiciones

| Término | Definición |
|---------|-----------|
| **SRS** | Software Requirements Specification. Documento que describe los requisitos de un sistema software. |
| **CRUD** | Create, Read, Update, Delete. Operaciones básicas sobre datos persistentes. |
| **CU** | Caso de Uso. Descripción de la interacción entre un actor y el sistema. |
| **Beaten** | Estado de un juego que indica que el usuario lo ha completado. |
| **DNF** | Did Not Finish. Estado que indica que el usuario abandonó el juego. |
| **Hall of Fame** | Vitrina de hasta 5 juegos destacados mostrada en el perfil del usuario. |
| **Co-op** | Modo cooperativo. Relación entre dos usuarios que han jugado juntos a un mismo juego. |
| **XP** | Puntos de experiencia usados en el sistema de gamificación. |
| **Trigger** | Procedimiento de base de datos que se ejecuta automáticamente ante un evento. |
| **Edge Function** | Función serverless ejecutada en la infraestructura de Supabase (Deno/TypeScript). |
| **Scraping / Crawler** | Proceso automatizado de extracción de datos de páginas web públicas. |
| **HLTB** | HowLongToBeat. Servicio web que registra tiempos de finalización de videojuegos. |
| **IGDB** | Internet Game Database. API de metadatos de videojuegos mantenida por Twitch. |

---

## 2. Referencias

| Ref. | Documento / Recurso | Descripción |
|------|---------------------|-------------|
| [R1] | Documentación oficial de Supabase — https://supabase.com/docs | Referencia técnica del backend, autenticación y Edge Functions. |
| [R2] | IGDB API Docs — https://api-docs.igdb.com | Especificación de los endpoints usados para metadatos y portadas. |
| [R3] | HowLongToBeat (wrapper npm `howlongtobeat`) — https://www.npmjs.com/package/howlongtobeat | Librería no oficial usada en la Edge Function para consultar tiempos de finalización de HLTB sin scraping directo. |
| [R4] | Flutter Documentation — https://docs.flutter.dev | Referencia del framework de desarrollo multiplataforma. |
| [R5] | Drift (SQLite ORM) — https://drift.simonbinder.eu | Documentación de la capa de caché local. |
| [R6] | Hive (NoSQL local) — https://pub.dev/packages/hive | Alternativa de caché local para velocidad instantánea. |
| [R7] | Reglamento General de Protección de Datos (RGPD) — UE 2016/679 | Marco legal aplicable al tratamiento de datos de usuarios. |

---

## 3. Requisitos específicos

### 3.1 Interfaces externas

#### Interfaz de usuario (UI)

La aplicación presenta tres pantallas principales:

**Dashboard**
- Lista "Jugando ahora" con portadas y progreso, incluyendo indicador "jugando ahora" para amigos activos en las últimas 24 h.
- Feed de actividad reciente de los amigos del grupo (actualizaciones en tiempo real).
- Buscador de actividad reciente

**Ficha de juego**
- *Header:* portada y banner del juego obtenidos de IGDB. Indicador de qué miembros del grupo tienen el juego y en qué estado ("¿Quién lo tiene?").
- *Body:* notas desglosadas del usuario (Gameplay, Audio), fotos adjuntas, compañero Co-op.
- *Tabs:* "Mi Opinión" | "Grupo" | "Comunidad (Stash/Steam)".

**Perfil de usuario**
- Banner personalizable en la cabecera.
- Hall of Fame: grid de 5 posiciones para juegos destacados.
- Lista de juegos por estado (Beaten, Abandoned, etc.) con etiquetas de motivo.
- Estadísticas: total de juegos, nivel y XP.
- Mapa de géneros: gráfico de distribución de la biblioteca por géneros (datos de IGDB).
- Panel de logros: logros de juego y logros meta del usuario.

> Los mockups detallados de cada pantalla se adjuntarán como apéndice gráfico en revisiones posteriores del documento.

#### Interfaces con sistemas externos

| Sistema | Tipo | Dirección | Descripción |
|---------|------|-----------|-------------|
| IGDB API | REST/JSON | Entrada | Consulta de metadatos, portadas y colecciones de juegos. |
| HLTB | Wrapper npm (`howlongtobeat`) | Entrada | Consulta de tiempos de finalización al añadir un juego. La librería gestiona internamente las peticiones a la web pública con los delays necesarios. |
| Stash | HTML scraping (SSR público) | Entrada | Extracción periódica de reseñas desde páginas públicas con estructura fija: `stash.games/games/{slug}/reviews/{usuario}`. Se extraen los campos: `username`, `rating` (numérico), `review_text`, `date`, `completion_type`, `play_time`. |
| Supabase Realtime | WebSocket | Bidireccional | Sincronización del feed de actividad social en tiempo real. |
| Supabase Storage | REST | Bidireccional | Subida y recuperación de imágenes de perfil, banners y fotos de reseñas. |

#### Interfaz de base de datos

Esquema relacional en PostgreSQL (Supabase):

| Tabla | Campos principales |
|-------|-------------------|
| `users` | `id`, `username`, `avatar_url`, `banner_url`, `created_at` |
| `games` | `igdb_id` (PK), `title`, `cover_url`, `release_date`, `hltb_time`, `genres` (array JSON de IGDB) |
| `user_games` | `user_id`, `game_id`, `status`, `rating`, `rating_gameplay`, `rating_soundtrack`, `comment`, `partner_id`, `updated_at` |
| `hall_of_fame` | `user_id`, `game_id`, `pin_order` (1–5) |
| `community_reviews` | `game_id`, `user_name_original`, `review_text`, `rating`, `source`, `created_at` |
| `user_stats` | `user_id`, `total_games_played`, `xp`, `level` |
| `user_achievements` | `user_id`, `achievement_id`, `type` (`game` / `meta`), `unlocked_at` |

Valores del campo `status` en `user_games`: `playing`, `beaten`, `wishlist`, `abandoned`, `on_hold`.

---

### 3.2 Funciones

A continuación se detallan los casos de uso principales del sistema.

---

#### CU-01: Añadir juego a la biblioteca

| Campo | Descripción |
|-------|-------------|
| **Actor** | Usuario |
| **Precondición** | El usuario ha iniciado sesión. |
| **Flujo principal** | 1. El usuario pulsa el botón "Añadir juego". 2. Introduce el título en el buscador. 3. El sistema consulta IGDB y muestra resultados. 4. El usuario selecciona el juego. 5. El sistema registra el juego en `user_games` con estado inicial y obtiene el tiempo HLTB automáticamente. |
| **Flujo alternativo** | Si IGDB no devuelve resultados, el sistema informa al usuario y permite reintentar. |
| **Postcondición** | El juego aparece en la biblioteca del usuario con su portada y metadatos. |

---

#### CU-02: Registrar reseña desglosada

| Campo | Descripción |
|-------|-------------|
| **Actor** | Usuario |
| **Precondición** | El juego existe en la biblioteca del usuario. |
| **Flujo principal** | 1. El usuario accede a la ficha del juego. 2. Selecciona la pestaña "Mi Opinión". 3. Introduce puntuación global, puntuaciones por categoría (Gameplay, OST) y comentario libre. 4. Opcionalmente adjunta fotos. 5. Guarda los cambios. |
| **Postcondición** | La reseña queda almacenada en `user_games` y las fotos en Supabase Storage. |

---

#### CU-03: Consultar feed de actividad

| Campo | Descripción |
|-------|-------------|
| **Actor** | Usuario |
| **Precondición** | El usuario tiene al menos un amigo en el grupo. |
| **Flujo principal** | 1. El usuario accede al Dashboard. 2. El sistema muestra en tiempo real las actualizaciones recientes de los amigos (juego añadido, estado cambiado, reseña publicada). |
| **Flujo alternativo** | Si no hay actividad reciente, el sistema muestra un mensaje vacío. |
| **Postcondición** | El usuario visualiza la actividad actualizada del grupo. |

---

#### CU-04: Gestionar Hall of Fame

| Campo | Descripción |
|-------|-------------|
| **Actor** | Usuario |
| **Precondición** | El usuario tiene juegos en su biblioteca. |
| **Flujo principal** | 1. El usuario accede a su perfil. 2. Selecciona una de las 5 posiciones del Hall of Fame. 3. Elige un juego de su biblioteca. 4. El sistema guarda la selección en `hall_of_fame`. |
| **Flujo alternativo** | Si ya hay un juego en esa posición, se sobreescribe con el nuevo. |
| **Postcondición** | El perfil muestra los juegos destacados actualizados. |

---

#### CU-05: Sincronizar reseñas de la comunidad (Stash)

| Campo | Descripción |
|-------|-------------|
| **Actor** | Sistema (Edge Function automática) |
| **Precondición** | Existen juegos registrados en la tabla `games` con su `slug` de Stash. |
| **Flujo principal** | 1. La Edge Function se ejecuta periódicamente (ej: cada 24 h). 2. Para cada juego, construye la URL pública de reseñas: `stash.games/games/{slug}/reviews`. 3. Obtiene la lista de usuarios con reseñas publicadas. 4. Para cada usuario, accede a `stash.games/games/{slug}/reviews/{usuario}` y parsea el HTML renderizado en servidor extrayendo: `username`, `rating` (valor numérico), `review_text`, `date` y `completion_type`. 5. Almacena las reseñas nuevas en `community_reviews`, ignorando duplicados por `(game_id, user_name_original, source)`. |
| **Flujo alternativo** | Si el origen no está disponible o el HTML cambia de estructura, la función registra el error en un log y omite ese juego en el ciclo actual. |
| **Postcondición** | La tabla `community_reviews` contiene reseñas actualizadas de Stash para los juegos registrados. |

---

#### CU-05b: Obtener tiempo de finalización (HLTB)

| Campo | Descripción |
|-------|-------------|
| **Actor** | Sistema (Edge Function invocada al añadir un juego) |
| **Precondición** | El usuario ha añadido un juego y el sistema dispone de su título. |
| **Flujo principal** | 1. Tras registrar el juego en `games`, la Edge Function invoca el wrapper `howlongtobeat` con el título del juego. 2. La librería realiza la consulta a HLTB con los delays internos configurados. 3. Se extraen los valores: `main_story`, `main_plus_extras` y `completionist` (en horas). 4. Se almacenan en el campo `hltb_time` de la tabla `games` como objeto JSON. |
| **Flujo alternativo** | Si HLTB no devuelve resultados para el título, el campo `hltb_time` queda como `null` y el juego se registra igualmente. El usuario puede ver el campo vacío en la ficha. |
| **Postcondición** | La ficha del juego muestra los tiempos estimados de HLTB junto a los metadatos de IGDB. |

---

#### CU-06: Ganar XP y subir de nivel

| Campo | Descripción |
|-------|-------------|
| **Actor** | Sistema (Trigger de base de datos) |
| **Precondición** | El usuario actualiza el estado de un juego a `beaten`. |
| **Flujo principal** | 1. El trigger detecta el cambio de estado. 2. Calcula el XP correspondiente. 3. Actualiza `user_stats`. 4. Si el XP acumulado supera el umbral del nivel actual, incrementa el nivel. |
| **Postcondición** | El perfil del usuario refleja el nuevo XP y, si procede, el nuevo nivel. |

---

#### CU-07: Asignar compañero Co-op

| Campo | Descripción |
|-------|-------------|
| **Actor** | Usuario |
| **Precondición** | El juego existe en la biblioteca del usuario y tiene al menos un amigo en el grupo. |
| **Flujo principal** | 1. El usuario accede a la ficha del juego. 2. Selecciona la opción "Compañero Co-op". 3. Elige un amigo de la lista. 4. El sistema actualiza `partner_id` en el registro de `user_games`. |
| **Postcondición** | El perfil del juego muestra el compañero Co-op vinculado. |

---

#### CU-08: Seguimiento de saga

| Campo | Descripción |
|-------|-------------|
| **Actor** | Usuario |
| **Precondición** | El usuario tiene juegos de una misma saga en su biblioteca. |
| **Flujo principal** | 1. El usuario accede a la sección de sagas. 2. El sistema agrupa los juegos por `collection_id` de IGDB. 3. Muestra una barra de progreso con los títulos completados frente al total de la saga. |
| **Postcondición** | El usuario visualiza su avance en la saga. |

---

#### CU-09: Consultar "¿Quién lo tiene?"

| Campo | Descripción |
|-------|-------------|
| **Actor** | Usuario |
| **Precondición** | El usuario visualiza la ficha de un juego. El grupo tiene al menos otro miembro. |
| **Flujo principal** | 1. El sistema consulta `user_games` filtrando por `game_id` y todos los `user_id` del grupo. 2. Muestra en el header de la ficha un listado de avatares con el estado de cada miembro (Playing, Beaten, Wishlist, etc.). 3. Si ningún miembro tiene el juego, no se muestra el indicador. |
| **Flujo alternativo** | Si el grupo solo tiene un miembro (el propio usuario), la sección no se renderiza. |
| **Postcondición** | El usuario puede ver de un vistazo quién del grupo tiene o ha jugado ese título. |

---

#### CU-10: Mostrar actividad en directo

| Campo | Descripción |
|-------|-------------|
| **Actor** | Sistema (Supabase Realtime) |
| **Precondición** | Un usuario del grupo tiene al menos un juego en estado `playing` con `updated_at` en las últimas 24 h. |
| **Flujo principal** | 1. Al cargar el Dashboard o el perfil de un amigo, el sistema consulta `user_games` buscando registros con `status = 'playing'` y `updated_at >= now() - interval '24 hours'`. 2. Si existe alguno, muestra un indicador visual ("jugando ahora") junto al nombre del usuario y la portada del juego. 3. El indicador desaparece automáticamente pasadas las 24 h sin actividad nueva. |
| **Postcondición** | El usuario puede ver en tiempo real qué están jugando sus amigos hoy. |

---

#### CU-11: Consultar mapa de géneros

| Campo | Descripción |
|-------|-------------|
| **Actor** | Usuario |
| **Precondición** | El usuario tiene al menos 5 juegos en su biblioteca con metadatos de género de IGDB. |
| **Flujo principal** | 1. El usuario accede a la sección de estadísticas de su perfil. 2. El sistema agrega los géneros de todos los juegos en `user_games` cruzando con la tabla `games` (campo `genres` de IGDB). 3. Genera una visualización (gráfico de barras o mapa de calor) con los géneros más frecuentes, desglosado por estado (Beaten, Abandoned, Playing). |
| **Flujo alternativo** | Si hay juegos sin género asignado en IGDB, se agrupan bajo "Sin clasificar". |
| **Postcondición** | El usuario visualiza la distribución de géneros de su biblioteca personal. |

---

#### CU-12: Desbloquear logro meta

| Campo | Descripción |
|-------|-------------|
| **Actor** | Sistema (Trigger de base de datos) |
| **Precondición** | El usuario realiza una acción dentro de la app que satisface la condición de un logro meta. |
| **Flujo principal** | 1. El trigger evalúa las condiciones de logros meta tras cada acción relevante (nueva reseña escrita, nuevo mes activo, nuevo juego añadido, etc.). 2. Si se cumple alguna condición no desbloqueada previamente, registra el logro en la tabla `user_achievements` con `type = 'meta'`. 3. La app notifica al usuario del desbloqueo. |
| **Ejemplos de condiciones** | "Llevas 6 meses con actividad registrada", "Has escrito más de 50 reseñas", "Nunca has abandonado un juego con más de 20 h de historia principal (según HLTB)". |
| **Postcondición** | El logro aparece en el panel de logros del perfil del usuario. |

---

### 3.4 Requisitos de rendimiento

| ID | Requisito | Métrica de verificación |
|----|-----------|------------------------|
| RND-01 | La biblioteca personal del usuario debe cargarse de forma instantánea en condiciones normales. | Tiempo de carga < 200 ms medido desde caché local (Hive/Drift) sin petición de red. |
| RND-02 | El feed de actividad debe reflejar nuevas actualizaciones en tiempo real. | Latencia de actualización < 2 s en conexión 4G estándar, verificable con Supabase Realtime logs. |
| RND-03 | La búsqueda de juegos en IGDB debe devolver resultados de forma ágil. | Tiempo de respuesta < 1,5 s bajo conexión normal (se mide el round-trip a IGDB). |
| RND-04 | El scraper de reseñas no debe impactar en la experiencia del usuario. | La Edge Function se ejecuta en segundo plano con delays configurables; no bloquea ninguna operación de UI. |
| RND-05 | El sistema debe soportar el uso simultáneo de los miembros del grupo. | Hasta 20 usuarios concurrentes sin degradación perceptible, dentro de los límites del plan gratuito de Supabase. |

---

### 3.6 Límites de diseño

- **Plan gratuito de Supabase:** la arquitectura debe respetar los límites de la capa gratuita (500 MB de base de datos, 1 GB de Storage, 2 millones de solicitudes Edge Functions/mes). Cualquier crecimiento que supere estos límites requerirá revisión del plan de costes.
- **Flutter como único framework de UI:** toda la interfaz debe implementarse en Flutter/Dart. No se permite el uso de WebViews como solución principal de UI.
- **Sin servidor propio:** el sistema no puede depender de infraestructura de servidor personalizada en esta fase. Toda la lógica en la nube reside en Supabase Edge Functions.
- **APIs externas de solo lectura:** la integración con Stash y HLTB es exclusivamente de lectura. El sistema no debe en ningún caso intentar autenticarse ni escribir en esas plataformas.
- **Compatibilidad de plataformas:** el sistema debe compilar y funcionar correctamente en Android, iOS y Web (Fase 6). La compilación para Windows es objetivo de la Fase 6.

---

### 3.7 Atributos del sistema software

| Atributo | Descripción | Cómo medirlo |
|----------|-------------|--------------|
| **Disponibilidad** | El sistema debe estar disponible siempre que lo estén los servicios de Supabase. | Monitorización del uptime de Supabase (SLA del plan gratuito). |
| **Seguridad** | Los datos de cada usuario solo son accesibles por él mismo y sus amigos del grupo. | Revisión de las Row Level Security (RLS) policies de Supabase en cada tabla. |
| **Privacidad** | Los datos personales se almacenan de forma mínima y no se comparten con terceros. | Auditoría del esquema de base de datos y las llamadas a APIs externas. |
| **Mantenibilidad** | El código debe seguir una estructura modular que permita añadir nuevas integraciones de APIs sin refactorizar el núcleo. | Revisión de la arquitectura de capas en el repositorio (separación de data sources, repositorios y UI). |
| **Portabilidad** | La aplicación debe poder compilarse para múltiples plataformas desde una única base de código. | Ejecución exitosa de `flutter build` para Android, iOS y Web sin errores. |

---

### 3.8 Información de soporte

#### Análisis de riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|-------------|---------|-----------|
| Bloqueo de HLTB | Baja | Medio | Se usa el wrapper npm `howlongtobeat`, que gestiona internamente delays y cabeceras. El volumen de peticiones es mínimo (solo al añadir un juego nuevo). Si la librería falla, `hltb_time` queda `null` sin afectar al resto de la app. |
| Cambio de estructura HTML en Stash | Media | Medio | Las páginas de reseñas de Stash son HTML renderizado en servidor con estructura estable. El parser debe aislarse en un módulo independiente para poder actualizarlo sin tocar el resto del sistema. |
| Superación de límites gratuitos de Supabase | Baja (fase inicial) | Medio | Monitorización periódica del uso. Diseño eficiente de consultas y compresión de imágenes antes de subir a Storage. |
| Lentitud por dependencia de red | Media | Bajo | Caché local obligatoria (Hive/Drift): el usuario siempre ve su biblioteca desde caché, nunca espera al servidor. |
| Indisponibilidad de IGDB | Baja | Alto | Caché local de los metadatos ya descargados. Los juegos previamente añadidos siempre son accesibles. |

#### Hoja de ruta — Desarrollador en solitario

La hoja de ruta está diseñada para un único desarrollador trabajando a ritmo personal, priorizando tener algo usable lo antes posible antes de añadir complejidad. Cada fase termina con un estado funcional y utilizable, no con trabajo a medias.

| Fase | Nombre | Contenido | Objetivo al terminar |
|------|--------|-----------|----------------------|
| **0** | **Fundación** | Crear proyecto Supabase. Definir esquema de BD completo con RLS básico. Proyecto Flutter vacío conectado a Supabase. Autenticación (email/password). | Login funcional. La app arranca y conecta con el backend. |
| **1** | **Biblioteca mínima** | CRUD completo de juegos: añadir (manual, sin IGDB todavía), cambiar estado, borrar. Caché local con Hive. Pantalla de biblioteca con lista y estados. | Puedes registrar tus juegos y verlos aunque no haya internet. |
| **2** | **Metadatos reales** | Integración IGDB: búsqueda de juegos, portadas automáticas, géneros y fechas. Integración HLTB (wrapper npm en Edge Function). La búsqueda manual desaparece. | Añadir un juego trae su portada, géneros y tiempo de HLTB automáticamente. |
| **3** | **Reseñas** | Puntuación global y desglosada (Gameplay, OST). Campo de comentario. Adjuntar fotos (Supabase Storage). | Puedes escribir una reseña completa y guardar fotos asociadas al juego. |
| **4** | **Perfil** | Pantalla de perfil propia: avatar, banner, Hall of Fame (5 pines), estadísticas básicas (total juegos, XP inicial). | Tu perfil es visible y personalizable. |
| **5** | **Social básico** | Sistema de grupo: invitar amigos, aceptar. Feed de actividad en tiempo real (Supabase Realtime). "¿Quién lo tiene?" en la ficha del juego. Indicador "jugando ahora". | El grupo funciona: ves lo que hacen tus amigos en tiempo real. |
| **6** | **Comunidad** | Scraper de reseñas de Stash (Edge Function periódica). Tab "Comunidad" en la ficha del juego. Co-op: asignar compañero a un juego. | La ficha de cada juego tiene reseñas externas y puedes registrar con quién lo jugaste. |
| **7** | **Sagas y descubrimiento** | Seguimiento de sagas con barra de progreso (agrupación por `collection_id` de IGDB). Mapa de géneros en el perfil. | Puedes ver tu avance en sagas y un mapa visual de qué tipos de juegos juegas. |
| **8** | **Gamificación completa** | Sistema de XP y niveles (triggers). Logros de juego (hitos: 10 juegos, primera reseña…). Logros meta (6 meses activo, 50 reseñas…). | La app recompensa el uso continuado con logros y progresión. |
| **9** | **Web y escritorio** | `flutter build web` + despliegue en Vercel. Compilación Windows. Ajustes de UI responsive. | Corpus funciona en navegador y en Windows sin código adicional. |

> **Nota sobre el ritmo:** las fases 0–2 son las más críticas y las que más tiempo toman porque sientan toda la base. A partir de la fase 3 el ritmo se acelera porque cada fase añade funcionalidad sobre una estructura ya estable. Se recomienda no empezar la fase 5 sin haber usado la app personalmente durante al menos una semana con datos reales.

---

## 4. Apéndices

### 4.1 Asunciones y dependencias

- Se asume que todos los usuarios disponen de conexión a Internet para las funcionalidades sociales y de sincronización. La biblioteca personal funciona en modo offline gracias a la caché local.
- Se asume que los servicios de terceros (Supabase, IGDB, HLTB, Stash) mantienen sus APIs/estructura actual durante el periodo de desarrollo. Cualquier cambio en ellos puede requerir modificaciones en los requisitos.
- Se asume que el número de usuarios del sistema se mantendrá en un rango reducido (grupo de amigos, < 50 usuarios) durante la fase inicial, lo que justifica el uso del plan gratuito de Supabase.
- Los requisitos de gamificación (XP, niveles, logros) asumen que la lógica de cálculo puede implementarse completamente mediante triggers de PostgreSQL sin necesidad de un servidor de lógica de negocio adicional.
- La funcionalidad de scraping de Stash asume que las páginas de reseñas individuales (`stash.games/games/{slug}/reviews/{usuario}`) siguen siendo HTML renderizado en servidor y de acceso público sin autenticación. Si Stash migrase a una SPA (JavaScript puro) o añadiese autenticación, el scraper requeriría rediseño.
- La obtención de tiempos de HLTB asume que el wrapper npm `howlongtobeat` se mantiene operativo y compatible. Si HLTB cambia su estructura interna, la dependencia del wrapper deberá actualizarse o reemplazarse; mientras tanto, los campos `hltb_time` quedarán como `null` sin bloquear el resto del sistema.

### 4.2 Acrónimos y abreviaciones

| Acrónimo | Significado |
|----------|-------------|
| SRS | Software Requirements Specification |
| CU | Caso de Uso |
| CRUD | Create, Read, Update, Delete |
| API | Application Programming Interface |
| UI | User Interface |
| UX | User Experience |
| RLS | Row Level Security |
| IGDB | Internet Game Database |
| HLTB | HowLongToBeat |
| OST | Original Soundtrack |
| XP | Experience Points (puntos de experiencia) |
| DNF | Did Not Finish |
| ORM | Object-Relational Mapping |
| PK | Primary Key (clave primaria) |
| FK | Foreign Key (clave foránea) |
| RGPD | Reglamento General de Protección de Datos |
| SLA | Service Level Agreement |


---

| Campo                | Valor                     |
| -------------------- | ------------------------- |
| **Título**           | Corpus                    |
| **Nº de revisión**   | 1.2                       |
| **Fecha de validez** | 25/06/2026                |
| **Autor**            | Rafael Casado San Segundo |

### Historial de revisiones

| Rev. | Fecha | Autor | Descripción de los cambios |
|------|-------|-------|----------------------------|
| **1.0** | Junio 2026 | Rafael Casado San Segundo | Versión inicial del documento. Definición del núcleo de la aplicación, fases 0-9, esquema base de Supabase y alcance general del proyecto. |
| **1.1** | Junio 2026 | Rafael Casado San Segundo | (1) `genres` a `jsonb`; (2) modelo `sync_queue` definido; (3) cachés separadas (Drift/Hive); (4) esquema de grupos añadido; (5) `last_played_at` introducido; (6) `play_count` y `play_time_hours` añadidos; (7) riesgo de Stash evaluado; (8) compresión de imágenes obligatoria; (9) límite Co-op documentado; (10) integración GG.deals y Fanatical. |
| **1.2** | 25/06/2026 | Rafael Casado San Segundo | (1) Integración de Steam Web API para automatizar estado "Jugando ahora"; (2) Añadido campo `steam_id`; (3) Regla "Last Write Wins" para `sync_queue`; (4) Paginación obligatoria documentada; (5) Nuevo CU-14 de eliminación de cuenta (RGPD); (6) Cronjob para token IGDB. |

---

## Índice

1. [Introducción](https://www.google.com/search?q=%231-introducci%C3%B3n)
* 1.1 [Propósito del sistema](https://www.google.com/search?q=%2311-prop%C3%B3sito-del-sistema)
* 1.2 [Alcance](https://www.google.com/search?q=%2312-alcance)
* 1.3 [Visión del producto](https://www.google.com/search?q=%2313-visi%C3%B3n-del-producto)
* 1.3.1 [Perspectiva del producto](https://www.google.com/search?q=%23131-perspectiva-del-producto)
* 1.3.2 [Funciones del producto](https://www.google.com/search?q=%23132-funciones-del-producto)
* 1.3.3 [Características de usuario](https://www.google.com/search?q=%23133-caracter%C3%ADsticas-de-usuario)
* 1.3.4 [Limitaciones](https://www.google.com/search?q=%23134-limitaciones)


* 1.4 [Definiciones](https://www.google.com/search?q=%2314-definiciones)


2. [Referencias](https://www.google.com/search?q=%232-referencias)
3. [Requisitos específicos](https://www.google.com/search?q=%233-requisitos-espec%C3%ADficos)
* 3.1 [Interfaces externas](https://www.google.com/search?q=%2331-interfaces-externas)
* 3.2 [Funciones](https://www.google.com/search?q=%2332-funciones)
* 3.4 [Requisitos de rendimiento](https://www.google.com/search?q=%2334-requisitos-de-rendimiento)
* 3.6 [Límites de diseño](https://www.google.com/search?q=%2336-l%C3%ADmites-de-dise%C3%B1o)
* 3.7 [Atributos del sistema software](https://www.google.com/search?q=%2337-atributos-del-sistema-software)
* 3.8 [Información de soporte](https://www.google.com/search?q=%2338-informaci%C3%B3n-de-soporte)


4. [Apéndices](https://www.google.com/search?q=%234-ap%C3%A9ndices)
* 4.1 [Asunciones y dependencias](https://www.google.com/search?q=%2341-asunciones-y-dependencias)
* 4.2 [Acrónimos y abreviaciones](https://www.google.com/search?q=%2342-acr%C3%B3nimos-y-abreviaciones)



---

## 1. Introducción

### 1.1 Propósito del sistema

Este documento constituye la Especificación de Requisitos Software (SRS) de **Corpus**, una aplicación multiplataforma de gestión personal y social de videojuegos. Su objetivo es describir de forma suficientemente detallada el sistema para que cualquier equipo de desarrollo que no conozca el proyecto pueda implementarlo sin necesidad de información adicional.

La audiencia de este documento son desarrolladores, colaboradores técnicos y cualquier interesado que deba comprender el alcance y los requisitos del sistema.

### 1.2 Alcance

**Corpus** es una aplicación multiplataforma construida con Flutter que permite a grupos reducidos de amigos gestionar su biblioteca de videojuegos de forma privada, compartir actividad, escribir reseñas desglosadas y sincronizar automáticamente datos de comunidades externas.

El sistema **incluye**:

* Gestión de biblioteca personal (listas de estado, puntuaciones, notas).
* Feed social en tiempo real entre usuarios del grupo.
* Integración con APIs externas de datos de videojuegos.
* Gamificación mediante XP, niveles y logros.
* Scraping automatizado de reseñas de comunidades públicas.
* Alertas de bundles y ofertas para juegos de la wishlist.

El sistema **no incluye**:

* Una red social pública abierta a cualquier usuario.
* Venta, alquiler o recomendación comercial de videojuegos.
* Funcionalidades de streaming o reproducción de contenido multimedia.

La necesidad de este proyecto surge de la ausencia de herramientas que combinen el seguimiento privado y detallado de una biblioteca personal con la dimensión social de un grupo cerrado de amigos, ofreciendo además análisis propios (reseñas por categoría, tiempos de finalización, sagas) de forma gratuita.

### 1.3 Visión del producto

Corpus se posiciona como una herramienta privada y orientada al detalle para jugadores que desean registrar su historial de videojuegos, compartirlo con su círculo cercano y enriquecerlo con datos agregados de la comunidad global, todo desde una única aplicación multiplataforma y de coste cero.

#### 1.3.1 Perspectiva del producto

El sistema opera en el ecosistema de aplicaciones móviles y de escritorio. Se apoya en los siguientes servicios externos:

* **Supabase** actúa como backend principal (base de datos PostgreSQL, autenticación y funciones en la nube).
* **IGDB** provee metadatos técnicos y portadas de videojuegos.
* **HowLongToBeat (HLTB)** provee tiempos estimados de finalización a través del wrapper npm no oficial `howlongtobeat`, que abstrae las peticiones a la web pública.
* **Stash** es la fuente de reseñas de la comunidad. Sus páginas de reseñas individuales son HTML público renderizado en servidor (ej: `stash.games/games/{slug}/reviews/{usuario}`), lo que permite extraer usuario, puntuación, texto y fecha mediante scraping directo desde la Edge Function.
* **GG.deals API** es la fuente principal para el sistema de alertas de bundles. Ofrece un endpoint REST público (`api.gg.deals/v1/bundles/`) que devuelve bundles activos y bundles históricos por Steam App ID, incluyendo datos de Humble Bundle, Fanatical y otras tiendas. Requiere API key gratuita generada en la cuenta de GG.deals.
* **Fanatical API** complementa la detección de bundles con un endpoint no oficial pero estable (`fanatical.com/api/all-promotions/en`) que devuelve JSON con todas las promociones activas en Fanatical sin necesidad de autenticación.
* **Steam Web API** se utiliza para sincronizar de forma silenciosa e instantánea la actividad actual ("Jugando ahora") de los usuarios en la plataforma de PC.
* **Vercel** alojará la versión web en fases posteriores.

El sistema no requiere ningún servidor propio en esta fase; toda la infraestructura se sustenta en los niveles gratuitos de los servicios mencionados.

#### 1.3.2 Funciones del producto

A continuación se lista el conjunto exhaustivo de funcionalidades que ofrece el sistema:

**Biblioteca**

* Gestión de listas de estado: Wishlist, Playing, Beaten, Abandoned, On Hold.
* Visualización de portada y metadatos del juego (título, fecha de lanzamiento, tiempo HLTB).
* Seguimiento de sagas con barra de progreso agrupada por `collection_id` de IGDB.
* Contador de repeticiones (`play_count`) para registrar partidas múltiples del mismo título sin perder la reseña original.
* Registro de tiempo propio de finalización (`play_time_hours`) independiente del tiempo estimado de HLTB.

**Reseñas y puntuación**

* Puntuación global del juego.
* Reseña desglosada por categorías: Gameplay, Banda Sonora (OST), etc.
* Campo de comentario libre.
* Adjuntar fotos a la reseña.

**Social**

* Feed de actividad en tiempo real de los amigos del grupo.
* Selector de compañero Co-op vinculado a un registro de juego compartido.
* Hall of Fame: vitrina de 5 juegos destacados en el perfil de usuario.
* **"¿Quién lo tiene?":** al buscar o visualizar un juego, el sistema muestra qué miembros del grupo lo tienen en su biblioteca y en qué estado.
* **Actividad en directo:** indicador visual automatizado ("jugando ahora") obtenido vía Steam, o de forma manual cuando el usuario actualiza `last_played_at`.

**Perfil de usuario**

* Avatar y banner personalizables.
* Lista de juegos abandonados con etiqueta de motivo.
* Estadísticas personales: total de juegos, XP y nivel.
* **Mapa de géneros:** visualización gráfica de la biblioteca personal desglosada por géneros obtenidos de IGDB, que muestra los géneros más jugados, completados y abandonados.

**Gamificación**

* Sistema de XP y niveles calculado mediante triggers de base de datos.
* Sistema de logros de juego (Achievements) evaluado por hitos (ej: "10 juegos terminados").
* **Logros meta:** logros sobre el uso de la propia app, independientes de los juegos (ej: "llevas 6 meses registrando actividad", "has escrito más de 50 reseñas", "nunca has abandonado un juego de más de 20 h de historia principal").

**Comunidad**

* Visualización de reseñas externas agregadas de Stash y Steam en la ficha del juego.
* Crawler automatizado en Edge Functions que sincroniza reseñas periódicamente.

**Alertas de bundles y ofertas**

* Notificación en la app cuando un juego de la Wishlist del usuario aparece en un bundle activo en Humble Bundle, Fanatical u otras tiendas, detectado mediante la GG.deals API y la Fanatical API.

**Interfaz**

* Dashboard con lista "Jugando ahora", feed del grupo y botón rápido de añadir juego.
* Ficha de juego con pestañas: "Mi Opinión" | "Grupo" | "Comunidad".
* Versión web (Fase 9) y compilación para Windows y móvil.

#### 1.3.3 Características de usuario

El sistema está orientado a un único tipo de usuario final:

**Usuario jugador**

* Perfil: persona joven-adulta (18-35 años) aficionada a los videojuegos.
* Nivel tecnológico: medio-alto; familiarizado con apps móviles y servicios de streaming/gaming.
* Motivación: llevar un registro personal detallado de su experiencia con videojuegos y compartirlo con un grupo cerrado de amigos.
* No se requieren conocimientos técnicos para el uso de la aplicación.
* El sistema no contempla usuarios con roles diferenciados (no hay administradores ni moderadores en esta fase).

#### 1.3.4 Limitaciones

* **Protección de datos (RGPD/LOPDGDD):** el sistema almacena datos personales de usuarios (nombre, avatar, actividad). Deberá cumplir con la normativa europea de protección de datos (incluyendo borrado de cuenta integral). En esta fase, al tratarse de un proyecto personal con usuarios conocidos, se aplica el principio de minimización de datos.
* **Términos de servicio de APIs externas:** el uso de IGDB está sujeto a los términos de Twitch/IGDB. Las reseñas de Stash se obtienen por scraping de páginas HTML públicas; la integración con HLTB se realiza a través del wrapper npm `howlongtobeat`. Ambas deben respetar un uso razonable (bajo volumen, delays entre peticiones). La GG.deals API requiere API key gratuita y tiene rate limits documentados. El endpoint de Fanatical es no oficial y puede cambiar sin previo aviso.
* **Capacidad de almacenamiento:** los niveles gratuitos de Supabase imponen límites de almacenamiento (base de datos y Storage para imágenes). El diseño debe contemplar esta restricción. Se aplicará compresión obligatoria en cliente antes de subir cualquier imagen: avatar máx. 150 KB, banner máx. 300 KB, foto de reseña máx. 500 KB (formato WebP o JPEG).
* **Disponibilidad de servicios de terceros:** el sistema depende de la disponibilidad de Supabase, IGDB y HLTB. Una caída de estos servicios puede afectar a funcionalidades clave.
* **Co-op limitado a un compañero:** el campo `partner_id` en `user_games` soporta un único compañero de partida. El registro de partidas multijugador de más de dos jugadores queda fuera del scope de esta versión.

### 1.4 Definiciones

| Término | Definición |
| --- | --- |
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
| **Bundle** | Paquete de juegos vendido a precio reducido por plataformas como Humble Bundle o Fanatical. |
| **Sync Queue** | Cola local de escrituras pendientes de sincronización con el servidor. |

---

## 2. Referencias

| Ref. | Documento / Recurso | Descripción |
| --- | --- | --- |
| [R1] | Documentación oficial de Supabase — [https://supabase.com/docs](https://supabase.com/docs) | Referencia técnica del backend, autenticación y Edge Functions. |
| [R2] | IGDB API Docs — [https://api-docs.igdb.com](https://api-docs.igdb.com) | Especificación de los endpoints usados para metadatos y portadas. |
| [R3] | HowLongToBeat (wrapper npm `howlongtobeat`) — [https://www.npmjs.com/package/howlongtobeat](https://www.npmjs.com/package/howlongtobeat) | Librería no oficial usada en la Edge Function para consultar tiempos de finalización de HLTB sin scraping directo. |
| [R4] | Flutter Documentation — [https://docs.flutter.dev](https://docs.flutter.dev) | Referencia del framework de desarrollo multiplataforma. |
| [R5] | Drift (SQLite ORM) — [https://drift.simonbinder.eu](https://drift.simonbinder.eu) | Documentación de la capa de caché local para datos de biblioteca. Decisión: Drift para todos los datos estructurados (juegos, estados, reseñas). |
| [R6] | Hive (NoSQL local) — [https://pub.dev/packages/hive](https://pub.dev/packages/hive) | Almacén clave-valor para datos de sesión y preferencias (token, tema, último scroll). No se usa para datos de biblioteca. |
| [R7] | Reglamento General de Protección de Datos (RGPD) — UE 2016/679 | Marco legal aplicable al tratamiento de datos de usuarios. |
| [R8] | flutter_image_compress — [https://pub.dev/packages/flutter_image_compress](https://pub.dev/packages/flutter_image_compress) | Librería de compresión de imágenes en cliente antes de subida a Supabase Storage. |
| [R9] | GG.deals Bundles API — [https://gg.deals/api/bundles/](https://gg.deals/api/bundles/) | API REST pública (requiere API key gratuita) que expone bundles activos e históricos por Steam App ID, incluyendo Humble Bundle, Fanatical y otras tiendas. Endpoint principal: `api.gg.deals/v1/bundles/active/` y `api.gg.deals/v1/bundles/by-steam-app-id/`. |
| [R10] | Fanatical Promotions API (no oficial) — `https://www.fanatical.com/api/all-promotions/en` | Endpoint JSON no documentado oficialmente que devuelve todas las promociones activas en Fanatical sin autenticación. Sujeto a cambios sin previo aviso. |

---

## 3. Requisitos específicos

### 3.1 Interfaces externas

#### Interfaz de usuario (UI)

La aplicación presenta tres pantallas principales:

**Dashboard**

* Lista "Jugando ahora" con portadas y progreso, incluyendo indicador "jugando ahora" para amigos con `last_played_at` en las últimas 24 h, o actividad directa vía Steam.
* Feed de actividad reciente de los amigos del grupo (actualizaciones en tiempo real).
* Buscador de actividad reciente.
* Notificaciones de bundles/ofertas para juegos en Wishlist.

**Ficha de juego**

* *Header:* portada y banner del juego obtenidos de IGDB. Indicador de qué miembros del grupo tienen el juego y en qué estado ("¿Quién lo tiene?").
* *Body:* notas desglosadas del usuario (Gameplay, Audio), fotos adjuntas, compañero Co-op, tiempo propio de finalización (`play_time_hours`), contador de repeticiones (`play_count`).
* *Tabs:* "Mi Opinión" | "Grupo" | "Comunidad (Stash/Steam)".

**Perfil de usuario**

* Banner personalizable en la cabecera.
* Hall of Fame: grid de 5 posiciones para juegos destacados.
* Lista de juegos por estado (Beaten, Abandoned, etc.) con etiquetas de motivo.
* Estadísticas: total de juegos, nivel y XP.
* Mapa de géneros: gráfico de distribución de la biblioteca por géneros (datos de IGDB).
* Panel de logros: logros de juego y logros meta del usuario.

> Los mockups detallados de cada pantalla se adjuntarán como apéndice gráfico en revisiones posteriores del documento.

#### Interfaces con sistemas externos

| Sistema | Tipo | Dirección | Descripción |
| --- | --- | --- | --- |
| IGDB API | REST/JSON | Entrada | Consulta de metadatos, portadas y colecciones. Requiere de una Edge Function (cronjob) para renovar el token de Twitch (caduca cada ~60 días). |
| HLTB | Wrapper npm (`howlongtobeat`) | Entrada | Consulta de tiempos de finalización al añadir un juego. La librería gestiona internamente las peticiones con los delays necesarios. |
| Stash (reseñas) | HTML scraping (SSR público) | Entrada | Extracción periódica de reseñas: `stash.games/games/{slug}/reviews`. Se extraen: `username`, `rating`, `review_text`, `date`, `completion_type`, `play_time`. |
| GG.deals Bundles API | REST/JSON (API key gratuita) | Entrada | Consulta periódica de bundles activos (`api.gg.deals/v1/bundles/active/`) y bundles históricos por Steam App ID (`api.gg.deals/v1/bundles/by-steam-app-id/`). Cubre Humble Bundle, Fanatical y otras tiendas. Respuesta incluye `title`, `store`, `url`, `dateFrom`, `dateTo` y lista de juegos por tier. |
| Fanatical Promotions API | REST/JSON (sin autenticación) | Entrada | Consulta periódica de `fanatical.com/api/all-promotions/en` para obtener promociones activas en Fanatical no cubiertas por GG.deals. Endpoint no oficial; se usa como fuente complementaria. |
| Supabase Realtime | WebSocket | Bidireccional | Sincronización del feed de actividad social en tiempo real. Se usa exclusivamente para el feed; el indicador "jugando ahora" se consulta por REST al cargar el Dashboard. |
| Supabase Storage | REST | Bidireccional | Subida y recuperación de imágenes de perfil, banners y fotos de reseñas. Todas las imágenes se comprimen en cliente antes de la subida. |
| Steam Web API | REST / JSON | Entrada | Consulta del estado de juego en tiempo real mediante el endpoint `GetPlayerSummaries`. Requiere que el usuario vincule su Steam ID público. |

#### Interfaz de base de datos

Esquema relacional en PostgreSQL (Supabase):

| Tabla | Campos principales |
| --- | --- |
| `users` | `id`, `username`, `avatar_url`, `banner_url`, `steam_id` (nullable), `created_at` |
| `games` | `igdb_id` (PK), `title`, `cover_url`, `release_date`, `hltb_time` (jsonb), `genres` (jsonb), `steam_app_id` (nullable, para cruce con GG.deals) |
| `user_games` | `user_id`, `game_id`, `status`, `rating`, `rating_gameplay`, `rating_soundtrack`, `comment`, `partner_id`, `play_count` (int, default 1), `play_time_hours` (float, nullable), `last_played_at` (timestamp, nullable), `updated_at` |
| `groups` | `id`, `name`, `created_by`, `created_at` |
| `group_members` | `group_id`, `user_id`, `invited_by`, `joined_at`, `status` (`pending` / `active`) |
| `hall_of_fame` | `user_id`, `game_id`, `pin_order` (1–5) |
| `community_reviews` | `game_id`, `user_name_original`, `review_text`, `rating`, `source`, `created_at` |
| `bundle_alerts` | `id`, `bundle_name`, `store`, `url`, `games` (jsonb), `end_date`, `source` (`ggdeals` / `fanatical`), `detected_at` |
| `user_stats` | `user_id`, `total_games_played`, `xp`, `level` |
| `user_achievements` | `user_id`, `achievement_id`, `type` (`game` / `meta`), `unlocked_at` |
| `sync_queue` | `id`, `user_id`, `table_name`, `record_id`, `operation` (`insert`/`update`/`delete`), `payload` (jsonb), `created_at`, `synced_at` (nullable) |

Valores del campo `status` en `user_games`: `playing`, `beaten`, `wishlist`, `abandoned`, `on_hold`.

**Notas de diseño del schema:**

* `genres` se define como `jsonb` (no `text[]`) para permitir queries estructurales sobre los datos de género de IGDB, necesarias para el mapa de géneros (CU-11).
* `hltb_time` se define como `jsonb` para almacenar los tres valores de HLTB (`main_story`, `main_plus_extras`, `completionist`) como objeto estructurado.
* `steam_app_id` en `games` es necesario para el cruce con la GG.deals Bundles API, que opera por Steam App ID. Se rellena automáticamente cuando IGDB devuelve el campo `external_games.steam`.
* `partner_id` en `user_games` soporta un único compañero Co-op. Esta es una limitación de scope documentada; el soporte a partidas multijugador de más de dos jugadores requeriría una tabla `game_partners` separada.
* `sync_queue` centraliza todas las escrituras offline. Los registros con `synced_at = null` están pendientes de sincronización con Supabase.

---

### 3.2 Funciones

A continuación se detallan los casos de uso principales del sistema.

#### CU-01: Añadir juego a la biblioteca

| Campo | Descripción |
| --- | --- |
| **Actor** | Usuario |
| **Precondición** | El usuario ha iniciado sesión. |
| **Flujo principal** | 1. El usuario pulsa el botón "Añadir juego". 2. Introduce el título en el buscador. 3. El sistema consulta IGDB y muestra resultados. 4. El usuario selecciona el juego. 5. El sistema registra el juego en `user_games` con estado inicial y obtiene el tiempo HLTB automáticamente. Si IGDB devuelve `steam_app_id`, se almacena en `games` para uso futuro del sistema de alertas. |
| **Flujo alternativo** | Si IGDB no devuelve resultados, el sistema informa al usuario y permite reintentar. |
| **Flujo offline** | Si no hay conexión, la operación se encola en `sync_queue` y se aplica localmente en Drift. Al recuperar conexión, la app sincroniza automáticamente los registros pendientes basándose en la regla Last Write Wins. |
| **Postcondición** | El juego aparece en la biblioteca del usuario con su portada y metadatos. |

---

#### CU-02: Registrar reseña desglosada

| Campo | Descripción |
| --- | --- |
| **Actor** | Usuario |
| **Precondición** | El juego existe en la biblioteca del usuario. |
| **Flujo principal** | 1. El usuario accede a la ficha del juego. 2. Selecciona la pestaña "Mi Opinión". 3. Introduce puntuación global, puntuaciones por categoría (Gameplay, OST) y comentario libre. 4. Opcionalmente introduce su tiempo real de finalización en `play_time_hours`. 5. Opcionalmente adjunta fotos (comprimidas en cliente antes de subir). 6. Guarda los cambios. |
| **Postcondición** | La reseña queda almacenada en `user_games` y las fotos en Supabase Storage. |

---

#### CU-03: Consultar feed de actividad

| Campo | Descripción |
| --- | --- |
| **Actor** | Usuario |
| **Precondición** | El usuario tiene al menos un amigo en el grupo. |
| **Flujo principal** | 1. El usuario accede al Dashboard. 2. El sistema muestra en tiempo real las actualizaciones recientes de los amigos (juego añadido, estado cambiado, reseña publicada). |
| **Flujo alternativo** | Si no hay actividad reciente, el sistema muestra una pantalla de empty state con invitación a añadir juegos o invitar amigos al grupo. |
| **Postcondición** | El usuario visualiza la actividad actualizada del grupo. |

---

#### CU-04: Gestionar Hall of Fame

| Campo | Descripción |
| --- | --- |
| **Actor** | Usuario |
| **Precondición** | El usuario tiene juegos en su biblioteca. |
| **Flujo principal** | 1. El usuario accede a su perfil. 2. Selecciona una de las 5 posiciones del Hall of Fame. 3. Elige un juego de su biblioteca. 4. El sistema guarda la selección en `hall_of_fame`. |
| **Flujo alternativo** | Si ya hay un juego en esa posición, se sobreescribe con el nuevo. Si el perfil está vacío, se muestra empty state con indicación de cómo configurar el Hall of Fame. |
| **Postcondición** | El perfil muestra los juegos destacados actualizados. |

---

#### CU-05: Sincronizar reseñas de la comunidad (Stash)

| Campo | Descripción |
| --- | --- |
| **Actor** | Sistema (Edge Function automática) |
| **Precondición** | Existen juegos registrados en la tabla `games` con su `slug` de Stash. |
| **Flujo principal** | 1. La Edge Function se ejecuta periódicamente (ej: cada 24 h). 2. Para cada juego, construye la URL pública de reseñas: `stash.games/games/{slug}/reviews`. 3. Obtiene la lista de usuarios con reseñas publicadas. 4. Para cada usuario, accede a `stash.games/games/{slug}/reviews/{usuario}` y parsea el HTML extrayendo: `username`, `rating`, `review_text`, `date`, `completion_type`. 5. Almacena las reseñas nuevas en `community_reviews`, ignorando duplicados por `(game_id, user_name_original, source)`. |
| **Flujo alternativo** | Si el HTML cambia de estructura o la fuente no está disponible, la función registra el error en log y dispara un webhook de alerta (configurable, ej. Discord) indicando el juego afectado y el tipo de fallo. |
| **Postcondición** | La tabla `community_reviews` contiene reseñas actualizadas de Stash para los juegos registrados. |

---

#### CU-05b: Obtener tiempo de finalización (HLTB)

| Campo | Descripción |
| --- | --- |
| **Actor** | Sistema (Edge Function invocada al añadir un juego) |
| **Precondición** | El usuario ha añadido un juego y el sistema dispone de su título. |
| **Flujo principal** | 1. Tras registrar el juego en `games`, la Edge Function invoca el wrapper `howlongtobeat` con el título del juego. 2. La librería realiza la consulta a HLTB con los delays internos configurados. 3. Se extraen los valores: `main_story`, `main_plus_extras` y `completionist` (en horas). 4. Se almacenan en el campo `hltb_time` de la tabla `games` como objeto JSON. |
| **Flujo alternativo** | Si HLTB no devuelve resultados, `hltb_time` queda como `null`. La ficha del juego mostrará el campo vacío con un botón de edición manual para que el usuario introduzca su propio tiempo. |
| **Postcondición** | La ficha del juego muestra los tiempos estimados de HLTB, o el campo de entrada manual si HLTB no devolvió datos. |

---

#### CU-06: Ganar XP y subir de nivel

| Campo | Descripción |
| --- | --- |
| **Actor** | Sistema (Trigger de base de datos) |
| **Precondición** | El usuario actualiza el estado de un juego a `beaten`. |
| **Flujo principal** | 1. El trigger detecta el cambio de estado. 2. Calcula el XP correspondiente. 3. Actualiza `user_stats`. 4. Si el XP acumulado supera el umbral del nivel actual, incrementa el nivel. |
| **Postcondición** | El perfil del usuario refleja el nuevo XP y, si procede, el nuevo nivel. |

---

#### CU-07: Asignar compañero Co-op

| Campo | Descripción |
| --- | --- |
| **Actor** | Usuario |
| **Precondición** | El juego existe en la biblioteca del usuario y tiene al menos un amigo en el grupo. |
| **Flujo principal** | 1. El usuario accede a la ficha del juego. 2. Selecciona la opción "Compañero Co-op". 3. Elige un amigo de la lista. 4. El sistema actualiza `partner_id` en el registro de `user_games`. |
| **Postcondición** | El perfil del juego muestra el compañero Co-op vinculado. |

---

#### CU-08: Seguimiento de saga

| Campo | Descripción |
| --- | --- |
| **Actor** | Usuario |
| **Precondición** | El usuario tiene juegos de una misma saga en su biblioteca. |
| **Flujo principal** | 1. El usuario accede a la sección de sagas. 2. El sistema agrupa los juegos por `collection_id` de IGDB. 3. Muestra una barra de progreso con los títulos completados frente al total de la saga. 4. El usuario puede marcar títulos individuales como "ignorar" dentro de una saga para excluirlos del cómputo de progreso. |
| **Postcondición** | El usuario visualiza su avance en la saga, pudiendo excluir spin-offs o títulos secundarios. |

---

#### CU-09: Consultar "¿Quién lo tiene?"

| Campo | Descripción |
| --- | --- |
| **Actor** | Usuario |
| **Precondición** | El usuario visualiza la ficha de un juego. El grupo tiene al menos otro miembro. |
| **Flujo principal** | 1. El sistema consulta `user_games` filtrando por `game_id` y todos los `user_id` del grupo (tabla `group_members`). 2. Muestra en el header de la ficha un listado de avatares con el estado de cada miembro (Playing, Beaten, Wishlist, etc.). 3. Si ningún miembro tiene el juego, no se muestra el indicador. |
| **Flujo alternativo** | Si el grupo solo tiene un miembro (el propio usuario), la sección no se renderiza. |
| **Postcondición** | El usuario puede ver de un vistazo quién del grupo tiene o ha jugado ese título. |

---

#### CU-10: Mostrar actividad en directo

| Campo | Descripción |
| --- | --- |
| **Actor** | Sistema |
| **Precondición** | Un usuario del grupo tiene un juego en estado `playing` o tiene configurado su `steam_id` público. |
| **Flujo principal** | 1. Al cargar el Dashboard o el perfil de un amigo, el sistema comprueba si el usuario tiene un `steam_id` registrado. <br>

<br>2. **Vía Automática (Steam):** Si tiene `steam_id`, una Edge Function consulta la Steam Web API. Si el usuario está jugando a un título en PC, el sistema busca el juego en la base de datos (vía `steam_app_id`) y activa el indicador visual ("Jugando ahora en Steam") junto a la portada. <br>

<br>3. **Vía Manual (Consolas/Otros):** Si no tiene Steam o está jugando offline, el sistema consulta `user_games` buscando registros con `status = 'playing'` y `last_played_at >= now() - interval '24 hours'`. Si existe, muestra el indicador visual ("jugando ahora"). |
| **Flujo alternativo** | Si el perfil de Steam del usuario es privado o la API de Steam no devuelve actividad, el sistema degrada el funcionamiento automáticamente al método manual. |
| **Nota de diseño** | Para evitar saturar las llamadas a la API de Steam y proteger los límites de Supabase, las consultas de Steam se realizan bajo demanda al cargar la UI y se cachean localmente en Drift durante 5 minutos. |
| **Postcondición** | El usuario puede ver qué están jugando sus amigos en tiempo real (vía Steam) o según su última interacción manual. |

---

#### CU-11: Consultar mapa de géneros

| Campo | Descripción |
| --- | --- |
| **Actor** | Usuario |
| **Precondición** | El usuario tiene al menos 5 juegos en su biblioteca con metadatos de género de IGDB. |
| **Flujo principal** | 1. El usuario accede a la sección de estadísticas de su perfil. 2. El sistema agrega los géneros de todos los juegos en `user_games` cruzando con la tabla `games` (campo `genres` de tipo `jsonb`). 3. Genera una visualización (gráfico de barras o mapa de calor) con los géneros más frecuentes, desglosado por estado (Beaten, Abandoned, Playing). |
| **Flujo alternativo** | Si hay juegos sin género asignado en IGDB, se agrupan bajo "Sin clasificar". |
| **Postcondición** | El usuario visualiza la distribución de géneros de su biblioteca personal. |

---

#### CU-12: Desbloquear logro meta

| Campo | Descripción |
| --- | --- |
| **Actor** | Sistema (Trigger de base de datos o Edge Function periódica) |
| **Precondición** | El usuario realiza una acción dentro de la app que satisface la condición de un logro meta. |
| **Flujo principal** | 1. El trigger (o Edge Function programada para logros que requieren histórico temporal) evalúa las condiciones tras cada acción relevante. 2. Si se cumple alguna condición no desbloqueada previamente, registra el logro en `user_achievements` con `type = 'meta'`. 3. La app notifica al usuario del desbloqueo. |
| **Ejemplos de condiciones** | "Llevas 6 meses con actividad registrada", "Has escrito más de 50 reseñas", "Nunca has abandonado un juego con más de 20 h de historia principal (según HLTB)". |
| **Nota de diseño** | Los logros que requieren evaluación de histórico temporal o cruce con datos externos se implementarán mediante Edge Functions periódicas en lugar de triggers síncronos, para evitar consultas costosas en tiempo real. |
| **Postcondición** | El logro aparece en el panel de logros del perfil del usuario. |

---

#### CU-13: Alertas de bundles y ofertas

| Campo | Descripción |
| --- | --- |
| **Actor** | Sistema (Edge Function automática) + Usuario |
| **Precondición** | El usuario tiene al menos un juego en estado `wishlist`. El juego tiene `steam_app_id` registrado en la tabla `games`. |
| **Flujo principal** | 1. La Edge Function se ejecuta periódicamente (cada 12 h). 2. **Fuente GG.deals:** consulta `api.gg.deals/v1/bundles/active/` para obtener todos los bundles activos en este momento (Humble Bundle, Fanatical y otras tiendas), con lista de juegos por tier, precio, `dateFrom` y `dateTo`. Para los juegos de cada wishlist que tengan `steam_app_id`, también puede consultar `api.gg.deals/v1/bundles/by-steam-app-id/?ids={steam_app_ids}` para obtener el historial de bundles de juegos concretos. 3. **Fuente Fanatical:** consulta `fanatical.com/api/all-promotions/en` para obtener promociones activas en Fanatical no cubiertas por GG.deals. 4. Almacena los bundles nuevos en `bundle_alerts`, ignorando duplicados por `(bundle_name, source)`. 5. Cruza los juegos de cada bundle con los registros en `wishlist` de cada usuario. 6. Para cada coincidencia, genera una notificación en la app dirigida al usuario correspondiente. |
| **Flujo alternativo** | Si la GG.deals API devuelve error (rate limit, clave inválida), se reintenta en el siguiente ciclo y se registra en log. Si el endpoint de Fanatical cambia de estructura, se omite esa fuente y se registra alerta de degradación. Si no hay coincidencias con ninguna wishlist, no se generan notificaciones. |
| **Nota de diseño** | Los juegos sin `steam_app_id` (consola, PC sin Steam) no son cruzables con GG.deals. En estos casos se intenta la comparación por título normalizado contra los datos de Fanatical como fallback, asumiendo que la coincidencia exacta de título es suficiente. |
| **Postcondición** | El usuario recibe una notificación indicando que un juego de su wishlist está disponible en bundle o en oferta, con enlace directo a la página del bundle. |

---

#### CU-14: Eliminar cuenta y datos personales

| Campo | Descripción |
| --- | --- |
| **Actor** | Usuario |
| **Precondición** | El usuario ha iniciado sesión en la aplicación. |
| **Flujo principal** | 1. El usuario accede al menú de configuración de su cuenta. 2. Selecciona la opción "Eliminar cuenta y datos personales". 3. El sistema muestra una advertencia de acción irreversible y requiere confirmación adicional. 4. Tras confirmar, el sistema ejecuta una función de Supabase que elimina el registro en la tabla `users` (disparando un borrado en cascada en las tablas dependientes: `user_games`, reseñas, grupo, etc.) y borra las imágenes asociadas en Supabase Storage. |
| **Postcondición** | Todos los datos del usuario son eliminados permanentemente del sistema, en cumplimiento de los requisitos de las tiendas de aplicaciones y el RGPD. |

---

### 3.4 Requisitos de rendimiento

| ID | Requisito | Métrica de verificación |
| --- | --- | --- |
| RND-01 | La biblioteca personal del usuario debe cargarse de forma instantánea en condiciones normales, implementando paginación si supera los 50 elementos. | Tiempo de carga < 200 ms medido desde caché local (Drift) sin petición de red. |
| RND-02 | El feed de actividad debe reflejar nuevas actualizaciones en tiempo real y soportar paginación (infinite scroll). | Latencia de actualización < 2 s en conexión 4G estándar, verificable con Supabase Realtime logs. |
| RND-03 | La búsqueda de juegos en IGDB debe devolver resultados de forma ágil. | Tiempo de respuesta < 1,5 s bajo conexión normal (se mide el round-trip a IGDB). |
| RND-04 | El scraper de reseñas y las Edge Functions de bundles no deben impactar en la experiencia del usuario. | Las Edge Functions se ejecutan en segundo plano con delays configurables; no bloquean ninguna operación de UI. |
| RND-05 | El sistema debe soportar el uso simultáneo de los miembros del grupo. | Hasta 20 usuarios concurrentes sin degradación perceptible, dentro de los límites del plan gratuito de Supabase. |
| RND-06 | Las escrituras offline deben sincronizarse sin intervención del usuario. | Los registros en `sync_queue` con `synced_at = null` deben procesarse en menos de 5 s tras recuperar conexión. |

---

### 3.6 Límites de diseño

* **Plan gratuito de Supabase:** la arquitectura debe respetar los límites de la capa gratuita (500 MB de base de datos, 1 GB de Storage, 2 millones de solicitudes Edge Functions/mes). Cualquier crecimiento que supere estos límites requerirá revisión del plan de costes.
* **Paginación obligatoria:** Para proteger la memoria del dispositivo y los límites de lectura, las consultas de colecciones que puedan crecer indefinidamente (la Biblioteca del usuario y el Feed social) deberán implementar paginación lógica o *infinite scroll* (ej. cargando elementos en bloques de 20 en 20).
* **Resolución de conflictos Offline:** Para las escrituras encoladas en la tabla `sync_queue`, el sistema aplicará siempre la regla de resolución **"Last Write Wins"** (La última escritura gana). Si existe un conflicto de sincronización tras estar sin conexión, prevalecerá la versión con el `updated_at` más reciente.
* **Flutter como único framework de UI:** toda la interfaz debe implementarse en Flutter/Dart. No se permite el uso de WebViews como solución principal de UI.
* **Sin servidor propio:** el sistema no puede depender de infraestructura de servidor personalizada en esta fase. Toda la lógica en la nube reside en Supabase Edge Functions.
* **APIs externas de solo lectura:** la integración con Stash, HLTB, GG.deals y Fanatical es exclusivamente de lectura. El sistema no debe en ningún caso intentar autenticarse ni escribir en esas plataformas.
* **Compatibilidad de plataformas:** el sistema debe compilar y funcionar correctamente en Android, iOS y Web (Fase 9). La compilación para Windows es objetivo de la Fase 9.
* **Caché local:** Drift se usa para todos los datos estructurados de la biblioteca (juegos, estados, reseñas). Hive se reserva para datos de sesión y preferencias (token, tema, preferencias de UI). No se deben mezclar responsabilidades.
* **Compresión obligatoria de imágenes:** toda imagen subida a Supabase Storage debe comprimirse en cliente (flutter_image_compress) antes del upload. Límites: avatar ≤ 150 KB, banner ≤ 300 KB, foto de reseña ≤ 500 KB.

---

### 3.7 Atributos del sistema software

| Atributo | Descripción | Cómo medirlo |
| --- | --- | --- |
| **Disponibilidad** | El sistema debe estar disponible siempre que lo estén los servicios de Supabase. | Monitorización del uptime de Supabase (SLA del plan gratuito). |
| **Seguridad** | Los datos de cada usuario solo son accesibles por él mismo y sus amigos del grupo. | Revisión de las Row Level Security (RLS) policies de Supabase en cada tabla, incluyendo `groups` y `group_members`. |
| **Privacidad** | Los datos personales se almacenan de forma mínima y no se comparten con terceros. Existe mecanismo de borrado de cuenta en cascada. | Auditoría del esquema de base de datos y las llamadas a APIs externas. |
| **Mantenibilidad** | El código debe seguir una estructura modular que permita añadir nuevas integraciones de APIs sin refactorizar el núcleo. El parser de Stash y los clientes de GG.deals/Fanatical deben estar aislados en módulos independientes. | Revisión de la arquitectura de capas en el repositorio (separación de data sources, repositorios y UI). |
| **Portabilidad** | La aplicación debe poder compilarse para múltiples plataformas desde una única base de código. | Ejecución exitosa de `flutter build` para Android, iOS y Web sin errores. |
| **Resiliencia offline** | El sistema debe funcionar en modo lectura sin conexión y encolar escrituras para sincronizar al recuperarla. | Prueba de añadir/modificar juegos sin conexión y verificar sincronización posterior con Supabase. |

---

### 3.8 Información de soporte

#### Análisis de riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
| --- | --- | --- | --- |
| Caducidad del Token de IGDB | Alta | Alto | Los tokens de acceso servidor de Twitch caducan cada ~60 días. Se mitigará implementando un cronjob (Edge Function) que renueve el token automáticamente antes de su caducidad y lo guarde de forma segura. |
| Bloqueo de HLTB | Baja | Medio | Se usa el wrapper npm `howlongtobeat`. Si falla, `hltb_time` queda `null`; la ficha muestra campo de edición manual. Monitorizar el porcentaje de `hltb_time = null` en nuevos juegos; alertar si supera el 20%. |
| Cambio de estructura HTML en Stash | Media-Alta | Alto | Parser aislado en módulo independiente. Webhook de alerta a Discord cuando el parser detecte errores estructurales recurrentes. |
| Superación de límites gratuitos de Supabase | Baja (fase inicial) | Medio | Monitorización periódica. Compresión obligatoria de imágenes. Paginación obligatoria. Consulta REST para "jugando ahora" en lugar de WebSocket permanente. |
| Lentitud por dependencia de red | Media | Bajo | Caché local en Drift. Cola de escrituras offline (sync_queue). |
| Indisponibilidad de IGDB | Baja | Alto | Caché local de los metadatos ya descargados. Los juegos previos siempre son accesibles. |
| Cambio en la GG.deals API | Baja | Medio | API documentada y estable, con changelog público. Si cambia, el módulo cliente es independiente y actualizable sin tocar el resto del sistema. El sistema de alertas se degrada gracefully (sin notificaciones) si la API falla. |
| Cambio en el endpoint de Fanatical | Media | Bajo | Endpoint no oficial; se usa como fuente complementaria. Si falla, GG.deals (que ya cubre Fanatical) actúa como fallback. El impacto es mínimo. |

#### Hoja de ruta — Desarrollador en solitario

La hoja de ruta está diseñada para un único desarrollador trabajando a ritmo personal, priorizando tener algo usable lo antes posible antes de añadir complejidad. Cada fase termina con un estado funcional y utilizable, no con trabajo a medias.

| Fase | Nombre | Contenido | Objetivo al terminar |
| --- | --- | --- | --- |
| **0** | **Fundación** | Crear proyecto Supabase. Definir esquema de BD completo con RLS básico (incluyendo `groups`, `group_members`, `sync_queue`, `bundle_alerts`, campo `steam_app_id` en `games`). Proyecto Flutter vacío conectado a Supabase. Autenticación (email/password). Decisión de caché resuelta: Drift para biblioteca, Hive para sesión. | Login funcional. Schema definitivo creado. La app arranca y conecta con el backend. |
| **1** | **Biblioteca mínima** | CRUD completo de juegos (manual, sin IGDB). Caché local con Drift. Cola de escrituras offline (sync_queue). Pantalla de biblioteca con lista, estados y paginación. | Puedes registrar juegos y verlos sin internet. Los cambios offline se sincronizan al recuperar conexión (Last Write Wins). |
| **2** | **Metadatos reales** | Integración IGDB: búsqueda, portadas, géneros (`jsonb`), fechas y `steam_app_id`. Cronjob de renovación del token de Twitch. Integración HLTB (Edge Function). Campo de edición manual si HLTB devuelve null. | Añadir un juego trae portada, géneros y tiempo HLTB automáticamente sin que el token caduque. |
| **3** | **Reseñas** | Puntuación global y desglosada. Campo de comentario. Campo `play_time_hours`. Adjuntar fotos con compresión (flutter_image_compress). | Puedes escribir una reseña completa, registrar tu tiempo real y guardar fotos. |
| **4** | **Perfil y Ajustes** | Avatar, banner (comprimidos), Hall of Fame (5 pines), estadísticas básicas. Implementación de CU-14 (Borrado de cuenta). Empty states en todas las pantallas. | Tu perfil es visible, personalizable y el usuario tiene control total sobre sus datos personales. |
| **5** | **Social y Conectividad** | Sistema de grupo (`groups`, `group_members`): invitar, aceptar. Feed en tiempo real paginado (Supabase Realtime). "¿Quién lo tiene?". Indicador "jugando ahora" automatizado con Steam Web API y fallback manual basado en `last_played_at`. | El grupo funciona: ves lo que hacen tus amigos en tiempo real y la app detecta automáticamente si están jugando en Steam. |
| **6** | **Comunidad y alertas** | Scraper de reseñas de Stash (Edge Function con webhook de alerta). Sistema de alertas de bundles (GG.deals API + Fanatical API, Edge Function cada 12 h). Co-op: asignar compañero, campo `play_count`. Tab "Comunidad" en la ficha. | Reseñas externas en la ficha. Recibes notificación cuando un juego de tu wishlist aparece en Humble Bundle, Fanatical u otras tiendas. |
| **7** | **Sagas y descubrimiento** | Seguimiento de sagas con barra de progreso y opción de ignorar títulos. Mapa de géneros (queries sobre `genres` jsonb). | Avance en sagas con control de qué títulos contar. Mapa visual de géneros. |
| **8** | **Gamificación completa** | XP y niveles (triggers). Logros de juego. Logros meta (Edge Functions periódicas). | La app recompensa el uso continuado. |
| **9** | **Web y escritorio** | `flutter build web` + Vercel. Compilación Windows. Ajustes responsive. | Corpus funciona en navegador y Windows. |

> **Nota sobre el ritmo:** las fases 0–2 son las más críticas porque sientan toda la base. A partir de la fase 3 el ritmo se acelera sobre una estructura ya estable. Se recomienda no empezar la fase 5 sin haber usado la app personalmente durante al menos una semana con datos reales.

---

## 4. Apéndices

### 4.1 Asunciones y dependencias

* Se asume que todos los usuarios disponen de conexión a Internet para las funcionalidades sociales y de sincronización. La biblioteca personal funciona en modo offline gracias a Drift y la `sync_queue`.
* Se asume que los servicios de terceros (Supabase, IGDB, HLTB, Stash, GG.deals, Steam) mantienen sus APIs/estructura durante el periodo de desarrollo. Cualquier cambio puede requerir modificaciones en los requisitos.
* Se asume que el número de usuarios se mantendrá en un rango reducido (< 50) durante la fase inicial, justificando el plan gratuito de Supabase.
* Los logros de juego (XP, niveles, hitos) se implementan mediante triggers de PostgreSQL. Los logros meta que requieren evaluación temporal o cruce de histórico se implementan como Edge Functions periódicas.
* La funcionalidad de scraping de Stash asume que las páginas de reseñas siguen siendo HTML SSR de acceso público sin autenticación.
* El sistema de alertas de bundles asume que la GG.deals API mantiene su estructura y la API key gratuita sigue siendo suficiente para el volumen de peticiones del proyecto. El endpoint de Fanatical se usa como fuente complementaria sin garantías de estabilidad.
* Los juegos sin `steam_app_id` (títulos exclusivos de consola, versiones DRM-free) tendrán cobertura limitada en el sistema de alertas de bundles y no serán compatibles con la detección automática de "jugando ahora" vía Steam.

### 4.2 Acrónimos y abreviaciones

| Acrónimo | Significado |
| --- | --- |
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
| SSR | Server-Side Rendering |
| KB | Kilobyte |
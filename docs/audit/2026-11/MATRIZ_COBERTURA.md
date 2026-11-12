# Matriz de Cobertura de la Auditoría Técnica: Corpus-dev

**Proyecto**: Corpus-dev  
**Fecha**: 2026-11-08  
**Rango de Delta**: `773bfc5..86c1116` (150 archivos modificados, +12.342 / -1.352 líneas)  

---

## 1. Cobertura por Directorio y Módulo del Repositorio

| Directorio / Área | Archivos Revisados / Total | Nivel de Profundidad | Notas de Alcance y Hallazgos Clave |
|---|:---:|:---:|---|
| `supabase/migrations/` | 52 / 52 (100%) | Exhaustivo (Línea a línea en Delta) | Colisión `20260904000000`, ciclo efímero de roadmap, omisión `to_play` en trigger de feed. |
| `supabase/functions/` | 15 / 15 (100%) | Exhaustivo (Código y configuración) | Auth check en `send-push`, Confused Deputy en `notify-*`, CORS compartido y rate limits. |
| `lib/models/` | 18 / 18 (100%) | Exhaustivo | Modelos nuevos (`game_group`, `game_group_item`, `user_game_platform`), enum `to_play`. |
| `lib/repositories/` | 12 / 12 (100%) | Exhaustivo | `CollectionRepository` (platinos), `GameGroupRepository` (corrupción descripción). |
| `lib/routes/` | 6 / 6 (100%) | Exhaustivo | ADR-001, `AppRoutes`, `CorpusRouter`, falta de `RouteSettings` en pantallas nuevas. |
| `lib/screens/my_games/` | 7 / 7 (100%) | Exhaustivo | Módulo completo nuevo: pestañas, drag & drop, controladores reactivos. |
| `lib/screens/profile/` | 18 / 18 (100%) | Exhaustivo | Estantería física, widgets de cajas 3D, asignación masiva de plataformas. |
| `lib/screens/library/` | 14 / 14 (100%) | Exhaustivo | Descomposición de `review_modal`, widgets extraídos, búsqueda y filtros. |
| `lib/screens/activity/` | 8 / 8 (100%) | Exhaustivo | Formatters de feed para `to_play`, visor de historias, detalle de reseñas. |
| `lib/screens/settings/` | 9 / 9 (100%) | Exhaustivo | Ajustes, importación Steam/Stash, notificación de prueba rota. |
| `lib/screens/bundles/` | 2 / 2 (100%) | Exhaustivo | Identificación de `bundles_screen.dart` como código huérfano. |
| `lib/theme/` | 3 / 3 (100%) | Exhaustivo | Verificación contra Zip Slip / Path traversal en `style_pack_registry.dart`. |
| `lib/utils/` | 8 / 8 (100%) | Exhaustivo | `shelf_platforms.dart` (80+ plataformas), `corpus_logger.dart`, `image_compressor.dart`. |
| `lib/widgets/` | 32 / 32 (100%) | Exhaustivo | Sistema Tabler Icons, `CorpusIconKind`, widgets reutilizables de diseño. |
| `test/` e `integration_test/` | 6 / 6 (100%) | Exhaustivo | Verificación de tests de deep routes, style packs y adaptaciones de review modal. |
| `macos/` | 3 / 3 (100%) | Exhaustivo | `Release.entitlements`: omisión crítica de `network.client`. |
| `ios/` | 4 / 4 (100%) | Exhaustivo | `Info.plist`: omisión crítica de permisos de fotos y cámara. |
| `android/` | 4 / 4 (100%) | Exhaustivo | `AndroidManifest.xml`: ausencia de deep link intent-filters. |
| `web/` | 4 / 4 (100%) | Exhaustivo | `index.html` (SRI ausente), `manifest.json`. |
| `Configuración raíz` | 7 / 7 (100%) | Exhaustivo | `vercel.json` (caché 1 año), `vercel_build.sh`, `pubspec.yaml`, `analysis_options.yaml`. |

---

## 2. Resumen Estadístico de Cobertura
- **Total de Archivos Auditados en Profundidad**: 224 archivos (incluyendo 150 modificados en delta y archivos contextuales base).
- **Porcentaje de Cobertura en Superficie Crítica**: 100% de migraciones, Edge Functions, configuraciones de empaquetado nativo y modelos de persistencia.
- **Modificaciones Aplicadas en el Código**: 0 archivos (Estricto modo de solo lectura cumplido).
- **Comprobaciones Ejecutables Locales Realizadas**:
  - `git diff --stat 773bfc5..86c1116` (verificación exacta de 150 archivos, 20 commits).
  - `git status --short` (verificación de working tree limpio).
  - `dart analyze c:\software\Corpus` (análisis estático de linter y compilador en SDK 3.12.2 con 1.106 diagnósticos mapeados).

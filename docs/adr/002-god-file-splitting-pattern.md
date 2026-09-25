# ADR-002: Patrón de Splitting de God Files

> **Estado:** Propuesto  
> **Fecha:** 2026-09-25  
> **Contexto:** Auditoría técnica, Fase 3

---

## Problema

10 archivos en `lib/screens/` superan las 1000 líneas. Los más críticos:

| Archivo | Líneas | Responsabilidades mezcladas |
|---------|-------:|----------------------------|
| `review_modal.dart` | 1902 | UI + validación + upload + state |
| `review_details_screen.dart` | 1834 | UI + fetch + like/comment + gallery |
| `hero_showcase.dart` | 1270 | UI + animaciones + datos |
| `profile_achievements_tab.dart` | 1213 | UI + fetch + filtros + grid |
| `profile_screen.dart` | 1210 | UI + fetch + social + stats |

## Patrón Propuesto: Screen + Controller + Widgets

Cada god file se divide en **3 capas**:

```
screens/activity/
├── activity_screen.dart           ← UI pura (build methods)
├── activity_controller.dart       ← Estado + lógica de negocio (ya existe)
└── widgets/
    ├── activity_feed_card.dart    ← Widget extraído del build
    ├── activity_stories_bar.dart  ← Widget extraído del build
    └── activity_empty_state.dart  ← Widget extraído del build
```

### Reglas del Split

1. **El Screen** solo tiene:
   - `initState` / `dispose` (delegando al controller)
   - `build()` que compone widgets extraídos
   - Handlers de UI (navegación, dialogs)
   - Máximo **300 líneas**

2. **El Controller** tiene:
   - Todo el estado (`ValueNotifier`, `ChangeNotifier`, o futuro Riverpod)
   - Llamadas a repositorios
   - Lógica de transformación de datos
   - Sin dependencias de `BuildContext`

3. **Los Widgets extraídos** son:
   - `StatelessWidget` o `StatefulWidget` auto-contenidos
   - Reciben datos por constructor (no acceden al controller directamente)
   - Reutilizables en otros contextos

### Ejemplo: Extraer la Story Bar del Activity Screen

**Antes** (en `activity_screen.dart`, líneas 500-650):
```dart
// 150 líneas de UI inline para el carrusel de stories
SizedBox(
  height: 100,
  child: ListView.builder(
    scrollDirection: Axis.horizontal,
    itemCount: friends.length,
    itemBuilder: (context, index) {
      // ... 80 líneas de avatar + anillo + nombre ...
    },
  ),
)
```

**Después** (en `widgets/activity_stories_bar.dart`):
```dart
class ActivityStoriesBar extends StatelessWidget {
  const ActivityStoriesBar({
    super.key,
    required this.friends,
    required this.userStories,
    required this.viewedIds,
    required this.onTap,
  });

  final List<Map<String, dynamic>> friends;
  final Map<String, List<Map<String, dynamic>>> userStories;
  final Set<String> viewedIds;
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    // Las mismas 150 líneas, ahora auto-contenidas
  }
}
```

**En `activity_screen.dart`**:
```dart
ActivityStoriesBar(
  friends: _controller.friends,
  userStories: _controller.userStories,
  viewedIds: viewedStoryIdsNotifier.value,
  onTap: (i) => _openUserStory(_controller.friends, i),
)
```

## Orden de Ejecución Propuesto

| Prioridad | Archivo | Razón |
|-----------|---------|-------|
| 1 | `review_modal.dart` (1902 líneas) | Más grande, UI + upload + state mezclados |
| 2 | `review_details_screen.dart` (1834 líneas) | Segundo más grande, muchas secciones extraíbles |
| 3 | `profile_screen.dart` (1210 líneas) | Ya tiene controller, falta extraer widgets |
| 4 | `home_screen.dart` (1166 líneas) | Muchas secciones independientes |
| 5 | `activity_screen.dart` (1015 líneas) | Ya tiene controller, split más directo |

## Riesgos

- **Riesgo de regresión:** Cada split puede romper gestión de estado si el widget extraído necesita acceso a `setState` del padre
- **Mitigación:** Hacer un archivo a la vez, con `flutter test` tras cada split
- **Mitigación 2:** Usar `ValueListenableBuilder` para comunicación padre→hijo reactiva

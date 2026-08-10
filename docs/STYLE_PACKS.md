# Corpus — Guía para crear Style Packs

Documento de referencia para agentes y desarrolladores que quieran **crear, registrar o importar** paquetes de estilo en Corpus.

---

## 1. Qué es un Style Pack

Un **Style Pack** es un conjunto de parámetros visuales que cambian la apariencia global de la app:

- Colores (primario, fondos, superficies, acento)
- Tipografía (fuente general y fuente del hero del inicio)
- Radios de borde (chips, cards, modales)
- Estilo de la barra de navegación móvil

**No controla** (quedan fuera del pack):

- Colores funcionales: medallas (oro/plata/bronce), plataformas (PlayStation, Xbox…), Metacritic, Steam, errores (`Colors.red`)
- Overlays sobre imágenes (hero, banners, galerías)
- Layout, orden de secciones, visibilidad de widgets (eso es otra pantalla: Apariencia → Personalizar Inicio)

---

## 2. Arquitectura (resumen)

```
StylePack (modelo)
    ├── AppTheme.getLightTheme / getDarkTheme  → ThemeData
    └── CorpusThemeExtension                   → tokens extra (hero, radios, navBar)

StylePackRegistry
    ├── built-in: incluidos en la app (default + los que registres en código)
    └── imported: JSON guardado en SharedPreferences (móvil)

ThemeNotifier (globals.themeNotifier)
    ├── stylePackId  → pack activo
    ├── setStylePack(id)
    └── currentPack
```

**Archivos clave:**

| Archivo | Rol |
|---------|-----|
| `lib/theme/style_pack.dart` | Modelo `StylePack`, `NavBarStyle`, serialización JSON |
| `lib/theme/style_pack_registry.dart` | Catálogo built-in + importados |
| `lib/theme/corpus_theme_extension.dart` | `ThemeExtension` accesible en widgets |
| `lib/theme/app_theme.dart` | Genera `ThemeData` desde un pack |
| `lib/globals.dart` | `themeNotifier` global |
| `lib/screens/appearance_screen.dart` | Selector de packs + importación (móvil) |
| `lib/main.dart` | `StylePackRegistry.loadImported()` al arrancar |

---

## 3. Formato JSON de un pack

Los packs importables son un **único archivo `.json`** con esta estructura:

```json
{
  "id": "retro_gaming",
  "name": "Retro Gaming",
  "description": "Estilo inspirado en consolas clásicas",
  "seedColor": "#FF6B35",
  "scaffoldLight": "#F0E6D3",
  "scaffoldDark": "#1A1A2E",
  "surfaceLight": "#FFF8F0",
  "surfaceDark": "#16213E",
  "accentColor": "#FFD700",
  "fontFamily": "Press Start 2P",
  "heroFontFamily": "Press Start 2P",
  "heroFontSize": 36,
  "heroFontWeight": 700,
  "borderRadiusSmall": 0,
  "borderRadiusMedium": 4,
  "borderRadiusLarge": 8,
  "navBarStyle": "solid"
}
```

### Campos obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | string | Identificador único (`snake_case`, sin espacios). Si se reimporta el mismo `id`, se sobrescribe. |
| `name` | string | Nombre visible en Apariencia |
| `seedColor` | string hex | Color primario (`#RRGGBB`). Al activar el pack, también actualiza el color de acento guardado. |
| `accentColor` | string hex | Color secundario del `ColorScheme` (p. ej. estrellas, chips secundarios) |

### Campos opcionales

| Campo | Tipo | Default | Descripción |
|-------|------|---------|-------------|
| `description` | string | — | Texto descriptivo (no se muestra aún en UI; útil para catálogo web) |
| `scaffoldLight` | hex | `#F5F5F5` | Fondo modo claro |
| `scaffoldDark` | hex | `#000000` | Fondo modo oscuro |
| `surfaceLight` | hex | `#FFFFFF` | Cards, inputs, superficies en claro |
| `surfaceDark` | hex | gris 900 | Superficies en oscuro |
| `fontFamily` | string \| omitir | `null` (Roboto/Material) | Fuente global. Si es nombre de **Google Font**, se resuelve vía paquete `google_fonts`. |
| `heroFontFamily` | string \| omitir | — | Fuente del hero en Inicio (`hero_showcase.dart`) |
| `heroFontSize` | number | `48` | Tamaño base del título del hero |
| `heroFontWeight` | number | `900` | Peso: `100`–`900` (múltiplos de 100) |
| `borderRadiusSmall` | number | `8` | Badges, chips pequeños |
| `borderRadiusMedium` | number | `12` | Cards, botones, inputs |
| `borderRadiusLarge` | number | `16` | Contenedores grandes, modales |
| `navBarStyle` | string | `liquidGlass` | Ver sección 5 |

### Colores hex

- Formato: `#RRGGBB` o `RRGGBB` (con o sin `#`)
- Ejemplo: `#7E57C2`, `#FF6B35`

---

## 4. Tres formas de añadir un pack

### A) Pack built-in (web y móvil, incluido en el binario)

Registrar en código **antes** de `runApp`, típicamente en `main.dart`:

```dart
import 'theme/style_pack.dart';
import 'theme/style_pack_registry.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  StylePackRegistry.registerBuiltIn(const StylePack(
    id: 'neon',
    name: 'Neon Nights',
    description: 'Violeta neón sobre fondo oscuro',
    seedColor: Color(0xFFE040FB),
    scaffoldDark: Color(0xFF0D0D1A),
    surfaceDark: Color(0xFF1A1A2E),
    scaffoldLight: Color(0xFFF3E5F5),
    surfaceLight: Colors.white,
    accentColor: Color(0xFF00E5FF),
    fontFamily: 'Orbitron',
    heroFontFamily: 'Orbitron',
    heroFontSize: 42,
    borderRadiusMedium: 16,
    navBarStyle: NavBarStyle.liquidGlass,
  ));

  await StylePackRegistry.loadImported();
  // ... resto de init
  runApp(const CorpusApp());
}
```

**Cuándo usarlo:** packs oficiales que quieras en el deploy web (selector en Apariencia) sin que el usuario importe nada.

### B) Archivo JSON importado (móvil)

1. Crear `mi_pack.json` con el esquema de la sección 3.
2. En la app: **Apariencia → Importar paquete (.json)**.
3. El pack se guarda en `SharedPreferences` (`imported_style_packs`) y aparece en el grid de packs.

**Cuándo usarlo:** addons descargados desde la web para no inflar el tamaño del APK/IPA.

### C) Programático vía JSON (tests o herramientas)

```dart
final pack = StylePackRegistry.importFromJson(jsonDecode(jsonString));
await themeNotifier.setStylePack(pack.id);
```

---

## 5. Estilos de barra de navegación (`navBarStyle`)

Solo afecta al **bottom nav en móvil** (ancho &lt; 800px). En desktop se usa la barra superior plana.

| Valor JSON | Enum | Comportamiento |
|------------|------|----------------|
| `"liquidGlass"` | `NavBarStyle.liquidGlass` | Efecto cristal (`liquid_glass_easy`). **Default de Corpus Classic.** |
| `"solid"` | `NavBarStyle.solid` | `BottomNavigationBar` Material estándar con colores del tema |
| `"minimal"` | `NavBarStyle.minimal` | Solo iconos, sin fondo pill |

Implementación: `lib/screens/main_screen.dart` → `_buildMobileNavBar()`.

---

## 6. Qué cambia cada campo en la UI

| Campo del pack | Dónde se nota |
|----------------|---------------|
| `seedColor` | Botones primarios, tabs activos, iconos seleccionados, links, chips seleccionados |
| `scaffoldLight/Dark` | Fondo general de pantallas |
| `surfaceLight/Dark` | Cards, list tiles, bottom sheets, inputs |
| `accentColor` | `ColorScheme.secondary` (ámbar por defecto en Classic) |
| `fontFamily` | Texto general vía `ThemeData.textTheme` (Google Fonts si aplica) |
| `heroFontFamily` | Títulos “Bienvenido…”, CTAs del hero en Inicio |
| `borderRadiusSmall/Medium/Large` | Cards, botones, inputs, contenedores de Apariencia (vía `CorpusThemeExtension`) |
| `navBarStyle` | Barra inferior móvil |

El usuario puede seguir cambiando **modo claro/oscuro/sistema** y el **color principal** en Apariencia; al elegir un pack, `setStylePack` también fija `seedColor` al del pack.

---

## 7. Pack de referencia: Corpus Classic (default)

Equivale a la UI original antes de style packs:

```dart
StylePack.defaultPack()
// id: 'default'
// name: 'Corpus Classic'
// seedColor: deepPurpleAccent
// scaffoldLight: #F5F5F5, scaffoldDark: black
// surfaceLight: white, surfaceDark: grey.shade900
// accentColor: amber
// fontFamily: null
// heroFontFamily: 'Helvetica'
// borderRadius: 8 / 12 / 16
// navBarStyle: liquidGlass
```

**No eliminar ni reutilizar el id `default`** para packs custom.

---

## 8. Fuentes

### Google Fonts (recomendado)

Si `fontFamily` / `heroFontFamily` coincide con una fuente de [Google Fonts](https://fonts.google.com/), `AppTheme` la carga con el paquete `google_fonts` (descarga en runtime, cache local).

Ejemplos válidos en JSON:

- `"Inter"`
- `"Roboto"`
- `"Press Start 2P"`
- `"Orbitron"`

Usa el **nombre exacto** de la fuente en Google Fonts.

### Fuentes del sistema

- `"Helvetica"` en el hero del default: depende del SO (macOS sí, Windows/web a menudo no).
- Para packs multiplataforma, preferir Google Fonts o fuentes empaquetadas en `pubspec.yaml`.

### Fuentes empaquetadas (futuro)

Hoy los JSON importados **no** incluyen archivos `.ttf`. Para una fuente propia no disponible en Google Fonts:

1. Añadir `.ttf` en `pubspec.yaml` → `fonts:`
2. Referenciar el `family` declarado en el JSON
3. O registrar el pack solo como built-in en la build que incluya esos assets

---

## 9. Checklist para crear un pack nuevo

1. **Definir identidad:** `id` único + `name` legible.
2. **Elegir paleta:** `seedColor`, fondos claro/oscuro, superficies, `accentColor`.
3. **Tipografía:** `fontFamily` (Google Font) + `heroFontFamily` si el hero debe diferir.
4. **Formas:** radios small/medium/large según estética (0 = pixel/retro, 12–16 = moderno).
5. **Nav bar:** `liquidGlass` | `solid` | `minimal`.
6. **Validar JSON** contra el esquema de la sección 3.
7. **Distribuir:**
   - Web oficial → `StylePackRegistry.registerBuiltIn()` en `main.dart` o módulo de init.
   - Addon móvil → publicar `.json` en la web; el usuario importa desde Apariencia.
8. **Probar** en claro y oscuro, y en web + móvil si aplica.

---

## 10. Ejemplo completo: pack “Midnight Blue”

**Archivo:** `midnight_blue.json`

```json
{
  "id": "midnight_blue",
  "name": "Midnight Blue",
  "description": "Azul profundo con acentos cyan",
  "seedColor": "#2979FF",
  "scaffoldLight": "#ECEFF1",
  "scaffoldDark": "#0A0E14",
  "surfaceLight": "#FFFFFF",
  "surfaceDark": "#141B26",
  "accentColor": "#00BCD4",
  "fontFamily": "Inter",
  "heroFontFamily": "Inter",
  "heroFontSize": 44,
  "heroFontWeight": 800,
  "borderRadiusSmall": 6,
  "borderRadiusMedium": 10,
  "borderRadiusLarge": 14,
  "navBarStyle": "solid"
}
```

**Registro built-in (alternativa):**

```dart
StylePackRegistry.registerBuiltIn(StylePack.fromJson({
  "id": "midnight_blue",
  "name": "Midnight Blue",
  "seedColor": "#2979FF",
  "scaffoldLight": "#ECEFF1",
  "scaffoldDark": "#0A0E14",
  "surfaceLight": "#FFFFFF",
  "surfaceDark": "#141B26",
  "accentColor": "#00BCD4",
  "fontFamily": "Inter",
  "heroFontFamily": "Inter",
  "heroFontSize": 44,
  "heroFontWeight": 800,
  "borderRadiusSmall": 6,
  "borderRadiusMedium": 10,
  "borderRadiusLarge": 14,
  "navBarStyle": "solid",
}));
```

---

## 11. Uso en widgets (para extender la app)

Si añades UI nueva, **no hardcodees** colores ni radios; usa el tema:

```dart
// Colores Material
final cs = Theme.of(context).colorScheme;
color: cs.primary,
backgroundColor: cs.surface,
style: TextStyle(color: cs.onSurfaceVariant),

// Tokens del pack
final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
borderRadius: ext.radiusMedium,
fontFamily: ext.heroFontFamily,
```

---

## 12. Persistencia y activación

| Clave SharedPreferences | Contenido |
|-------------------------|-----------|
| `style_pack_id` | Id del pack activo (`default` si no hay) |
| `theme_mode` | `system` \| `light` \| `dark` |
| `theme_color` | ARGB del seed (se sincroniza al cambiar pack) |
| `imported_style_packs` | JSON array de packs importados |

Activar un pack:

```dart
await themeNotifier.setStylePack('midnight_blue');
```

La UI se reconstruye vía `ListenableBuilder` en `CorpusApp` (`lib/main.dart`).

---

## 13. Errores frecuentes

| Problema | Causa | Solución |
|----------|--------|----------|
| Pack no aparece en Apariencia | No registrado ni importado | `registerBuiltIn` o importar JSON |
| Fuente no cambia | Nombre incorrecto o no es Google Font | Verificar nombre en fonts.google.com |
| Hero sigue con otra fuente | Solo cambiaste `fontFamily` | Definir también `heroFontFamily` |
| Import falla | JSON inválido o falta `id`/`seedColor`/`accentColor` | Validar campos obligatorios |
| Mismo id, pack viejo | Reimport sobrescribe | Cambiar `id` si quieres conservar ambos |
| Nav no cambia en desktop | Esperado | `navBarStyle` solo afecta bottom bar móvil |

---

## 14. Flujo recomendado para un agente

1. Leer este documento y `lib/theme/style_pack.dart`.
2. Generar el JSON del pack (o el bloque `StylePack(...)` / `registerBuiltIn`).
3. Si es pack oficial web: añadir `registerBuiltIn` en `main.dart` (o archivo de init dedicado).
4. Si es addon: entregar solo el `.json` + instrucciones de importación.
5. No modificar colores funcionales (medallas, plataformas, Metacritic).
6. Probar activación con `themeNotifier.setStylePack(id)` y revisar Inicio, cards, botones y nav móvil.

---

*Última actualización: arquitectura Style Packs v1 — Corpus, rama `design`.*

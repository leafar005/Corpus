# Corpus — Design Guidelines

## Stance: Kinetic Dark

Full-commitment to a dark, information-dense mobile gaming aesthetic. The canvas is near-black with a cool blue undertone. Violet is the signature accent. Game cover art (gradient-based in this mockup) provides the visual warmth and variety. Every UI element serves information density without feeling cramped.

## Typography

| Role | Family | Weight |
|---|---|---|
| Display / headings | Chakra Petch | 600, 700 |
| Body / UI | DM Sans | 400, 500, 600 |

**Rules:**
- `font-display` (`Chakra Petch`) for screen titles, level badges, scores, and numeric callouts
- `DM Sans` for all body copy, labels, captions
- Keep body text at 12–14px on mobile; never smaller than 9px for secondary labels

## Palette

| Token | Value | Use |
|---|---|---|
| `--background` | `#0c0e18` | Page canvas |
| `--card` | `#131520` | Cards, panels |
| `--primary` | `#7c3aed` | CTA buttons, active nav |
| `--accent` | `#8b5cf6` | Hover states, gradients |
| Emerald `#10b981` | — | Beaten / success / online |
| Amber `#f59e0b` | — | Playing / warnings |
| Sky `#06b6d4` | — | On Hold |
| Red `#ef4444` | — | Abandoned / destructive |

## Component patterns

**Game Cover:** gradient rectangle with title text at bottom over dark scrim. Initials as ghosted large text behind. Status dot top-right when actively playing.

**Status Badge:** pill with 10% opacity background of its semantic color + label text in that color.

**Cards:** `bg-white/[0.03]` background, `border border-white/[0.05]`, `rounded-2xl`. No drop shadow — depth comes from the border only.

**Buttons / FAB:** `bg-violet-600` with `shadow-violet-600/40` glow. Hover to `bg-violet-500`.

**XP Bar:** full-width, 6px tall, gradient from violet-500 to fuchsia-500 on a white/10 track.

## Layout

Mobile-first, 390×844px phone shell. Bottom tab navigation (4 tabs). Content areas scroll independently with `scrollbar-hide`. No page-level scroll.

## Screens

1. **Dashboard** — XP bar, bundle alert, Playing Now horizontal scroll, activity feed
2. **Library** — filter pill row + vertical game list
3. **Search** — search input + category grid + recent list
4. **Profile** — banner, avatar, stats row, Hall of Fame, tab (genres chart / achievements grid)
5. **Game Detail** — cover header, "who has it?", 3-tab body (Mi Opinión / Grupo / Comunidad)

## Tone

Dense but breathable. Generous gap between sections. Thin hairline borders (`border-white/[0.05]`). Avoid heavy shadows; use glow only on primary interactive elements.

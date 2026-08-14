# Design system

Logged is an Operate-mode app (task-completion UI: log a set, check progress, adjust settings) — expression never gets in the way of the task, and the system leans on the platform's own text and interaction conventions rather than a bespoke display face. Source of truth for tokens and shared widgets: `lib/core/theme/app_theme.dart` and `lib/core/widgets/app_widgets.dart`.

## Palette: "warm earth"

> Terracotta primary, sage accents, and warm cream/charcoal neutrals — deliberately avoiding the cold indigo/violet defaults.

- **Primary** — terracotta/clay (`#B05C3B` light, `#E08A63` dark)
- **Secondary** — muted sage
- **Tertiary** — warm mocha
- **Neutrals** — warm cream (light) / warm charcoal, not pure black (dark)
- **Semantic extension** (`AppColors` in `app_theme.dart`, read via `theme.extension<AppColors>()!`):
  - `streak` / `onStreak` / `streakContainer` — amber-gold, the streak/attention color. Always pair `streak`-colored surfaces with `onStreak` text, never a hardcoded white/black — `onStreak` flips per brightness (dark brown in light mode, dark brown again in dark mode since the surface itself goes light) precisely so gradient cards built from `streak` stay legible in both themes.
  - `success` / `onSuccess` / `successContainer` — sage green, the "good outcome" color.

One accent carries selection state (terracotta) throughout; sage and mocha stay secondary/tertiary roles rather than competing for attention.

## Radius tokens (`AppRadius` in `app_theme.dart`)

| Token | Value | Use for |
|---|---|---|
| `AppRadius.card` | 22 | Full tappable cards and list tiles — matches `CardThemeData` |
| `AppRadius.control` | 16 | Inline badges, steppers, inputs nested inside a card — matches `InputDecorationTheme` |
| `AppRadius.pill` | 999 | Small badges/tags. Prefer `StadiumBorder` where the widget supports it (buttons, chips) instead of this numeric radius |

Two radii stay outside this token set because they're already theme-native with no ad-hoc duplicates to drift: dialog/bottom-sheet corners (28, from `DialogThemeData`/`BottomSheetThemeData`) and the segmented-button radius (14). Don't add tokens for values that only ever come from `ThemeData` already.

## Icons

Phosphor via `AppIcons` (`lib/core/app_icons.dart`) — the single source of truth for iconography. Convention: `PhosphorIconsRegular` at rest, `PhosphorIconsFill` on selection/active state (see the bottom nav in `home_shell.dart`). Never reach for raw `Icons.*` (Material) in feature code — add the missing entry to `AppIcons` instead, even if it's a one-off.

## Shared widgets (`lib/core/widgets/app_widgets.dart`)

| Widget | When to use |
|---|---|
| `SectionHeader` | Uppercase overline label (+ optional trailing action) above a group of related content — a functional list-group divider for dense Operate screens, not a marketing eyebrow. |
| `StatTile` | One metric: a large value over a quiet label, optional accent color and leading icon. |
| `StreakCard` | The current streak as a warm gradient card. Pairs with a neutral `StatTile` in a row for balance. |
| `WeeklyProgressStrip` | M–S day-dot ribbon with a "done / goal" tally — the at-a-glance weekly view. |
| `EmptyState` | Icon circle + title + message + optional CTA for any empty list/screen. |
| `AppListCard` | Full-width tappable row: leading box, title/subtitle column, optional trailing widget(s). The shape shared by every list tile (recent sessions, history, templates) — use this instead of hand-rolling the `Material`/`InkWell`/`Container` skeleton again. |

## Muscle volume-zone color ramp

`_zoneColor` in `lib/features/exercise/widgets/muscle_anatomy_view.dart` maps the 5-step `VolumeZone` coaching scale to theme tokens — no hardcoded hex, so it stays in the warm-earth family and adapts automatically per brightness:

| Zone | Token |
|---|---|
| `belowMev` | `scheme.outline` |
| `developing` | `scheme.tertiary` (warm mocha) |
| `optimal` | `AppColors.success` (sage) |
| `diminishing` | `AppColors.streak` (amber-gold) |
| `overreaching` | `scheme.error` (warm brick-red) |
| neutral base (0 intensity) | `scheme.surfaceContainerHighest` |

Reach for this table before adding a new semantic color anywhere in the app — five zones already cover most "intensity/severity" needs.

## Typography

No bundled display font, by design: this is Operate-mode UI, which is well served by the system stack (Roboto/SF). The type scale in `AppTheme._typography` adds weight and negative tracking to Material's default `TextTheme` (e.g. `titleLarge` → w700, tracking −0.2) rather than swapping faces. Revisit this only if a Persuade-mode surface (marketing, onboarding-as-pitch) gets added — Operate screens like this one don't need it.

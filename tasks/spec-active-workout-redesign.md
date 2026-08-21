# Spec — Active Workout screen redesign

Grounded at `f1df0b2` + one uncommitted fix (`analytics_repository.dart` rank filter).
Target: rebuild `ActiveSessionScreen` to match the supplied mock, keeping every behaviour the
screen has today. **This is a redesign, not a rewrite** — all existing logic (inline commit,
debounce, tick-gated rest timer, deviations, warm-up generator, plate calculator, reorder,
prescription editing) must survive.

Baseline: `flutter analyze` clean, `flutter test` **340/340 green**. Both must still hold.

---

## Read first

- `tasks/lessons.md` — every rule there applies. Two are load-bearing here:
  - A screen with a **device-width / text-scale branch needs a test for EACH branch.** A single
    representative MediaQuery config has hidden a broken default path for months before.
  - `CrossAxisAlignment.stretch` inside a scrollable needs `IntrinsicHeight`. The new stats card
    uses a stretch Row for its dividers — **wrap it**, and keep the wrapper on BOTH arms of any
    stacked/row ternary.
- `void` callbacks passed to `setState` get a **block body**, never an arrow over an assignment.

---

## Phase A — domain (no UI)

### A1. Calories: hybrid work + MET  → new `lib/core/domain/session_energy.dart`

Public entry point:

```dart
/// Estimated energy cost of one session, in kcal. Deliberately an ESTIMATE:
/// mechanical work for resistance sets, MET-time for cardio/timed work and the
/// rest between sets. Absolute accuracy is roughly ±25%; it is self-consistent,
/// so comparing your own sessions week to week is the honest use.
double estimateSessionKcal({
  required Iterable<SessionEnergySet> sets,
  required Duration elapsed,
  required double bodyweightKg,
});
```

`SessionEnergySet` carries what each set contributes: `weightValue`, `unit`, `weightEntry`,
`sideCount`, `reps`, `durationSec`, `loadingMode`, `isWarmup`, `category`, `muscleGroup`,
`bodyweightFactor`.

**Resistance component** (per non-warmup set with `reps > 0`):

```
loadKg  = per loadingMode:
            external        → totalLoadKg(weightValue, unit, weightEntry)
            bodyweight      → bodyweightKg * bodyweightFactor
            bodyweightAdded → bodyweightKg * bodyweightFactor + totalLoadKg(...)
            bodyweightAssisted → max(0, bodyweightKg * bodyweightFactor - totalLoadKg(...))
work_J  = loadKg * 9.81 * romMetres * reps * sideCount
work_J *= 1.30                  // eccentric costs ~30% of the concentric
kcal    = work_J / 0.22 / 4184  // ~22% muscular efficiency
```

`romMetres` is a documented lookup on the coarse library `muscleGroup`, default **0.40 m**:

| group | m | | group | m |
|---|---|---|---|---|
| quads / hamstrings / glutes / legs | 0.50 | | shoulders | 0.45 |
| back / lats | 0.45 | | chest | 0.40 |
| arms / biceps / triceps | 0.35 | | core / abs | 0.30 |
| calves | 0.15 | | *(anything else)* | 0.40 |

**Timed / cardio component** (per non-warmup set with `durationSec > 0`):

```
MET = cardio → 6.0 | stretching → 2.5 | any other timed hold → 4.0
kcal = MET * 3.5 * bodyweightKg / 200 * (durationSec / 60)
```

**Rest component** — whatever session time the sets above did not account for:

```
workedMinutes = Σ(durationSec)/60  +  Σ(reps * 3s)/60      // 3s per rep
restMinutes   = max(0, elapsed.inMinutes - workedMinutes)
kcal = 1.5 * 3.5 * bodyweightKg / 200 * restMinutes        // MET 1.5, standing
```

Bodyweight comes from the latest `bodyweightEntries` row; **fall back to 75 kg** with a comment
saying so. Warm-up sets are excluded from the resistance and timed components but their time still
lands in rest.

Tests (`test/core/session_energy_test.dart`), each asserting against a hand-computed number:
1. a plain barbell set (external, kg)
2. a bodyweight set uses bodyweight × factor, not zero
3. an assisted set subtracts assistance and never goes negative
4. a cardio duration set uses the MET path, not the work path
5. warm-ups add no work but their minutes still count as rest
6. a session with zero sets returns only the rest component

### A2. Total session metrics → extend `lib/core/domain/workout_metrics.dart`

`SessionTotals` value type + `computeSessionTotals(details)` returning `exerciseCount`,
`setCount` (non-warmup, with any logged value), `totalVolumeKg` (reuse `setVolumeKg`).
Test: mixed units and a `perSide` entry double correctly; warm-ups excluded from `setCount`.

### A3. Suggestion decimal noise — **bug fix**

`suggestNextSet` returns unrounded values on the "match last time" path: `_inUnit()` divides by
`2.2046226218`, so a 45 lb history under a kg header suggests `20.411656887...` and the chip renders
every digit. Two fixes, both required:

1. `lib/core/domain/progression.dart` — round every **converted** load to a loadable step:
   nearest **0.5 kg** / nearest **1 lb**. Do NOT round unconverted values — `62.5 kg` off the
   2.5 kg increment path is correct and must stay `62.5`.
2. `set_row.dart` `_formatDouble` — cap at **2 decimals** and strip trailing zeros. This is the
   formatter every load on the screen goes through; float noise from any other source dies here too.

Tests: a lb-history-under-kg-header suggestion is a clean 0.5 step; `62.5` survives untouched;
`_formatDouble(20.4116568)` → `'20.41'`, `_formatDouble(20.0)` → `'20'`.

### A4. Insert an exercise at a position → `session_repository.dart`

`addExerciseAt({sessionId, exerciseId, position})` — shifts every row at or after `position` down
by one, then inserts. Mirror `insertSetAt` in `set_repository.dart`, including its transaction and
its renumbering discipline. Existing `addExercise` (append) stays.
Tests: insert at 0, in the middle, and at `length` (== append); positions stay contiguous 0..n-1.

---

## Phase B — UI

### B1. Stats card (top of the list)

Four tiles, matching the mock: **Duration · Exercises · Total Volume · Calories**.
Each tile is a Phosphor icon in `colorScheme.primary`, then the value (`titleLarge`, `w700`,
`FontFeature.tabularFigures()`) with its unit as a smaller trailing span, then the label in
`bodySmall`/`onSurfaceVariant`. 1px `outlineVariant` dividers between tiles.

- Duration: `HH:MM:SS` off `session.startedAt`, **ticking live** on a 1s `Timer.periodic`.
  Start it only while the session is unfinished; cancel it in `dispose()` and on finish.
  A completed session shows the frozen `endedAt - startedAt`.
- Total Volume: `NumberFormat.decimalPattern` + `kg` suffix.
- Calories: `~` + `estimateSessionKcal` rounded to the nearest 10 + `kcal` suffix. Label reads
  **"Calories est."** — it is an estimate and the UI must not pretend otherwise.
- Icons: `AppIcons.clock`, `AppIcons.dumbbell`, `AppIcons.plates`, `AppIcons.fire`.

**Responsive**: a 4-wide stretch Row above ~380px at default text scale; **2×2 grid** below that or
at text scale > 1.3. Wrap the stretch Row in `IntrinsicHeight` (see "Read first"). Ship a widget
test for **each** branch — narrow AND wide, scaled AND unscaled.

### B2. Muscle thumbnail — CUT (2026-08-21)

Dropped entirely. Both attempts — the painted `MuscleThumbnail`/`MuscleFigure` widget and the
Blender anatomical-render spike (`tools/render_muscle_masks.py`) — read as unrecognisable blobs at
44px and weren't worth the upkeep. `session_exercise_card.dart` header is now: badge · name +
prescription link · info · video · ⋮ · drag handle. `MuscleThumbnail`/`MuscleFigure` deleted;
`regionForMuscle`/`regionIntensitiesForExercise` stay in `muscle_map.dart` since `MuscleHeatmap`
(the exercise-detail screen's full-body view, unrelated to this card) still uses them.

### B3. Exercise card

Header row, left to right:
`① green numbered badge` · `name (titleMedium w600) + prescription link`
· `info` · `video` · `⋮` · `drag handle`.

- The badge is the position number in a `colors.streakContainer` circle, as in the mock.
- The prescription line keeps today's behaviour exactly: `Add prescription` in `primary` when empty,
  the formatted prescription in `onSurfaceVariant` when set, tappable to edit.
- **Keep** the "Last time: …" hint and the `prescriptionNotes` line under the name.
- **Keep the drag handle inline** — Palash asked for it explicitly even at the cost of the space.

`⋮` menu, in this order:
`Add exercise above` · `Add exercise below` · `Warm-up` (disabled when no warm-ups are available)
· `Remove exercise`. "Add above/below" open the same exercise picker `_addExercise` uses and insert
via `addExerciseAt` (A4) at this card's index / index+1.

Set table:
- A `surfaceContainerHigh` rounded band carrying the `SET / KG / REPS` headings — same
  `SetTableHeader` column maths, just given a background so it reads as a table head. The header
  and every row must stay on one shared grid; do not fork the metrics.
- Rows: unchanged `SetRow` (steppers, tick, `⋮`). The tick stays the only thing that starts a rest
  timer.
- **Keep the suggestion chip.** With A3 it now shows clean numbers.

Action row under the sets: `Plates` · `Repeat` · `Swap`, `primary`-coloured with icons and 1px
vertical dividers between them, exactly as the mock. Warm-up is no longer here — it moved to `⋮`.
Must fall to a second line at large text scale rather than overflow (keep the `Wrap` behaviour).

Below it, a full-width **`+ Add set`** button with a dashed `outlineVariant` border.

### B4. Sticky bottom stack

Replace the `FloatingActionButton` entirely. `bottomNavigationBar` becomes a
`SafeArea` + `Column(mainAxisSize: min)`:

1. `RestTimerBar` — only while a rest is running (unchanged widget)
2. **Finish Workout** — full width, `colorScheme.secondary` green, check icon
3. **Add Exercise** — full width, `primary` orange, plus icon

Both action bars are always visible; the timer sits above them when running. This also retires the
old "FAB covers the rest controls" workaround — delete that comment with the FAB.
A completed session hides Finish and Add Exercise.

Empty state (no exercises) keeps its centred `EmptyState`; the bottom bar still shows Add Exercise.

---

## Constraints

- Do not change the database schema. No migration in this work.
- Do not change rest-timer semantics: **the tick is the only thing that starts a rest.**
- Do not remove any existing capability. Everything either stays where it is or moves into `⋮`,
  and this spec says which.
- `flutter analyze` clean and the **full** suite green — 340 existing + the new tests. If an
  existing test needs updating because the widget tree moved, update it; do not delete it or weaken
  its assertion.
- Keep files under ~800 lines. `active_session_screen.dart` is already 1786 — extract the stats
  card and the exercise card into `lib/features/session/widgets/` rather than growing it further.

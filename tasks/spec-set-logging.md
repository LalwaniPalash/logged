# Spec — Set logging UX + per-side load semantics (2026-07-21)

> Standalone implementation spec. Flutter 3.41.9 / Dart 3.11.5, Drift + Riverpod,
> local-only SQLite. Project: `/Users/palashlalwani/code/active/products/logged`.
> All four design decisions below are **already decided by the user** — do not
> re-litigate them, implement them.

---

## Problem

1. **Dumbbell ambiguity.** `SetEntries.weightValue` is one bare number. Doing incline
   dumbbell press with 7.5 lb in each hand, there is no way to record whether "7.5"
   means one dumbbell or the total. Nothing doubles it, nothing records the convention.
2. **Every set costs a modal.** `_openSet` (`active_session_screen.dart:64`) opens a
   bottom sheet with 8 fields for every single set. No inline entry, no duplicate.
3. **Prescriptions are stored but never used.** `SessionExercises` carries `targetSets`,
   `minReps`, `maxReps`, `targetDurationSec`, `restSeconds`, tempo (`app_database.dart:64-75`)
   and `startFromTemplate` copies them from the template. But `_openSet` seeds only from
   `lastSetForExercise` (previous *session*). A stretch prescribed "1 set · 40s each side"
   prefills nothing.
4. **"each side" is free text.** e.g. `prescriptionNotes: '40s each side'`
   (`workout_template_seed_service.dart:374`). Not machine-readable.

---

## Decision 1 — Per-hand weight entry (decided)

The user types the weight of **one implement** (7.5). The app knows the exercise is
per-side and derives total load (15) for volume.

New enum in `lib/core/domain/enums.dart`:

```dart
/// How the number typed into the weight field relates to total load.
/// [perSide] means the user held one implement per hand — total load is 2x.
enum WeightEntry { total, perSide }

extension WeightEntryLabel on WeightEntry {
  String get label => switch (this) {
    WeightEntry.total => 'total',
    WeightEntry.perSide => 'per hand',
  };
  int get implements => this == WeightEntry.perSide ? 2 : 1;
}
```

**Critical math split — get this exactly right:**

| Quantity | Uses | Why |
|---|---|---|
| Volume, muscle load | **doubled** total load (15 lb) | actual mechanical work done |
| 1RM estimate, progress charts | **entered** per-hand value (7.5 lb) | numbers must match what's on the rack |

Single-arm exercises (one-arm DB row) are `total` + `sideCount: 2`, **not** `perSide` —
`perSide` specifically means two implements moving simultaneously.

---

## Decision 2 — Per-side execution via `sideCount` (decided)

One set row covers both sides. `sideCount: 2` on a 40s stretch = 80s of work logged,
one row, one tap. Also covers "8 reps/side" dead bugs (`reps: 8, sideCount: 2`).

---

## Schema — migration v6

`schemaVersion` 5 → 6 in `app_database.dart`.

**Exercises** (remembered per-exercise defaults, same pattern as `defaultUnit`):
```dart
TextColumn get weightEntry =>
    textEnum<WeightEntry>().withDefault(const Constant('total'))();
```

**SetEntries** (snapshot per set — historical math must not shift if the exercise
default is later changed):
```dart
TextColumn get weightEntry =>
    textEnum<WeightEntry>().withDefault(const Constant('total'))();
IntColumn get sideCount => integer().withDefault(const Constant(1))();
```

**TemplateExercises** and **SessionExercises** (prescription):
```dart
IntColumn get sidesPerSet => integer().nullable()();
```

Migration block — follow the existing `if (from < N)` style:
```dart
if (from < 6) {
  await migrator.addColumn(exercises, exercises.weightEntry);
  await migrator.addColumn(setEntries, setEntries.weightEntry);
  await migrator.addColumn(setEntries, setEntries.sideCount);
  await migrator.addColumn(templateExercises, templateExercises.sidesPerSet);
  await migrator.addColumn(sessionExercises, sessionExercises.sidesPerSet);
}
```
Extend `test/data/database_migration_test.dart` to cover v5 → v6 and assert existing
rows default to `total` / `sideCount: 1` (i.e. every already-logged set keeps its
current meaning — no silent doubling of history).

---

## Metrics — `lib/core/domain/workout_metrics.dart`

```dart
/// Total load moved, in kg. [WeightEntry.perSide] means two implements.
double totalLoadKg(double value, WeightUnit unit, WeightEntry entry) =>
    weightKg(value, unit) * entry.implements;
```

`setVolumeKg` gains `WeightEntry entry = WeightEntry.total` and `int sideCount = 1`,
returning `totalLoadKg(...) * reps * sideCount`.

`estimatedOneRepMax` is **unchanged** — it keeps using the entered per-hand value.
Add a doc comment saying so explicitly, so nobody "fixes" it later.

Update `test/core/workout_metrics_test.dart`: 7.5 lb perSide × 10 reps → volume equals
15 lb in kg × 10; 1RM still computed off 7.5.

---

## Analytics — `lib/data/repositories/analytics_repository.dart`

- Add `se.weight_entry` and `se.side_count` to `_query` and `_muscleProgressQuery`.
- `WorkoutSetRecord` gains `final WeightEntry weightEntry;` and `final int sideCount;`.
- `volumeKg` → `weightKg * weightEntry.implements * reps * sideCount`
- `estimatedOneRepMaxKg` → **unchanged** (`weightKg * (1 + reps / 30)`), still per-hand.
- `muscle_progress.dart:355` — the `external` load path must use the **doubled** total
  load, since muscle stimulus tracks real mechanical load.

---

## Prefill cascade

New method on `SessionRepository`:
```dart
/// Values to prefill a new set with, in priority order:
/// 1. the last set already logged for this exercise *in this session*
/// 2. the session-exercise prescription (template targets)
/// 3. the last set from the most recent completed session
Future<SetSeed> seedForNextSet({required int sessionExerciseId});
```

`SetSeed` is a small immutable class: `reps, weightValue, unit, weightEntry,
loadingMode, durationSec, distanceMeters, sideCount`.

Step 2 maps prescription → seed: `minReps` (or `maxReps`) → `reps`,
`targetDurationSec` → `durationSec`, `targetDistanceMeters` → `distanceMeters`,
`sidesPerSet` → `sideCount`. Never seed `rpe` or `notes` from anything —
those are always per-set observations.

This replaces the bare `lastSetForExercise` call in `_openSet`.

---

## UI — `active_session_screen.dart`

Sets become **inline editable rows** inside `_ExerciseCard`. Target:

```
Incline Dumbbell Press      3 sets · 8-10 reps
┌──────────────────────────────────────────┐
│ 1   [ 7.5 ]lb ×2   [ 10 ]reps       ✓   │
│ 2   [ 7.5 ]lb ×2   [  9 ]reps       ✓   │
│ 3   [ 7.5 ]lb ×2   [  8 ]reps       ○   │
└──────────────────────────────────────────┘
  ⟳ Repeat set      + Add set      ⋯ More
```

Requirements:
- Extract the set row into its own widget file — `active_session_screen.dart` is
  already 875 lines and the repo standard is 200-400 (`~/.claude/rules/common/coding-style.md`).
  Suggest `lib/features/session/widgets/set_row.dart` and `set_editor_sheet.dart`.
- Inline numeric fields for the primary axes only. Which fields show depends on the
  exercise category: strength → weight + reps; stretching → duration; cardio →
  duration + distance.
- `−` / `+` steppers flanking each numeric field. Weight step follows unit
  (2.5 kg / 5 lb), reps step 1, duration step 5s. Long-press to repeat.
- **Repeat set** — one tap, inserts a set identical to the last one on that exercise.
- Rows commit on blur/submit, debounced; never lose a value on rebuild. Each row owns
  its `TextEditingController`, keyed by set id.
- **More** overflow menu holds the rare fields: RPE, notes, warm-up toggle, loading
  mode, per-hand/total toggle, delete. The bottom sheet stays for these — it just
  stops being the price of entry for every set.
- Per-hand rendering: `7.5 lb × 2`. Total: `15 lb`. Per-side execution: `40s each side`.
- Existing behaviour that must survive: `updateLoggingDefaults` still remembers unit +
  loading mode per exercise (now also `weightEntry`); the bodyweight-assist validation
  in `_SetEditorState._save`; the `LoadingMode` segmented control; warm-up rows
  rendering `W` instead of a set number.

---

## Seed data + template editor

- `workout_template_seed_service.dart`: replace free-text side info with structured
  `sidesPerSet: 2` where the note says "each side" / "/side" (line 374 and the
  `_p(...)` entries whose notes contain `/side`). Keep the human note text as-is.
- Mark the obvious two-implement exercises in the exercise library with
  `weightEntry: perSide` — dumbbell presses, dumbbell lateral raises, dumbbell curls,
  dumbbell flyes. Not single-arm rows, not barbell/cable/machine work.
- `template_editor_screen.dart`: expose `sidesPerSet` as a small "each side" toggle
  next to target sets.

---

## Definition of done

- [ ] `flutter analyze` clean
- [ ] `flutter test` green, including new v5→v6 migration test and updated metrics tests
- [ ] Logging 3 sets of an exercise takes 3 taps when values repeat (was ~24)
- [ ] A stretch prescribed "1 set · 40s each side" is fully prefilled on first tap
- [ ] Existing logged sets read back with identical volume + 1RM to before the migration

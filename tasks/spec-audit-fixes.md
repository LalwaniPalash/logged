# IMPLEMENTATION SPEC — Audit remediation (for Codex) — 2026-08-14

> **Read this as a standalone brief.** You (Codex) have NO prior conversation context. Everything
> needed is below, grounded in the CURRENT codebase. Real file paths and symbols are named so you
> must **NOT invent APIs** — open each file and confirm the signature before using anything.
> Work phase by phase, top to bottom. Verify each phase before starting the next.
> Defaults here are **decided**; do not ask questions unless genuinely blocked.
>
> Full reasoning and evidence for every item: **`tasks/audit-2026-08-14.md`**. Read it first.
> Findings are referenced by their audit IDs (G1, K1, A1…). Where this spec and the audit differ,
> **this spec wins** — it carries the decisions.

## Project context (20 seconds)

Logged is a private, 100% local, no-account Flutter workout tracker (Android + iOS, Drift +
Riverpod, feature-first). No network, no analytics, no accounts — **do not degrade that guarantee.**
Baseline at time of writing: `flutter analyze` clean, `flutter test` 230/230 green.

**Every bug in this spec survived that green suite.** Passing tests is necessary, not sufficient.

---

## GROUND RULES (non-negotiable — from `tasks/lessons.md`)

1. **Verify APIs before use.** Every symbol named below exists today. Still open the file and
   confirm the signature. Never assume a method shape.
2. **Schema changes ship with a migration AND a one-time backfill.** `schemaVersion` is **10** in
   `lib/data/database/app_database.dart:153`; `_schemaVersion = 10` in
   `lib/data/services/backup_service.dart:38`. Any schema change bumps **both**, adds an `onUpgrade`
   step, and adds the new version to `_supportedSchemaVersions`. Seeding uses
   `InsertMode.insertOrIgnore`, so new columns NEVER reach existing rows without an explicit
   backfill. A user-editable backfill must be one-time, guarded by a flag in the `app_settings`
   key/value table.
3. **Per-set truth.** `unit`, `weightEntry` (total|perSide), and `sideCount` are per-SET. Never
   hoist a per-set value into a shared header without a per-row deviation flag.
4. **Don't delete capability by "showing only what's relevant."** Before hiding a control, confirm
   it is not the only writer of a field. Drive visibility off the DATA, not the category enum.
5. **1RM convention:** estimated 1RM uses the **entered** (per-hand) value, NOT doubled total load,
   and NOT multiplied by `sideCount`. Volume DOES double for `perSide` and DOES multiply by
   `sideCount`. See `lib/core/domain/workout_metrics.dart` — `estimatedOneRepMax` vs `setVolumeKg`
   are the canonical pair. Phase 1.4 exists because one call site broke this.
6. **Native additions are fragile.** After ANY dependency or native change, run
   `flutter clean && flutter pub get && (cd ios && pod install)` and test on a REAL device. A green
   simulator build does not prove a notification fires.
7. **Green tests are necessary, not sufficient.** For data-shaped features, verify against the
   actual on-device SQLite DB (query counts before/after), not just fixtures.
8. **Commit a baseline BEFORE you start**, so `git diff HEAD` is a clean review surface. Do not
   modify files outside a phase's stated scope.
9. **Every phase adds at least one test that fails before the change and passes after.** Several
   bugs here exist specifically because no test crosses the UI↔domain seam. See Phase 1.1.

---

## Phase 0 — Baseline

1. `git status` must be clean, or commit what is there first.
2. `flutter analyze` → expect clean.
3. `flutter test` → expect 230 passing.
4. Record the counts. Every later phase must keep analyze clean and the suite green.

---

# PHASE 1 — Silent math corruption (do this first)

These four change numbers the user already sees. Nothing here needs a schema change except 1.1.

## 1.1 — G1: muscle bias halves logged volume 🔴

**File:** `lib/features/session/widgets/set_editor_sheet.dart`, `lib/core/domain/muscle_bias.dart`,
`lib/data/database/app_database.dart` (migration).

**The bug.** The domain treats a bias weight as a **multiplier** — `muscle_progress.dart` and
`live_muscle_state.dart` both do:
```dart
final weight = primaryMuscleBiasWeight(muscle: muscle, weights: record.muscleBiasWeights) ?? 1.0;
acc.primarySets += weight;
```
Null bias credits **1.0 per primary muscle**. But `_SetEditorSheetState._normalizeBiasWeights`
forces the persisted weights to **sum to 1.0** across the primaries. So a 2-primary exercise credits
2.0 effective sets when the sheet was never opened and 1.0 when it was — and `_save()` writes the
even-split default whenever `_showsMuscleBias` is true, so merely opening the sheet halves it.
Biasing 100% to one muscle yields exactly the no-bias value; every other setting is strictly below
it. **Using the feature can only reduce credited volume.**

**Decided fix: normalize to MEAN 1.0, not SUM 1.0.**

1. In `set_editor_sheet.dart`, `_normalizeBiasWeights` must return weights whose **sum equals
   `widget.primaryMuscles.length`** (mean 1.0). Keep the existing "distribute the remainder into the
   last muscle" behaviour so the total is exact. The even-split default becomes `1.0` for every
   muscle — identical to no bias, which is the correct neutral.
2. `_biasPercentages` and `_biasEcho` must keep displaying **percentages** — compute the share as
   `weight / sum(weights)`. The UI copy does not change. Only the persisted scale changes.
3. `_setBiasShare(muscle, share)` receives a 0–1 slider value. Convert: the target weight is
   `share * N`, and the remaining `(1 - share) * N` is distributed across the other muscles in
   proportion to their current weights (same algorithm as today, scaled by `N`).
4. **Migration to schemaVersion 11.** In `onUpgrade`, `if (from < 11)`: for every `set_entries` row
   with a non-null `muscle_bias_weights`, decode it with `decodeMuscleBiasWeights`, count the keys
   as `N`, multiply every value by `N`, re-encode with `encodeMuscleBiasWeights`, and write it back.
   That converts share semantics to multiplier semantics exactly. Use the same
   `customSelect` / `customUpdate` pattern already used by the `from >= 8 && from < 10` block —
   copy its shape.
5. Bump `schemaVersion` to **11** and `backup_service.dart` `_schemaVersion` to **11**, and add
   `11` to `_supportedSchemaVersions`.
6. **Backups written at schemaVersion ≤ 10 hold share-scale weights.** In
   `BackupService.replaceFromPayload`, after the transaction, if
   `source['schemaVersion'] as int? ?? 1` is `< 11`, run the same rescale over the imported
   `set_entries`. Extract the rescale into a single reusable function so the migration and the
   import call the identical code.

**Do NOT** change `primaryMuscleBiasWeight`, `muscle_progress.dart`, or `live_muscle_state.dart`.
The domain is already correct — this is a UI/persistence unit fix.

**Tests (required).**
- `test/core/muscle_bias_test.dart`: rescale round-trip — a 3-key share map `{1/3, 1/3, 1/3}`
  rescales to `{1.0, 1.0, 1.0}`; `{0.5, 0.3, 0.2}` → `{1.5, 0.9, 0.6}`.
- `test/data/database_migration_test.dart`: a v10 DB with share-scale weights migrates to v11 with
  multiplier-scale weights. Follow the existing v9 migration test's structure.
- **`test/features/set_editor_sheet_test.dart` — the seam test.** Pump `SetEditorSheet` for an
  exercise with 2 primary muscles, save without touching the slider, take the returned
  `muscleBiasWeights`, feed it into `buildMuscleProgress`, and assert `primarySets` is **identical**
  to the same set logged with `muscleBiasWeights: null`. This is the test whose absence let the bug
  ship; it must exist.
- Existing assertions in `test/core/muscle_progress_test.dart` (`:362`) and
  `test/core/live_muscle_state_test.dart` use raw multiplier weights and stay valid unchanged.

## 1.2 — K1: progression permanently stalls without RPE 🔴

**File:** `lib/core/domain/progression.dart` (`suggestNextSet`).

**The bug.** RPE is optional and absent from the inline set row entirely
(`lib/features/session/widgets/set_row.dart` has no RPE input). For a user who never logs it:
- `increaseAllowed` requires `topSet.rpe != null` → always false → **the weight never increases**;
- the fall-through returns `((reps ?? minReps) + 1).clamp(minReps, maxReps)`, which at the top of the
  range is the same rep count the user already did, with the rationale
  *"Keep the load and add one rep toward the top of the range."* The value contradicts the sentence,
  forever, with no way out;
- and the early guard `minReps == null || maxReps == null || targetRpe == null` returns
  *"Match last time; add a rep range and target RPE to progress."*

**Decided fix: RPE enhances, it never gates. Double progression on reps alone.**

1. Change the early-return guard to `if (minReps == null || maxReps == null)`. **Drop
   `targetRpe == null`.** A rep range alone is enough to progress. Update the rationale string to
   `'Match last time; add a rep range to progress.'`
2. Replace `increaseAllowed` with a reps-only condition plus an optional RPE veto:
   ```dart
   final allSetsAtTop = workingSets.every((set) => (set.reps ?? 0) >= maxReps);
   final rpeVetoes = targetRpe != null
       && topSet.rpe != null
       && topSet.rpe! > targetRpe + effortAllowance;
   final increaseAllowed = allSetsAtTop && !rpeVetoes;
   ```
   `effortAllowance` keeps its existing definition. When `targetRpe` is null, `effortAllowance`
   still computes from `progressionAggressiveness` — leave that as is; it is unused in the veto when
   `targetRpe` is null.
3. The existing "hold" branch keeps its RPE clause but must guard `targetRpe != null` first.
4. Rationale strings must stop naming RPE when it played no part. Use
   `'Top of the range on every set; add one ${unit.label} increment.'` (and the assisted variant
   `'…drop one ${unit.label} of assistance.'`). Keep the RPE-flavoured wording **only** when
   `topSet.rpe != null && targetRpe != null`.
5. Fix the lying rationale: if the computed `reps` equals the reps already achieved and the weight is
   unchanged, the rationale must be `'Hold this and repeat it cleanly.'`, not "add one rep".

**Do NOT** remove the RPE parameters or the RPE fields. They stay, they just stop being required.

**Tests (required).** `test/core/progression_test.dart`:
- all working sets at `maxReps`, **every `rpe` null**, `targetRpe` null → suggests weight + one
  increment and `reps == minReps`. (Fails today.)
- top set at `maxReps` but an earlier set below it, all `rpe` null → holds the load.
- `targetRpe` set and `topSet.rpe` above it → still holds (the veto works).
- no rep range → returns the match-last-time suggestion.

## 1.3 — A1 + A2: warm-ups inflate weekly volume; bodyweight sessions are invisible 🔴

**File:** `lib/data/repositories/analytics_repository.dart` (`_query`, `_map`,
`WorkoutSetRecord`), `lib/core/domain/progress_analytics.dart` (`recentPrs`).

**The bug.** `_query` (~line 97) has **no `is_warmup = 0` filter** — unlike `_benchmarkQuery`,
`_deloadQuery`, and the muscle-progress path. It also filters `se.weight_value IS NOT NULL`, so a
bodyweight-only session contributes 0 volume **and 0 to `WeekStat.sessions`**. `_query` feeds
`completedSetsProvider` → `weeklyStats`, `muscleVolumeThisWeek`, `recentPrs`
(`progress_screen.dart:80-81`, `active_session_screen.dart:534`) **and** the home-screen widget via
`home_widget_snapshot.dart` (`weeklyVolumeKg`, `completedSetsThisWeek`). One query, three surfaces.

**Decided fix (scoped — read the second half carefully).**

1. Add `AND se.is_warmup = 0` to `_query`. This fully fixes A1.
2. Remove `AND se.weight_value IS NOT NULL` from `_query`. Add `se.loading_mode AS loading_mode` to
   the selected columns.
3. `_map` currently does `(row.data['wv'] as num).toDouble()` — a non-null cast that will now
   throw. Make it null-safe: `weightKg` becomes `0` when `wv` is null.
4. Add `final LoadingMode loadingMode` to `WorkoutSetRecord` (default `LoadingMode.external`).
5. **Guard `recentPrs`**: skip any record with `weightKg <= 0`, so a bodyweight set cannot register
   a 0 kg "personal record". Add the guard at the top of the loop in
   `progress_analytics.dart:recentPrs`.
6. `volumeKg` stays as it is — a bodyweight set has `weightKg == 0` and therefore contributes 0
   tonnage. That is deliberate for this phase.

**Explicitly out of scope (record it, do not build it):** folding bodyweight into tonnage so a
pull-up session shows non-zero volume requires the dated bodyweight series, which `_map` has no
access to (`buildMuscleProgress` gets it via `_loadBodyweights()`). Leave a `// TODO(A2b):` comment
at `WorkoutSetRecord.volumeKg` naming the limitation. After this phase, bodyweight sessions correctly
count toward **session count and set count** but still show zero tonnage.

**Tests (required).** `test/core/progress_analytics_test.dart` (create if absent):
- a week containing warm-up sets → `weeklyStats` volume excludes them.
- a bodyweight-only session → `weeklyStats` reports `sessions == 1` (fails today).
- a bodyweight set → produces no `PrEvent`.

## 1.4 — A4: `sideCount` and `perSide` inflate a 1RM proxy 🟠

**File:** `lib/core/domain/muscle_progress.dart` (`_performanceSignal`, `_resistedMassKg`).

**The bug.** The reps branch computes `value: load * sides * (1 + record.reps! / 30)` where `load`
is already `totalLoadKg(...)` (doubled for `perSide`). 5 reps each leg at 20 kg is not a 40 kg lift.
This violates ground rule 5, and it disagrees with `WorkoutSetRecord.estimatedOneRepMaxKg`, which
obeys it. Toggling "Each side" or "Per hand" partway through history doubles the index, which clamps
at 175 and ranks the user up instantly.

**Decided fix.**
1. Split `_resistedMassKg` into two callers-facing values, or add a
   `{bool perImplement = true}` parameter. The **1RM path must use the ENTERED value** —
   `weightKg(record.weightValue!, record.unit ?? WeightUnit.kg)` — **not** `totalLoadKg`. Bodyweight
   / added / assisted modes are unaffected by `weightEntry`, so their arithmetic is unchanged.
2. In `_performanceSignal`, the **reps branch** becomes `value: load * (1 + record.reps! / 30)` —
   drop `* sides` entirely.
3. The **duration** and **distance** branches keep `* sides`. Those are volume-like signals and
   doubling for two limbs is correct there.
4. The `reps`-without-load fallback (`value: record.reps!.toDouble() * sides`) also keeps `* sides` —
   it is a rep count, not a load estimate.

**Tests (required).** `test/core/muscle_progress_test.dart`: two identical sets, one logged
`weightEntry: total, sideCount: 1` at 40 kg and one `perSide, sideCount: 2` at 20 kg per hand,
produce **different volume but the same performance index baseline shape** — specifically, assert the
`sideCount: 2` record's `ExerciseProgressPoint.rawValue` equals the entered-value 1RM, not 4× it.

## 1.5 — G2: the deload path ignores bias entirely 🟠

**File:** `lib/data/repositories/analytics_repository.dart` (`_deloadQuery`, `loadDeloadData`).

**The bug.** `loadDeloadData` does `weekly[muscle]![weekIndex] += 1` for every primary muscle,
ignoring `muscle_bias_weights`. Meanwhile `buildLiveMuscleState` and `buildMuscleProgress` are
bias-weighted. **Three different effective-set computations, all compared against the same
`VolumeLandmarks`.** After 1.1 the divergence would be up to N×.

**Decided fix.**
1. Add `se.muscle_bias_weights AS muscle_bias_weights` to `_deloadQuery`'s column list.
2. In the `loadDeloadData` loop, decode it with the existing `_decodeMuscleBiasWeights` helper and
   apply `primaryMuscleBiasWeight(muscle: muscle, weights: weights) ?? 1.0` exactly as
   `buildMuscleProgress` does. Secondary muscles keep `secondaryMuscleSetWeight` unchanged.

**Test (required).** `test/data/live_muscle_analytics_repository_test.dart` or a new deload test:
a biased set contributes its bias weight, not 1.0, to `weeklyEffectiveSetsByMuscle`.

## Phase 1 verification
- `flutter analyze` clean; full suite green plus the new tests.
- **Manual, on a real device or emulator with a real DB**: log two sets of a 2-primary exercise via
  the set editor, then check the Progress screen's weekly muscle balance shows **2.0 sets per
  muscle**, not 1.0. Query `sqlite3` before and after the migration to confirm weights were rescaled.

---

# PHASE 2 — Partial-week arithmetic

## 2.1 — J2: rank drops every Monday 🟠

**File:** `lib/core/domain/muscle_progress.dart` (`_rankScore`).

**The bug.** The loop gives `offset 0` — the **current, incomplete week** — the **largest** decay
weight (`0.82^0 == 1.0`). On Monday it contributes `_volumeAdequacy(0) == 0` and fails the
`>= mev` consistency test. The 8 weights sum to ≈4.44, so that is ~22% of the combined volume +
consistency score — about **11 of 100 rank points, lost every Monday** and recovered by Sunday. Rank
tiers are 18 points apart, so muscles visibly rank down and back up with no change in training.

**Decided fix: score completed weeks only.** Base the window at the **last completed week**
(`startOfWeek(today)` minus 7 days) and keep 8 buckets. The current week is excluded from rank
scoring entirely — the live sculpture and weekly-balance card already show it, so nothing is hidden
from the user. This is deliberately simpler than prorating, which is noisy on a Monday.

## 2.2 — J1: `Duration(days: n * 7)` breaks week keys across DST 🟠

**Files:** `lib/core/domain/muscle_progress.dart` (`_rankScore`),
`lib/data/repositories/analytics_repository.dart` (`loadDeloadData`).

Both build week keys with `someWeek.subtract(Duration(days: offset * 7))` and then use the result as
an **exact-equality** lookup (`weeks[...]`, `weekStarts.indexOf(...)`). A DST transition shifts the
value by an hour, the lookup misses, and a whole week's volume silently vanishes from both the rank
score and the deload assessment.

**Decided fix.** Replace every such expression with calendar arithmetic:
`DateTime(base.year, base.month, base.day - offset * 7)`. `lib/core/domain/streak.dart` already
documents this exact hazard in the comment above `_previousDay` — follow that pattern.

**Test (required).** Construct week keys across a DST boundary (use a fixed `today` in late October)
and assert the volume lands in the right bucket.

## 2.3 — Deload signal 2 compares a partial week against a full-week MRV 🔴

**File:** `lib/data/repositories/analytics_repository.dart` (`loadDeloadData`),
`lib/core/domain/deload.dart` (`assessDeload`).

**The bug.** `weekStarts` is `[3wk ago, 2wk ago, 1wk ago, current]`, so `values.last` is the
**current, partial week**, and `assessDeload` compares it to a full-week `mrv`. On Monday it is ~0.
The overreach signal can effectively only fire late in a very high-volume week — which, combined
with the dead RPE signal (2.4) and `triggered: reasons.length >= 2`, is why **the deload card has
never appeared for any user**.

**Decided fix.** Build `weekStarts` ending at the **last completed week**, same as 2.1. Keep
`weeks: 4`. `assessDeload` then compares two complete weeks and needs no change to its own logic.

## 2.4 — Deload signal 3 is structurally dead without RPE 🔴

**File:** `lib/core/domain/deload.dart` (`assessDeload`),
`lib/data/repositories/analytics_repository.dart` (`loadDeloadData`, `DeloadData`).

**The bug.** `risingEffort` needs ≥3 logged RPE values at the same load. RPE has no input on the
inline row and is optional in the sheet, so `rpeAtLoadSeries` is empty for most users and the signal
can never fire.

**Decided fix: add an RPE-free third signal and keep RPE as a bonus.**

1. Add `Map<int, List<double>> repDecaySeries` to `DeloadData` — per exercise, one value per training
   day: `(first working set reps - last working set reps)` at the same load within that session. This
   is the closest free proxy for rising effort and needs no new column.
2. Compute it in `loadDeloadData` from rows already selected (`reps`, `weight_value`, `unit`, the
   session date). Group by exercise and day; only include days with ≥2 working sets at the same
   rounded load.
3. In `assessDeload`, add a `wideningRepDecay` signal: ≥3 values, monotonically non-decreasing, and
   `recent.last - recent.first >= 1.0 * goal.deloadSensitivity`. Reason string:
   `'Reps are falling further across sets on N lifts.'`
4. **Keep** the existing `risingEffort` RPE signal exactly as is. It now contributes when RPE data
   exists and is simply absent when it does not.
5. Bound signal 1 (`stalledLifts`) to recency: add
   `AND s.started_at >= ?` to `_deloadQuery` limiting it to the last **12 weeks**, so an accessory
   trained three times over six months stops flagging as "stalled" (audit A8). `_deloadQuery`
   currently has no date filter at all and loads the entire set history on every evaluation — this
   also fixes that.
6. Leave `triggered: reasons.length >= 2` unchanged. With three live signals it is now reachable.

**Tests (required).** `test/core/deload_test.dart`:
- two completed weeks over MRV → overreach fires; a partial current week over MRV alone → does not.
- a widening rep-decay series with **no RPE at all** → the new signal fires.
- a lift last trained 6 months ago → does not count as stalled.

## 2.5 — J3: `createDeloadWeek` throws when a deload is most warranted 🟡

**File:** `lib/data/repositories/template_repository.dart` (`createDeloadWeek`).

It reads only `s.started_at >= startOfWeek(today)`. A user who overreached last week and rested the
start of this week — the expected behaviour — gets
`StateError('Complete at least one workout this week…')` instead of a template.

**Decided fix.** Base it on the most recent week that **contains** training: find
`MAX(s.started_at)` among completed sessions, take `startOfWeek` of that, and build from there.
Update the `StateError` message to `'Complete at least one workout before generating a deload.'`
Update the existing test `'deload template keeps this week exercises at half volume'` accordingly.

## Phase 2 verification
Suite green. Manually set the device clock to a Monday and confirm the dashboard rank does **not**
drop relative to Sunday.

---

# PHASE 3 — Timed & distance exercises (schema)

## 3.1 — F1 + F2: a custom exercise cannot be marked as timed 🔴

**User-reported.** A Copenhagen plank has to be logged as *30 reps/side* instead of *30 seconds/side*.

**The bug.** `Exercises` has no `isTimed` column. `isTimedExercise`
(`lib/features/session/widgets/set_row.dart:44`) **infers** timed-ness from history:
```dart
if (sets.isNotEmpty) return sets.any((s) => s.durationSec != null) && sets.every((s) => s.reps == null);
return targetDurationSec != null && minReps == null && maxReps == null;
```
A new custom `bodyweight`/`strength` exercise logged ad hoc has no sets and no prescription →
`timed == false` → `_showsDuration` in `set_editor_sheet.dart` is false → **the seconds field never
renders**. It is a chicken-and-egg: the only unlocks are a set that already has a duration, or a
`targetDurationSec` prescription, which is editable **only in the template editor** (F7). Every
escape hatch is a trap — `stretching` removes the weight field so a weighted plank is impossible;
`cardio` makes `isSetComplete` require duration **AND** distance so the set never completes and the
rest timer never auto-starts. Affects side plank, dead hang, L-sit, wall sit, hollow hold, ab wheel
hold — a whole modality.

**Decided fix: declare it on the exercise. Inference is the wrong model for user-created rows.**

1. Add to `Exercises` in `lib/data/database/app_database.dart`:
   ```dart
   BoolColumn get isTimed => boolean().withDefault(const Constant(false))();
   BoolColumn get tracksDistance => boolean().withDefault(const Constant(false))();
   ```
2. Bump `schemaVersion` to **12** (11 was consumed by Phase 1.1) and add
   `if (from < 12) { await migrator.addColumn(exercises, exercises.isTimed);
   await migrator.addColumn(exercises, exercises.tracksDistance); }`.
3. Bump `backup_service.dart` `_schemaVersion` to **12**, add `12` to `_supportedSchemaVersions`,
   and add `'isTimed': source['isTimed'] ?? false` / `'tracksDistance': …` defaults to
   `_exerciseFromBackup` so older backups import cleanly.
4. **One-time backfill**, guarded by a new `app_settings` flag `timedExerciseBackfilled`, in
   `lib/data/services/exercise_anatomy_service.dart` alongside the existing
   `backfillMuscleAnatomyOnce` / `backfillWeightEntryOnce` / `backfillPullUpOnce`. Call it from
   `lib/main.dart` inside the existing try/catch. Set `isTimed = true` for bundled exercises whose
   category is `stretching`, plus any bundled exercise that has a `"isTimed": true` field in
   `assets/data/exercise_library.json` (add the field to the asset for the obvious holds — plank,
   side plank, dead hang, wall sit, L-sit, hollow hold). Set `tracksDistance = true` for `cardio`.
   Custom exercises are **never** touched — mirror the `isCustom.equals(false)` filter already used
   by `_bundledAnatomyChanges`.
5. `isTimedExercise` must **prefer the column**. Change its signature to take
   `required bool exerciseIsTimed` and return `true` immediately when set; keep the existing
   inference as the fallback so nothing regresses for exercises the backfill did not mark. Update
   both call sites (`active_session_screen.dart:290` and `:919`) to pass
   `detail.exercise.isTimed`.
6. `_showsDistance` in `set_editor_sheet.dart` gains `|| widget.tracksDistance` (thread a new
   widget field from `detail.exercise.tracksDistance`). This is F2 — a farmer's carry filed as
   `strength` currently can never record distance.
7. **Custom-exercise sheet** (`lib/features/settings/settings_screen.dart`, the "Custom exercise"
   modal around line 150-400): add two `SwitchListTile`s — **"Logged in seconds"** and
   **"Tracks distance"** — and pass them into the `ExercisesCompanion.insert`. Place them directly
   under the Category chips.
8. **Category chips need a subtitle.** Each category silently rewires the form and the completion
   rule (audit F10). Add one line of helper text under the Category `Wrap` stating what the selected
   category logs, e.g. `'Cardio sets need both a duration and a distance to count as complete.'`

## 3.2 — P: CSV program import cannot express a timed exercise 🟠

**File:** `lib/features/templates/import/program_parser.dart`,
`lib/features/templates/import/import_screen.dart`.

`programCsvHeader` is `day,exercise,sets,min_reps,max_reps,rest_sec,rpe,notes`. No duration, no
distance, no sides — so bulk import also cannot create the `targetDurationSec` prescription.

**Decided fix.** Add three optional columns: `duration_sec`, `distance_m`, `sides`. Validate the
same way the existing optional columns are validated (`_optionalInt` / `_optionalDouble`, with a
per-row error message when the cell is non-empty but unparseable; `sides` must be 1 or 2). Add them
to `ParsedProgramRow`, thread into `TemplateExercisesCompanion` as `targetDurationSec`,
`targetDistanceMeters`, `sidesPerSet`. Update the sample header shown at `import_screen.dart:152`.
**Keep the parser's existing structure** — validation, per-row errors, and RFC-4180 quote handling
are correct; only the column set is short.

**Tests (required).** `test/features/program_parser_test.dart`: a row with `duration_sec` parses;
a non-numeric `duration_sec` produces a per-row error; `sides: 3` produces a per-row error.

## Phase 3 verification
**Manual, on a real device.** Create a custom exercise "Copenhagen Plank", category `bodyweight`,
toggle **Logged in seconds** on. Start an ad-hoc workout (no template), add it, open the set editor,
and confirm the **duration field is present and the reps field is not**. Log 30 s each side. Then
query the on-device DB and confirm `duration_sec = 30`, `side_count = 2`, `reps IS NULL`.

---

# PHASE 4 — CRUD gaps & destructive-action confirmations

Full evidence in audit sections D, F, I. Grouped because they are small and share files.

## 4.1 — F3 + I3 + D4: exercises cannot be renamed, re-categorised, or deleted 🟠
**File:** `lib/data/repositories/exercise_repository.dart`, `lib/features/settings/settings_screen.dart`.

`ExerciseRepository` has `add`, `archive`, `updateMuscles`, `updateVideoUrl`, `updateDefaultUnit`,
`updateLoggingDefaults` — and **no** `updateName`, `updateCategory`, `updateBodyweightFactor`, or
`delete`. `bodyweightFactor` scales `_resistedMassKg` and therefore every rank and strength-standard
number for that lift; a typo is permanent, and because `name` is UNIQUE and there is no delete, the
exercise cannot even be recreated correctly. This applies to **bundled exercises too** — a wrong
`bodyweightFactor` on a library row cannot be corrected.

**Decided fix.**
1. Add `updateDetails(int exerciseId, {String? name, ExerciseCategory? category, double? bodyweightFactor, bool? isTimed, bool? tracksDistance})` using `Value.absent()` for
   every null argument. **Do not** use the `x ?? default` pattern — see 4.4.
2. Add `Future<bool> delete(int exerciseId)`: inside a transaction, count referencing rows in
   `session_exercises` and `template_exercises`. If **any** exist, return `false` without deleting
   (the caller offers Archive instead). If none, delete the row and return `true`.
3. Extend the existing `_editExerciseMuscles` dialog in `settings_screen.dart` into a full
   **Edit exercise** sheet: name (with the same `isDuplicateExerciseName` check the create sheet
   uses), category, bodyweight factor, the two Phase-3 toggles, muscles, and video URL. Available for
   **custom and bundled** exercises alike.
4. Add a **Delete** action to that sheet, behind an `AlertDialog` confirmation. When
   `delete()` returns `false`, show a dialog explaining the exercise is used by logged workouts and
   offering **Archive** instead.

## 4.2 — D1 + D2 + D3: unconfirmed destructive actions 🔴/🟠
1. **`_removeExercise`** (`active_session_screen.dart:187`, invoked at `:754`) deletes the exercise
   **and every set logged under it** with no confirmation. "Replace exercise?" (`:160`) already
   confirms the identical destruction. **Add an `AlertDialog`** naming the exercise and the set
   count.
2. **Set delete** — the trash icon in `set_editor_sheet.dart`'s header pops straight through. A
   modal on every set delete would be punishing mid-workout: **use a `SnackBar` with an Undo action**
   instead. Re-insert via `SetRepository.add` with the original field values on undo.
3. **Bodyweight entry delete** (`settings_screen.dart:1588`) retroactively changes every bodyweight,
   added-weight, and assisted calculation in history. **SnackBar + Undo**, same pattern.

## 4.3 — F5 + A7: session notes have no writer 🟠
`Sessions.notes` exists, `SessionRepository.finish(id, {notes, endedAt})` accepts it, and
`backup_service` serialises it — but `active_session_screen.dart:531` calls `finish(widget.sessionId)`
with no notes, and nothing else writes the column.

1. Add a multiline `TextField` to the existing "Finish workout?" `AlertDialog` (`:509`) and pass its
   value to `finish`.
2. **A7:** `finish` currently writes `notes: Value(notes)`, so calling it without notes **nulls any
   existing note**. Change to `notes: notes == null ? const Value.absent() : Value(notes)`.
3. Show the note on the completed-session view and in `history_screen.dart`.

## 4.4 — A3: `SetRepository.edit` resets unpassed fields to defaults 🟠
`lib/data/repositories/set_repository.dart:60-77` writes `weightEntry ?? WeightEntry.total`,
`sideCount ?? 1`, `loadingMode ?? LoadingMode.external`, `isWarmup ?? false`. A null argument means
"not supplied", but the code writes the **default**. Both current callers pass everything, so it is
latent — but this is the exact bug `tasks/lessons.md` already records once
("delete-resets-logging-defaults").

**Decided fix.** Use `Value.absent()` for every null argument. For the nullable columns
(`rpe`, `notes`, `distanceMeters`, `durationSec`, `weightValue`, `unit`, `muscleBiasWeights`) the API
cannot currently distinguish "leave alone" from "clear" — introduce a small
`sentinel`/`Value<T>`-taking signature so both are expressible, and update the two call sites in
`active_session_screen.dart` (`:333`, `:459`) to pass explicit values.

## 4.5 — A6: `addExercise` can create duplicate positions 🟠
`SessionRepository.addExercise` uses `position: rows.length`. Remove the middle of 3 exercises
(0,1,2 → 0,2) then add → `rows.length == 2` → **two rows at position 2**, and ordering becomes
non-deterministic. `template_repository.dart:96` already does this correctly with
`max(position) + 1`. Copy that.

## 4.6 — F7: the prescription is read-only inside a session 🟠
`_formatPrescription` (`active_session_screen.dart:1195`) **renders** `targetSets`, `minReps`,
`maxReps`, `targetDurationSec`, `targetDistanceMeters`, `restSeconds`, and tempo — and nothing in
the session screen edits any of them. They are writable only in the template editor. Consequences:
an ad-hoc workout can never set a rep range, so **`suggestNextSet` returns the match-last-time
message forever** (Phase 1.2 fixes the RPE half of this; this fixes the other half), and it is the
only unlock for F1/F2 for anyone not using templates.

**Decided fix.** Make the prescription line tappable, opening an edit sheet that writes to
`SessionExercises` via a new `SessionRepository.updatePrescription(int sessionExerciseId, {...})`
using `Value.absent()` throughout. Reuse the field widgets from
`lib/features/templates/template_editor_screen.dart` rather than duplicating them.

## Phase 4 verification
Suite green. Manually: remove an exercise mid-session and confirm the dialog appears; delete a set
and undo it; rename a bundled exercise; try to delete an exercise that has logged sets and confirm
the Archive fallback.

---

# PHASE 5 — Flutter practice & set-list mechanics

## 5.1 — B1: Streams and Futures constructed inside `build()` 🟠
`dashboard_screen.dart:64`, `history_screen.dart:28`, `templates_screen.dart:173`,
`progress_screen.dart:191`. Each rebuild creates a **new** subscription, and
`snapshot.data ?? const []` then renders the **empty state** while it reconnects — so the recent
sessions, history, and template lists visibly flash empty on unrelated rebuilds.
`active_session_screen.dart:668` caches its future correctly and is the pattern to follow.

**Decided fix.** Convert each to a Riverpod `StreamProvider` / `FutureProvider` in
`lib/data/providers.dart` (several already exist there) and consume with `ref.watch(...).when(...)`.
Each must render a **distinct loading state** — today none of them distinguish loading from empty.

## 5.2 — H1: set numbers gap permanently after a delete 🟠
`SetRepository.delete` never renumbers and `_nextSetNumber` is `max(setNumber) + 1`. Delete set 2 of
3 → rows read **1, 3**, next add is **4**. `shiftSetNumbers` already exists and is wired only into
`insertWarmupSets`.

**Decided fix.** After deleting a set, renumber the remaining sets of that `sessionExerciseId`
contiguously from 1 inside the same transaction. Add the renumber to `SetRepository.delete` so every
caller benefits (root-cause fix, not a call-site patch).

## 5.3 — H2: sets cannot be reordered or inserted mid-list 🟠
`onReorder` (`active_session_screen.dart:723`) reorders **exercises**. Add a set-level reorder to the
set list and an "Insert set above" action, both routed through `shiftSetNumbers` + the 5.2 renumber.

## 5.4 — H3: an entirely empty set can be saved 🟡
`_save()` in `set_editor_sheet.dart` validates only the assisted-vs-bodyweight case. Add a guard: if
every logged field is null/blank, set `_errorText` and do not pop.

## 5.5 — B2 / B3 🟡
`SessionRepository.details()` is N+1 (one query per exercise plus one per set list, re-run on every
`setState(_refresh)`) — replace with two batched queries and an in-memory group-by. `DateTime.now()`
is read inside `dashboard_screen.dart`'s `build()` so the greeting, week strip, and "missed" markers
never update across midnight — hoist to a provider that re-emits at local midnight.

---

# PHASE 6 — Rest timer: persistent lock-screen countdown

Fixes **C1** (Android alarm scheduled `inexactAllowWhileIdle`, so a 90-second rest can fire minutes
late) and **C2** (on completion `RestTimerBar` returns `SizedBox.shrink()` — haptic only, no visual
completion state).

## 6.1 — Android: ongoing chronometer notification
`flutter_local_notifications ^22.1.0` already exposes everything needed on
`AndroidNotificationDetails` — **no new dependency**:
`ongoing: true`, `usesChronometer: true`, `chronometerCountDown: true`,
`when: endTime.millisecondsSinceEpoch`, `onlyAlertOnce: true`, plus notification **actions** for
+15s / Skip.

Post with `showNow` at `RestTimerController.start()` rather than `zonedSchedule`. This takes
`AndroidScheduleMode.inexactAllowWhileIdle` off the critical path — the notification is already
posted and the system ticks it. Fire a separate alert at zero.

## 6.2 — Controller inversion
`RestTimerController._syncBackgroundNotification` currently **cancels** the notification whenever the
app resumes and only posts while backgrounded. Invert it: post at `start()`, hold it for the whole
rest period regardless of lifecycle, update on `adjust()`, and cancel only on `skip()` / `_finish()` /
session dispose. On finish, replace it with a **"Rest complete"** notification instead of cancelling —
that is C2's completion state.

Also: `_syncBackgroundNotification` currently fires on `AppLifecycleState.inactive`, which on iOS
includes every notification-centre pull. Only act on `paused` / `resumed`.

## 6.3 — A dedicated full-screen rest timer (user-requested)
Push a full-screen route when the timer auto-starts; keep `RestTimerBar` as the minimised state.
- **Full-screen route, not a dialog**, so the system back gesture maps to minimise, not kill.
- **Minimise ≠ dismiss.** A chevron-down running a `Hero` from the ring into the bottom bar reads as
  "still running". A separate ✕ cancels, confirming **only** if >30 s remain.
- **Drive the animation from the data**: one `AnimatedBuilder` on an `AnimationController` seeded
  from `state.endTime`, not a `Timer.periodic` rebuilding text. `endTime` is already authoritative on
  resume, so the ring resyncs correctly after backgrounding for free. Carry over the
  `FontFeature.tabularFigures()` already used on the bar so digits do not jitter.
- **Show the next set**: exercise name, set number, and the `suggestNextSet` rationale. This is the
  one moment the user is idle and looking at the phone.
- **Every control on the full screen must also exist on the minimised bar.** Do not let the new
  screen become the sole writer of anything — that is the F1 mistake repeated at the UI layer.

## 6.4 — iOS Live Activities (separate, optional follow-up)
There is no chronometer equivalent on iOS and `flutter_local_notifications` cannot do it. The real
answer is **ActivityKit**, which ticks natively via `Text(timerInterval:)` on the lock screen and
Dynamic Island with no app process. Groundwork exists: `ios/LoggedWidget` +
`LoggedWidgetExtension.entitlements` are already in the tree for the home widget. Still needed:
`NSSupportsLiveActivities` in `Runner/Info.plist` (**currently absent**), an `ActivityAttributes`
struct and view in the extension, and a method channel from Dart.

**Interim:** set `interruptionLevel: .timeSensitive` on the completion notification so it breaks
through Focus modes.

**Ground rule 6 applies to this whole phase.** After it lands:
`flutter clean && flutter pub get && (cd ios && pod install)`, then test on a **real, backgrounded
device**. A green simulator build proves nothing here.

---

# PHASE 7 — Lower priority (do last, or defer)

| ID | Item |
|---|---|
| **L1** | `appSettings` carries device-local state into portable backups — `healthExportedSessionIds` and the backfill flags. Restore on a new phone → those workouts are **never** written to that phone's Apple Health. Exclude device-local keys from `exportPayload`, or skip them on import. |
| **L2** | `importFromPicker` uses `result?.files.single.path`; `.single` throws `StateError` outside the normalised `FormatException` path. Use `firstOrNull`. |
| **M1** | Training reminders die after 28 days of not opening the app — the rolling window is refreshed only on app open. Add one repeating weekly alert beyond the horizon as a backstop. |
| **I2** | The anatomy backfill flag is permanent and unversioned, so library anatomy corrections never reach existing installs. Add a per-exercise `anatomyEditedByUser` flag so the backfill can re-run on a version bump and skip only genuinely user-edited rows. |
| **N1** | 5 `Semantics` usages in 29,571 lines and **zero** `textScaler` handling. Fixed `SizedBox(height: 56)` and `maxHeight: screenHeight * 0.85` sheets overflow at large system text — on the two screens used most mid-workout. |
| **A9** | `recentPrs` compares `estimatedOneRepMaxKg` across `weightEntry`; 30 per-hand then 60 total registers a fake PR. Compare within the same entry mode. |
| **A5** | Default `restWeekdays: {7}` means a Mon/Wed/Fri lifter has a streak stuck at 1 forever and sees Tue/Thu marked "missed". Ask for training days in onboarding, or make the streak tolerant of N non-training days per week. **Product decision — confirm before building.** |
| **A10/A11, G3, G5, H4, L3, M2, N2, N3, I4** | See the audit document. |

---

# Explicit DO NOTs

- Do not change `primaryMuscleBiasWeight`, or the bias handling in `muscle_progress.dart` /
  `live_muscle_state.dart`. Phase 1.1 is a UI/persistence fix; the domain is already correct.
- Do not remove RPE fields, parameters, or inputs. Phase 1.2 makes RPE optional, not absent.
- Do not "simplify" the set editor by hiding controls. Ground rule 4 — check for other writers first.
- Do not add a network call, analytics, or an account. The local-only guarantee is absolute.
- Do not touch `assets/data/exercise_library.json` beyond adding the `isTimed` field named in 3.1.4.
  It has uncommitted changes; leave the rest alone.
- Do not skip the migration or the backfill for any schema change. Both Phase 1.1 and Phase 3.1
  change persisted data.
- Do not reorder or renumber the phases. Phase 1.1 consumes schemaVersion 11 and Phase 3.1 consumes
  12; doing them out of order breaks both migrations.

# Definition of done (per phase)

1. `flutter analyze` clean.
2. `flutter test` green, including the new tests named in that phase.
3. The manual on-device verification named in that phase has been performed against a real SQLite
   database, with counts checked before and after.
4. `git diff HEAD` touches only the files that phase names.

# IMPLEMENTATION SPEC — "Coach, not just a tracker" (T1→T3, for Codex) (2026-07-23)

> **Read this as a standalone brief.** You (Codex) have NO prior conversation context. Everything
> needed to build Tiers 1–3 is below, grounded in the CURRENT codebase (real file paths + symbols
> are named so you must NOT invent APIs — open the file and confirm before using anything). Work
> top-to-bottom, phase by phase, verifying each before moving on. Defaults here are decided; do not
> ask questions unless truly blocked. Keep it simple, immutable, feature-organized. Tier 4
> (open-source packaging) and Tier 5 (sync) are intentionally out of scope for this spec.

## Why this exists (context, 20 seconds)
Logged is a private, 100% local, no-account Flutter workout tracker (Android + iOS, Drift + Riverpod,
feature-first). It already has a live-reacting offline 3D muscle model. The goal of T1–T3 is:
(1) T1 — add the table-stakes daily-use features it's missing, (2) T2 — turn the muscle model from a
*visualization* into a *coach* (the differentiator), (3) T3 — let users import a whole program in one
paste. Do not degrade the local-only / no-network / no-analytics guarantee.

---

## GROUND RULES (non-negotiable — these come from logged/tasks/lessons.md)
1. **Verify APIs before use.** Every symbol named below exists today; still open the file and confirm
   the signature. Never assume a method shape.
2. **Schema changes ship with a migration AND a one-time backfill.** The DB is Drift; current
   `schemaVersion` in `lib/data/database/app_database.dart` and `_schemaVersion = 6` in
   `lib/data/services/backup_service.dart`. Any new column/table bumps BOTH, adds an `onUpgrade` step,
   and — if it's library/derived data existing installs need — a backfill guarded by a one-time flag in
   the `app_settings` key/value table (via `SettingsRepository` pattern). Seeding uses
   `InsertMode.insertOrIgnore`, so new columns NEVER reach existing rows without an explicit backfill.
3. **Per-set truth.** Units, `weightEntry` (total|perSide), and `sideCount` are per-SET. Never hoist a
   per-set value into a shared header/label without a per-row deviation flag.
4. **Don't delete capability by "showing only what's relevant."** Before hiding a control, confirm it's
   not the only writer of a field. Drive visibility off the DATA, not the category enum.
5. **1RM convention:** `estimatedOneRepMaxKg = weightKg * (1 + reps/30)` uses the entered (per-hand)
   value, NOT doubled total load. Volume DOES double for `perSide`. Any new suggestion/coaching math
   must follow this exact split (see `analytics_repository.dart` `WorkoutSetRecord`).
6. **Native additions are fragile.** `flutter_local_notifications` (T1.1/T1.3) is the only native
   surface here. After adding it run `flutter clean && flutter pub get && (cd ios && pod install)` and
   test on a REAL device backgrounded — a green simulator build does not prove the notification fires.
   iOS release builds need real network (native-asset dylibs are fetched at build time).
7. **Green tests are necessary, not sufficient.** For data-shaped features, verify against the actual
   on-device SQLite DB (query counts before/after), not just fixtures. Free-text parsing (T3) needs
   explicit negative-case tests.
8. **Baseline in git BEFORE you start**, so `git diff HEAD` is a clean Mode-B review surface. Do not
   modify files outside a phase's stated scope.

## EXISTING ARCHITECTURE MAP (what to build on — all real, today)
- **DB / schema**: `lib/data/database/app_database.dart` (Drift tables: `Exercises`, `Templates`,
  `TemplateExercises`, `Sessions`, `SessionExercises`, `SetEntries`, `BodyweightEntries`, `RestDays`,
  `AppSettings`). `TemplateExercises`/`SessionExercises` ALREADY have: `targetSets`, `sidesPerSet`,
  `minReps`, `maxReps`, `targetDurationSec`, `targetDistanceMeters`, `restSeconds`, tempo
  (`eccentricSec`,`bottomPauseSec`,`concentricSec`,`topPauseSec`), `prescriptionNotes`, `formUrl`.
  `SetEntries` has `reps`, `weightValue`, `sideCount`, `distanceMeters`, `durationSec`, `isWarmup`,
  `rpe`, `notes`. `Exercises` has `primaryMuscles`/`secondaryMuscles` (JSON arrays of muscle ids),
  `muscleGroup`, `bodyweightFactor`, `isCustom`, `isArchived`.
- **Providers** (`lib/data/providers.dart`): `databaseProvider`, `sessionRepositoryProvider`,
  `exerciseRepositoryProvider`, `templateRepositoryProvider`, `settingsRepositoryProvider`,
  `analyticsRepositoryProvider`, `workoutSettingsProvider` (StreamProvider<WorkoutSettings>),
  `liveMuscleStateProvider` (StreamProvider<LiveMuscleState>), `muscleProgressProvider`,
  `completedSetsProvider`, `trainingDaysProvider`.
- **Muscle model** (`lib/core/domain/`): `MuscleId` enum (27 ids, `muscle.dart`),
  `live_muscle_state.dart` — `buildLiveMuscleState(records)` → `LiveMuscleState` with per-muscle
  `MuscleLoad { primarySets, secondarySets, effectiveSets, intensity, exercises }`. Constants:
  `secondaryMuscleSetWeight = 0.35`, **`muscleIntensitySetCeiling = 12.0`** (THE current flat ceiling
  T2.1 replaces). `intensity = (effectiveSets / muscleIntensitySetCeiling).clamp(0,1)`.
  `muscle_progress.dart` also has `productiveWeeklyEffectiveSetCap = 12.0` (rank scoring).
  `muscle_model.dart` — `muscleModelEntities` maps `MuscleId` → GLB mesh names (the 3D coloring).
  `muscle_map.dart` — 2D region fallback.
- **Analytics** (`lib/data/repositories/analytics_repository.dart`): `WorkoutSetRecord`
  (`volumeKg`, `estimatedOneRepMaxKg`), `watchCompletedSets()`, `watchLiveMuscleSets()`,
  `watchMuscleProgress()`. Pure functions in `lib/core/domain/progress_analytics.dart`:
  `weeklyStats()`, `muscleVolumeThisWeek()`, `recentPrs()`.
- **Session** (`lib/data/repositories/session_repository.dart`): `start`, `startFromTemplate`,
  `addExercise`, `details(sessionId)` → `List<SessionExerciseDetails>`,
  `seedForNextSet({sessionExerciseId})` → `SetSeed`, **`lastSetForExercise(exerciseId)` → `SetEntry?`**
  (already exists — the hook for T1.2), `finish`, `watchTrainingDays`.
- **Streak math** (`lib/core/domain/streak.dart`): `computeStreak`, `trainedToday`,
  `trainingDaysThisWeek`, `startOfWeek`, `dateOnly`. Pure, unit-tested.
- **Settings** (`lib/features/settings/settings_screen.dart`, `SettingsRepository`): key/value over
  `AppSettings`; `WorkoutSettings { restWeekdays, weeklyGoal }`.
- **Active session UI**: `lib/features/session/active_session_screen.dart` +
  `widgets/set_row.dart`, `widgets/set_editor_sheet.dart`. `lib/core/widgets/app_widgets.dart` has
  shared `EmptyState`, `SectionHeader`, `StreakCard`. Icons in `lib/core/app_icons.dart`.
- **Tests** live in `test/`; run `flutter analyze` and `flutter test` after every phase.

═══════════════════════════════════════════════════════════════════════════════════════════════
# TIER 1 — Table stakes (do first; each phase is independently shippable)
═══════════════════════════════════════════════════════════════════════════════════════════════

## PHASE T1.1 — Rest timer with local notification
**Goal**: an auto-starting between-sets countdown that fires a notification + haptic when done, even
backgrounded / screen-off.
**New dep**: `flutter_local_notifications` (latest stable). Configure iOS (request permission on first
use; `UNUserNotificationCenter`) + Android (`POST_NOTIFICATIONS` runtime permission on API 33+,
notification channel "rest_timer"). Add a thin `lib/core/services/notification_service.dart` wrapper
(init, requestPermission, showNow, schedule, cancel) — keep plugin usage out of widgets.
**Schema**: add global default rest seconds as an `app_settings` key `defaultRestSeconds` (no table
change). Per-exercise rest already lives in `SessionExercises.restSeconds`.
**Files**:
- create `lib/core/services/notification_service.dart`
- create `lib/features/session/rest_timer_controller.dart` (Riverpod `Notifier<RestTimerState>` —
  holds remaining secs, running flag, target endTime; ticks via a `Timer.periodic`; survives tab
  switches because it's a provider, not widget state).
- create `lib/features/session/widgets/rest_timer_bar.dart` (sticky bar pinned above the set list /
  above the bottom action row in `active_session_screen.dart`).
- edit `active_session_screen.dart`: on set complete (the existing "mark set done" path — the set
  chip that fills `primaryContainer` when `_isComplete`), start the timer using
  `SessionExercises.restSeconds ?? defaultRestSeconds`.
- edit `settings_screen.dart`: a "Rest timer" row (default seconds + on/off for notifications).
**Behavior**: presets 60/90/120/180 + custom; controls skip / +15s / −15s; on reaching 0 →
haptic (`HapticFeedback.heavyImpact`) + local notification if app backgrounded. Timer state is
per-active-session; leaving the session cancels it.
**Acceptance**:
- [ ] Completing a set auto-starts the countdown with the exercise's prescribed rest.
- [ ] Notification fires with the app backgrounded on a real device (both platforms).
- [ ] Switching tabs and returning keeps the countdown accurate (provider-held, not rebuilt).
- [ ] Permission denial degrades gracefully (in-app timer still works; no crash).
**Tests**: unit-test the controller's tick/skip/adjust math (inject a clock; no real timer);
`flutter analyze` clean, `flutter test` green. Manual device verification per Ground Rule 6.

## PHASE T1.2 — "Last time" inline reference
**Goal**: show the previous session's performance for the same exercise as a read-only hint on each
set row, so progressive overload is visible while logging.
**Schema**: none.
**Files**:
- edit `session_repository.dart` if needed: expose a `lastSetsForExercise(exerciseId, {limit})` or
  reuse existing `lastSetForExercise(exerciseId)` — confirm signature first. It must return the most
  recent COMPLETED session's sets for that exercise (ended_at not null, excluding the current session).
- edit `widgets/set_row.dart`: render a muted "last: {reps} × {weight}{unit}" line per row (or a
  per-exercise header line "Last time: 3×8 @ 40 kg"). Respect per-set unit/`weightEntry` when
  formatting (Ground Rule 3) — show the value as it was entered, not re-normalized.
- edit `active_session_screen.dart`: fetch last-session data alongside `details()` and pass down.
**Acceptance**:
- [ ] Each exercise in an active session shows its last completed-session numbers; brand-new exercises
      show nothing (no "0 × 0").
- [ ] The hint reflects the entered unit/per-hand semantics, not a kg round-trip.
- [ ] Purely additive — does not change the seeded/auto-filled input values (that's `seedForNextSet`).
**Tests**: repository test with two sessions (older + current) asserting the correct "last" set is
returned and the current session is excluded. Analyze/test green.

## PHASE T1.3 — Local reminder notifications
**Goal**: scheduled "train today" reminders on scheduled training days, suppressed once trained.
**Dep**: reuse `notification_service.dart` from T1.1.
**Schema**: `app_settings` keys `reminderEnabled` (bool) + `reminderTime` (HH:mm). No table change.
**Files**:
- create `lib/features/settings/reminder_scheduler.dart`: computes training weekdays as the complement
  of `WorkoutSettings.restWeekdays`; schedules a daily repeating local notification at `reminderTime`;
  on app open / after finishing a workout, if `trainedToday` (from `streak.dart`) is true, skip/cancel
  today's. Reschedule whenever `restWeekdays` or `reminderTime` change.
- edit `settings_screen.dart`: "Reminders" section (enable toggle + time picker) under Schedule.
**Acceptance**:
- [ ] With reminders on and today a training day and not yet trained, a notification is scheduled for
      `reminderTime`; training beforehand cancels it.
- [ ] Rest days (scheduled or logged) get no reminder.
- [ ] Changing rest weekdays / time reschedules correctly.
**Tests**: unit-test the "should remind on day D?" pure function against rest weekdays + trained set +
logged rest days (mirror the streak module's style). Device-verify one real fire.

## PHASE T1.4 — Onboarding + empty-state guidance
**Goal**: a short first-run flow + empty states that lead somewhere; lead with the muscle model (hook).
**Schema**: `app_settings` key `onboardingComplete` (bool), one-time.
**Files**:
- create `lib/features/onboarding/onboarding_screen.dart` (3–4 pages: welcome + "private, offline, no
  account"; "units are per-exercise, toggle on the set row"; "your 3D body reacts to every set — meet
  your coach"; "start an empty workout or from a template"). PageView + Skip/Get-started; sets the flag.
- edit `lib/main.dart` (or the root/`home_shell.dart` gate): show onboarding when the flag is unset,
  else `HomeShell`. Keep it inside the existing provider scope; do not block startup on it (Ground
  Rule: never let a first-run path crash boot — wrap in try/catch, default to HomeShell on error).
- edit empty states via `app_widgets.dart` `EmptyState`: add an optional primary action; wire Dashboard
  ("Start your first workout"), Templates ("Create a template"), History, Progress ("Log a set to light
  up your body").
**Acceptance**:
- [ ] First launch shows onboarding once; subsequent launches go straight to HomeShell.
- [ ] Every major empty screen has a one-tap primary action.
- [ ] Flag failure / read error falls back to HomeShell without crashing.
**Tests**: widget test that onboarding shows when flag unset and is skipped when set. Analyze/test green.

## PHASE T1.5 — Template CRUD (rename / delete / duplicate / reorder)
**Goal**: complete missing template management. Today you can create a template and edit its exercises,
but you CANNOT rename it, delete it, duplicate it, or reorder the list — close the gap.
**Current state (verified)**: `TemplateRepository` has `create`, `watchAll`, `replaceExercises`,
`replaceExerciseDetails`, `exerciseIds/exercises/exerciseDetails` — but NO `rename`, `delete`,
`duplicate`, or `reorder`. `template_editor_screen.dart` renders `template.name` as a STATIC title
(no edit path); `templates_screen.dart` only offers create + open.
**Schema**: none — all columns exist (`Templates.name`, `Templates.position`).
**Files**:
- edit `template_repository.dart`: add `rename(int id, String name)`; `delete(int id)`;
  `duplicate(int id)` (copy the template + all its `TemplateExercises` WITH every prescription field —
  sets/sidesPerSet/min-maxReps/duration/distance/rest/tempo/notes/formUrl — name "… (copy)", appended
  position); `reorder(List<int> orderedIds)` (rewrite `position`).
- edit `templates_screen.dart`: per-row actions (`PopupMenuButton` or swipe) — Rename, Duplicate,
  Delete (with a confirm dialog; deletion is destructive) — plus drag-to-reorder (`ReorderableListView`).
- edit `template_editor_screen.dart`: make the title editable (tap → rename dialog calling `rename`).
**Watch (FK integrity)**: `Sessions.templateId` is a NULLABLE FK to `Templates`. Deleting a template a
past session points to would dangle/violate the FK. The delete transaction must first set
`Sessions.templateId = NULL` where it equals this id (preserve the completed workout, drop only the
link), THEN delete the template's `TemplateExercises`, THEN the `Templates` row. A finished session must
survive deletion of the template it came from.
**Acceptance**:
- [ ] Rename works from both the templates list and inside the editor; persists.
- [ ] Delete confirms, removes the template + its exercises, but historical sessions that used it stay
      intact (their `templateId` goes null, the session and its logged sets remain).
- [ ] Duplicate produces an independent copy carrying ALL prescription fields.
- [ ] Reorder persists across app restarts (position column).
**Tests**: repository tests for rename/delete/duplicate/reorder + a test proving deleting a template
does NOT delete or corrupt a historical session that referenced it. Analyze/test green.

═══════════════════════════════════════════════════════════════════════════════════════════════
# TIER 2 — The muscle model becomes a coach (the differentiator)
═══════════════════════════════════════════════════════════════════════════════════════════════
Shared foundation: T2.1 introduces the volume-landmark model that T2.3/T2.4 build on. Do T2.1 first.

## PHASE T2.1 — Volume-landmark coaching on the 3D model  ← FLAGSHIP
**Goal**: color each muscle by this week's effective sets against evidence-based per-muscle weekly
landmarks, and coach ("Rear delts: 4 sets · below MEV 8 · add ~4"), replacing the flat 12-set ceiling.

**Science (locked — do not use a single fixed cap):** current evidence (Pelland et al. 2025
meta-regression; Baz-Valle 2022) shows hypertrophy rises with weekly volume with DIMINISHING RETURNS
and no hard ceiling; the commonly-cited productive range is ~12–20 hard sets/muscle/week, minimum
effective ~10, with detectable benefit out to ~30+ sets at rising fatigue cost. So model BANDS with a
diminishing-returns zone, NOT a "junk volume" hard wall. All numbers are per-WEEK **effective** sets
(primary 1.0 + secondary 0.35), consistent with the existing model, so the number shown matches the color.

**Landmark model** — create `lib/core/domain/volume_landmarks.dart`:
```
class VolumeLandmarks { final double mev, mav, mrv; }   // effective sets / week
enum VolumeZone { belowMev, developing, optimal, diminishing, overreaching }
// belowMev: <MEV · developing: MEV..MAV low · optimal: within MAV band · diminishing: MAV..MRV ·
// overreaching: >MRV (recovery-risk, still-some-growth — NOT labeled "junk")
VolumeZone zoneFor(double effectiveSets, VolumeLandmarks l);
double coachingIntensity(double effectiveSets, VolumeLandmarks l); // 0..1 for the model color ramp,
//   anchored so "optimal band" reads as full/healthy, not the old fixed /12.
```
Provide `const Map<MuscleId, VolumeLandmarks> defaultLandmarks` seeded from published RP-style ranges
(smaller muscles lower, e.g. rear/side delts, calves, biceps MEV~6–8/MAV~14–20; larger back/quads/chest
MEV~8–10/MAV~16–20; core/forearms/neck lower). Keep it a single reviewed constant table; document the
source in a comment. Make it USER-OVERRIDABLE later via `app_settings` (store overrides as JSON under
key `volumeLandmarkOverrides`; fall back to defaults when absent) — implement the read path now,
editing UI can be a later slice. **Resolution order (shared with T2.5):** effective landmarks =
`defaultLandmarks` scaled by the user's **goal profile** (Maintain/Build/Push — see T2.5) THEN any
per-muscle `volumeLandmarkOverrides`. Implement the goal-scaling read here so T2.1 and T2.5 read the
same landmarks. The separate rank-scoring cap `productiveWeeklyEffectiveSetCap` in `muscle_progress.dart`
is NOT repurposed here — it is unified into the goal-scaled landmarks in T2.5.
- **Build `lib/core/domain/training_goal.dart` in THIS phase** (T2.5-A specifies it fully), because the
  goal-scaling read above depends on it. Define `enum TrainingGoal { maintain, build, push }`, read
  `trainingGoal` from `app_settings` (default `build`), and apply its scale factor to the landmarks. T2.5
  then builds the rest (rank thresholds, progression, deload, UI) on top of the same enum — do not create
  a second copy there.

**Wire into the model & UI**:
- edit `lib/core/domain/live_muscle_state.dart`: keep `MuscleLoad.effectiveSets`; add a
  landmark-aware color source. Do NOT silently repurpose `intensity` (other callers use it) — add
  `MuscleLoad.zone(landmarks)` / a `coachingColor` path and switch the 3D renderer to it. Deprecate the
  flat `muscleIntensitySetCeiling` for coloring but leave the constant until all callers move.
- edit the 3D view (`lib/features/exercise/widgets/muscle_anatomy_view.dart` + `muscle_heatmap.dart`):
  color by `VolumeZone` (belowMev cool/grey → optimal green → diminishing amber → overreaching red).
  On muscle tap, show sets-this-week, the zone, the landmark numbers, and a one-line suggestion.
- add a Progress "Weekly muscle balance" card (in `progress_screen.dart`): lists muscles below MEV
  (neglected) and above MRV (overreached) this week. Reuse `liveMuscleStateProvider`.
**Acceptance**:
- [ ] A muscle at 4 effective sets vs MEV 8 renders in the "below" color and reads "below MEV".
- [ ] A muscle inside its MAV band reads "optimal"; above MRV reads "overreaching / recovery risk"
      (never "junk volume").
- [ ] Numbers shown are effective sets (primary 1.0 + secondary 0.35), matching the existing model.
- [ ] Removing/adding a set this week moves the color/zone live (it flows through `liveMuscleStateProvider`).
- [ ] Default landmarks are overridable via the `app_settings` JSON read path (defaults when unset).
**Tests**: unit-test `zoneFor` at every boundary (below/at MEV, mid-MAV, at MRV, above) and
`coachingIntensity` monotonicity; a golden-ish test that a known weekly set count maps to the expected
zone per muscle. Analyze/test green.

## PHASE T2.2 — Auto-progression / next-weight suggestions
**Goal**: suggest the next set's load/reps from history + prescription, one-tap to accept.
**Schema**: none (reads history + prescription). Prefer stateless — do not persist suggestions.
**Logic** — create `lib/core/domain/progression.dart` (pure):
```
class ProgressionSuggestion { double? weightValue; WeightUnit? unit; int? reps; String rationale; }
ProgressionSuggestion? suggestNextSet({
  required List<SetEntry> lastExerciseSets,   // most recent completed session, same exercise
  int? minReps, int? maxReps, double? targetRpe,
  required WeightEntry weightEntry, required WeightUnit unit,
});
```
Rule (double progression): if last time the top set hit `maxReps` at RPE ≤ target → increase load by
the smallest sensible increment (unit-aware: **+2.5 kg / +5 lb**) and reset reps to `minReps`; if reps
were below `minReps` or RPE too high → hold load (or −1 step) and keep rep target; otherwise → same
load, +1 rep toward `maxReps`. **Follow the per-hand 1RM convention (Ground Rule 5): operate on the
entered value; do not double `perSide` loads.**
**UI**: on the set row (extends T1.2's "last time"), show "Suggested: 82.5 kg × 5" with a one-tap apply
that fills the input. Never auto-commit.
**Acceptance**:
- [ ] Hitting the top of the rep range at/under target RPE proposes +1 increment and rep reset.
- [ ] A missed or high-RPE session proposes a hold, not an increase.
- [ ] Dumbbell/`perSide` exercises suggest per-hand values consistent with how they're logged.
- [ ] No template rep range/RPE → falls back to "match last time" (no crash, sensible default).
**Tests**: table-driven unit tests over the rule matrix (hit/miss/borderline × kg/lb × total/perSide).
Analyze/test green.

## PHASE T2.3 — Fatigue / deload awareness
**Goal**: detect stalling/overreaching and offer a deload.
**Schema**: none for detection. "Generate deload week" writes a new Template (reuses template schema).
**Logic** — create `lib/core/domain/deload.dart` (pure):
```
class DeloadSignal { bool triggered; List<String> reasons; }
DeloadSignal assessDeload({
  required Map<MuscleId, List<double>> weeklyEffectiveSetsByMuscle, // recent weeks, with landmarks
  required Map<int, List<double>> oneRepMaxSeriesByExercise,        // est-1RM over sessions
  required Map<int, List<double>> rpeAtLoadSeries,                  // rising RPE at same load
  required Map<MuscleId, VolumeLandmarks> landmarks,
});
```
Fire when ≥2 of: (a) a muscle above MRV for ≥2 consecutive weeks, (b) est-1RM flat/declining across
≥3 sessions on a lift, (c) RPE rising at equal load. Surface a DISMISSIBLE Progress card "Consider a
deload"; a one-tap "generate deload week" creates a template at ~50% of current weekly volume (halve
`targetSets` or load, keep exercises).
**Acceptance**:
- [ ] With <2 signals, no card. With ≥2, a dismissible card appears with the specific reasons.
- [ ] "Generate deload week" produces a valid Template (opens in the template editor for review; does
      not silently alter the user's program).
- [ ] Dismiss persists for the current week (store a `deloadDismissedWeek` `app_settings` key).
**Tests**: unit-test the signal logic (0/1/2/3 signals) and the deload-template generation. Analyze/test green.

## PHASE T2.4 — Muscle-map-driven workout building
**Goal**: build/extend sessions & templates by tapping a muscle → pick exercises that train it; also
exercise substitution ("swap for another that hits this muscle").
**Schema**: none. Reverse-index existing `Exercises.primaryMuscles`/`secondaryMuscles`.
**Files**:
- create `lib/data/repositories/muscle_exercise_index.dart` (or a method on `ExerciseRepository`):
  build `Map<MuscleId, List<{exercise, isPrimary}>>` from all non-archived exercises; rank primary
  before secondary, then by user's training frequency for that exercise if available.
- edit the muscle detail view (from T2.1 tap target) + `template_editor_screen.dart` +
  `active_session_screen.dart`: a "Add exercise for {muscle}" / "Build from muscle" entry point that
  opens a filtered `exercise_picker` (reuse `lib/core/widgets/exercise_picker.dart`).
- add "Swap" on a session/template exercise row → picker filtered to the same primary muscle(s).
**Acceptance**:
- [ ] Tapping a muscle (e.g. from the below-MEV balance card) offers exercises that train it, primary
      first; adding one inserts it into the current session/template.
- [ ] Swap replaces an exercise while preserving its prescription slot where sensible.
- [ ] Archived exercises are excluded; custom exercises with muscle metadata are included.
**Tests**: repository test that the reverse index maps a known exercise to the right muscles with
correct primary/secondary ranking. Analyze/test green.

## PHASE T2.5 — Rank redesign + goal profile + Ranks page + Strength Standards
**Order**: do AFTER T2.1 (it shares the goal-scaled landmarks). One phase, five parts (A–E). Rank is
DERIVED (computed from sets, not stored) so redesigning it needs NO schema migration — it just
recomputes; existing users will see their ranks shift once (acceptable — call it out in the commit).

**Decisions locked (via user Q&A):** goal-FRAMED knob (not "difficulty"); v1 scope = rank redesign +
goal profile + Ranks page + Strength Standards + rank-up/PR celebration moments. No achievements/XP/
leaderboards (local-only, no social — gamification is self-competitive only). Rule: reward REAL
training, never fake achievement.

### A. Goal profile (the honest "difficulty" knob)
- **Schema**: `app_settings` key `trainingGoal` ∈ {`maintain`,`build`,`push`}, default `build`.
- create `lib/core/domain/training_goal.dart`: `enum TrainingGoal { maintain, build, push }` with a
  per-goal scale factor on the volume landmarks (reviewed constants, e.g. maintain ~0.7×, build 1.0×,
  push ~1.25× applied to MEV/MAV/MRV) AND matching rank-threshold + progression-aggressiveness +
  deload-sensitivity presets. This ONE knob drives T2.1 landmarks, the T2.5 rank, T2.2 progression, and
  T2.3 deload — so a person's whole coaching stack is calibrated to intent (the "unique per user" goal).
- **UI**: picked during onboarding (T1.4) and changeable AT ANY TIME in Settings ("What are you training for?" —
  Maintain / Build / Push, with a one-line plain description each). Label ranks with the goal
  ("Gold · Build") so tiers earned under different goals are self-evidently different.

### B. Rank redesign (self-relative, sex-neutral) — replaces `_rankScore` in `muscle_progress.dart`
- **New meaning**: "How developed and well-trained is this muscle, on MY journey?" Three components:
  1. **Strength progress vs personal baseline** — weight the RECENT trend, not best-ever, so detraining
     actually lowers rank (fixes today's "locked forever" behavior; reuse the existing performance index
     but decay/recency-weight it instead of taking `math.max`).
  2. **Volume-landmark adequacy** — reward training inside the goal-scaled productive band (MEV→MAV);
     no reward for junk volume above MRV; underweight below MEV. **This replaces the flat
     `productiveWeeklyEffectiveSetCap = 12.0`** — unify on the goal-scaled landmarks (resolves the
     two-different-"12"s inconsistency).
  3. **Consistency / recency** — recent weeks trained, with gentle decay when a muscle is neglected.
- Rank tiers stay (`MuscleRank` Foundation→Elite); thresholds scale with the goal profile (Push needs
  more). Keep it self-relative → sex is irrelevant here.
- create a pure `rankExplainer(MuscleProgress, TrainingGoal) → String` ("You're Silver lats. To reach
  Gold: train lats ~2 more weeks in the 10–18 set band and add ~5% to your best row.") — powers the
  "how to improve" on the Ranks page.
- **Watch**: `BodyProgressSummary` and the Dashboard `_BodyRankHero` read the same score — keep them
  consistent after the rewrite.

### C. Ranks page (NO new nav tab)
- create `lib/features/ranks/ranks_screen.dart`, pushed as a route from a now-TAPPABLE Dashboard
  `_BodyRankHero` card (edit `dashboard_screen.dart`).
- Two sections (segmented control): **(1) Your muscles** — all 27, sortable by rank, each with tier +
  progress-to-next bar + `rankExplainer` text. **(2) Strength standards** — part D.
- **Move** the per-muscle rank content currently in `progress_screen.dart` (`_MuscleRankCard`, the
  rank sort) INTO the Ranks page so Progress goes back to charts/analytics. Reuse `muscleProgressProvider`,
  `bodyProgressSummaryProvider`.

### D. Strength Standards layer (population, opt-in) — the only place sex matters
- **Schema**: `app_settings` key `userSex` ∈ {`male`,`female`,`unset`} (default unset). Bodyweight
  already exists — use the latest `BodyweightEntries` value (do NOT add a second store).
- create `lib/core/domain/strength_standards.dart` (pure): const tables of **bodyweight-multiple**
  thresholds per **level** (untrained/novice/intermediate/advanced/elite) × **sex**, for the six
  benchmark lifts. **VERIFIED exact seed names (already checked against
  `assets/data/exercise_library.json` — use these strings verbatim, do NOT guess):**
  `Barbell Bench Press`, `Barbell Back Squat`, `Barbell Deadlift`, `Barbell Overhead Press`,
  `Barbell Bent-Over Row`, and **Pull-Up** (see the gap note below). Document the source (public
  bodyweight-ratio standards) in a comment. `standardFor({lift, sex, bodyweightKg, estOneRepMaxKg}) →
  {level, ratio, nextThreshold}`.
- **Pull-Up gap (DECIDED):** the library currently has NO plain "Pull-Up" — only `Assisted Pull-Up`
  (the opposite of a weighted pull-up, so unusable for standards). Fix: add a bodyweight **`Pull-Up`**
  exercise to `assets/data/exercise_library.json` (category bodyweight, `loadingMode` bodyweight /
  bodyweightAdded so a weighted pull-up logs bodyweight + added plate; primary lats, secondary biceps).
  Because seeding is `InsertMode.insertOrIgnore` (reaches NEW installs only), ALSO ship a one-time
  idempotent backfill insert for existing installs (guard with an `app_settings` flag, per the backfill
  lesson). Standards for the pull-up use total resisted mass = **bodyweight + added load**, not just the
  plate. (Alternative if you'd rather not touch the seed: drop to FIVE benchmark lifts for v1 and omit
  the pull-up — but the decided default is to ADD the Pull-Up.)
- **UI**: Standards section lists each benchmark lift the user has actually logged (hide the rest),
  showing level + progress to next. If `userSex == unset` or no bodyweight → an "Enable strength
  standards" prompt that captures sex (and bodyweight if missing). Settings: add an optional **Sex**
  field near the existing bodyweight section. Age is intentionally excluded (v1).
- **Note**: standards are per-LIFT (big compounds only) — they do NOT produce a per-muscle rank. Keep
  them clearly separate from the self-relative muscle ranks; never blend the two numbers.

### E. Rank-up + PR celebration moments (light)
- Detect a muscle rank INCREASE: store last-seen tier per muscle (`app_settings` JSON key
  `lastSeenRanks` or a tiny table) and fire a one-time celebration sheet/toast when it rises. Never on
  a decrease.
- Surface the already-computed `recentPrs` as a live PR moment on session finish (reuse
  `progress_analytics.dart` `recentPrs`; no new math). Keep both lightweight — no coins/XP.

**Acceptance (T2.5)**:
- [ ] Goal profile changes landmarks + rank thresholds + progression + deload together; default `build`.
- [ ] Goal is changeable AT ANY TIME in Settings; changing it live-recomputes landmarks, ranks,
      progression and deload (all derived — no data migration, no history rewrite).
- [ ] Rank reflects RECENT state: neglecting a muscle lowers its rank over time (not locked to best-ever).
- [ ] Rank uses the goal-scaled landmarks — `productiveWeeklyEffectiveSetCap` is gone/unified; the 3D
      color (T2.1) and the rank now agree on "productive volume."
- [ ] Dashboard rank card is tappable and pushes the Ranks page; there is NO new bottom-nav tab.
- [ ] Ranks page lists all 27 muscles with a concrete "how to improve" line each; Progress no longer
      duplicates the rank cards.
- [ ] Strength Standards appears only for logged benchmark lifts once sex + bodyweight are set; sex is
      optional and only used here; Weighted Pull-up includes bodyweight in the load.
- [ ] Rank-up and PR moments fire on real events only; no fake-reward mechanics anywhere.
**Tests**: pure-unit tests for `TrainingGoal` scaling, the new rank score (recency/decay, landmark
adequacy, boundary tiers), `rankExplainer` output, and `standardFor` at each level boundary for both
sexes incl. the Weighted Pull-up bodyweight case. Rank-up detection test (rise fires once, decrease
never). Analyze/test green.

═══════════════════════════════════════════════════════════════════════════════════════════════
# TIER 3 — Program / template import
═══════════════════════════════════════════════════════════════════════════════════════════════

## PHASE T3.1 — Program import (paste / file → Templates)
**Goal**: import a structured program into Templates + TemplateExercises with prescriptions, with an
exercise-name mapping step.
**Schema**: none (writes existing template schema).
**Files**:
- create `lib/features/templates/import/program_parser.dart` (pure): parse a documented CSV shape
  FIRST — columns: `day,exercise,sets,min_reps,max_reps,rest_sec,rpe,notes` (one row per exercise;
  `day` groups into separate Templates). Add optional recognizers for 1–2 named programs (e.g. a
  simple 5/3/1 or PPL text) behind a format enum; keep the parser extensible and total-function
  (return a typed result with per-row errors, never throw on user input).
- create `lib/features/templates/import/import_screen.dart`: paste box or file pick
  (`file_picker`, already a dep), then a MAPPING UI — each parsed exercise name fuzzy-matched to the
  library (case/whitespace-insensitive + simple token overlap); unmatched → "create custom" or pick
  manually. Preview the resulting templates, then commit in a transaction.
- edit `templates_screen.dart`: an "Import program" action.
**Acceptance**:
- [ ] A valid CSV produces the right Templates with per-exercise sets/reps/rest/notes populated.
- [ ] Unmatched exercise names are surfaced for mapping (never silently dropped or mis-mapped).
- [ ] Malformed rows are reported with row numbers; the rest still import (no crash, no partial-commit
      without confirmation).
- [ ] Import is one transaction; failure rolls back cleanly.
**Tests** (Ground Rule 7 — negative cases are mandatory): parser unit tests including malformed rows,
duplicate exercise names, empty cells, and strings that must NOT match a library exercise. Fuzzy-match
tests for near-miss names. Analyze/test green.

---

## Cross-cutting done criteria for this spec
- [ ] `flutter analyze` clean and `flutter test` green after EVERY phase (not just at the end).
- [ ] Any schema touch: version bumped in `app_database.dart` AND `backup_service.dart`, `onUpgrade`
      migration added, a v(old)→v(new) migration test proves existing data is preserved, and backup
      export/import round-trips the new fields.
- [ ] No new network calls, no analytics, no account surface introduced.
- [ ] Each phase committed separately with a `feat:`/`fix:` message; `git diff HEAD` reviewable.
- [ ] Native (T1.1/T1.3) verified on a real backgrounded device on BOTH platforms.

## Smaller wins (not in T1–T3 scope; slot in opportunistically)
PR-celebration moment (reuse `recentPrs`), plate calculator, warm-up set generator, home-screen
widget, Health/Health Connect one-way export.

## Deferred (Tier 5, NOT in this spec)
Optional privacy-preserving sync (encrypted file / self-host / P2P) — opt-in only, never breaks the
local-first/no-account promise. Do not build now.

---

# Active task — Backup format + keyboard + builds (2026-07-23)
User asks, in order:
1. "make new IPA APK with templates" — templates default via LOGGED_SEED_DEFAULT_TEMPLATES=true.
2. "when I export something, why does it export two files?" — share_plus iOS appends `text` as a
   SECOND activity item when `files` is also set. Fixed: use `subject` (metadata only), not `text`.
3. "wouldn't it be better to have another format?" — Q&A locked: zip the JSON (.json still imports)
   + add CSV set-history (export-only). Added `archive` dep.
4. "no processing screen telling the user to wait" — added blocking `_withProgress` spinner around
   export / CSV / import in Settings.
5. "keyboard on edit set won't hide, can't press Save" — ROOT CAUSE: iOS numeric keypad has no
   return key; nothing unfocused on tap-outside. Fixed: onTapOutside unfocus on every field +
   ScrollViewKeyboardDismissBehavior.onDrag.

- [x] Export → zip (package:archive), ~80-90% smaller, one file
- [x] Import accepts .zip AND .json (magic-byte sniff, not just extension); old backups still load
- [x] CSV set-history export (RFC-4180 quoted, per-hand/each-side flattened into volume_kg)
- [x] share_plus two-files fix (subject, not text)
- [x] Settings: CSV tile + progress spinners + corrected .zip/.json copy
- [x] Keyboard dismiss: onTapOutside unfocus + onDrag
- [x] archive 4.0.9 API verified (encode→List<int> non-null, content→Uint8List auto-decompress)
- [x] flutter analyze clean + 88 tests green (added CSV volume/quoting test)
- [x] APK (release, with templates) → dist/logged-1.0.0-zip-export-keyboard-fix.apk (93.9MB)
- [x] IPA (release, unsigned, with templates) → dist/logged-1.0.0-zip-export-keyboard-fix-unsigned.ipa
      (24.4MB). First attempt FAILED (sandbox blocked github.com for sqlite3 native-asset dylib);
      rebuilt with sandbox disabled. Verified objective_c + sqlite3 frameworks present, fresh mtime.
- [x] Templates confirmed in both: flag defaults true, 6 templates seed at runtime, asset bundled
- [x] Codex Mode B review → 3 findings, all verified real, all fixed:
      - Med: import only caught FormatException; a corrupt/encrypted .zip threw an ArchiveException
        that escaped as an uncaught async error. Fixed: `_decodeBackup` normalises any failure to
        FormatException so the settings snackbar handles it.
      - Med: CSV formula injection via user-entered exercise names (=/+/-/@). Fixed: leading `'`.
      - Low: `\r` missing from the CSV quote regex. Fixed.
      - Codex confirmed NO bug in the archive encode path and NO stuck/double-pop in `_withProgress`.
- [x] Regression test for formula injection; 89 tests green, analyze clean
- [x] REBUILT APK (93.9MB) + IPA (24.4MB) with the 3 hardening fixes; verified App.framework mtime
      current and native frameworks bundled. Both in dist/ as logged-1.0.0-zip-export-keyboard-fix*.

# Active task — Session + set-editor UI/UX pass (2026-07-22)
User: "both these screens can be better in relation to UI and UX", + "why do we have
two options for each side / each hand". Decisions locked via Q&A:
compact stepper table; set-number chip = derived status (NO schema change), `⋯` = details.

Diagnosis (root causes, not symptoms):
- `set_row.dart:221` — each `_StepperField` is ~172px (two 48px IconButtons + text +
  suffix); two cannot fit in ~337px so the `Wrap` breaks every set onto 2 lines → 215px/set.
- `set_row.dart:291` — a ✓ that opens the edit sheet. In every tracker ✓ means "set done".
- `set_editor_sheet.dart:196` — 4-way SegmentedButton has no room → "Weig/ht" wraps mid-word.
- Sheet renders Duration+Distance for a barbell squat (meaningless), 11 flat controls, no grouping.
- "Per hand" (weight ×2) and "Each side" (reps ×2) are orthogonal but read as synonyms and sit
  in unrelated groups 400px apart → the user's confusion. Fix = attach each to the field it
  modifies + live plain-English echo. NOT a redundancy; both are needed.

- [x] `setFieldsFor()` single source of truth so header labels and row fields cannot desync
- [x] Rewrite `SetRow` compact: 32px chip + flex steppers + `⋯`, one line (measured 46pt/set vs ~215pt)
- [x] `_MicroStepper` (30x38 hit target) replaces IconButton to fit the width budget
- [x] `SetTableHeader` widget: column labels carry unit / "per hand" / "each side"
- [x] Per-row deviation line when a set differs from the header (loadingMode/weightEntry/sideCount/unit)
- [x] Set chip fills primaryContainer when complete (derived, as `_isComplete` today)
- [x] Rebuild `SetEditorSheet`: category-aware fields, grouped sections, chips not SegmentedButton
- [x] Relabel: "Per hand (×2)" under weight w/ echo; "Each side (×2)" under reps w/ echo
- [x] Theme segmented/choice selection → primaryContainer (terracotta), drop clashing sage
- [x] `flutter analyze` clean + `flutter test` green (87 tests, up from 67)
- [x] Codex Mode B review → 4 findings, ALL verified real against source, all fixed:
      - High: `Plank` is bodyweight+90s/zero-rep → hiding duration made hold time unloggable.
        Fixed with `isTimedExercise()`; columns/sheet now data-driven, not category-driven.
      - High: hiding loading modes for `external` exercises broke assisted/added on strength lifts.
        Fixed: picker shows for all lifting categories.
      - Med: unit hoisted to the header hid per-set unit mismatches (critical — mixed-unit gym).
        Fixed: rows flag "in lb" when they differ from the heading.
      - Med: `Row` for the action buttons could overflow at large text scale. Restored `Wrap`.
- [x] Regression tests added for all four (timed holds, unit mismatch, loading modes, isTimedExercise)
- [x] Verified layout via widget tests at 402pt + 320pt; goldens inspected then deleted (machine-specific)

# Active task — Set logging UX + per-side load (2026-07-21)
Full spec: `tasks/spec-set-logging.md`. Decisions locked with user via Q&A.
- [x] Schema v6: Exercises.weightEntry, SetEntries.weightEntry+sideCount, sidesPerSet on template/session exercises
- [x] `WeightEntry {total, perSide}` enum + `totalLoadKg` helper
- [x] Volume/muscle-load double for perSide; 1RM + charts stay per-hand (deliberate split)
- [x] Analytics queries + WorkoutSetRecord carry weight_entry / side_count
- [x] `SessionRepository.seedForNextSet` cascade: this session -> prescription -> last session
- [x] Inline set rows w/ steppers + Repeat set; modal demoted to "More" (RPE/notes/warmup/mode)
- [x] Split active_session_screen.dart (875 lines) into widgets/
- [x] Seed: sidesPerSet=2 for "/side" entries; weightEntry=perSide for dumbbell lifts
- [x] template_editor_screen: "each side" toggle
- [x] v5->v6 migration test proves existing sets keep identical volume + 1RM
- [x] Reviewed: 4 bugs found+fixed (sideCount clobber, delete-resets-defaults, setNumber collision, disposed controller)
- [x] Baselined entire source in git (89abe3d) — lib/ had never been committed

# Active task — Dashboard + Settings UX/vibe pass (2026-07-20)
- [x] WeeklyProgressStrip widget (M-T-W-T-F-S-S dots, done/goal) → replaces ring
- [x] Floating pill navigation bar in HomeShell
- [x] Dashboard re-layout: weekly strip + balanced Streak/Total cards
- [x] Start workout button: intentional, lifted above floating nav
- [x] Fix "Manage custom exercises" empty-state 4px overflow + polish sheet
- [x] Polish "Add custom exercise" dialog (chips, header, muscle fields)
- [x] Home verified on sim; Settings modals user-verified (look good)
- [x] Two-tier dock: wide Start pill + clean icon-only nav (underline indicator)
- [x] Removed dead StreakBanner + WeeklyGoalRing widgets
- [x] Moved Streak + Total workouts off Home → History (2x2 bento: streak/total/week/month)
- [x] Promoted _StreakCard → shared StreakCard widget

# Active task — Rest day option in Settings (2026-07-20)
Dashboard already has a today-only "Log rest day" button. Gap: can't mark an
*upcoming* day (e.g. "trained legs hard, can't go tomorrow"), and it's not in Settings.
- [x] Add a "Rest day" section to Settings below Schedule
- [x] Toggle today as a rest day (respects scheduled weekly rest)
- [x] "Mark another day" → date picker (covers tomorrow / any upcoming day)
- [x] List logged manual rest days, each removable
- [x] flutter analyze clean

---

# Logged — Implementation Brief (for Codex)

> This is a **standalone spec**. You (Codex) have no prior conversation context — everything
> needed is below. Build a personal, local-only workout tracker in Flutter for Android + iOS.
> Work top-to-bottom through the Phases. Do NOT ask the user questions unless truly blocked;
> the defaults here are decided. Keep it simple and idiomatic. Verify each phase before moving on.

---

## 0. Context & environment
- **Project dir**: `/Users/palashlalwani/code/active/products/logged` (already contains `.claude/` and `tasks/` only — safe to scaffold into).
- **Installed**: Flutter **3.41.9** stable, Dart **3.11.5**, macOS arm64. `flutter` and `dart` on PATH.
- **App name**: `Logged`  ·  **Bundle/package ID**: `com.palash.logged`  ·  **Platforms**: Android + iOS only.
- **Storage**: 100% local (SQLite). No accounts, no network, no hosting, no analytics.
- **User**: single person, personal use, 2 devices (Android + iOS) synced only via manual JSON export/import.

## 1. Product requirements (confirmed by user)
- Track three workout kinds: **strength**, **cardio**, **bodyweight/calisthenics** — plus **stretching/mobility**.
- **Templates** (e.g. "Push Day") AND **ad-hoc** adding of exercises mid-session.
- **Quick start**: start an active session instantly on arriving at the gym (empty or from a template).
- **No rest timer** (do not build one).
- **Starter exercise library of 200–300 exercises** across all muscle groups (push/pull/legs/core, full body)
  **plus a stretching/mobility section**. User can add/edit/archive custom exercises.
- **Manual export/import** of a full JSON backup (share sheet out, file picker in) to move data between devices.
- Progress views: **PRs**, **charts over time**, **history/calendar**, **volume & totals**.

## 2. Units — CRITICAL behavior (read carefully)
The user's gym mixes units: some machines/dumbbells are in **lb** (lat pulldown, seated row, chest fly,
rear delt, some dumbbells), some in **kg** (plate/barbell work, other dumbbells, e.g. 35 kg single-arm row).
He must NOT have to open settings to switch units repeatedly.

Rules:
1. Each `SetEntry` stores the **weight value as entered** + the **unit it was entered in** (`kg` | `lb`). Source of truth.
2. Each `Exercise` has a `defaultUnit`. The active-session logging row shows a **one-tap kg/lb toggle**.
   Tapping it applies to the current set AND **updates that exercise's `defaultUnit`**, so next time it defaults
   correctly (Lat Pulldown stays `lb`, Barbell Row stays `kg`). Set once per exercise, never again.
3. **All progress math is normalized to kg**: `weightKg = (unit == 'lb') ? value * 0.45359237 : value`.
   PRs, charts, and volume are all computed in kg so mixed-unit lifts are comparable. Display keeps the
   entered unit; derive kg on the fly for aggregation (avoid lossy kg→lb→kg round trips in display).
4. Global fallback `defaultUnit` for brand-new/custom exercises = **kg** (per-exercise value overrides after first log).
5. Charts/PR labels show **kg** (this is the normalized progress unit). History rows show the entered value+unit.

## 3. Tech stack (use these — do not substitute)
- **Flutter/Dart** (single codebase, Android + iOS).
- **drift** (SQLite ORM) + `drift_flutter` (or `sqlite3_flutter_libs` + `path_provider`) + `drift_dev`/`build_runner` for codegen. Type-safe reactive queries; clean aggregations for PR/volume/charts.
- **flutter_riverpod** (state management; pairs with Drift streams). Use `Notifier`/`AsyncNotifier` style.
- **fl_chart** (progress charts).
- **share_plus** + **file_picker** + `path_provider` (export/import JSON backup).
- **intl** (date formatting), **collection** (utilities).
- Theme: Material 3, clean, light/dark following system. Choose a single seed color (e.g. indigo/teal). App name shown as "Logged".
- Keep files small (200–400 lines, 800 max), feature-organized. Immutable models, explicit error handling.

## 4. Data model (Drift tables)
- `Exercises`: id (PK), name, category (enum: strength|cardio|bodyweight|stretching), muscleGroup (text/enum),
  defaultUnit (enum: kg|lb), isCustom (bool), isArchived (bool), createdAt.
- `Templates`: id, name, position, createdAt.
- `TemplateExercises`: id, templateId (FK), exerciseId (FK), position.
- `Sessions`: id, startedAt, endedAt (nullable), templateId (nullable FK), notes (nullable).
- `SessionExercises`: id, sessionId (FK), exerciseId (FK), position.  ← enables ad-hoc adds within a session.
- `SetEntries`: id, sessionExerciseId (FK), setNumber, reps (nullable int), weightValue (nullable double),
  unit (nullable enum kg|lb), distanceMeters (nullable double), durationSec (nullable int),
  isWarmup (bool default false), notes (nullable).
  - **strength**: reps + weightValue + unit
  - **cardio**: distanceMeters + durationSec (weight null)
  - **bodyweight**: reps (+ optional weightValue for weighted variants, + optional durationSec for holds)
  - **stretching**: durationSec (+ optional reps/side)
- Add appropriate indexes (sessionExerciseId, exerciseId, session startedAt).
- Provide DB migration scaffolding (schemaVersion=1) so future changes are easy.

### Derived progress (compute in queries/repositories, kg-normalized)
- **Heaviest set** per exercise = max weightKg.
- **Estimated 1RM** (Epley) = `weightKg * (1 + reps/30)`; track best.
- **Best reps** at any weight.
- **Session volume** = Σ (weightKg * reps) for strength/weighted sets.
- **Weekly volume/totals**, training streaks, days trained.

## 5. Screens
1. **Dashboard**: current training streak, recent sessions list, prominent **Start Workout** (choose empty or a template).
2. **Templates**: list + editor — name it, add/reorder exercises from the library.
3. **Active session**: fast set logging. Each exercise card lists sets; each set row has reps + weight input
   with an **inline kg/lb toggle** (updates exercise defaultUnit). **+ Add exercise** on the fly. Show last
   session's values as greyed placeholders/auto-fill. Big "Finish" to end session (sets endedAt).
4. **History / Calendar**: calendar or grouped list of training days, streaks; tap a day → session detail (read-only).
5. **Exercise detail**: fl_chart trends (heaviest kg, est-1RM kg, volume over time), **PR badges**, set history.
6. **Settings**: export backup (share_plus), import backup (file_picker), manage/add/edit/archive custom exercises,
   brief note explaining units are per-exercise. (No global unit switch needed; no rest timer.)

## 6. Export / Import (JSON backup)
- **Export**: serialize ALL tables to one JSON object and share via `share_plus`
  (filename e.g. `logged-backup-YYYYMMDD-HHmm.json`).
- **Import**: pick a JSON file (`file_picker`), validate schema/version, then **replace-all** by default
  (wrap in a transaction; confirm with a dialog before wiping current data). Include `appVersion` and
  `schemaVersion` in the payload for forward-compat. Keep the format stable and documented in code.
- JSON top-level shape (guideline):
  `{ "app":"Logged", "schemaVersion":1, "exportedAt":"<iso>", "exercises":[...], "templates":[...],
     "templateExercises":[...], "sessions":[...], "sessionExercises":[...], "setEntries":[...] }`

## 7. Exercise library (seed asset)
- Author a JSON asset at `assets/data/exercise_library.json` with **200–300 exercises**, seeded into the DB
  on first launch (idempotent: only seed if Exercises table empty; do NOT overwrite user edits on later launches).
- Each entry: `{ "name", "category", "muscleGroup", "defaultUnit" }`.
- **Categories**: strength | cardio | bodyweight | stretching.
- **Muscle groups** to cover broadly: chest, back (lats/upper back/lower back), shoulders (front/side/rear delt),
  biceps, triceps, forearms, quads, hamstrings, glutes, calves, core/abs, obliques, traps, neck, full body/olympic,
  cardio, mobility/stretching.
- Distribution guidance: a rich compound + isolation set per muscle group across barbell/dumbbell/machine/cable/
  bodyweight variations; include common cardio (treadmill run/walk, cycling, rowing erg, stair climber, elliptical,
  jump rope, incline walk) and a solid **stretching/mobility** block (hip flexor stretch, hamstring stretch,
  couch stretch, pigeon, thoracic rotation, shoulder dislocates, cat-cow, child's pose, calf stretch, 90/90, etc.).
- **defaultUnit hints** (reflect the user's gym; still per-exercise editable later):
  set **lb** for typical US-plated selectorized machines/cables (lat pulldown, seated cable row, chest fly / pec deck,
  rear delt fly, tricep pushdown, cable machines) and set **kg** for barbell/plate lifts and most free-weight/bodyweight
  work. When unsure, default **kg**.
- Keep names clean and consistent (e.g. "Barbell Bench Press", "Dumbbell Lateral Raise", "Cable Lat Pulldown").

## 8. Phases & acceptance criteria (do in order; verify each)
- [ ] **Phase 0 — Scaffold**
      - Run: `flutter create --org com.palash --project-name logged --platforms=android,ios .`
      - Add all deps (Section 3) to `pubspec.yaml`; `flutter pub get`.
      - Create feature-first folder structure under `lib/` (e.g. `lib/data/`, `lib/features/{dashboard,templates,session,history,exercise,settings}/`, `lib/core/`).
      - `flutter analyze` clean; app boots to a placeholder home. **Verify**: `flutter run` compiles (or `flutter build apk --debug`).
- [ ] **Phase 1 — Data layer**
      - Drift tables (Section 4) + enums + generated code (`dart run build_runner build --delete-conflicting-outputs`).
      - Repositories for exercises/templates/sessions/sets. Unit-normalization helper (`weightKg`).
      - Seed the 200–300 exercise library from the JSON asset on first launch.
      - **Unit tests**: kg/lb conversion, Epley 1RM, volume aggregation, seed idempotency. **Verify**: `flutter test` green.
- [ ] **Phase 2 — Logging flow**
      - Templates CRUD + editor. Start session (empty or from template). Active-session UI with per-set
        **kg/lb toggle** (updates exercise defaultUnit), add-exercise-on-the-fly, last-values auto-fill, finish session.
      - **Verify**: create template → run a session mixing kg & lb exercises → reopen app → data persisted, units remembered.
- [ ] **Phase 3 — Dashboard + History/Calendar**
      - Streaks, recent sessions, calendar/day view → session detail. **Verify**: streak counts and day view correct.
- [ ] **Phase 4 — Progress**
      - Exercise detail charts (fl_chart) for heaviest kg / est-1RM kg / volume; PR badges; weekly volume & totals.
      - **Verify**: PRs and charts reflect logged mixed-unit data correctly (all in kg).
- [ ] **Phase 5 — Export / Import**
      - JSON export via share_plus; import via file_picker with validation + confirm + replace-all transaction.
      - **Verify**: export on device A → import on device B (or simulate) → identical data.
- [ ] **Phase 6 — Polish**
      - Material 3 theming (light/dark), app icon + display name "Logged", empty states, error handling.
      - **Verify**: `flutter analyze` clean, `flutter test` green, debug build runs on a real device/emulator.

## 9. Definition of done
- Builds and runs on Android and iOS from this single codebase; no network usage.
- All 6 screens functional; mixed-unit logging works with per-exercise remembered units; progress normalized to kg.
- 200–300 seeded exercises incl. stretching; custom exercises supported.
- Export/import round-trips full data. `flutter analyze` clean, tests green (target the units/PR/volume logic).
- No rest timer. Simple, readable, feature-organized code.

## 10. Conventions
- Immutable data models; explicit error handling; no silent catches.
- Small focused files; keep business logic in repositories/services, not widgets.
- Commit style (if committing): `feat:`, `fix:`, `refactor:` etc. (Git attribution disabled globally.)

---
See `tasks/lessons.md` for the non-negotiable units rule.

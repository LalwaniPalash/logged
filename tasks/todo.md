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
- [x] Completing a set auto-starts the countdown with the exercise's prescribed rest.
- [x] Notification fires with the app backgrounded on a real device — VERIFIED on a physical iPhone
      2026-07-24 (see the implementation record below). Android shares the identical
      `notification_service` plugin/permission path but was not separately hardware-tested.
- [x] Switching tabs and returning keeps the countdown accurate (provider-held, not rebuilt).
- [x] Permission denial degrades gracefully (in-app timer still works; no crash).
**Tests**: unit-test the controller's tick/skip/adjust math (inject a clock; no real timer);
`flutter analyze` clean, `flutter test` green. Manual device verification per Ground Rule 6.

**Implementation record — completed 2026-07-23 (`7ef47d7`)**
- Added the notification service and native Android/iOS notification configuration, including the
  Android rest-timer channel and runtime permission handling.
- Added a Riverpod-owned, end-time-based rest timer plus the sticky in-session timer bar with
  skip, +15s, −15s, preset, and custom-duration controls.
- Completing a previously incomplete set starts the exercise-specific/default timer; leaving the
  active session cancels its timer. Notification denial only disables the native notification—the
  in-app countdown remains functional.
- Added Settings controls for the default duration and notification preference.
- **Verified:** controller behavior and app integration are covered by automated tests; the final
  Android debug APK and iOS simulator debug builds both succeeded.
- **VERIFIED 2026-07-24 (iOS):** the shared `notification_service` fires a real backgrounded
  notification on device — confirmed via the T1.3 reminder firing at its set time on a physical
  iPhone. The rest-timer notification uses the same plugin/permission path. Android not separately
  re-tested on hardware.

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
- [x] Each exercise in an active session shows its last completed-session numbers; brand-new exercises
      show nothing (no "0 × 0").
- [x] The hint reflects the entered unit/per-hand semantics, not a kg round-trip.
- [x] Purely additive — does not change the seeded/auto-filled input values (that's `seedForNextSet`).
**Tests**: repository test with two sessions (older + current) asserting the correct "last" set is
returned and the current session is excluded. Analyze/test green.

**Implementation record — completed 2026-07-23 (`73f7169`)**
- Added `SessionRepository.lastSetsForExercise`, which selects the newest completed workout and
  excludes the active/incomplete session.
- Active-session loading fetches previous performance alongside session details and renders a
  read-only hint without changing the existing next-set seed values.
- Formatting preserves the originally entered unit and per-hand/each-side semantics rather than
  round-tripping the display value through kilograms.
- **Verified:** repository selection/exclusion and widget rendering are covered by automated tests.

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
- [x] With reminders on and today a training day and not yet trained, a notification is scheduled for
      `reminderTime`; training beforehand cancels it.
- [x] Rest days (scheduled or logged) get no reminder.
- [x] Changing rest weekdays / time reschedules correctly.
**Tests**: unit-test the "should remind on day D?" pure function against rest weekdays + trained set +
logged rest days (mirror the streak module's style). Device-verify one real fire.

**Implementation record — completed 2026-07-23 (`3562259`)**
- Added a pure reminder planner and rolling 28-day one-shot schedule, accounting for configured rest
  weekdays, manually logged rest days, workouts already completed, enablement, and reminder time.
- Reminder schedules resynchronize on app open, reminder/schedule changes, rest-day changes, and
  workout completion. Permission denial is handled without blocking the app.
- Added the Reminders Settings section with enablement and time selection.
- **Verified:** scheduler decisions and rescheduling inputs are covered by automated tests.
- **VERIFIED 2026-07-24:** a scheduled reminder fired at the set time on a real backgrounded
  iPhone (iOS). Android not separately re-tested but uses the same `notification_service` path.

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
- [x] First launch shows onboarding once; subsequent launches go straight to HomeShell.
- [x] Every major empty screen has a one-tap primary action.
- [x] Flag failure / read error falls back to HomeShell without crashing.
**Tests**: widget test that onboarding shows when flag unset and is skipped when set. Analyze/test green.

**Implementation record — completed 2026-07-23 (`1632ace`)**
- Added a four-page first-run flow, Skip/Get started persistence, and a non-blocking root gate that
  safely falls back to the home shell if the onboarding flag cannot be read.
- Added a shared start-workout flow and actionable empty states across Dashboard, Templates, History,
  and Progress. The onboarding goal choice was subsequently integrated by T2.5.
- **Verified:** first-run, subsequent-launch, skip, and failure-fallback paths are covered by widget
  tests.

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
- [x] Rename works from both the templates list and inside the editor; persists.
- [x] Delete confirms, removes the template + its exercises, but historical sessions that used it stay
      intact (their `templateId` goes null, the session and its logged sets remain).
- [x] Duplicate produces an independent copy carrying ALL prescription fields.
- [x] Reorder persists across app restarts (position column).
**Tests**: repository tests for rename/delete/duplicate/reorder + a test proving deleting a template
does NOT delete or corrupt a historical session that referenced it. Analyze/test green.

**Implementation record — completed 2026-07-23 (`1418479`)**
- Added transactional repository operations for rename, delete, duplicate, and persisted reorder,
  with list-row actions, confirmation UI, drag-to-reorder, and editor-title rename.
- Delete first clears matching nullable `Sessions.templateId` references, preserving historical
  sessions and logged sets. Duplicate copies every prescription field into an independent template.
- **Verified:** repository tests cover all four operations, complete-field duplication, persisted
  ordering, and historical-session preservation after deletion.

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
- [x] A muscle at 4 effective sets vs MEV 8 renders in the "below" color and reads "below MEV".
- [x] A muscle inside its MAV band reads "optimal"; above MRV reads "overreaching / recovery risk"
      (never "junk volume").
- [x] Numbers shown are effective sets (primary 1.0 + secondary 0.35), matching the existing model.
- [x] Removing/adding a set this week moves the color/zone live (it flows through `liveMuscleStateProvider`).
- [x] Default landmarks are overridable via the `app_settings` JSON read path (defaults when unset).
**Tests**: unit-test `zoneFor` at every boundary (below/at MEV, mid-MAV, at MRV, above) and
`coachingIntensity` monotonicity; a golden-ish test that a known weekly set count maps to the expected
zone per muscle. Analyze/test green.

**Implementation record — completed 2026-07-23 (`e69814b`)**
- Added the default 27-muscle volume-landmark table, goal-scaled landmarks, validated JSON overrides,
  zone classification, coaching intensity, and consistent zone colors.
- The live 3D muscle state and Weekly Muscle Balance use the same effective-set calculation; tapping
  a muscle exposes its current volume, landmark band, and coaching copy.
- Added the training-goal Settings control used by the coaching stack.
- **Verified:** boundary behavior, monotonic intensity, override fallback, and known-volume mappings
  are covered by automated tests.

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
- [x] Hitting the top of the rep range at/under target RPE proposes +1 increment and rep reset.
- [x] A missed or high-RPE session proposes a hold, not an increase.
- [x] Dumbbell/`perSide` exercises suggest per-hand values consistent with how they're logged.
- [x] No template rep range/RPE → falls back to "match last time" (no crash, sensible default).
**Tests**: table-driven unit tests over the rule matrix (hit/miss/borderline × kg/lb × total/perSide).
Analyze/test green.

**Implementation record — completed 2026-07-23 (`66ef61f`)**
- Added the pure double-progression engine with unit-aware 2.5 kg/5 lb increments, rep-range logic,
  high-RPE holds, prescription-free fallback, and goal-based aggressiveness.
- Suggestions operate on the entered value for per-side loads and appear as an optional set-row action
  that fills the editor without saving or completing the set.
- **Verified:** table-driven tests cover hit/miss/borderline cases, kg/lb, total/per-side entries,
  RPE handling, and missing prescriptions.

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
- [x] With <2 signals, no card. With ≥2, a dismissible card appears with the specific reasons.
- [x] "Generate deload week" produces a valid Template (opens in the template editor for review; does
      not silently alter the user's program).
- [x] Dismiss persists for the current week (store a `deloadDismissedWeek` `app_settings` key).
**Tests**: unit-test the signal logic (0/1/2/3 signals) and the deload-template generation. Analyze/test green.

**Implementation record — completed 2026-07-23 (`a096ae6`)**
- Added pure two-of-three fatigue detection using consecutive above-MRV weeks, stalled/declining
  estimated 1RM, and rising RPE at equal load, with repository aggregation for the required history.
- Added the dismissible Progress card and current-week dismissal persistence.
- “Generate deload week” transactionally creates a reviewable template with roughly half the working
  sets, preserves the exercise structure, and opens it in the template editor without changing the
  active program.
- **Verified:** 0/1/2/3-signal behavior, dismissal, aggregation, and deload-template generation are
  covered by automated tests.

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
- [x] Tapping a muscle (e.g. from the below-MEV balance card) offers exercises that train it, primary
      first; adding one inserts it into the current session/template.
- [x] Swap replaces an exercise while preserving its prescription slot where sensible.
- [x] Archived exercises are excluded; custom exercises with muscle metadata are included.
**Tests**: repository test that the reverse index maps a known exercise to the right muscles with
correct primary/secondary ranking. Analyze/test green.

**Implementation record — completed 2026-07-23 (`18d3dd5`)**
- Added a reverse muscle→exercise index that excludes archived exercises, includes custom exercises
  with muscle metadata, ranks primary before secondary matches, and uses training frequency as a
  tie-breaker.
- Added build/add entry points from muscle detail, muscle balance, active sessions, and template
  editing, all reusing the filtered exercise picker.
- Session/template swaps preserve the prescription slot. Session swaps explicitly confirm removal of
  incompatible logged sets before replacement.
- **Verified:** index membership/ranking, archived/custom handling, add flows, prescription
  preservation, and swap safety are covered by automated tests.

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
- [x] Goal profile changes landmarks + rank thresholds + progression + deload together; default `build`.
- [x] Goal is changeable AT ANY TIME in Settings; changing it live-recomputes landmarks, ranks,
      progression and deload (all derived — no data migration, no history rewrite).
- [x] Rank reflects RECENT state: neglecting a muscle lowers its rank over time (not locked to best-ever).
- [x] Rank uses the goal-scaled landmarks — `productiveWeeklyEffectiveSetCap` is gone/unified; the 3D
      color (T2.1) and the rank now agree on "productive volume."
- [x] Dashboard rank card is tappable and pushes the Ranks page; there is NO new bottom-nav tab.
- [x] Ranks page lists all 27 muscles with a concrete "how to improve" line each; Progress no longer
      duplicates the rank cards.
- [x] Strength Standards appears only for logged benchmark lifts once sex + bodyweight are set; sex is
      optional and only used here; Weighted Pull-up includes bodyweight in the load.
- [x] Rank-up and PR moments fire on real events only; no fake-reward mechanics anywhere.
**Tests**: pure-unit tests for `TrainingGoal` scaling, the new rank score (recency/decay, landmark
adequacy, boundary tiers), `rankExplainer` output, and `standardFor` at each level boundary for both
sexes incl. the Weighted Pull-up bodyweight case. Rank-up detection test (rise fires once, decrease
never). Analyze/test green.

**Implementation record — completed 2026-07-23 (`46fef11`)**
- Replaced the best-ever/flat-cap rank with recent strength trend, goal-scaled productive volume, and
  consistency/recency components with decay. Existing ranks intentionally recompute and may shift.
- Added Maintain/Build/Push across onboarding and Settings; the selected goal consistently scales
  landmarks, rank thresholds, progression behavior, and deload sensitivity.
- Added the Dashboard-linked Ranks screen with all 27 muscles, progress-to-next-tier, concrete
  explainers, and no additional bottom-navigation tab; duplicate rank cards were removed from Progress.
- Added opt-in, sex-specific strength standards using the latest bodyweight for the six benchmark
  lifts. Added the `Pull-Up` seed and idempotent existing-install backfill; weighted pull-up standards
  use bodyweight plus added load.
- Added one-time real rank-up celebrations and session-finish PR moments.
- **Verified:** goal scaling, rank boundaries/decay/explainers, both-sex standard boundaries,
  weighted pull-up math, event deduplication, and seed backfill are covered by automated tests.

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
- [x] A valid CSV produces the right Templates with per-exercise sets/reps/rest/notes populated.
- [x] Unmatched exercise names are surfaced for mapping (never silently dropped or mis-mapped).
- [x] Malformed rows are reported with row numbers; the rest still import (no crash, no partial-commit
      without confirmation).
- [x] Import is one transaction; failure rolls back cleanly.
**Tests** (Ground Rule 7 — negative cases are mandatory): parser unit tests including malformed rows,
duplicate exercise names, empty cells, and strings that must NOT match a library exercise. Fuzzy-match
tests for near-miss names. Analyze/test green.

**Implementation record — completed 2026-07-23 (`978b92f`)**
- Added a total-function CSV parser with documented columns, quoted-cell support, row-numbered errors,
  and partial valid results that remain reviewable instead of crashing or silently committing.
- Added conservative exact/normalized/token exercise matching plus explicit manual mapping and custom
  exercise creation for unresolved names.
- Added paste/file input, mapping, preview, and a single transactional repository commit. Because the
  existing prescription schema has no RPE column, imported RPE is retained in prescription notes.
- **Verified:** malformed rows, duplicate names, empty cells, non-matches, near matches, mapping,
  successful import, and transaction rollback are covered by automated tests.

---

## Cross-cutting done criteria for this spec
- [x] `flutter analyze` clean and `flutter test` green after EVERY phase (not just at the end).
- [x] Any schema touch: version bumped in `app_database.dart` AND `backup_service.dart`, `onUpgrade`
      migration added, a v(old)→v(new) migration test proves existing data is preserved, and backup
      export/import round-trips the new fields.
- [x] No new network calls, no analytics, no account surface introduced.
- [x] Each phase committed separately with a `feat:`/`fix:` message; `git diff HEAD` reviewable.
- [x] Native (T1.1/T1.3) verified on a real backgrounded device — reminder fired on a physical iPhone
      (iOS) 2026-07-24. Android uses the same code path (not separately hardware-tested).

**Final verification record — 2026-07-23 (`027fd8d` checklist baseline)**
- `flutter analyze`: clean.
- `flutter test`: 138 tests passing.
- `flutter build apk --debug`: succeeded.
- `flutter build ios --simulator --debug`: succeeded.
- T1–T3 required no database schema-version change; new preferences use the existing
  `app_settings` store, and the Pull-Up addition uses an idempotent data backfill.
- Every implementation phase has its own commit; the hashes are recorded under the corresponding
  phase above. The physical-device background notification check is now VERIFIED on iOS (2026-07-24,
  a reminder fired at its set time on a real backgrounded iPhone); Android shares the code path but
  was not separately hardware-tested.

# Post-T1–T3 Mode-B review fixes — loadingMode propagation (2026-07-23)
Codex reviewed the full T1–T3 diff → 7 findings. Validated each against source: 5 real, 1
by-design (import partial-commit is spec-allowed + errors shown), 1 false positive (Dart's
`String.trim()` DOES strip the U+FEFF BOM — verified empirically). Root cause of all 5 reals: the
new `LoadingMode` (external/bodyweight/bodyweightAdded/bodyweightAssisted) was not threaded through
the systems that consume it. Fixed at the root:
- [x] **F1 (High)** — `exercise_seed_service.dart` now writes `preferredLoadingMode` from the asset
      (was silently defaulting every seeded row to `external`, so fresh-install Pull-Up demanded a
      weight). `exercise_anatomy_service.backfillPullUpOnce` also corrects an existing Pull-Up left on
      `external` by the older seed (one-time, flag-guarded).
- [x] **F6 (High)** — Strength Standards rode `completedSetsProvider` whose SQL has
      `weight_value IS NOT NULL`, dropping strict bodyweight pull-ups. Added `BenchmarkSetRecord` +
      `_benchmarkQuery` + `benchmarkSetsProvider` (keeps bodyweight sets) and
      `resistedOneRepMaxKg(bw)` that folds bodyweight in per loading mode; `ranks_screen` uses it.
- [x] **F2 (Med)** — `set_row.dart` `setFieldsFor`/`isSetComplete` gated the weight requirement on
      category; a strength-category bodyweight lift couldn't complete. Now keyed on `loadingMode`.
- [x] **F3 (Med)** — `progression.dart` `suggestNextSet` gained a `loadingMode` param; for assisted
      lifts it treats the least-assisted set as the top set and REMOVES assistance (floored at 0).
      Call site in `active_session_screen.dart` passes the header loading mode.
- [x] **F4 (Low-Med)** — `analytics_repository._deloadQuery` carries `loading_mode`; assisted lifts
      are excluded from the est-1RM stall detector (a falling assistance load is progress, not decline).
- [x] Regression tests: progression assisted matrix (3), seed-loading-mode, backfill-correction,
      set-completion by mode (3), benchmark bodyweight inclusion + assisted-1RM exclusion (DB-backed).
- [x] Codex Mode-B review of the fix diff → 4 real gaps, all fixed: (A) benchmark counted any mode for
      a benchmark-named lift + (B) weighted-mode set with blank load scored as a strict PR → added pure
      `countsForStandard()` gate (canonical mode + real weight required), applied in `ranks_screen`;
      (C) Pull-Up backfill over-corrected a deliberate `bodyweight` choice → now only heals the exact
      legacy `external` value; (D) progression reused cross-mode history → filters history to the same
      `loadingMode`. Tests added for each.
- [x] `flutter analyze` clean · **153 tests green** (was 138).

# Feature — Per-exercise video link + play button (2026-07-23)
User: in an active workout (from template OR ad-hoc added exercises), show a button to play an
exercise's YouTube/demo video, opening in the browser / YouTube app. Implemented (no review, per user):
- [x] Schema v7: nullable `Exercises.videoUrl` (link belongs to the exercise, shows in every workout
      it appears in). Migration `from < 7` addColumn; no backfill (null = no video). v6→v7 migration test.
- [x] Backup: bumped `_schemaVersion`/supported to 7; export/import round-trip videoUrl (toJson/fromJson,
      tolerant of old backups). Round-trip assertion added to backup test.
- [x] `ExerciseRepository.updateVideoUrl(id, url?)`.
- [x] Active session header button: effective link = `sessionExercise.formUrl` (template override) ??
      `exercise.videoUrl`; play button opens externally (LaunchMode.externalApplication — already). No
      link → an "add video" (YouTube icon) button opens a paste dialog saving to the exercise; existing
      link editable via long-press (+ Remove in the dialog).
- [x] Custom-exercise dialog: optional "Video link" field.
- [x] `flutter analyze` clean · **154 tests green**.

# Fix — Dashboard rank hero + Ranks page infinite refresh (2026-07-24, `e126dd0`)
User: the home-screen Body Rank widget flickered foundation<->bronze endlessly; the Ranks page also
refreshed constantly. Same root cause (one self-triggering loop, not two):
- `ref.listen(muscleProgressProvider)` → `_handleRankUpdates` wrote `lastSeenRanks` into `app_settings`
  on EVERY emission; `watchCoachingPreferences()` watches that whole table → re-emitted coaching prefs
  → recomputed `muscleProgress` → fired the listener again. `bodyProgressSummary` cycled
  null('Foundation') <-> data('Bronze'). The Ranks page churned because the Dashboard listener stays
  mounted under the pushed route and the page consumes the same providers.
- [x] Guard the write: only persist `lastSeenRanks` when `!mapEquals(previous, current)` — breaks the loop.
- [x] Harden: value equality on `CoachingPreferences` + `.distinct()` on its watch stream, so writes to
      UNRELATED `app_settings` keys never recompute the coaching/rank chain.
- [x] Regression tests (coaching prefs ignore unrelated writes, emit on real change) · analyze clean · 156 green.
- Note: `mapEquals` needed an explicit `import 'package:flutter/foundation.dart'`.

# Feature — Rest timer auto-start toggle (2026-07-24, `95dbd38`)
User: some people log their sets after training rather than resting in-app, so an auto-starting
countdown on every completed set is noise for them.
- [x] Settings "Auto-start rest timer" toggle, default ON (the previous, standard behavior).
- [x] When off, completing a set no longer starts the countdown bar, and the default-rest +
      notification controls collapse since they no longer apply.
- [x] Stored as a new `app_settings` key — no schema change; the existing `app_settings` export
      carries it through backup automatically.
- [x] `flutter analyze` clean · **157 tests green**.
- [x] Release builds: `dist/logged-1.0.0-rest-timer-toggle.apk` (97MB) +
      `...-rest-timer-toggle-unsigned.ipa` (24MB).

# Current state (2026-07-26, end of day)
Branch `feat/set-editor-backup-ux`, nothing pushed anywhere — **no git remote is connected at all**,
so every commit is local-only. `flutter analyze` clean, **193 tests green**. Release APK + release
xcarchive both build. Platform floors are Android `minSdk` 26 / iOS 14.0.

Hardware-verified on Android (2026-07-26, user's phone):
- All three home-screen widgets add and render.
- Reminder notifications arrive backgrounded — so notifications are now verified on BOTH platforms
  (iOS 2026-07-24). This closes the "Android shares the code path but is untested" caveat.
- Health Connect is **not available on that device**, so Android Health export remains untested.
  The service already handles this: `isHealthConnectAvailable()` is checked up front and the user
  gets "Health Connect is not available on this device." rather than a silent failure. Health Connect
  is built into Android 14+; on Android 8–13 it is a separate Play Store app.

Still hardware-unverified: Apple Health export (never written a real workout), and the iOS widgets
(iOS is build-verified only — all three kinds are in the appex binary, but none has been placed).

The seven unticked boxes under "Phases & acceptance criteria" at the bottom of this file are the
ORIGINAL implementation brief (scaffold → data layer → logging → dashboard → progress → export →
polish). All of it shipped long ago; the boxes were simply never ticked. Do not read them as open
work.

## Release artifacts — 2026-07-26 (`11da0e7`, notification icon + launch screen)
- `dist/logged-1.0.0-notification-icon.apk` (94 MB, release)
- `dist/logged-1.0.0-notification-icon-unsigned.ipa` (27 MB, release, UNSIGNED)
- Fixes the blank grey square in the Android notification shade, which had TWO causes: an opaque
  launcher icon used as a small icon (alpha-only rendering), and the replacement vector then being
  stripped from the release APK by the resource shrinker because it is named only at runtime. See
  `tasks/lessons.md` — the second one is the dangerous class, since debug builds do not shrink.
- Verified in the shipped APK: `aapt2 dump resources` finds `drawable/ic_stat_logged`, and
  `aapt2 dump xmltree` shows all six paths intact.
- Verified in the shipped IPA: `assetutil --info` reports LaunchImage renditions at 120/240/360 px
  (they were 1x1 placeholders), and the archive build no longer emits Flutter's placeholder
  launch-image warning.
- Still open here: `ios/LoggedWidget/README.md` remains in the extension's Copy Bundle Resources.
  Removing it needs a `project.pbxproj` edit, deliberately not attempted from the CLI.
- `dist/logged-1.0.0-notification-icon-nowidget-unsigned.ipa` — same build with `PlugIns/` removed.

### Sideloading rejects the widget extension (2026-07-26)
Installing the normal IPA fails with `AppexBundleMissingClassOrStoryboard`: installd says the appex
defines neither `NSExtensionMainStoryboard` nor `NSExtensionPrincipalClass`. **This is not a defect
in our build.** Apple's own Xcode 26 Widget Extension template
(`…/Templates/Project Templates/MultiPlatform/Application Extension/Widget Extension.xctemplate/
TemplateInfo.plist`) generates an `NSExtension` dict containing ONLY
`NSExtensionPointIdentifier = com.apple.widgetkit-extension`, which is byte-for-key what the shipped
appex contains — a SwiftUI `@main` WidgetBundle has no ObjC principal class to name, so adding one
would be a fabrication, not a fix.

The rejection comes from the sideload/re-sign path, which rewrites bundle IDs (the error shows
`com.palash.logged.KDZBF8D2X2.LoggedWidget`, not our `com.palash.logged.LoggedWidget`). Options:
- **Sideloadly's own answer is to tick "Remove plugins"** (their support forum, thread 166824), which
  strips the appex — identical in effect to the `-nowidget-` IPA. Also uninstall the app from the
  phone first; a stale appex from a previous install reproduces the same error.
- **Install from Xcode** (device selected, signed with the Apple ID) — the only path that installs
  the extension properly, so it is the one that keeps iOS widgets.

**RESOLVED — add `NSExtensionPrincipalClass` (`ios/LoggedWidget/Info.plist`).** Apple Developer
Forums 734428 describes this as a catch-22: the key is required for installation but rejected by
App Store Connect as "unexpected". Logged is local-only and never submitted, so only the first half
applies — the key is now set to `$(PRODUCT_MODULE_NAME).LoggedWidgetBundle`, which builds out to
`LoggedWidgetExtension.LoggedWidgetBundle`, verified inside the shipped IPA. **Remove this key if
the app is ever submitted to the App Store.** WidgetKit enters via the `@main` attribute rather than
instantiating the named class, so the value only has to exist.

What was ruled out before landing there: not an OS-version issue (reproduced on iOS 26.5, so the
iOS-14-only reading of that thread was wrong), not a stale install (uninstalling first changed
nothing), and not a malformed build (Xcode 26.4's own template generates exactly the plist we had).
Artifact: `dist/logged-1.0.0-widget-sideload-fix-unsigned.ipa`. Not yet confirmed installed on
hardware at the time of writing.

If the Xcode route is used instead, note that the widget needs the `group.com.palash.logged` App
Group to read any data, and App Groups is not available to free personal-team provisioning — on a
free Apple ID Xcode will refuse to build with a "profile doesn't support the App Groups capability"
error. That is an account-tier limit, not a code problem.

Note also that even a successfully installed extension needs the App Group entitlement to show real
data; personal-team provisioning may not grant it, in which case the widget renders its placeholders
forever — the symptom already documented in `ios/LoggedWidget/README.md`.

## The sideloaded build was entirely data-dead — simulator dylibs (2026-07-26, second session)
User report after sideloading `widget-sideload-fix`: backup import did nothing, the muscle sculpture
span forever, and the iOS widget was absent from the gallery. The first two were ONE fault, and it had
nothing to do with either feature.

**Root cause: the IPA shipped `IOSSIMULATOR` native-asset dylibs.**
`vtool -show-build` on the shipped frameworks:

| dylib | last known-good IPA (24 Jul) | shipped 26 Jul |
|---|---|---|
| `objective_c` | `platform IOS`, arm64, 198 KB | `platform IOSSIMULATOR`, x86_64+arm64, 394 KB |
| `sqlite3` | `platform IOS`, arm64, 1.7 MB | `platform IOSSIMULATOR`, x86_64+arm64, 3.5 MB |

A simulator dylib cannot `dlopen` on a device, so `path_provider_foundation` died,
`getApplicationDocumentsDirectory()` threw, and drift never got a path — **`logged.sqlite` was never
created**. Confirmed on hardware: the app's `Documents/` container is empty. Hence no seeded exercise
library, no templates, workouts un-startable, `replaceFromPayload` never completing (so import looked
like a no-op rather than an error), and every Drift `.watch()` stuck in `loading` — which is the
`liveMuscleStateProvider` spinner that reads as "the sculpture won't load". The 3D model and the
backup code were never at fault.

Poison source: `build/native_assets/ios/` is a SINGLE directory with no per-platform separation.
`flutter build ios --simulator --debug`, run as a verification step at 11:14, wrote simulator dylibs
there and the release archive copied them in verbatim. `build/ios/iphoneos/` still held correct `IOS`
dylibs from an earlier device build, which is why this worked until now.

Fixed by a full `flutter clean` rebuild with NO simulator build afterwards, plus a hard verification
gate before packaging (`vtool -show-build` must report `IOS`; `lipo -archs` must not list x86_64).
Earlier release checks only asserted the frameworks were *bundled*, never which platform they were
built for — see `tasks/lessons.md`.

### Why the widget was invisible (separate, real bug)
Extensions were NOT being stripped (Sideloadly's "Remove app extensions" is unchecked, confirmed with
the user), so the appex was installed. The cause was the install fix itself:
`NSExtensionPrincipalClass` named `LoggedWidgetBundle`, a SwiftUI **struct**, which has no
Objective-C class metadata, so `NSClassFromString` returns nil. installd only checks the key is
PRESENT (install succeeded); WidgetKit resolves it when probing the appex to enumerate kinds for the
gallery, got nil, and offered no widgets. The claim recorded above — "the value only has to exist" —
was wrong. Now points at a real `@objc(LoggedWidgetPrincipal) final class … : NSObject` declared in
`ios/LoggedWidget/LoggedWidgetBundle.swift` solely to be named; `@main` still drives WidgetKit.

**Still blocked by account tier, not code:** the user's Apple ID is a free personal team, which cannot
provision App Groups, so `group.com.palash.logged` is not granted and the widget cannot read workout
data even once visible. Expect it to appear in the gallery and render placeholders. Real widget data
needs a paid Apple Developer account. Android widgets are unaffected and already work.

## Release artifacts — 2026-07-26 (`cbd0296`, widget fix + three variants)
- `dist/logged-1.0.0-widget-variants.apk` (94 MB, release)
- `dist/logged-1.0.0-widget-variants-unsigned.ipa` (27 MB, release, UNSIGNED)
- Fixes the reason the widget could not be added at all on a real phone: the divider in
  `logged_widget.xml` was a bare `<View>`, which `RemoteViews` refuses to inflate, so the launcher
  showed "couldn't add widget" over an empty shell. Reproduced and confirmed fixed with
  `./gradlew :app:lintDebug` (`RemoteViewLayout`) — see `tasks/lessons.md`.
- Adds three pickable variants per platform: `LoggedStreakWidgetProvider` / `LoggedStreakWidget`
  (2x2, small), `LoggedWidgetProvider` / `LoggedWidget` (4x2, medium), `LoggedSummaryWidgetProvider` /
  `LoggedSummaryWidget` (4x4, large). The medium provider class name is unchanged, so widgets already
  placed on a home screen survive the update.
- Verified in the shipped APK (aapt2 dump resources + apkanalyzer manifest): all three receivers,
  all three layouts, and all three `appwidget-provider` configs.
- Verified in the release xcarchive: `LoggedWidgetExtension.appex` at `MinimumOSVersion 14`, with all
  three widget `kind` strings present in the extension binary.
- Still hardware-unverified: the small and large layouts have never been rendered on a device, and
  Health export has still never written a real workout.
- Minor, pre-existing: `ios/LoggedWidget/README.md` is in the extension's Copy Bundle Resources, so
  the internal setup notes ship inside `LoggedWidgetExtension.appex`. Harmless, needs Xcode to fix.

## Release artifacts — 2026-07-26 (`23c950a`)
- `dist/logged-1.0.0-widget-health-export.apk` (98.5 MB, release)
- `dist/logged-1.0.0-widget-health-export-unsigned.ipa` (27.7 MB, release, UNSIGNED)
- Verified in the shipped APK (aapt2 badging + manifest xmltree): `minSdkVersion 26`,
  `android.permission.health.WRITE_EXERCISE`, and the `LoggedWidgetProvider` receiver with its
  `APPWIDGET_UPDATE` filter.
- Verified in the release xcarchive: `LoggedWidgetExtension.appex` embedded at `MinimumOSVersion 14`,
  and `health` / `home_widget` / `sqlite3` / `objective_c` frameworks all bundled.
- **`flutter build ipa --no-codesign` does NOT emit an .ipa** — it logs "Codesigning disabled with
  --no-codesign, skipping IPA" and stops at the xcarchive. The unsigned IPA is packaged by hand:
  copy `Runner.xcarchive/Products/Applications/Runner.app` into a `Payload/` directory and zip it.
- Cosmetic, pre-existing: the iOS launch image is still the default Flutter placeholder.

**Not yet done / next time:** the widget and Health export have NOT been exercised on real hardware —
the widget has never been placed on a home screen, and no workout has actually been written to Apple
Health or Health Connect. Both are build-verified only. The IPA is unsigned (sideload/codesign), and
no git remote is connected.

## Smaller wins (not in T1–T3 scope; slot in opportunistically)
- [x] PR-celebration moment — already shipped in T2.5-E (`46fef11`): session-finish PR dialog reusing
      `recentPrs`, plus one-time rank-up toasts. This backlog line was stale.
- [x] Plate calculator (`297027a`)
- [x] Warm-up set generator (`297027a`)
- [x] Home-screen widget — Android AppWidget + iOS WidgetKit extension (iOS target wired in Xcode
      by the user 2026-07-26)
- [x] Health / Health Connect one-way export — manual, opt-in, workouts only

**The smaller-wins backlog is now empty.** Remaining open items are not features: no git remote is
connected, and the IPA is still unsigned (sideload/codesign).

═══════════════════════════════════════════════════════════════════════════════════════════════
# Active task — Finish the smaller wins (2026-07-25)
═══════════════════════════════════════════════════════════════════════════════════════════════
User: "update todo.md and tick the notification box, then complete the smaller wins."
Scope decided by Q&A (asked once, upfront — the two native items are far bigger than the label):
- Home-screen widget → **Android now, iOS staged**. Ship a real Android AppWidget; write the iOS
  SwiftUI source + step list but do NOT touch `project.pbxproj` (a malformed pbxproj breaks every
  iOS build and the target can't be verified without opening Xcode).
- Health export → **manual, opt-in, workouts only**. Settings toggle + explicit action; no background
  sync, no silent writes.

## SW.0 — Docs (done first)
- [x] Tick the T1.1 backgrounded-notification box with the iOS-verified / Android-not-hardware-tested
      caveat spelled out inline (it was already verified; the box just never got ticked).
- [x] Record `95dbd38` (rest-timer auto-start toggle) as its own section.
- [x] Refresh "Current state" to 2026-07-25 / 4 unpushed commits / 157 tests / rest-timer-toggle builds.
- [x] Correct the stale "PR-celebration moment" backlog line — it shipped in `46fef11`.

## SW.1 — Plate calculator
**Domain** `lib/core/domain/plate_math.dart` (pure, no Flutter imports):
- `PlateInventory` — bar weight + available plate sizes (kg and lb lists) + optional pair counts.
  Defaults: kg bar 20, plates 25/20/15/10/5/2.5/1.25; lb bar 45, plates 45/35/25/10/5/2.5.
- `PlateSolution` — per-side stack, achieved total, residual (what could NOT be loaded).
- Greedy largest-first per side, respecting pair counts; exact-match preferred, otherwise the closest
  achievable UNDER target with the shortfall reported. Never silently round up.
- `roundToLoadable(target, inventory)` — snap an arbitrary weight down to the nearest loadable total.
**Persistence**: `plateInventory` JSON in `app_settings` (no schema change; rides the existing
`app_settings` backup export). `SettingsRepository.watch/readPlateInventory` + setter.
**UI**: "Plates" action on the active-session exercise card → bottom sheet with the resolved stack for
the current/target load, an editable target field, and a plain "can't make this exactly, short by X"
line. Settings card for bar weight + which plates you own.
- Only offered for `external` / `bodyweightAdded` loading modes with a real load — a strict
  bodyweight or assisted lift has no plates to compute. Per-hand (`perSide`) entry means dumbbells,
  so the sheet computes a single implement, not a barbell.

## SW.2 — Warm-up set generator
**Domain** `lib/core/domain/warmup.dart` (pure):
- Ramp off the working weight: ~40%×5, ~60%×3, ~80%×2 (empty-bar first when the working load is far
  above the bar). Each rung snapped through `roundToLoadable` so every warm-up is actually loadable —
  this is why SW.1 lands first.
- Returns empty for `bodyweight`/`bodyweightAssisted`, for timed exercises, and when the working load
  is at/below the bar (nothing to ramp).
**Insertion**: warm-ups must precede working sets, so `SetRepository.shiftSetNumbers(...)` renumbers
existing sets up by N before inserting the warm-ups as 1..N with `isWarmup: true`.
(`SetEntries.setNumber` has no unique constraint — verified — so the shift is safe.)
**UI**: "Warm-up" action on the exercise card → preview dialog of the generated rungs → "Add" inserts.

## SW.3 — Home-screen widget (Android now, iOS staged)
- `home_widget` package. `lib/core/services/home_widget_service.dart` pushes streak, sets logged this
  week, and last workout name/date; refreshed on app start and after a session finishes.
- Android: `LoggedWidgetProvider.kt` + `res/layout/logged_widget.xml` + `res/xml/logged_widget_info.xml`
  + manifest receiver. Tapping the widget opens the app.
- iOS: SwiftUI widget source staged under `ios/LoggedWidget/` + a step list in this file. NOT added to
  `project.pbxproj` — that's a manual Xcode step, called out explicitly so it isn't mistaken for done.

## SW.4 — Health / Health Connect export (manual, opt-in, workouts only)
- `health` package. `lib/core/services/health_export_service.dart`: request permission, write each
  completed session as a strength-training workout (type + start/end + duration), and record exported
  session ids in `app_settings` so re-running never double-writes.
- Settings: opt-in toggle + "Export to Health" action tile reusing the existing `_withProgress` spinner.
- Android: Health Connect permissions + rationale activity in the manifest. iOS: HealthKit entitlement
  + `NSHealthShareUsageDescription`/`NSHealthUpdateUsageDescription` strings.
- Still no network and no account — these are on-device stores. The local-first promise holds.

## Verification gate (per Ground Rules — do not report done without these)
- [x] `flutter analyze` clean; `flutter test` green — **186 tests** (baseline was 157).
- [x] `flutter build apk --debug` and `flutter build ios --simulator --debug` both succeed.
- [x] Codex Mode-B review of the full diff; every finding validated against source before acting.

## What I found reviewing the delegated work (Codex reported all of this as done and green)
1. **Plate solver froze the UI.** Exhaustive search with no early exit on an UNLOADABLE target:
   501.3 kg = **4.9s**, 301.9 kg = 147ms — and the sheet re-solves per keystroke. Replaced with a
   reachability DP over hundredths (4929ms → **1ms**, identical answers) + a latency regression test.
   The DP only answers *how much* is loadable; a separate heaviest-first pass lays the stack out,
   because 40 kg a side is both 20+20 and 25+15 and a lifter expects the latter.
2. **Warm-up button could double-log the ramp** — it stayed visible after warm-ups existed. Now hidden
   once the exercise has any warm-up set.
3. **Health export was not idempotent (Mode-B finding, and worse than reported).** The exported-id
   marker was batched to the end of the loop. Proven by temporarily reverting the fix: when a write
   THROWS, the service unwinds into its catch-all and **every** marker for the run is lost
   (`Actual: []`), so a retry re-writes them all as duplicates in Apple Health. Now persisted after
   each write — two stores can't be written atomically, so the order is chosen for the least-bad
   failure (write then mark = risk a duplicate, never a lost workout), and marking per write caps the
   exposure at the single workout in flight. Test added that fails against the old batching.
4. **`skippedCount` was wrong** whenever history was already exported — it counted already-exported
   sessions as skipped and, on the failure path, conflated them with never-attempted ones. Now
   derived from `pending`, so it means "already in the health store".
5. **False alarm, checked and cleared:** the diff *looked* like it overwrote the rank-flicker
   regression test. It was dartfmt rewrapping plus a new analogous test — coverage intact.

## SW.3 / SW.4 iOS wiring — DONE 2026-07-26 (was staged; user completed the Xcode steps)
- Widget Extension target `LoggedWidgetExtension` added in Xcode; App Group
  `group.com.palash.logged` on BOTH Runner and the extension; HealthKit capability on Runner
  (`Runner.entitlements` now actually referenced by `CODE_SIGN_ENTITLEMENTS` — it was inert before).
- `HomeWidget.setAppGroupId` now called in `refresh()`; it was deliberately omitted while the
  entitlement did not exist, because calling it first throws.
- **Two traps hit during that wiring, both worth remembering:**
  - Xcode's Widget Extension template **overwrote the staged `ios/LoggedWidget/LoggedWidget.swift`**
    (5114 → 2596 bytes, losing the app-group read). Restored from the git index. Staging Swift under
    the same filename the template generates is the mistake.
  - `flutter build` then died with `Cycle inside Runner`. Cause: Xcode appends **Embed Foundation
    Extensions** LAST, after Flutter's **Thin Binary** script, which declares no outputs — so Xcode
    assumes it may touch anything in `Runner.app` including `PlugIns/`, and the appex copy both
    depends on and invalidates it. Fix: move Embed Foundation Extensions BEFORE Thin Binary.
  - Xcode also defaulted the extension to **iOS 26.4** minimum deployment (would have silently never
    installed); lowered to 14.0, which is all the widget's APIs need.
- Platform floors raised, confirmed acceptable by the user (all their phones are Android 8+/iOS 14+):
  Android `minSdk` 24 → **26** (forced by `health` 13.3.1 Health Connect), iOS `platform` 13.0 →
  **14.0** (WidgetKit needs 14+ regardless).

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

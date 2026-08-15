# tasks/todo.md — current state

> **Status as of 2026-08-14.** The T1→T3 spec below (2026-07-23) is **shipped and historical** —
> keep it for context on why the architecture looks the way it does, but it is not the active
> work item.

## ACTIVE WORK

**Phases 1–7 are shipped** (Phases 1–6 via commits `1d9c03e`, `8a1a9fd`, `ccdaf4d`, `0be0ba9`,
`874ae26`..`6e10c58`, `6aad644`..`eba9010`; Phase 7 record appended below). **Next is the deferred
end-to-end verification run.** Baseline at the head of Phase 6: `flutter analyze` clean,
`flutter test` **301/301**.

| File | What it is |
|---|---|
| **`tasks/spec-phase7.md`** | **The active implementation spec.** Standalone Phase 7 brief for Codex, grounded at `4206e28`. Start here. |
| `tasks/spec-audit-fixes.md` | The full phased spec, Phases 1–7. Phases 1–6 are done; its Phase 5, 6 and 7 sections are superseded by `spec-phase5.md` / `spec-phase6.md` / `spec-phase7.md`. |
| `tasks/spec-phase6.md` | Standalone Phase 6 brief, grounded at `3f41587`. Done — shipped in `6aad644`..`6477411` plus the review fixes in `eba9010`. |
| `tasks/spec-phase5.md` | Standalone Phase 5 brief, grounded at `0be0ba9`. Done — shipped in `a9075ed`..`6e10c58` plus the review fix `3f41587`. |
| `tasks/audit-2026-08-14.md` | Full audit: 50+ findings across 6 rounds, with evidence and file:line references. The spec's reasoning lives here. |
| `tasks/lessons.md` | Read before touching anything. |
| `tasks/spec-set-logging.md` | Earlier set-logging spec (historical). |

### Remaining phases at a glance

- ~~**Phase 5 — Flutter practice & set-list mechanics.**~~ Done 2026-08-14.
- ~~**Phase 6 — Rest timer: persistent lock-screen countdown.**~~ Done 2026-08-15. Every code item
  landed; **none of its device verification has been run.**
- ~~**Phase 7 — LAST PHASE.**~~ Done 2026-08-15. All seven tasks shipped within
  `tasks/spec-phase7.md`'s stated scope: A5 onboarding training days, I2 `anatomyEditedByUser`
  (**schema v13**), the in-session exercise info/edit sheet, L1/L2/L3 backup fixes, M1/M2 reminder
  backstop, A9 PRs across `weightEntry`, and N1/N3 accessibility + theme. Both open decisions were
  settled by Palash on 2026-08-15: **A5 → ask training days in onboarding** (not inferred),
  **I2 → yes, take v13**. N2, A10, A11, G3, H4 stayed out of scope exactly as the spec required.

### After Phase 7: the deferred verification reckoning

Palash decided on 2026-08-14 to defer all manual and on-device checks until every phase had landed,
then run the application end to end. That debt comes due after Phase 7. What has never touched
hardware, oldest first:

- The Copenhagen Plank check and a real-device restore of a **≤ v11** backup (carried since Phase 3).
- None of Phase 4's manual flow checks.
- None of Phase 5's manual checks.
- **All of Phase 6** — the lock-screen countdown, the flip to "Rest complete" at zero, the
  backgrounded +15s action, the iOS notification-centre pull, and both review fixes that only a
  device can settle (the ring resync after backgrounding, and `timeoutAfter` reaping an orphaned
  `ongoing` notification).

## Where the audit came from

A full-app UX + logic audit on 2026-08-14 against a baseline of `flutter analyze` clean and
`flutter test` 230/230 green. **Every finding survived that green suite.** The audit ran in six
rounds; each later round was prompted by the previous one missing something, which is itself the
main lesson (see `lessons.md` 2026-08-14).

## The five that matter most

1. **G1 — muscle bias halves logged volume.** The set editor persists weights normalised to *sum*
   1.0; the domain reads them as *multipliers* where null means 1.0 **per muscle**. Opening the set
   sheet on a 2-primary exercise halves its credited volume. Using the feature can only ever reduce
   volume, never increase it. Drives rank, MEV/MAV zones, and the deload trigger.
2. **K1 — progression is permanently stalled for anyone who does not log RPE.** `increaseAllowed`
   requires `topSet.rpe != null`, so the weight never increases; the fall-through then suggests the
   exact rep count already performed, with the rationale "add one rep toward the top of the range".
3. **F1 — a custom exercise cannot be marked as timed.** User-reported: Copenhagen planks had to be
   logged as 30 reps/side instead of 30 seconds/side. Timed-ness is inferred from history, so a new
   exercise can never have any. Every escape hatch (stretching, cardio, CSV import) is a trap.
4. **Deload has never been able to fire.** Of three signals, one needs RPE data that does not exist
   and one compares a *partial* current week against a full-week MRV. Two of three are required.
5. **A1/A2 — weekly volume is wrong in two directions.** `_query` in `analytics_repository.dart`
   has no `is_warmup = 0` filter and excludes `weight_value IS NULL`, so warm-ups inflate the number
   and bodyweight-only sessions read as zero. One query, three surfaces: Progress screen, PR list,
   and the home-screen widget.

## Schema version budget

`schemaVersion` is **10** today. The spec allocates:
- **11** → Phase 1.1 (rescale `muscle_bias_weights` from share to multiplier semantics)
- **12** → Phase 3.1 (`Exercises.isTimed`, `Exercises.tracksDistance`)

Both also bump `_schemaVersion` in `lib/data/services/backup_service.dart` and extend
`_supportedSchemaVersions`. **Do not do these phases out of order.**

---

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
data even once visible. Real widget data needs a paid Apple Developer account. Android widgets are
unaffected and already work.

### CONFIRMED on hardware — the widget is killed at launch by code signing (2026-07-26)
The native-assets fix is **verified working on device**: `Documents/logged.sqlite` now exists (132 KB)
in the app container, and the user confirms the app works. The widget still does not appear, and the
crash logs settle why — the principal-class theory above was NOT the operative cause.

`xcrun devicectl device info files --device <id> --domain-type systemCrashLogs` shows **24
`LoggedWidgetExtension-*.ips` reports and zero for the main app**, beginning at 12:45 PM with the very
first install that contained the appex and continuing after the rebuild (new container UUID). So the
extension has never once launched. Every report:

```
termination : { "namespace" : "CODESIGNING", "indicator" : "Invalid Page" }
exception   : EXC_BAD_ACCESS / SIGKILL / KERN_PROTECTION_FAILURE
codeSigningTrustLevel : 0
reportNotes : dyld_process_snapshot_get_shared_cache failed   (empty usedImages)
```

It dies ~23 ms after launch, before dyld initialises, so no line of our Swift runs — the principal
class is never reached. `bundleInfo.CFBundleIdentifier` is
`com.palash.logged.KDZBF8D2X2.LoggedWidget`, confirming Sideloadly rewrites the nested appex ID
correctly and that "Remove app extensions" is off, so the appex IS installed.

Cause: `ios/LoggedWidgetExtension.entitlements` (live — wired through `CODE_SIGN_ENTITLEMENTS` at three
places in `project.pbxproj`) requests `com.apple.security.application-groups`, which a free personal
team cannot provision. The re-signed appex carries an entitlement its profile cannot back, so the
kernel refuses to map its pages. The host app survives the same signing pass because the tool strips
what it cannot provision there; nested-appex handling is not equivalent.

**Not fixable in this codebase on a free account.** Options, in order of honesty:
1. Accept Android-only widgets (Android's three widgets already work on hardware).
2. Paid Apple Developer account ($99/yr) — provisions App Groups, so the appex signs validly AND can
   read the shared container. The only route to a working iOS widget with real data.
3. Drop the App Group from both entitlements files so the appex can be signed. It would then appear in
   the gallery, but `loadEntry()` has no shared container to read, so it renders
   `LoggedWidgetEntry.placeholder` ("No workouts yet", 0 days / 0 sets / 0 kg) permanently. Cosmetic
   only; not recommended.

Note the same tier limit applies to `com.apple.developer.healthkit` in `Runner.entitlements`, which is
consistent with Apple Health export never having been verified on this device.

### CHECKLIST — when a paid Apple Developer account arrives (decided 2026-07-26: defer, option 1)
Chosen for now: leave iOS widgets broken, keep using Android widgets. This is the list for future-you,
because none of it is obvious months later.

**No code changes are required.** Verified 2026-07-26 that the project is already wired correctly:
`group.com.palash.logged` is byte-identical in all four places that matter
(`ios/Runner/Runner.entitlements`, `ios/LoggedWidgetExtension.entitlements`,
`LoggedWidgetKeys.appGroupId` in `ios/LoggedWidget/LoggedWidget.swift`, and
`HomeWidgetService._iosAppGroupId` in `lib/core/services/home_widget_service.dart`); the appex ID
`com.palash.logged.LoggedWidget` is a correct child of `com.palash.logged`; and
`CODE_SIGN_ENTITLEMENTS` is set for both targets in all six build configs. Do not "fix" any of this.

1. [ ] **Export a backup from Settings BEFORE reinstalling.** This is the step that loses data if
       skipped. The app is currently installed as `com.palash.logged.KDZBF8D2X2` — Sideloadly rewrites
       the bundle ID by appending the team ID — while the project's real ID is `com.palash.logged`.
       Installing from Xcode is therefore a DIFFERENT app with a different container, and the existing
       `Documents/logged.sqlite` will not carry over. Import the backup after installing.
2. [ ] **Register the App Group** `group.com.palash.logged` on the developer portal and enable it for
       BOTH App IDs (`com.palash.logged` and `com.palash.logged.LoggedWidget`). With a paid team and
       automatic signing, ticking the App Groups capability in Xcode does this — but it is a step, not
       zero-touch. This is the entitlement whose absence gets the appex SIGKILLed today.
3. [ ] **Verify the Team ID.** The project hardcodes `DEVELOPMENT_TEAM = KDZBF8D2X2` in six places. If
       enrolling the same Apple ID keeps that Team ID, nothing to do; if it differs, update it (once,
       via Xcode). Note the only signing identity in this Mac's keychain belongs to a DIFFERENT team
       (`ZF8Y28Y8P4`, palashlalwani00@gmail.com), so do not assume the keychain reflects the project.
4. [ ] **`flutter clean` before building.** Non-negotiable — see the simulator-dylib entry in
       `tasks/lessons.md`. Never run a simulator build between the clean and shipping a device build,
       and gate on `vtool -show-build` reporting `platform IOS` for `objective_c` and `sqlite3`.
5. [ ] **Open the app once after installing.** The widget renders from the shared container, which
       `HomeWidgetService.refresh()` populates on launch (called from `main.dart`). Before that first
       run the widget legitimately shows `LoggedWidgetEntry.placeholder`.
6. [ ] **Then finally verify the two things that have never run on real hardware:** place all three iOS
       widgets on a home screen (small/streak, medium, large/summary — none has ever been rendered), and
       write a real workout to Apple Health, which `com.apple.developer.healthkit` also makes
       provisionable for the first time.
7. [ ] **Only if submitting to the App Store / TestFlight:** remove `NSExtensionPrincipalClass` from
       `ios/LoggedWidget/Info.plist`. App Store Connect rejects it as an unexpected key. The reason is
       written beside the key; read that comment before touching it. Not needed for device installs.

Side benefit of going paid: provisioning lasts a year instead of 7 days, so the app stops needing to be
re-sideloaded weekly.

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

# Feature — Custom exercise muscle suggestion + per-set muscle bias + exercise library expansion (2026-08-08, COMPLETED 2026-08-09)

Full plan written to `/Users/palashlalwani/.claude/plans/fluffy-nibbling-russell.md`. Implemented by
codex across three commits: `14b7ed9` (suggest), `d2bb149` (bias v8), `f1ce9a6` (library expansion).
Reviewed manually (codex Mode B hit its usage limit mid-review) against the 5 highest-risk areas:
schema v8 migration + backup version bump, `primarySets` int→double fallout, the bias-weight math in
`lib/core/domain/muscle_bias.dart`, the exercemus dedup, and the both-null-or-both-set axis invariant.
All clean. `flutter analyze` clean, 205 tests green.

- [x] **Part 1 — Local muscle suggestion for custom exercise names.** No network call (app is local-only). New `lib/core/domain/exercise_muscle_suggestion.dart`: keyword-token map mined once from `assets/data/exercise_library.json`, prefills primary/secondary in the Add Custom Exercise dialog (`settings_screen.dart` `_addExercise`) until the user manually touches the picker.
  - **Verify**: add a custom exercise named "Barbell Bench Press" → chest/delts/triceps prefill without touching the picker.

- [x] **Part 2 — Per-set muscle bias (schema v8).** Bias is a **two-different-muscles tradeoff only** (e.g. quads↔glutes on Leg Press stance width) — NOT laterality/unilateral bias (B-stance RDL etc. stay out of scope; confirmed with Palash the 3D model `assets/models/muscular.glb` has 47 fused meshes, no left/right geometry, so a left/right `MuscleId` split would have zero visual payoff on the signature 3D view).
  - `Exercises` gets nullable `biasMuscleA`/`biasMuscleB` (single `MuscleId.id` strings); `SetEntries` gets nullable `muscleBias` (-1..1). Bump `schemaVersion` to 8, add migration, bump `backup_service.dart` `_schemaVersion`/`_supportedSchemaVersions`.
  - Bias formula: `t=(bias+1)/2; shareA=1-t; shareB=t`. Only reweights the two axis muscles — everything else on the exercise keeps full credit as today.
  - Touches: `muscle_progress.dart` and `live_muscle_state.dart` (`primarySets` becomes `double`, not `int` — secondary stays `int`), `muscle_anatomy_view.dart` (format the now-fractional counters, 4 call sites), `analytics_repository.dart` (3 `customSelect` queries need the new columns joined in), `exercise_repository.dart` (`updateBiasAxis`), `set_repository.dart` (`add`/`edit` gain `muscleBias`), `settings_screen.dart` (bias-axis dropdown pickers in the custom exercise dialogs), `set_editor_sheet.dart` (bias slider, only rendered when the exercise has an axis), `active_session_screen.dart` (wiring).
  - Seed `biasMuscleA`/`biasMuscleB` for **Leg Press** and **Barbell Squat** only (quads/glute_max) in `exercise_library.json`, synced via the existing `ExerciseAnatomyService.enrichBundledExercises`.
  - **Verify**: Leg Press set editor shows the slider; dragging it toward Quads and saving shows up in the muscle detail / heatmap; old (pre-v8) backups still import; new bias fields round-trip through export/import.

- [x] **Part 3 — Expand bundled exercise library from `exercemus/exercises` (MIT license).** One-time offline script (not shipped) appends ~834 net-new exercises (after exact-name dedup against the current 213) to `assets/data/exercise_library.json` in the existing shape — no runtime code changes, `enrichBundledExercises` already syncs new asset rows on launch. Solves the named gaps (Smith Machine variants, Behind-the-Neck Press).
  - Coarse→fine muscle crosswalk: most of the 19 source labels map 1:1 (quads, hamstrings, calves, forearms, biceps, brachialis, triceps, abs, adductors, lats, neck, traps→upperTraps, abductors→gluteMedMin, middle back→rhomboids, lower back→spinalErectors). Three ambiguous ones (chest, shoulders, glutes — ~300 of the 834 rows) use the same keyword rules as Part 1's suggester (incline/decline, lateral/rear/rotation, abduction-vs-thrust) to pick the specific muscle.
  - This is a lossy, best-effort import for the ambiguous third — every row stays editable through the existing muscle picker, same as any exercise today. Spot-check chest/shoulder/glute entries after import.
  - **Verify**: exercise picker search for "smith" and "behind the neck" returns the previously-missing exercises with sane muscle assignments.
  - Result: bundled library is now **1047 rows** (213 original + 834 net-new, 38 exact-name overlaps
    skipped). Importer stats: 510 rows hit an ambiguous source label, 44 resolved via keyword rule,
    466 took the default (chest 18/119 keyword/default, shoulders 26/294, glutes 0/233).

# Fix — 3D muscle view: "Reset view" no-op + some muscles not tappable (2026-08-09, `3f10522` + `25915fd`)
Two bugs in the vendored `third_party/interactive_3d` plugin (path dependency, not pub.dev), root-caused
by reading the plugin source directly, then fixed by codex and independently verified (including a full
iOS archive build, which codex's own environment cannot do — no Xcode there).

- [x] **Reset view was a complete no-op on iOS.** `SceneManager.cameraNode` was declared but NEVER
      assigned anywhere in the pre-fix code, so `setCameraZoomLevel`'s `guard let cam = cameraNode`
      silently failed on every single call — reset did nothing, not even zoom. On Android, `CameraController
      .setZoom()` only ever touched `zoomLevel`, never the `orbitAngleX`/`orbitAngleY` that pan gestures
      mutate. Fix: iOS now creates and owns a real camera node (`configureCamera`), captures its post-framing
      transform as a reset baseline, and a new `resetCamera()` restores rotation + zoom together on both
      platforms — plumbed end-to-end through `platform_interface.dart` → `method_channel.dart`/`widget.dart`
      → `controller.dart` → `muscle_anatomy_view.dart _resetModelView()`.
- [x] **Some muscles never registered a tap, Android only.** 39 of the 47 muscle meshes in
      `assets/models/muscular.glb` are multi-primitive (2–4 primitives each). Filament/gltfio only
      propagates the glTF node name to one primitive's renderable entity; `SelectionManager.notifySelectionChanged`
      silently dropped any selected entity whose name didn't resolve, so tapping a muscle's other primitive(s)
      visually flickered but never reached Dart. iOS already handled the equivalent problem (unnamed child
      geometry) by walking up to the nearest named ancestor; Android had no such fallback. Fix: new
      `EntityNameResolver` walks the Filament `TransformManager` hierarchy the same way, built into a
      entity→name map at model-load time, used everywhere tap/selection resolves a name.
- [x] Verified: `flutter analyze` clean, 206 Dart tests green, 2 new Kotlin unit tests green
      (`CameraControllerTest`, `EntityNameResolverTest`), Kotlin compiles (`gradlew testDebugUnitTest`),
      Swift compiles (`flutter build ipa --no-codesign` archives clean — confirmed independently after
      codex's report, since codex has no macOS/Xcode).
- Not verified (needs a real device pass): actual rotate/tap feel in-hand on iOS or Android.
- Release artifacts: `dist/logged-1.0.0-3d-view-fixes.apk`, `dist/logged-1.0.0-3d-view-fixes-unsigned.ipa`.

# Fix — Android reset-view zoom mismatch (2026-08-09, uncommitted)
User: "reset view" on Android made the muscle model dramatically smaller than on first load instead
of restoring the original framing.
- Root cause: `CameraController.kt`'s `resetOrbit()` hardcoded `zoomLevel = 1.0f`, ignoring the
  `defaultZoom = 3.0` Dart sends via `setZoom()` right after every load. iOS never had this bug —
  `SceneManager.swift` captures a reset baseline the first time `setCameraZoomLevel` runs after load.
- [x] Ported the same capture-on-first-zoom-after-load pattern to Android: `resetZoomLevel` +
      `shouldCaptureNextZoomAsResetBaseline`, captured in `setZoom()`, consumed in `resetOrbit()`.
- [x] 2 unit tests in `CameraControllerTest.kt` (existing default-state case + a new case proving
      reset restores the load-time zoom, not a hardcoded value). Both pass via
      `./gradlew :interactive_3d:testDebugUnitTest` (the plugin only builds through the app module,
      no standalone `gradle.properties`).

# Feature — Muscle bias axis settable on ANY exercise (2026-08-09, uncommitted, codex gpt-5.4 medium
reasoning implemented, manually reviewed)
User: wanted the bias slider (previously only Leg Press/Barbell Back Squat + hand-made custom
exercises) available from "the list of exercises," for any of the ~1047 bundled exercises too.
- Schema **v9**: new `Exercises.biasAxisUserSet` bool (default false, no backfill needed).
- [x] `exercise_anatomy_service.dart`'s `enrichBundledExercises()` — which re-syncs `biasMuscleA/B`
      from the asset on EVERY launch for non-custom rows — now skips that sync for any row with
      `biasAxisUserSet=true`. Without this, a user's bias choice on a bundled exercise would have
      silently reverted on next launch (found before shipping, see tasks/lessons.md).
- [x] `updateBiasAxis()` always sets `biasAxisUserSet=true` on both the "set axis" and "clear axis"
      paths — clearing is also a deliberate user choice.
- [x] Settings → "Manage exercises" (renamed from "Manage custom exercises") now lists ALL exercises
      with a live search field, not just custom ones. Custom rows still open the full muscle editor;
      bundled rows open a new bias-axis-only dialog (`_editBundledExerciseBias`) — primary muscles
      shown read-only, no primary/secondary editing for bundled rows (same overwrite trap, kept out of
      scope). List uses `ListView.builder` (not eager `ListView`) — 1047 rows would jank the sheet
      otherwise; caught and fixed in review of codex's diff.
- [x] Backup export/import round-trips `biasAxisUserSet`; old backups without the key import with
      `false` (tolerant, no crash) — `_schemaVersion` bumped 8→9 alongside it.
- [x] New/extended tests: v8→v9 migration, anatomy-service protected-vs-synced-row behavior, repo
      sets-the-flag-on-both-paths, old-backup-compat. `flutter analyze` clean, 209/209 green, debug
      APK builds.

# Feature — Global swipe-to-dismiss-keyboard (2026-08-09, uncommitted)
User: wanted every text field (exercise search, etc.) dismissible by dragging, so search results
aren't hidden behind the keyboard.
- [x] Found Flutter's actual ambient hook instead of touching ~25 scrollable call sites:
      `ScrollView.keyboardDismissBehavior` falls back to `ScrollBehavior.getKeyboardDismissBehavior`
      via the `ScrollConfiguration` `MaterialApp` installs around its whole `Navigator` (dialogs/sheets
      included). One override point covers the entire app, present and future screens alike.
- [x] Added `lib/core/keyboard_dismiss_scroll_behavior.dart`
      (`KeyboardDismissScrollBehavior extends MaterialScrollBehavior`, overrides
      `getKeyboardDismissBehavior` → always `.onDrag`), wired into `MaterialApp.scrollBehavior` in
      `main.dart`. Confirmed platform-agnostic (plain Dart in `scroll_view.dart`, no native
      plugin/platform channel involved) — works identically on iOS and Android.
- [x] Left the 2 pre-existing explicit per-widget overrides (`plate_calculator_sheet.dart`,
      `set_editor_sheet.dart`) in place — redundant now, harmless.
- [x] `flutter analyze` clean, **210/210 tests green** (added a widget test asserting the resolved
      behavior is `.onDrag`), debug APK builds.

# Investigation — "new IPA killed all my data, no templates, muscle view won't load" (2026-08-09)
User installed the `design-polish` IPA and reported data loss + broken templates/muscle view. Pulled
the real on-device database (`devicectl device copy from`) and found **nothing was lost**: 216
exercises, 7 templates, 13 sessions, 320 sets, last written that day — a completely different failure
mode from the actual July 26 data-wipe (see that dated entry above; this was not a repeat).
- Migration v7→v9 (the device was still on v7) was probed by running it against a COPY of the real
  pulled database via a throwaway test — completed cleanly, all rows intact. Not a migration bug.
- Real root cause: the `design-polish` redesign moved Templates from wherever it used to live to a
  small unlabeled icon (top-right of Dashboard) — the user hadn't found it. Confirmed by loading a copy
  of the real database into a simulator: the icon opens the templates correctly (Monday—Push A, etc.).
  User separately confirmed the 3D muscle view also loads fine. No code was broken; nothing to fix.
- Note for future sessions: simulator UI automation (cliclick + AppleScript window activation) is
  unreliable while the user is actively using other apps on the same Mac — `System Events` reported
  Simulator as frontmost, then the very next click landed on Brave/Sublime instead, twice. Don't burn
  time chasing coordinate-precision when this happens; confirm frontmost app with `osascript -e 'tell
  application "System Events" to get name of first application process whose frontmost is true'`
  immediately before AND after every click, and treat rapid drift as a sign to stop and ask the user to
  interact directly rather than keep retrying.

# Feature — Reorder exercises in an active workout (2026-08-09, uncommitted)
User wanted to drag-reorder exercises mid-session (already existed for Templates via T1.5; sessions
never got the same treatment). `SessionExercises.position` already existed — no schema change.
- [x] `SessionRepository.reorderExercises(sessionId, orderedIds)` — mirrors `TemplateRepository.reorder`'s
      validation (no duplicates, no missing/foreign ids) but scoped to one session's own exercises;
      writes to positions in a transaction.
- [x] `active_session_screen.dart`: swapped the flat `ListView` for a `CustomScrollView` +
      `SliverReorderableList` (exercise cards) + a footer sliver (Finish button) — needed because
      `ReorderableListView` would have made the Finish button itself draggable if left in the same list.
      Each `_ExerciseCard` gained a drag handle icon (`ReorderableDragStartListener`) next to the
      existing remove button; hidden once the workout is completed (`reorderable: !completed`).
- [x] Tests: `reorderExercises persists the new position order` and a rejection test for an id from a
      different session (mirrors the template repository's cross-collection validation tests).
- [x] `flutter analyze` clean, **229 tests green** (was 210 for lib/ + new tests here).

## Release artifacts — 2026-08-09 (`reorder-exercises`, uncommitted tree)
- `dist/logged-1.0.0-reorder-exercises.apk` (99 MB, release)
- `dist/logged-1.0.0-reorder-exercises-unsigned.ipa` (27.8 MB, release, UNSIGNED)
- Full `flutter clean` before building — a simulator debug build ran earlier this session for the data
  investigation above, and per the dated lesson two sections up, a stray simulator build silently
  poisons `build/native_assets/ios/` for the next device build. Verified this did NOT happen:
  `vtool -show-build` on both `objective_c` and `sqlite3` in the shipped archive reports `platform IOS`,
  `lipo -archs` shows `arm64` only (no `x86_64`). This is the same check that would have caught the
  July 26 incident before it shipped.
- Old `dist/logged-1.0.0-design-polish*` artifacts deleted per user request (they were not actually
  faulty — see the investigation above — but the user asked for a fresh build regardless).

# Current state (2026-08-09, end of session)
Branch `feat/set-editor-backup-ux`, still no git remote — all commits local-only, and **everything
above (reset-view fix, bias-axis-on-any-exercise, global keyboard dismiss, session exercise reorder)
is uncommitted** in the working tree as of this entry. `flutter analyze` clean, **229 tests green**.
Schema is still **v9** (no schema change for the reorder feature — `SessionExercises.position` already
existed). Bundled exercise library is **1047 rows**. `dist/` holds only the latest release pair
(`logged-1.0.0-reorder-exercises.apk` + `-unsigned.ipa`).

## Machine/toolchain notes (2026-08-09)
- **`third_party/interactive_3d` is a vendored path dependency**, not the pub.dev `interactive_3d`
  package (see `pubspec.yaml`) — Kotlin under `android/src/main/kotlin/com/example/interactive_3d/`,
  Swift under `ios/Classes/`. Edit the vendored copy, not anything from `.pub-cache`.
- **Unsigned IPA packaging recipe** (still true): `flutter build ipa --no-codesign` stops at
  `build/ios/archive/Runner.xcarchive` and does not emit an .ipa. Package by hand:
  `mkdir Payload && cp -R Runner.xcarchive/Products/Applications/Runner.app Payload/ && zip -r out.ipa Payload`.
- **Xcode auto-updates can silently break device archives.** Xcode went 26.4→26.6 between sessions;
  `flutter build ipa` started failing with "iOS 26.5 is not installed" until
  `xcodebuild -downloadPlatform iOS` ran. Never pipe that command through `head` — it sends SIGPIPE
  and kills the download mid-transfer with a misleading exit 0.
- **This machine's disk fills up.** Hit 1.1GB free (of 460GB) mid-session, which is what actually broke
  the iOS platform download, not a genuine missing-component problem. Biggest recoverable offenders
  found here: stale `CoreSimulator` runtimes (~50GB for versions Xcode no longer needs), Docker Desktop
  VM data (`~/Library/Containers/com.docker.docker`, doesn't shrink via `docker system prune` alone —
  delete directly if Docker isn't running), `.gradle/caches`, `~/.npm/_cacache`, browser/tool caches
  under `~/Library/Caches`, and old `dist/` build artifacts.
- **Files >30MB can't go through `SendUserFile`.** For an APK on the go, drop it into a synced cloud
  folder (`~/Library/CloudStorage/GoogleDrive-.../My Drive/` here) instead — syncs to the phone
  automatically if the Drive app is signed in.
- **Codex has a usage limit that can trip mid-session** (resets on a schedule, e.g. "Aug 11"). When
  Mode B review fails this way, don't skip review — do it manually against the same risk areas the
  codex prompt would have flagged, reading the actual diff rather than trusting green tests alone.

---

# Feature — N-muscle bias (replaces 2-muscle axis) + bundled-exercise muscle editing + keyboard-overlap fix (2026-08-09)

User found the 2-muscle bias axis (`biasMuscleA`/`biasMuscleB`, schema v9) unintentionally reachable
on ANY exercise with 2+ primary muscles (256/1278 bundled exercises qualify, not just squats/legs —
`Barbell Bent-Over Row`, `Dumbbell Pullover`, etc.), because `settings_screen.dart` gates the picker on
`primary.length >= 2` with no exercise-type restriction. Rather than restrict it, the user wants it
**widened**: bias should support N muscles (e.g. Zercher Squats — quads/glutes/hams — biasing all
three, or just two of them, or 100% into one). Decision: no restriction at all, arbitrary weight
distribution across an exercise's tagged primary muscles.

**Design** (superseding the `logged-pending-muscle-bias-feature` memory's 2-muscle-only scoping —
that memory is now stale, update it after this ships):
- Drop the pre-configured exercise-level "bias axis" entirely (no more picking a fixed pair in
  Settings). Bias becomes a live, per-SET weight distribution over whichever primary muscles the
  exercise currently has (2+) — chosen at set-log time in `set_editor_sheet.dart`, not pre-wired.
- Schema v9→v10: `SetEntries.muscleBias` (real, -1..1) → `SetEntries.muscleBiasWeights` (text,
  nullable JSON map `{"quads":0.6,"glute_max":0.4}`). Migrate existing non-null rows using the
  exercise's `biasMuscleA`/`biasMuscleB` + old `resolveMuscleBiasShares` math into a 2-key map so
  historical analytics are unaffected. Drop `Exercises.biasMuscleA`/`biasMuscleB`/`biasAxisUserSet`
  columns (no longer needed — nothing to pre-configure).
- `lib/core/domain/muscle_bias.dart`: replace the A/B pair functions with an N-muscle weight-map
  resolver. Preserve today's default: a primary muscle with no explicit weight entry still gets full
  `1.0` credit in `muscle_progress.dart`'s `primaryMuscleBiasWeight(...) ?? 1.0` call site — do not
  regress existing unbias'd analytics.
  - `muscle_progress.dart`, `live_muscle_state.dart`, `analytics_repository.dart` (raw SQL currently
    selects `bias_muscle_a`/`bias_muscle_b`/`muscle_bias` columns — update the queries), and
    `backup_service.dart` (JSON export/import + `_schemaVersion`) all consume the old A/B shape and
    need updating together.
- `set_editor_sheet.dart`: `SetEditorSheet` takes `primaryMuscles: List<MuscleId>` (not
  `biasMuscleA`/`biasMuscleB`) from `active_session_screen.dart`; the bias section renders one
  row/slider per primary muscle (only shown when length >= 2), renormalizing to 100% on change,
  defaulting to an even split. `SetEditorResult.muscleBias` (double?) → `muscleBiasWeights`
  (`Map<MuscleId,double>?`).
- `settings_screen.dart`: delete `_editBundledExerciseBias` and the bias-axis portion of
  `_editExerciseMuscles`/`_BiasAxisField` (no more exercise-level config). Separately, unify
  `_manageExercises`'s onTap (currently `if (exercise.isCustom) → _editExerciseMuscles else →
  _editBundledExerciseBias`, line ~767) so BUNDLED exercises get the same full primary/secondary
  muscle editor as custom ones — `exercise_repository.dart`'s `updateMuscles` already works
  identically on any exercise row (custom is just a bool flag), no repository change needed for this
  part. This is what lets a user actually add `glute_max`/`hamstrings` as primary on Zercher Squats
  (today it ships with only `quads`).
- `exercise_repository.dart`: remove `updateBiasAxis` (tied to the deleted A/B columns).
- Tests to update/add: `test/data/database_migration_test.dart` (v9→v10 migration preserves existing
  bias data), `test/core/muscle_bias_test.dart`, `test/data/session_repository_test.dart`,
  `test/data/exercise_repository_test.dart`, `test/data/backup_service_test.dart` (round-trip the new
  field). Cover: N=2 unchanged default behavior, N=3 (Zercher-style) distribution, migration fidelity,
  bundled-exercise muscle edit path.

**Separately — keyboard-overlap bug (small, fixed directly, not delegated):** exercise search bottom
sheets don't reserve space for the keyboard. `showModalBottomSheet` does NOT auto-pad for
`viewInsets` (verified against Flutter SDK source, `bottom_sheet.dart` — no `viewInsets` reference in
the framework's own layout code; the caller must add it, which `set_editor_sheet.dart` already does
correctly at line ~261 as the reference pattern). Two sheets are missing it:
- `lib/core/widgets/exercise_picker.dart` (`_ExercisePickerSheet`, the shared search used from
  session/progress/template/import screens) — `DraggableScrollableSheet` sizes against full screen
  height regardless of keyboard.
- `lib/features/settings/settings_screen.dart` `_manageExercises` (line ~692) — `Column(mainAxisSize:
  MainAxisSize.min)` content is bottom-anchored with no keyboard padding; when results are few, total
  content height < keyboard height, so the ENTIRE sheet (including the search field) renders behind
  the on-screen keyboard. This is exactly the "vanishes behind the keyboard" symptom — reproduces most
  visibly with few/zero results because the sheet is short.
- Fix: wrap both sheets' content in `Padding(padding: EdgeInsets.only(bottom:
  MediaQuery.viewInsetsOf(context).bottom))`.

Sequencing to avoid concurrent edits to the same file: keyboard fix done directly first (small, 2
files), THEN the N-muscle bias rewrite dispatched to Codex (touches settings_screen.dart too, among
5+ other files — per the Codex delegation rule for heavy/multi-file work), reviewed (Mode B) before
being called done.

**Implementation record — completed 2026-08-09 (uncommitted)**
- Schema v9→v10: `SetEntries.muscleBias` (real) → `muscleBiasWeights` (text/JSON weight map);
  `Exercises.biasMuscleA`/`biasMuscleB`/`biasAxisUserSet` dropped. Migration converts existing
  non-null legacy bias rows via the preserved `resolveMuscleBiasShares` formula; verified by a new
  v9→v10 test that checks the exact converted weights (0.25 legacy bias → `{quads:0.375,
  glute_max:0.625}`), not just presence/absence.
- `muscle_bias.dart`: `primaryMuscleBiasWeight` now takes a `Map<MuscleId,double>?` and returns
  `weights?[muscle]`, preserving every existing `?? 1.0` default-credit call site unchanged.
- `set_editor_sheet.dart`: one slider per primary muscle (`_showsMuscleBias` when 2+), proportional
  redistribution on drag, percentages always sum to exactly 100 (last muscle absorbs rounding
  remainder) — verified by reading `_normalizeBiasWeights`/`_setBiasShare`/`_biasPercentages` by hand.
- `settings_screen.dart`: `_editBundledExerciseBias` and all bias-axis config UI deleted;
  `_manageExercises`'s onTap no longer branches on `isCustom` — every exercise opens the full
  primary/secondary muscle editor, so bundled exercises (e.g. Zercher Squats, shipped with only
  `quads` primary) can have muscles added.
- `analytics_repository.dart` raw SQL, `backup_service.dart` export/import, `session_repository.dart`,
  `set_repository.dart`, `active_session_screen.dart` all updated to the new shape — grepped for
  dangling `biasMuscleA`/`biasMuscleB`/`bias_muscle_a`/`bias_muscle_b`/`updateBiasAxis` references
  after the fact; every remaining hit is legacy-migration/legacy-backup-import code that's supposed to
  still reference the old shape, none are live call sites.
- Keyboard-overlap fix (done directly, not via Codex): `exercise_picker.dart` and
  `settings_screen.dart`'s `_manageExercises` now wrap sheet content in
  `Padding(bottom: MediaQuery.viewInsetsOf(context).bottom)` — previously neither reserved space for
  the keyboard, so a short sheet (few/no results) rendered entirely behind it.
- **Verified:** `flutter analyze` clean, `flutter test` green (222 tests, up from 193). Codex did the
  N-muscle rewrite (Mode A); Mode B review done by hand against the 5 highest-risk areas above, not
  just green tests.

---

# Feature — Workout plan v8 templates + stretching-by-day-type fix + IPA/APK (2026-08-09)

Source: `/Users/palashlalwani/life/fitness/workout_plan_v8.docx` (read via pandoc). Rewrote
`lib/data/services/workout_template_seed_service.dart`'s `_templates` (all 6 days) to match v8's
exact sets/reps/tempo/rest/load notes. Every exercise name in the plan already existed in the 1278-row
library under some name (no new library rows needed) — cross-checked every name against
`assets/data/exercise_library.json` before writing the seed, including non-obvious aliases (Cable
External Rotation → `External Rotation with Cable`, Suitcase Hold → `Suitcase Carry`, Pec Fly Machine →
`Pec Deck`, B-Stance Romanian Deadlift → `B-Stance RDL`, Lean-Away (Bayesian) Lateral Raise →
`Lean-Away Cable Lateral Raise`, Reverse Nordic Curl → `Reverse Nordic`).

**Real bug found and fixed, unrelated to v8 content**: `_allStretches` was a single flat list spread
into ALL 6 templates identically — every day got all 6 stretches, when the plan's own stretching table
(unchanged since v7) explicitly varies by day type (Push/Pull/Legs each get a different 3–4-stretch
subset, not all 6). Split into `_pushStretches`/`_pullStretches`/`_legStretches`. Hip flexor lunge is
the only stretch that's genuinely on all 6 days.

**Propagation gap, same pattern as the muscle-anatomy backfill earlier**: `seedIfEmpty()` only ever
inserts a template if the NAME doesn't exist yet, and only refreshes an existing one if it has zero
prescription data (`_shouldRefreshDefaultTemplate`) — a template that already has full v7 prescriptions
(which Palash's live app does) would never pick up v8 changes. Added a version gate:
`_templatePlanVersion = 'v8'` stored in `app_settings` under `templatePlanVersion`; when the stored
version doesn't match, every template's exercises get replaced regardless of existing prescription
completeness, then the version is bumped. This is what actually gets v8 onto the phone — editing the
Dart list alone would not have.

**Real limitation, flagged not hidden**: v8 alternates Barbell Back Squat ↔ Zercher Squat and Barbell
RDL ↔ B-Stance RDL weekly on Legs A (same slot, different exercise every other week). The app has no
"alternate weekly" template mechanic — Wednesday's template shows the Week-A exercise as the fixed row,
with a prescriptionNotes line stating the alternation and instructing a manual swap via the exercise
row's existing swap feature every other week. This is a real capability gap, not a data-entry choice —
worth a proper feature if it comes up again.

Per explicit instruction, stripped every "NEW v8"/"UPDATED v8" label from user-facing
`prescriptionNotes` (was useful in the planning doc, not in the app) — capitalized the now-first-word of
every note that used to start after that prefix. The internal `_templatePlanVersion` constant/app_settings
key stayed (plumbing, not user-facing).

**Tests**: updated `test/data/exercise_library_asset_test.dart`'s hardcoded Monday row count (15→17,
Push A gained JM Press/Tate Press/Cable Pullover/Cable Serratus Punch/External Rotation as new rows).
Added a new test proving the version-gated upgrade actually fires on a template with COMPLETE stale
prescriptions (the exact scenario `_shouldRefreshDefaultTemplate` alone would skip) and is idempotent on
a second run.
- **Verified:** `flutter analyze` clean, `flutter test` green (230 tests).

**Builds**: `dist/logged-1.0.0-workout-plan-v8.apk` (99MB, copied to Google Drive `My Drive/` for phone
sync — too big for direct chat delivery) + `...-workout-plan-v8-unsigned.ipa` (27.8MB, sent directly).
IPA verified `platform IOS`, `arm64`-only via `vtool`/`lipo` per the July 26 incident lesson. Old
`dist/logged-1.0.0-reorder-exercises*` artifacts left in place (not asked to clean up).

---
See `tasks/lessons.md` for the non-negotiable units rule.

---

## Audit remediation — PHASE 1 (spec: `tasks/spec-audit-fixes.md`) — 2026-08-14

Implemented by Codex, reviewed and corrected here. All five items landed as specified:

- [x] **1.1 G1** — bias weights normalize to MEAN 1.0 (sum = N), not sum 1.0. Percentages still shown
      in the sheet; schemaVersion 10 → 11 with an `onUpgrade` rescale, mirrored in
      `BackupService.replaceFromPayload` for backups written at ≤ 10 via the shared
      `rescaleStoredMuscleBiasWeights`. Seam test asserts an untouched sheet save credits exactly
      what `muscleBiasWeights: null` credits.
- [x] **1.2 K1** — RPE enhances, never gates. Rep range alone drives double progression; RPE only
      vetoes. Rationale strings no longer name RPE when it played no part, and the "add one rep"
      string no longer fires when the suggestion repeats last time.
- [x] **1.3 A1+A2** — `_query` filters `is_warmup = 0` and no longer requires a non-null
      `weight_value`; `recentPrs` skips `weightKg <= 0`. Bodyweight sessions now count toward sessions
      and sets, still 0 tonnage (`TODO(A2b)` records the limitation).
- [x] **1.4 A4** — reps-branch performance signal uses the entered value and drops `* sides`.
      Duration/distance branches keep `* sides`.
- [x] **1.5 G2** — `loadDeloadData` applies `primaryMuscleBiasWeight`, matching `buildMuscleProgress`.

### Review corrections applied on top

1. `_resistedMassKg` took the entered value only for `LoadingMode.external`; added/assisted plates
   logged "per hand" still doubled into the 1RM proxy. Now all branches share one `external` value.
   Regression test: `muscle_progress_test.dart` "added load logged per hand is not doubled…".
2. The backup rescale ran after the import transaction — moved inside it (crash in the gap would have
   stranded share-scale weights permanently).
3. Stale doc comments claiming `completedSetsProvider` holds "weighted sets" and that `_query` drops
   bodyweight sets (`providers.dart`, `analytics_repository.dart`) rewritten to match the new
   behaviour.
4. `decodeMuscleIds` now drops duplicate ids. A repeated primary muscle would have double-credited
   sets and given two bias sliders the same `ValueKey`.

- **Verified:** `flutter analyze` clean, `flutter test` green (242 tests, up from 230 baseline).
- **NOT done:** the spec's manual on-device check — log two sets of a 2-primary exercise on a real DB,
  confirm weekly muscle balance reads 2.0 sets per muscle, and `sqlite3` the v10 → v11 rescale.
- **NOT done:** ground rule 8 — no baseline commit was taken before Phase 1, so these changes sit in
  the working tree mixed with the earlier uncommitted N-muscle bias work. Commit before Phase 2.

## Audit remediation — PHASE 2 (spec: `tasks/spec-audit-fixes.md`) — 2026-08-14

Implemented by Codex. All five Phase 2 items landed as specified:

- [x] **2.1 J2** — `_rankScore` now scores the last 8 **completed** weeks only. The current partial
      week no longer changes rank score/consistency mid-week, so Monday does not zero out the
      heaviest decay bucket.
- [x] **2.2 J1** — week-key arithmetic in `_rankScore` and `loadDeloadData` now uses calendar
      arithmetic (`DateTime(year, month, day - n * 7)`), not `Duration(days: n * 7)`, so DST shifts
      no longer break exact week-key lookups.
- [x] **2.3** — `loadDeloadData` builds its `weekStarts` window ending at the **last completed**
      week, not the current partial one. Deload volume compares completed weeks against MRV.
- [x] **2.4** — `DeloadData` now carries `repDecaySeries`; `assessDeload` adds the
      `wideningRepDecay` signal while leaving `risingEffort` unchanged; `_deloadQuery` is bounded to
      the last 12 weeks. The provider wiring now threads `repDecaySeries` into the deload assessment.
- [x] **2.5 J3** — `createDeloadWeek` now bases the template on the most recent week **with**
      completed training, not "this week", and the empty-history error now reads
      `'Complete at least one workout before generating a deload.'`

- **Verified:** targeted red-first tests were added for current-week rank exclusion, DST-safe week
  keys, completed-week deload bucketing, rep-decay capture/signal, 12-week stall recency, and
  most-recent-trained-week deload templates. `flutter analyze` is clean, and `flutter test` is green
  at **250 tests** (up from the 242-test Phase 1 baseline).
- **NOT done:** the spec's manual clock-change check — set the device clock to a Monday and confirm
  the dashboard rank does not drop relative to Sunday.
- **NOT done:** any real-device verification of the deload card itself. The new signals and windows
  are automated-test covered, but I did not manipulate a live device clock/database to watch the UI
  surface a deload recommendation.

### Phase 2 review (Claude, same day)

Validated all five items against source. `flutter analyze` clean, `flutter test` **250 green**.
The DST test is genuinely red-first: under `Europe/Berlin` with `today = 2026-11-02`, the old
`currentWeek.subtract(Duration(days: 21))` lands on `2026-10-11 23:00` instead of `2026-10-12`, so
the exact-equality lookup missed and the week was dropped. The new calendar arithmetic buckets it.

- [x] **Fixed — dead parameter.** `createDeloadWeek({DateTime? today})` kept its `today` param after
      the body switched to `MAX(started_at)`, so the argument was silently ignored. Two tests still
      passed `today:` and read as date-scoped while testing nothing of the sort. Removed the
      parameter and updated all three call sites (`progress_screen.dart` already passed nothing).
      Same class as the `cameraNode` no-op in `lessons.md` — an input that looks wired and is inert.

**Residual gaps — all three fixed (same day):**
- [x] **A bodyweight-only trainee could never trigger a deload.** `loadDeloadData`'s
      `if (weight == null || weight <= 0 ...) continue;` gated *all three* per-exercise signals, so
      1RM-stall, rep-decay and rising-RPE were simultaneously dead for someone training only
      pull-ups / dips / push-ups — only volume-overreach survived, 1 of 4 against
      `reasons.length >= 2`. Exactly the failure class 2.4 exists to fix, relocated to a different
      population. Fixed at the gate (one `continue`, three signals): the guard is now `reps` only.
      Rep decay keys on `mode:addedKg` — bodyweight is constant within a session, so a null
      `weight_value` is a valid load key. The est-1RM stall proxy uses `bodyweight_factor` for
      strict bodyweight lifts; the detector compares a series against itself, so the constant
      bodyweight term cancels and the factor alone is a valid scale. Assisted lifts stay excluded.
      Bodyweight drift is the known ceiling, marked `ponytail:` at the call site.
- [x] `repDecaySeries` candidate loads now tie-break on the load key. `List.sort` is not stable in
      Dart, so equal set counts previously picked arbitrarily between runs.
- [x] `assessDeload`'s `repDecaySeries` is now `required`, matching its siblings — a future caller
      cannot drop the signal silently.
- Regression test added: `bodyweight-only training still produces rep-decay and stall signals`
  (three sessions, two strict sets each, zero `weight_value` anywhere). Red before the gate fix.
- `flutter analyze` clean, `flutter test` **251 green**.

**Correction to the Phase 2 note above:** the "NOT done: ground rule 8 / commit before Phase 2" item
was already stale when written — Phase 1 landed as `1d9c03e`, whose message states it is the
baseline for Phase 2. Phase 1 and Phase 2 are separate commits; nothing needed splitting.

## Audit remediation — PHASE 3 (spec: `tasks/spec-audit-fixes.md`) — 2026-08-14

Implemented by Codex. Both Phase 3 items landed as specified:

- [x] **3.1 F1+F2** — schemaVersion bumped to **12** with new `exercises.isTimed` and
      `exercises.tracksDistance` columns; backup writer/importer bumped to schema 12 with false
      defaults for older backups; fresh seeding now writes the reviewed timed/distance defaults; a
      one-time bundled backfill `timedExerciseBackfilled` corrects existing installs and is called
      from `main()`. `isTimedExercise` now prefers the exercise column, `SetEditorSheet` accepts
      `tracksDistance`, and the custom-exercise modal adds **Logged in seconds** /
      **Tracks distance** switches plus category helper text.
- [x] **3.1 launch-sync guard** — `enrichBundledExercises()` was deliberately left blind to
      `isTimed` / `tracksDistance`. Only the one-time backfill writes those columns for bundled rows,
      so a later user choice cannot be silently reverted on every app launch.
- [x] **3.1 bounded asset edit** — only `Plank` and `Side Plank` in
      `assets/data/exercise_library.json` received `"isTimed": true`. The other requested names were
      not exact matches in the real asset, so they were intentionally left untouched rather than
      guessed (`Dead Hang`, `Wall Sit`, `L-Sit`, `Hollow Hold`).
- [x] **3.2 P** — CSV program import now accepts optional `duration_sec`, `distance_m`, and `sides`
      columns, keeps per-row validation/errors, and threads the parsed values into
      `TemplateExercisesCompanion` as `targetDurationSec`, `targetDistanceMeters`, and `sidesPerSet`.
      The import-screen sample header was updated accordingly.

- **Verified:** targeted tests added for the seed path, the one-time timed/distance backfill, v11 →
  v12 migration, backup round-trip/defaults, parser duration/sides validation, and the zero-history
  `exerciseIsTimed` regression. `flutter analyze` is clean, and `flutter test` is green at
  **258 tests**.
- **NOT done:** the spec's manual real-device check — create a custom `Copenhagen Plank`, toggle
  **Logged in seconds**, log `30 s` each side in an ad-hoc workout, then inspect the on-device DB for
  `duration_sec = 30`, `side_count = 2`, `reps IS NULL`.
- **NOT done:** any real-device backup import/export pass. The backup schema/defaults are test-covered,
  but I did not restore an actual ≤11 backup on hardware and inspect the post-import exercise rows.

### Phase 3 review (Claude, same day)

`flutter analyze` clean, `flutter test` **264 green** (codex handed over 258). Reviewed the whole
diff by hand and ran a Codex Mode-B pass in parallel. Four real defects, all fixed with tests.

**Asset audit — the spec's list was wrong, and it omitted the actual bug.**
Four of the six holds the spec names do not exist in `exercise_library.json`: `Dead Hang`,
`Wall Sit` and `L-Sit` are absent entirely, and `Hollow Hold` is really `Hollow Body Hold`. Codex
correctly reported the misses instead of inventing rows. More importantly **`Copenhagen Plank` is
already a bundled `bodyweight` exercise and the spec never listed it** — F1 was written up as a
*custom*-exercise problem, so following the spec literally would have shipped Phase 3 with the
user's own reported bug still live. Marked 10 holds `isTimed` and 15 loaded carries
`tracksDistance` (audit F2), verified name-by-name against the asset. Deliberately excluded
`Leverage Iso Row` (isolateral, not isometric), the `Hang Clean`/`Hang Snatch` family (a starting
position, not a hold), and the ambiguous locomotion drills. Pinned in the real-asset seeding test —
a fixture cannot catch a renamed entry, which is how the spec's list went stale.

- [x] **Seed and backfill disagreed on `tracksDistance`.** The backfill derived it from
      `category == cardio` alone while the seed path read the asset, so a `Farmer Carry` (category
      `strength`) tracked distance on a fresh install and silently did not on an upgraded one — F2
      would have stayed broken for every existing user. Latent until the asset gained a
      strength-category carry, which my audit added. Fixed by extracting the one rule both paths now
      call (`lib/data/services/bundled_logging_flags.dart`).
- [x] **Saving a set destroyed reps it already carried.** Codex changed save to null every hidden
      field, but `_showsReps` had no existing-value guard while its siblings `_showsDuration` and
      `_showsDistance` both did. A stretching set (never `_isLifting`) logged with reps lost them on
      any later edit. Verified red first: `Expected: <12>, Actual: <null>`.
- [x] **A timed or distance-tracking strength lift could never complete.** `isSetComplete` took no
      `timed`/`tracksDistance` at all and demanded `reps > 0` for the whole strength/bodyweight
      branch — but the editor now hides and nulls reps for those exercises, so the set stayed
      incomplete forever and the rest timer never fired. Exactly the `cardio` trap the audit
      describes. Threaded both flags through `setFieldsFor`, `setColumnsFor` and `isSetComplete`;
      distance now replaces reps as a carry's volume column the way duration does for a hold.
- [x] **CSV import created custom exercises with both columns at defaults** (Codex Mode-B finding 3).
      The exercise row outlives the template and is reachable ad hoc, where a prescription cannot
      speak for it. Flags are now OR-ed across every row naming the exercise.
- [x] **`duration_sec` / `distance_m` accepted 0 and negatives** (finding 4) while the sibling
      `rest_sec` correctly rejected them. Bounded; error text updated and its assertion realigned.

Codex Mode-B finding 1 (bundled holds left untagged) was already resolved by the asset audit above —
it reviewed a diff snapshotted before that work. Its clearance of `enrichBundledExercises` and the
backup version path matches my own read: the new columns are deliberately outside the launch-time
sync, so a bundled row cannot be clobbered.

**Migration coverage is real:** v9→v12 exercises the `alterTable` branch and v2/v5/v6/v7 the
`addColumn` branch, so the awkward `from < 12 && (from < 8 || from >= 10)` guard is proven on both
sides. That condition is precisely "the v8–v9 rebuild did not run" — correct, but obscure enough
that the next migration should re-derive it rather than copy it.

- **Still NOT done** (both carried from codex's record): the real-device Copenhagen Plank check and
  a real-device restore of a ≤11 backup. Neither is verified on hardware.

## Audit remediation — PHASE 4 (spec: `tasks/spec-audit-fixes.md`) — 2026-08-14

Implemented by Codex. Phase 4 landed within the stated scope:

- [x] **4.1 F3+I3+D4** — `ExerciseRepository` now has `updateDetails(...)` with
      `Value.absent()` semantics and a guarded `delete(...)` that refuses to remove exercises still
      referenced by `session_exercises` or `template_exercises`. `settings_screen.dart`'s old
      muscles-only dialog is now a full **Edit exercise** sheet for bundled and custom exercises:
      name, category, bodyweight factor, timed/distance flags, muscles, video link, and delete with
      archive fallback when history/templates block removal.
- [x] **4.2 D1+D2+D3** — removing an exercise from an active workout now confirms the exact exercise
      name and current set count. Set delete in the set editor is now `SnackBar` + **Undo**, and the
      undo path re-inserts the original set values rather than a fresh default row. Bodyweight-entry
      delete in Settings also uses `SnackBar` + **Undo**.
- [x] **4.3 F5+A7** — finishing a workout now includes a multiline notes field and `SessionRepository.finish`
      no longer nulls an existing note when the caller omits `notes`. Completed-session view
      (`active_session_screen.dart` when `endedAt != null`) and `history_screen.dart` now display
      saved session notes.
- [x] **4.4 A3** — `SetRepository.edit` now uses `Value.absent()` for omitted fields and `Value<T?>`
      for nullable ones, so callers can separately express **leave alone** vs **clear**. Both real
      callers in `active_session_screen.dart` were updated deliberately.
- [x] **4.5 A6** — `SessionRepository.addExercise` now assigns `max(position) + 1`, so adding after a
      middle delete cannot collide with an existing position.
- [x] **4.6 F7** — session prescriptions are now editable from the active workout screen through a
      new `SessionRepository.updatePrescription(...)` method with `Value.absent()` semantics. The
      active-session prescription line is tappable, and both the template editor and session screen
      now use the same shared prescription sheet widget/formatter.

- **Verified:** added the required repository tests for guarded exercise delete, `finish()` note
  preservation, non-colliding `addExercise()` positions, `updatePrescription()` partial writes, and
  `SetRepository.edit()` leave-alone vs clear semantics. `flutter analyze` is clean, and
  `flutter test` is green at **272 tests**.
- **NOT done:** the spec's manual Phase 4 flow checks — I did **not** manually remove an exercise
  mid-session and inspect the confirmation dialog, delete a set and undo it in the running app,
  rename a bundled exercise in Settings, or attempt a blocked delete and choose Archive in the UI.

## Audit remediation — PHASE 5 (spec: `tasks/spec-phase5.md`) — 2026-08-14

Implemented by Codex. Phase 5 landed within the stated scope:

- [x] **5.1 B1** — moved the dashboard/history recent-session streams, the templates stream, and the
      progress screen's one-rep-max point load off widget `build()` methods and into Riverpod
      providers. `dashboard_screen.dart`, `history_screen.dart`, `templates_screen.dart`, and
      `progress_screen.dart` now use `ref.watch(...).when(...)` with distinct loading and empty
      states, so rebuilds no longer flash those screens blank.
- [x] **5.2 H1** — `SetRepository.delete(...)` now renumbers remaining sets contiguously inside the
      same transaction, and Undo restores the deleted set at its original ordinal through a
      repository method instead of naively re-adding a duplicate `setNumber`.
- [x] **5.3 H2** — sets can now be reordered and inserted mid-list through per-row overflow actions
      (**Move up**, **Move down**, **Insert set above**) without nesting a reorderable list inside
      the existing exercise-card reorderable. The actions are hidden on completed sessions.
- [x] **5.4 H3** — `SetEditorSheet._save()` now refuses an otherwise blank set and surfaces
      `Log at least one value for this set.` while still allowing reps-only bodyweight, duration-only
      timed/stretching, and distance-only cardio saves.
- [x] **5.5a B2** — `SessionRepository.details()` no longer does N+1 queries per exercise. It now
      loads session-exercise/exercise rows in one join, loads all sets for those links in one query,
      groups them in memory, and preserves the existing order/empty-set contract.
- [x] **5.5b B3** — added `todayProvider` and pure `nextLocalMidnight(DateTime)` in
      `lib/data/providers.dart`. The dashboard and history month-summary date now read the provider
      instead of a raw `DateTime.now()` inside `build()`, so they can roll over at local midnight.

- **Verified:** added provider tests for recent-session family limits and `nextLocalMidnight(...)`,
  repository tests for delete renumbering, undo restore, set reorder/insert, and `details()`
  ordering/empty-set behavior, plus widget tests for the blank-save guard and the accepted
  single-field save cases. `flutter analyze` is clean, and `flutter test` is green at
  **288 tests** (the entry originally claimed 283; the suite actually reports 288).
- **NOT done:** the spec's manual Phase 5 checks. I did **not** manually verify in a debug build
  that History/Templates avoid empty-state flashing during rotation/theme changes, that deleting the
  middle of three sets and undoing it behaves correctly on-device, that inserting above set 2 keeps
  numbering contiguous in the running app, that exercise-card drag still feels right by hand, or
  that the blank-set refusal was exercised manually outside the widget tests.

### Phase 5 review follow-up — 2026-08-14

Reviewed by Claude against `tasks/spec-phase5.md`. One regression found and fixed; the rest of the
phase stands as written.

- [x] **5.1 regression** — `oneRepMaxPointsForExerciseProvider` shipped as a non-autoDispose
      `FutureProvider.family`, so the Progress deep-dive chart computed its points once and cached
      them for the app's lifetime. Nothing invalidates it, so sets logged after the chart first
      rendered never appeared until an app restart. The old `FutureBuilder` re-ran on every build,
      which is why the audit never saw this. `AnalyticsRepository.oneRepMaxPointsForExercise` is now
      a `Stream` (`customSelect(...).watch()` with `readsFrom`, SQL byte-identical) behind a
      `StreamProvider.family`. `progress_screen.dart` needed no change — `.when(...)` is the same.
      Regression test: `oneRepMaxPointsForExerciseProvider re-emits when a later set is logged`,
      confirmed failing (5s timeout, no second emission) against the pre-fix code. Suite now 289.

- **Known, not fixed** (logged for a later phase, none block Phase 6):
  1. `active_session_screen.dart` fires the set move/insert actions through `unawaited(...)`, so an
     `ArgumentError` from `reorderSets` on a stale id list is an uncaught async error with no user
     feedback.
  2. `SetRepository.insertSetAt` never passes `isWarmup` (and `seedForNextSet` does not carry it),
     so "Insert set above" on a warm-up row inserts a working set into the warm-up block.
  3. `SetRow`'s `PopupMenuButton` passes no `constraints`, so Flutter's internal `IconButton` falls
     back to its 48px minimum where the old branch pinned 36px — set rows are probably ~12px taller
     on an active session. Not verified on device.
  4. "Set details" is now two taps (menu → item) where it was one tap on the ⋯ button. Row
     long-press still opens it directly.

## Audit remediation — PHASE 6 (spec: `tasks/spec-phase6.md`) — 2026-08-14

Implemented by Codex. Phase 6 landed within the stated scope:

- [x] **6.1 C1** — `NotificationClient` now exposes `showRestCountdown(...)`,
      `showRestComplete(...)`, and the foreground-isolate `actionSelections` stream. `NotificationService`
      now posts the Android rest timer as an ongoing low-importance chronometer on the separate
      `rest_timer_progress` channel, keeps iOS on the existing one-shot schedule path, uses a
      time-sensitive completion alert on `rest_timer`, wires `onDidReceiveNotificationResponse`,
      and deliberately does **not** register the background callback. The shared `schedule(...)`
      path and its reminder-scheduler caller are unchanged.
- [x] **6.2 lifecycle + C2** — `RestTimerController` now posts the countdown immediately and keeps it
      up for the full rest instead of lifecycle-gating it. `didChangeAppLifecycleState(...)` now
      ignores `inactive`/`hidden` churn, acts only on `paused` and `resumed`, routes notification
      actions through the controller, and replaces the countdown with a completion alert at zero.
      `RestTimerState.completed` and `acknowledge()` distinguish **finished** from **idle**, and
      `RestTimerBar` now renders a stable completion row with **Done** instead of vanishing.
- [x] **6.3 full-screen timer** — added `lib/features/session/rest_timer_screen.dart` and now push it
      from `_startRestTimer(...)` only after `start()` succeeds and the timer is actually running.
      The route is a full-screen `MaterialPageRoute` with chevron-down minimise, a confirm-on-cancel
      path only when more than 30 seconds remain, the existing `-15s` / `+15s` / `Skip` controls,
      next-set context from the already-computed `ProgressionSuggestion?`, and an
      `AnimationController` + `AnimatedBuilder` countdown driven from `endTime` with **no**
      `Timer.periodic`.

- **Verified:** extended `test/features/rest_timer_controller_test.dart` for the immediate countdown,
  resume/inactive lifecycle behavior, countdown repost on adjust, completion alert vs skip cancel,
  `state.completed`, and notification Skip action. Added `test/features/rest_timer_bar_test.dart`
  for the completion row and `test/features/rest_timer_screen_test.dart` for the `>30s` confirm /
  `<30s` immediate-cancel branches. `flutter analyze` is clean, `flutter test` is green at
  **300 tests**, and `flutter clean && flutter pub get && (cd ios && pod install)` completed on
  Friday, August 14, 2026.
- **NOT done:** the spec's required real-device notification checks. I did **not** verify on a real
  Android device that the countdown appears in the shade and on the lock screen, that it flips to
  **Rest complete** within a second or two of zero while the app is backgrounded, or that the
  backgrounded `+15s` action extends the live countdown. I also did **not** verify the iOS
  notification-centre pull behavior on hardware. This environment has no real-device interaction, so
  those checks remain unverified.

### Phase 6 review fixes — 2026-08-15

Claude reviewed the three Phase 6 commits against `tasks/spec-phase6.md`. Three real defects, one
proven by a failing test written before the fix:

1. **Settings leak (confirmed by test).** `_finish()` called `showRestComplete(...)` unguarded while
   `_postCountdownNotification()` gates on `_notificationsAllowed`. With rest-timer notifications
   switched **off** in settings but the OS permission still granted for coaching reminders, the user
   got a "Rest complete" notification they had opted out of. Now gated the same way; the haptic stays
   unconditional. Regression test: `notifications disabled posts nothing at zero`.
2. **Progress ring went stale after backgrounding.** `RestTimerScreen` only resynced its
   `AnimationController` when `running` or `endTime` changed, and neither changes across
   background → resume — but the vsync ticker is frozen while away and the scheduler resets the
   animation epoch on return, so the ring lost exactly the backgrounded time and would still be part
   full at zero. Added `_animationDrifted(...)`, which resyncs whenever the ring has drifted more
   than a second from `endTime`. Digits were always correct (wall clock); only the ring was wrong.
   **Not device-verified** — reasoned from the scheduler's resume behaviour.
3. **Orphaned ongoing countdown.** `_countdownDetails` posted `ongoing: true` with no `timeoutAfter`,
   and nothing cancels id 1001 at app start. Killing the app mid-rest left a notification that is not
   user-dismissible below Android 14, counting into negative time, until the next completed rest.
   Android now gets its own deadline: `endTime - now + 1 min`. **Not device-verified.**

Also folded in: `_completionDetails` no longer takes two parameters both call sites filled with the
same literals; `RestTimerScreen` reads `restTimerClockProvider` instead of `DateTime.now()` directly;
and `_startRestTimer` no longer awaits `Navigator.push`, which had held the session screen's
`setState(_refresh)` back for the entire rest period.

Deliberately **not** changed: `didChangeAppLifecycleState` reposting the countdown on `paused`. The
spec says "act only on `paused` and `resumed`", which sanctions a `paused` action, and the repost is
a harmless silent update (`onlyAlertOnce`) that restores the notification if the user swiped it away
on Android 14+.

`flutter analyze` clean, `flutter test` green at **301 tests**. The spec's real-device notification
checks (items 2–4 and 6 of Phase 6 verification) remain **unverified** — no Android or iOS hardware
in this environment, and fixes 2 and 3 above are exactly the kind of thing only a device settles.

## Audit remediation — PHASE 7 (spec: `tasks/spec-phase7.md`) — 2026-08-15

Implemented by Codex. Phase 7 landed within the stated scope:

- [x] **7.1 A5 onboarding training days** — onboarding now asks for training days directly, defaults
      to Mon/Wed/Fri, saves the complementary `restWeekdays`, and leaves existing installs untouched.
      Added onboarding and streak regressions for the Mon/Wed/Fri split and the new selection flow.
- [x] **7.2 I2 schema v13 anatomy dirty flag** — added `Exercises.anatomyEditedByUser`, bumped the
      database and backup schema to **13**, migrated existing installs, replaced the one-shot boolean
      anatomy backfill guard with `muscleAnatomyBackfillVersion`, skipped user-edited rows during
      backfill, and made `ExerciseRepository.updateMuscles(...)` set the dirty flag.
- [x] **7.3 in-session exercise info/edit sheet** — extracted the settings-only exercise editor into
      `lib/core/widgets/exercise_editor_sheet.dart`, reused it from Settings and the active session,
      added the read-first info sheet with named primary and secondary muscles, and refreshed the
      active workout card in place after save.
- [x] **7.4 backup device-local state** — portable backups now filter device-local settings on both
      export and import, zero-file picker results stay on the normal `false`/`FormatException` path,
      and backup/CSV exports prune stale temp files older than a day instead of accumulating forever.
- [x] **7.5 reminder backstop + channel descriptions** — kept the rolling 28-day reminder window,
      added one weekly repeating backstop beyond the horizon, cancelled it when reminders are off,
      and gave reminder/rest-timer channels distinct Android descriptions.
- [x] **7.6 A9 PRs across `weightEntry`** — `recentPrs(...)` now keys bests on
      `(exerciseId, weightEntry)` so switching between total-load and per-hand logging no longer
      creates a fake PR celebration, while real same-mode increases still do.
- [x] **7.7 N1/N3 accessibility + theme** — large-text widget regressions now cover the set editor
      and dashboard, icon-only controls on those surfaces carry explicit semantic labels, the
      dashboard summary cards stack under large text, the set editor swaps fixed-height rows for
      stacked layouts when needed, and Settings now persists a system/light/dark appearance
      preference that `LoggedApp` applies at startup.

- **Verified:** every new regression test was written first and confirmed to fail against the pre-fix
  code before the implementation changed. Added or extended tests in
  `test/features/onboarding_screen_test.dart`, `test/core/streak_test.dart`,
  `test/data/backup_service_test.dart`, `test/data/exercise_repository_test.dart`,
  `test/data/exercise_anatomy_service_test.dart`, `test/data/database_migration_test.dart`,
  `test/core/widgets/exercise_editor_sheet_test.dart`, `test/features/reminder_scheduler_test.dart`,
  `test/core/progress_analytics_test.dart`, `test/features/set_editor_sheet_test.dart`,
  `test/features/dashboard_screen_test.dart`, and `test/main_test.dart`. `flutter analyze` is
  clean, `flutter test` is green at **322 tests**, and
  `flutter clean && flutter pub get && (cd ios && pod install)` completed on Saturday,
  August 15, 2026.
- **NOT done:** I did **not** verify a real populated-device v12 → v13 upgrade, a restore of a
  backup created before 7.4a onto a second device with Apple Health enabled, or the new large-text
  / appearance-setting behavior with TalkBack, VoiceOver, or a real OS light/dark theme switch. I
  also did **not** run the broader deferred hardware/manual backlog listed above: the Phase 3
  Copenhagen/v11-restore checks, all Phase 4 manual flows, all Phase 5 manual flows, and all Phase 6
  notification behavior.

### Phase 7 review fixes — 2026-08-15

Claude reviewed all seven Phase 7 commits against `tasks/spec-phase7.md`. Two defects, one proven by
a failing test written before the fix, plus one accepted limitation now documented in the code:

1. **The anatomy dirty flag was set on every save (confirmed by test).** `updateMuscles(...)` wrote
   `anatomyEditedByUser: true` unconditionally, but the editor sheet re-sends **every** field on
   **every** save — so fixing a typo in an exercise name, changing its category, or pasting a video
   link permanently opted that exercise out of all future library anatomy corrections. That defeats
   the entire point of task 7.2, and task 7.3 had just moved the editor to one tap away on every
   card in every workout, so the blast radius was large. `updateMuscles` now compares against the
   stored anatomy and leaves the flag absent when nothing changed. Codex's own test covered only the
   changed case; the regression test `re-saving unchanged muscles leaves anatomy eligible for
   backfill` covers the other half.
2. **`_categoryLoggingHelper` was duplicated by the extraction.** Task 7.3 moved the editor out of
   `settings_screen.dart` but left a verbatim copy of the helper behind, still live in the
   create-exercise sheet — a `switch` needing to stay in sync across two files. Now one public
   `categoryLoggingHelper` in `exercise_editor_sheet.dart`, called from both.
3. **Accepted and documented, not fixed:** the new weekly backstop anchors in UTC (like the existing
   `schedule`), so in a DST-observing timezone it drifts an hour after each transition and does not
   self-correct — the one-shot window self-corrects only because opening the app rebuilds it, and
   the backstop exists precisely for users who have stopped opening the app. Fixing it means
   detecting the device's IANA zone, which is another native plugin the app deliberately avoids.
   Reasoning recorded above `scheduleWeekly`. No impact in India (no DST).

Also checked and found correct, contrary to first reading: the v13 migration guard
(`from >= 8 && from < 10` alterTable vs `from < 8 || from >= 10` addColumn are exact complements, so
the column lands once on every upgrade path); `validateMuscleSelection` throwing out of the editor
(both pickers prevent primary/secondary overlap, so it is unreachable); the backstop being cancelled
before the `enabled` early-return; and `_applyAnatomyChanges`, which Codex revived as the shared
batch instead of deleting it — better than the spec asked for. Task 7.6 is also better than specified:
it suppresses the first set in a newly-switched entry mode, which keying alone would not have.

`flutter analyze` clean, `flutter test` green at **323 tests**. The device verification listed in the
Phase 7 record above remains **unverified**, and now leads into the full end-to-end run.

### Phase 7 device check — 2026-08-15 (Vivo V2143, Android 13)

First real-device run of the whole remediation, sideloaded over the 2026-08-09 build.

- **VERIFIED on device:** the **v12 → v13 migration** ran clean on an existing populated install —
  app launched with no crash, no `SqliteException`, and the rank card rendered real history
  (26 muscles trained) off the upgraded schema. This was Phase 7's headline unverified item.
- **VERIFIED on device:** task 7.3's in-workout exercise info sheet. The ⓘ renders on every exercise
  card in a live session and opens a sheet showing category, logging traits, **primary muscles**
  ("Mid / lower chest", "Upper chest") and **secondary muscles** ("Front delts") as named chips,
  bodyweight factor, and an Edit button that opens the full extracted editor in place.
- **FOUND AND FIXED on device — nothing in the suite could have caught it:** the editor sheet
  autofocused its name field, so opening it from a workout immediately raised the keyboard over the
  muscle pickers (`dumpsys input_method` → `mInputShown=true`). Inherited verbatim from the Settings
  version, where it is correct because creating an exercise starts with typing a name; editing an
  existing one does not. `autofocus` removed from the extracted editor only; the create-exercise
  sheet in Settings keeps it.

Still **not** verified on device: everything notification-shaped from Phase 6 (lock-screen countdown,
the flip to "Rest complete" at zero, the backgrounded +15s action, `timeoutAfter` reaping an orphaned
`ongoing` notification — this Android 13 handset is the right device for that last one, since ongoing
notifications are non-dismissible below Android 14), the reminder backstop, backup export/restore
across devices, large-text and TalkBack behaviour, and all iOS behaviour.

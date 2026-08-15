# PHASE 7 SPEC — the last phase: edit everything from everywhere, and stop lying to the user (standalone brief for Codex)

> **You have NO prior conversation context.** Everything you need is below. Every file path, symbol,
> and line number named here was verified against the working tree at commit `4206e28`
> (branch `feat/set-editor-backup-ux`) on 2026-08-15. Line numbers drift as you edit — treat them as
> "look here first", and **always open the file and confirm the signature before using it.**
>
> Full audit evidence lives in `tasks/audit-2026-08-14.md`. The Phase 7 table in
> `tasks/spec-audit-fixes.md` (line 635) is a one-line-per-item index; **this document supersedes
> it** and is the authority on scope, decisions, and order.

## Project in 20 seconds

Logged is a private, 100% local, no-account Flutter workout tracker (Android + iOS, Drift +
Riverpod, feature-first). No network, no analytics, no accounts — do not add any. This is **Phase 7
of 7, the last phase.** After it lands, Palash runs the whole application end to end for the first
time, which is when every deferred manual check finally gets run.

Baseline you must preserve: **`flutter analyze` clean, `flutter test` 301/301 green.**

---

## GROUND RULES (non-negotiable — distilled from `tasks/lessons.md`, read it)

1. **Verify APIs before use.** Every symbol named below exists today. Still open the file and confirm
   the signature. Never assume a method shape. Never invent one.
2. **This phase DOES change the schema — exactly once, to v13.** Task 7.2 owns that bump. No other
   task may touch `schemaVersion`. If a task seems to want a second migration, re-read the spec.
3. **Root-cause, not call-site.** When you fix a shared function, grep every caller first.
4. **Never build a `DateTime` by adding a `Duration` of days.** DST makes `now.add(Duration(days: 1))`
   land on 23:00. Construct calendar-wise: `DateTime(y, m, d + 1)`. `lib/core/domain/streak.dart` is
   the reference.
5. **Green tests are necessary, not sufficient.** Every finding in the source audit survived a green
   suite. Add tests that would have caught the bug, not tests that describe the new code.
6. **A preference that gates one call must gate every sibling call.** Phase 6 shipped a rest-timer
   notification setting that was honoured by the countdown and silently ignored by the completion
   alert three lines away. When you gate something, grep every other call into that same service.
7. **Do not modify files outside a task's stated scope.** `git diff HEAD` must stay a clean review
   surface.
8. **Commit per task**, in the order given. Run `flutter analyze` and `flutter test` before each
   commit. Do not proceed on a red suite.

---

## ARCHITECTURE MAP (what exists today — all verified at `4206e28`)

- **Schema** — `lib/data/database/app_database.dart`. `schemaVersion => 12` at line **156**;
  `MigrationStrategy` at **159**, `onUpgrade` at **161** with a chain of `if (from < N)` blocks, the
  most recent being `if (from < 12 && (from < 8 || from >= 10))` at **333**. `Exercises` table at
  line **10**; note the existing `BoolColumn get isTimed` at **24** as the shape to copy.
- **`BackupService`** (`lib/data/services/backup_service.dart`) — `_supportedSchemaVersions` at
  **26**, `_schemaVersion = 12` at **40**, `exportAndShare()` at **45**, `exportSetHistoryCsv()` at
  **71**, `importFromPicker()` at **82** (the `result?.files.single.path` bug is line **87**),
  `exportPayload()` at **208** with `'appSettings'` at **240**, `replaceFromPayload` deleting
  `appSettings` at **340** and reinserting at **399**. The audit calls this the best code in the repo
  — FKs enforced, validation inside the transaction, zip magic-byte sniffing, CSV formula-injection
  defence. **Preserve all of that.**
- **`SettingsRepository`** (`lib/data/repositories/settings_repository.dart`) — key constants at
  **97–113**. Device-local ones: `_kOnboardingComplete` (**105**), `_kHealthExportedSessionIds`
  (**113**).
- **`ExerciseAnatomyService`** (`lib/data/services/exercise_anatomy_service.dart`) — backfill key
  constants at **21–24** (`muscleAnatomyBackfilled`, `weightEntryBackfilled`,
  `pullUpExerciseBackfilled`, `timedExerciseBackfilled`), `backfillMuscleAnatomyOnce()` at **43**,
  and the dead `_applyAnatomyChanges` at **286** (called only from line **30**; `backfillMuscleAnatomyOnce`
  inlines the identical batch). `main.dart:27` is the single caller of the backfill.
- **`ExerciseRepository`** (`lib/data/repositories/exercise_repository.dart`) — `updateDetails` at
  **22** (name/category/bodyweightFactor/isTimed/tracksDistance), `updateDefaultUnit`, `updateVideoUrl`,
  `updateLoggingDefaults`, `updateMuscles` at **73** (takes **encoded strings**, not `Set<MuscleId>`),
  `archive`, and a guarded `delete`.
- **The exercise editor is trapped inside Settings.** `_editExerciseMuscles(context, ref, exercise)`
  at `lib/features/settings/settings_screen.dart:437` is a ~340-line private method on a settings
  widget: it builds a `showModalBottomSheet<_ExerciseEditorAction>` (**468**) over name, category,
  bodyweightFactor, videoUrl, isTimed, tracksDistance, and primary/secondary `Set<MuscleId>`, then
  saves via `updateDetails` (**773**) + `updateMuscles` (**781**) + `updateVideoUrl`. **Task 7.3
  extracts this.** The precedent is `lib/core/widgets/prescription_editor_sheet.dart` (287 lines),
  which Phase 4 extracted from exactly this file for exactly this reason.
- **`buildReminderSchedule`** (`lib/features/settings/reminder_scheduler.dart:43`) — a pure function
  returning `List<DateTime>` over a rolling `horizonDays` window (`_reminderHorizonDays = 28`, line
  **10**). `ReminderScheduler.sync(...)` at **71**/**87** calls it at **101**.
- **`recentPrs`** (`lib/core/domain/progress_analytics.dart:79`) — ranks on
  `WorkoutSetRecord.estimatedOneRepMaxKg`. `WorkoutSetRecord`
  (`lib/data/repositories/analytics_repository.dart:18`) already carries `weightEntry`, `sideCount`,
  and `loadingMode`. Two callers: `progress_screen.dart:55` and `active_session_screen.dart:770`.
- **Onboarding** (`lib/features/onboarding/onboarding_screen.dart`, 319 lines) — a `PageView.builder`
  (**145**) over a `List<_OnboardingPageData>` of purely informational pages
  (`_OnboardingPageData` at **307**: icon, eyebrow, title, body). `_complete()` at **112** writes
  `setTrainingGoal(_goal)` then calls `widget.onComplete()`; `OnboardingGate` calls
  `setOnboardingComplete()` at **42**. The last page already collects a real choice (training goal),
  so there is a pattern for an interactive page — **find it and follow it.**
- **`WorkoutSettings`** (`lib/core/domain/workout_settings.dart`) — `defaults` at line **12** is
  `restWeekdays: {7}, weeklyGoal: 6`. `restWeekdays` is consumed by `streak.dart` (**17**, **31**,
  **44**), `home_widget_service.dart:63`, `reminder_scheduler.dart` (**26**, **47**, **105**),
  `settings_screen.dart` (**2002**, **2174**), and `dashboard_screen.dart` (**83**, **87**).
  A per-weekday chip row already exists at `settings_screen.dart:2174` — **reuse its shape.**
- **Active session** (`lib/features/session/active_session_screen.dart`, ~1500 lines) — `_ExerciseCard`
  at **1150** renders each exercise; its existing `PopupMenuItem` block is around **926**;
  `onOpenPlates` threads a callback down at **1140**/**1173**/**1501**. This is the class Task 7.3
  adds an info affordance to.
- **`AppIcons`** (`lib/core/app_icons.dart`) — Phosphor icons. `close` (**25**), `chevronDown` (**27**),
  `edit`, `target`, `rest`, `minus`, `add` all exist. **There is no `info` icon yet** — add one
  (`PhosphorIconsRegular.info`) rather than reaching into the package at the call site.

---

# TASK 7.1 — A5: the streak calls a consistent lifter a failure 🟠

### The bug
`WorkoutSettings.defaults` is `restWeekdays: {7}` — Sunday only. `computeStreak`
(`lib/core/domain/streak.dart`) only bridges a gap on a day that is trained **or** a rest day, so a
Mon/Wed/Fri lifter who never opens Settings has a streak **permanently stuck at 1**, and
`_weekStates` in `dashboard_screen.dart` marks Tue/Thu as `WeekDayState.missed`. The dashboard tells
a perfectly consistent user they failed twice a week, forever. Onboarding never asks.

### Decided fix — ask in onboarding (Palash chose this on 2026-08-15)

Explicit over inferred. Do **not** infer training days from history — that is the same
infer-instead-of-declare pattern the audit filed as F1, and it is wrong for the first few weeks and
after every schedule change.

1. Add one **interactive** onboarding page: "Which days do you train?", a Mon–Sun chip row. Model it
   on the training-goal page that already exists (it is the last entry in `_pages` and its selection
   is held in `_goal` — open `_OnboardingScreenState` and follow that exact pattern rather than
   inventing a second one). `_OnboardingPageData` as declared today holds only static copy; extend
   it or special-case the interactive pages the same way the goal page already is.
2. The user picks **training** days; persist the complement as `restWeekdays`. Do not make the user
   reason about rest days — the setting is stored that way, the question is not asked that way.
3. Default the selection to **Mon/Wed/Fri** so Skip produces something sane rather than `{7}`.
   `_complete()` must write the weekdays alongside `setTrainingGoal(_goal)` on **both** the finish
   and Skip paths — Skip currently routes through `_complete()` too (line **139**); confirm that.
4. **Existing installs never see onboarding again.** They keep `{7}`. Do not migrate them silently —
   instead make the settings row at `settings_screen.dart:2174` discoverable enough to fix by hand,
   and leave a comment saying why no migration was written (guessing a training split from history
   would be the F1 mistake at a worse moment).

### Acceptance
- [ ] A fresh install is asked for training days and the answer reaches `restWeekdays`.
- [ ] Skipping onboarding yields Mon/Wed/Fri, not Sunday-only.
- [ ] A Mon/Wed/Fri lifter's streak survives Tue and Thu, and the dashboard stops marking them missed.
- [ ] Unit test on `computeStreak` with `restWeekdays: {2,4,6,7}` and a Mon/Wed/Fri log: streak counts
      the full run. **Check this test fails against today's `{7}` default.**

---

# TASK 7.2 — I2: library anatomy corrections can never reach an existing install 🟠 (schema **v13**)

### The bug
`backfillMuscleAnatomyOnce()` (`exercise_anatomy_service.dart:43`) is guarded by a permanent,
unversioned boolean (`muscleAnatomyBackfilled`, line **21**). The guard exists to protect user edits
to bundled exercises (finding I1, which is otherwise correct) — but because it never re-runs, it
throws out **library fixes** along with them. `assets/data/exercise_library.json` was under active
edit during the audit; every anatomy correction in it reaches fresh installs only.

### Decided fix — a per-exercise dirty flag, and a versioned backfill (Palash approved v13 on 2026-08-15)

1. **`Exercises.anatomyEditedByUser`** — `BoolColumn ... .withDefault(const Constant(false))()`.
   Copy the shape of `isTimed` at `app_database.dart:24`.
2. **Bump `schemaVersion` to 13** (line **156**) and add `if (from < 13) { await migrator.addColumn(...); }`
   to `onUpgrade`. Existing rows default to `false` — which is *deliberately optimistic*: it means the
   first versioned backfill may overwrite an anatomy edit made before this flag existed. Say so in a
   comment. The alternative (defaulting every existing row to `true`) would permanently freeze every
   install at its current anatomy, which is the exact bug being fixed.
3. **Bump `BackupService._schemaVersion` to 13** (line **40**) and **add 13 to
   `_supportedSchemaVersions`** (line **26**). Both. Phase 1 and Phase 3 each did this; grep those
   commits if unsure.
4. **Replace the boolean guard with a version integer.** `muscleAnatomyBackfilled` becomes something
   like `muscleAnatomyBackfillVersion` (an int). Bump a `const _anatomyBackfillVersion` in the service
   whenever the library's anatomy changes; the backfill runs when the stored version is lower, and
   **skips any row with `anatomyEditedByUser == true`**. Migrate the old boolean: `true` → version 1.
5. **Every writer of muscles must set the flag.** `ExerciseRepository.updateMuscles` (**73**) is the
   single choke point — set `anatomyEditedByUser: const Value(true)` inside it, not at its call sites.
   That is ground rule 3, and it is what makes Task 7.3 safe: the new in-session editor gets the
   protection for free.
6. **I4 — delete `_applyAnatomyChanges`** (line **286**) and its call at **30** if that call is itself
   dead; the audit says `backfillMuscleAnatomyOnce` inlines the identical batch. **Confirm before
   deleting** — if line 30 is on a live path, leave it and say so.

### Acceptance
- [ ] Schema is **13**, `BackupService._schemaVersion` is **13**, and `_supportedSchemaVersions`
      contains 13 **and** every version it contained before.
- [ ] Migration test: a v12 database upgrades to v13 with `anatomyEditedByUser` present and `false`.
- [ ] Test: a row with `anatomyEditedByUser = true` is untouched by a version-bumped backfill; a row
      with `false` is corrected.
- [ ] Test: `updateMuscles` sets the flag.
- [ ] A v12 backup still imports (that is what `_supportedSchemaVersions` is for).

---

# TASK 7.3 — 🆕 exercise info and editing, reachable from inside a workout (user-requested)

> Palash, 2026-08-15: *"I want to be able to edit everything from everywhere — in an active workout I
> want to click an info button to see info about the exercise, what muscles it targets primarily and
> secondarily, and be able to edit and save them."*

This also closes **G5** (bias and anatomy are invisible outside the editor) and part of **I3/F3**
(name, category, bodyweightFactor uneditable where you actually notice they are wrong).

### The problem is reach, not capability
The editor already exists and is already correct — it is just **buried inside
`settings_screen.dart:437` as a private method on a settings widget**, so the only route to it is
Settings → Manage exercises. Mid-workout, when you actually notice a wrong muscle assignment or a
wrong bodyweight factor, it is four navigations away.

### Decided fix — extract, then reuse. Do NOT write a second editor.

1. **Extract** `_editExerciseMuscles` (**437–~800**) into
   `lib/core/widgets/exercise_editor_sheet.dart`, following `prescription_editor_sheet.dart` exactly
   — that file is the house pattern for "a sheet Phase 4 pulled out of settings_screen so two
   features could share it". Move `_ExerciseEditorAction` and the muscle-picker sheet at
   `settings_screen.dart:1511` with it if they are not used elsewhere; **grep before moving.**
2. **`settings_screen.dart` must then call the extracted sheet** and lose its private copy. If the
   behaviour changes at all in Settings, you have extracted it wrong. This is a move, not a rewrite.
3. **Add an info affordance to `_ExerciseCard`** (`active_session_screen.dart:1150`). One icon button
   in the card header (`AppIcons.info` — add it to `lib/core/app_icons.dart`, do not reach into
   Phosphor at the call site). It opens a **read-first** sheet:
   - Exercise name, category, and whether it is timed / tracks distance.
   - **Primary muscles and secondary muscles, named and readable** — this is the part Palash asked
     for. `decodeMuscleIds` + the existing `MuscleId` display names; reuse
     `lib/features/exercise/widgets/muscle_anatomy_view.dart` if it can render at sheet size, and if
     it cannot, show a plain labelled list rather than shrinking a 865-line 3D view into a sheet.
   - `bodyweightFactor`, and the video link if set.
   - An **Edit** button that opens the extracted editor sheet on top, and on save refreshes the
     session card in place.
4. **Saving from the session must go through `ExerciseRepository.updateMuscles`** so Task 7.2's
   `anatomyEditedByUser` flag is set. Do not add a second write path. If you find yourself writing a
   new `update...` method on the repository for this, stop — the existing ones cover it.
5. **The session list must refresh after a save.** `_ActiveSessionScreenState` uses
   `setState(_refresh)`; follow that, and confirm the exercise name shown on the card updates if the
   name was edited.
6. **Editing a bundled exercise stays permitted** — finding I1 confirms this is already correct and
   deliberate. Do not add a "bundled exercises are read-only" guard; the protection is the dirty flag
   from Task 7.2, not a lock.

### Acceptance
- [ ] The editor lives in exactly **one** file and both Settings and the active session call it.
- [ ] `settings_screen.dart` is shorter by roughly the extracted amount and behaves identically.
- [ ] An info button on each exercise card in an active workout opens a sheet naming primary and
      secondary muscles.
- [ ] Editing muscles from inside a workout saves, refreshes the card, and sets `anatomyEditedByUser`.
- [ ] Widget test: the info sheet renders primary and secondary muscle names for a known exercise.
- [ ] Widget test: saving from the session sheet calls `updateMuscles` exactly once.

---

# TASK 7.4 — L1/L2/L3: the backup lies about device state 🟠

### 7.4a — L1: device-local state rides along in a portable backup
`exportPayload()` (**208**) exports the whole `appSettings` table (**240**) and `replaceFromPayload`
restores it wholesale (**340**/**399**). That table holds device-local markers:
`healthExportedSessionIds`, `muscleAnatomyBackfilled` (now a version — Task 7.2),
`weightEntryBackfilled`, `pullUpExerciseBackfilled`, `timedExerciseBackfilled`, `onboardingComplete`.

Two failures, in both directions:
- **Restoring onto a new phone**: the markers claim every session is already in Apple Health, but
  that phone's Health store is empty. Those workouts are **never** exported, and there is no UI to
  reset the markers. (This is the 2026-07-26 duplicate-health-record lesson resurfacing from the
  other side.)
- **Restoring a pre-v2 backup**: `_optionalRows` returns `[]`, so `appSettings` ends up empty,
  clearing the backfill flags. Next launch, the backfill re-runs and **overwrites the user's restored
  anatomy edits**, defeating I1 through a side door — and `onboardingComplete` is cleared, dropping
  the user back into onboarding on top of their restored data.

**Fix:** define one `static const Set<String> _deviceLocalSettingKeys` in `BackupService` and filter
it out on **export** *and* skip it on **import**, so old backups that still contain those keys are
also handled. Both sides — a filter on export alone leaves every existing backup file dangerous.
Note that Task 7.2's `anatomyEditedByUser` is a **column on Exercises**, not a setting, so it
correctly stays in the backup; only the *backfill version* is device-local.

### 7.4b — L2: `importFromPicker` throws outside the normalised error path
Line **87**: `result?.files.single.path`. `.single` raises `StateError` when the picker returns zero
or multiple files, bypassing the `FormatException` contract `_decodeBackup` carefully maintains for
the caller's single error path. Use `firstOrNull` (`package:collection`, already a transitive dep —
**confirm it is a direct dependency in `pubspec.yaml` before importing it**; if it is not, use
`isEmpty ? null : first`).

### 7.4c — L3: exported files accumulate 🟢
`exportAndShare()` (**45**) and `exportSetHistoryCsv()` (**71**) write timestamped files into the temp
directory and never delete them. Delete files older than a day from that directory on the next
export, or write to a single reused filename. Do **not** delete the file immediately after sharing —
the share sheet reads it asynchronously.

### Acceptance
- [ ] Test: `exportPayload()` contains no device-local key.
- [ ] Test: importing a payload that *does* contain them leaves the local values untouched.
- [ ] Test: a pre-v2 backup (no `appSettings`) imports without clearing `onboardingComplete` or the
      backfill version. **Check this fails against today's code.**
- [ ] `importFromPicker` returns `false` or throws `FormatException` for a zero-file pick — never
      `StateError`.
- [ ] Every existing backup-service test still passes; the transaction and FK behaviour is unchanged.

---

# TASK 7.5 — M1/M2: reminders switch themselves off exactly when they matter 🟠

### 7.5a — M1
`buildReminderSchedule` (**43**) builds a rolling 28-day window of one-shot alerts, refreshed only on
app open, settings change, or workout logged. **A user who lapses for a month stops getting
reminders** — the feature turns itself off precisely when it is the only thing that could bring them
back.

The rolling-window design is otherwise correct and must stay: it is what lets a one-off rest day or a
completed workout suppress a specific day, which a repeating alarm cannot do. It needs a **floor**,
not a replacement.

**Fix:** keep the window, and additionally schedule **one plain weekly repeating alert beyond the
horizon** as a backstop, so the chain never fully empties. Use the existing plugin surface — check
whether `NotificationClient` can express a repeating alert today and **add a narrow method to the
interface if it cannot**, in the plugin-free style of `showRestCountdown` (Phase 6 is the reference
for how to extend that interface). Keep it on its own channel id so its importance is independent.
**Respect the reminder-enabled setting on both the window and the backstop** — ground rule 6.

### 7.5b — M2 🟢
`_details()` hardcodes `channelDescription: 'Logged workout reminders'` for every channel. Android
surfaces this text in system notification settings, so the rest-timer channel currently describes
itself as a reminder. Phase 6 already gave the countdown channel its own description; do the same for
the rest. `_details`'s **signature is shared with the coaching reminders — extend it carefully or add
an optional named parameter with the current string as its default**, so no existing caller changes
behaviour.

### Acceptance
- [ ] Test: with the window exhausted, a backstop alert is still scheduled.
- [ ] Test: disabling reminders cancels the backstop too, not just the window.
- [ ] No new permission in `AndroidManifest.xml`. No new package.
- [ ] Existing `reminder_scheduler` tests unchanged and passing.

---

# TASK 7.6 — A9: fake PRs across weight-entry modes 🟡

`recentPrs` (`progress_analytics.dart:79`) ranks on `estimatedOneRepMaxKg`, which uses the **entered**
value. Log a dumbbell press as `30 per hand`, later re-log the same effort as `60 total`, and the app
fires an all-time-PR celebration for a lift that did not happen.

`WorkoutSetRecord` already carries `weightEntry` (`analytics_repository.dart:27`), so the data is
there. **Key the `best` map on `(exerciseId, weightEntry)` rather than `exerciseId`**, so a PR is only
ever compared against the same entry mode. Note the map is `<int, double>` today — a record key
`(int, WeightEntry)` works in current Dart; confirm the analyzer agrees before reaching for a
composite string key.

Grep both callers (`progress_screen.dart:55`, `active_session_screen.dart:770`) and confirm neither
depends on one entry per exercise.

### Acceptance
- [ ] Test: 30 kg per-hand then 60 kg total on the same exercise produces **no** PR event.
      **Check it fails against today's code.**
- [ ] Test: a genuine increase within one entry mode still produces a PR.

---

# TASK 7.7 — N1/N3: accessibility, text scale, and a theme switch 🟠

### 7.7a — N1
Across 29,571 lines there are **5** `Semantics`/`semanticLabel` usages and **0** references to
`textScaler`. Combined with fixed-height layout, a user with large system text hits overflow on the
two screens used most during a workout. Confirm the current numbers with a grep before trusting them.

Scope this deliberately — a full accessibility pass is its own project. Do **these**, on the set
editor and the dashboard stat tiles only:
- Replace fixed heights that wrap text with intrinsic or constrained-minimum layout. The audit names
  `SizedBox(height: 56)` around the unit `SegmentedButton`, `ConstrainedBox(maxHeight: screenHeight * 0.85)`
  on the sheets, and `IntrinsicHeight` rows on the dashboard. **Grep for the current shape; do not
  trust these snippets verbatim.**
- Add `semanticLabel` / `Semantics` to icon-only buttons on those two screens. The 20 existing
  `tooltip:` usages are **not** labels and do not count.
- Verify at `textScaleFactor` 2.0 in a widget test (`MediaQuery` override with
  `TextScaler.linear(2.0)`), asserting no overflow. That test is the deliverable — a manual look is
  not.

### 7.7b — N3 🟢
`themeMode: ThemeMode.system` is hardcoded in `main.dart` with no override. Add a
system/light/dark setting, persisted through `SettingsRepository` alongside the existing keys at
**97–113**, and read in `main.dart`.

### Acceptance
- [ ] Widget test at `TextScaler.linear(2.0)`: the set editor and the dashboard stat tiles render
      without a `RenderFlex` overflow.
- [ ] Icon-only controls on those two screens carry semantic labels.
- [ ] The theme setting persists across a restart.

---

# EXPLICITLY OUT OF SCOPE (decided — do not build these, do not "notice" them mid-task)

These are real audit findings deliberately left unbuilt. Each has a reason; if you disagree, say so
in the final report rather than implementing it.

| ID | Why not now |
|---|---|
| **N2** localization | Every UI string is hardcoded English while `intl` localizes dates, giving mixed-language output on a non-English device. Real, and its own project — an ARB extraction across 29,571 lines does not belong in a phase that also changes the schema. |
| **A10** `_volumeAdequacy` step discontinuities | 7.9 effective sets → 0.55, 8.0 → 0.75. Intentional as a threshold model. Smoothing it is a **product decision about how the rank should feel**, not a bug fix. Ask Palash before touching it. |
| **A11** `muscleVolumeThisWeek` on the legacy `muscle_group` string | Two parallel muscle vocabularies is a genuine structural wart, but unifying it means rewriting `analytics_repository.dart`'s raw SQL (`line 106`), which Phase 1 just stabilised for A1/A2 and which feeds three surfaces. Not in the same phase as a schema bump. |
| **G3** secondary muscles cannot be biased | Needs a design pass on the bias editor. Task 7.3 makes secondary muscles *visible* in-session, which is the useful half. |
| **H4** warm-up sets have no number | Cosmetic. |
| **I3/F3** name & bodyweightFactor on bundled exercises | Already editable via the extracted sheet once Task 7.3 lands — verify that and note it, rather than writing anything new. |

---

# EXPLICIT DO NOTs

- **Do not** add a package for anything above. If you believe one is required, stop and say why.
- **Do not** change `schemaVersion` anywhere except Task 7.2, and when you do, change
  `BackupService._schemaVersion` **and** `_supportedSchemaVersions` in the same commit.
- **Do not** weaken `backup_service.dart`: FKs enforced in `beforeOpen`, validation inside the
  transaction, zip magic-byte sniffing, and `_csvField`'s formula-injection defence all stay.
- **Do not** write a second exercise editor. Task 7.3 is an extraction; two editors is the F1 mistake
  repeated at the UI layer.
- **Do not** add a second write path for muscles. `ExerciseRepository.updateMuscles` is the choke
  point that sets the dirty flag.
- **Do not** infer training days from logged history (Task 7.1) — explicitly rejected.
- **Do not** remove the rolling reminder window in favour of a repeating alarm (Task 7.5) — the
  window is what makes per-day suppression possible.
- **Do not** register `onDidReceiveBackgroundNotificationResponse`. Phase 6 left it off on purpose:
  separate isolate, cannot reach the Riverpod container, produces a button that lies.
- **Do not** add network calls, analytics, crash reporting, or accounts. The local-only guarantee is
  the product.

---

# PHASE 7 VERIFICATION

```bash
flutter analyze          # must be clean
flutter test             # must be green, and higher than 301
```

Then, because this phase changes the schema:

```bash
flutter clean && flutter pub get && (cd ios && pod install)
```

Record what you did and did **not** verify in `tasks/todo.md`, following the format of the Phase 6
entry already there. Be explicit about anything you skipped — an honest "not verified" is worth more
than an unverified checkmark.

## What Phase 7 owes the end-to-end run

Palash runs the whole application after this phase. Everything below has **never** touched hardware
across the entire remediation, and this is the list that gets worked through then — do not attempt
it, but do not let it disappear either:

1. The Copenhagen Plank check and a real-device restore of a **≤ v11** backup (carried since Phase 3).
2. All of Phase 4's and Phase 5's manual flow checks.
3. All of Phase 6's rest-timer notification behaviour — the lock-screen countdown, the flip to "Rest
   complete" at zero, the backgrounded +15s action, the iOS notification-centre pull, plus the two
   review fixes only a device can settle (the ring resync after backgrounding, and `timeoutAfter`
   reaping an orphaned `ongoing` notification).
4. **New in this phase:** a real v12 → v13 upgrade on a populated device database, and a restore of a
   backup taken *before* 7.4a onto a second device with Apple Health enabled.

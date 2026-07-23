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

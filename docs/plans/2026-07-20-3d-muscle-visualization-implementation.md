# Live 3D Muscle Visualization Implementation Plan

**Design:** `docs/plans/2026-07-20-3d-muscle-visualization-design.md`  
**Date:** 2026-07-20  
**Execution style:** Test-first, staged, and reversible

## Constraints

- Preserve existing user changes; most project files are currently untracked.
- Do not remove the broad `muscleGroup` field.
- Complete detailed anatomy metadata for all 200 bundled exercises before integrating the 3D UI.
- The model state is Monday-to-now but reacts to every saved working set, including active sessions.
- Keep the existing weighted, completed-session analytics for PR and volume charts separate from the live muscle-state analytics.
- Keep a 2D fallback until the native renderer passes Android and iOS acceptance checks.
- Do not change the globally installed Flutter SDK without explicit approval; prefer a project-local/isolated upgrade if practical.

## Phase 0: Establish a Baseline

### Files

- No product-file changes.

### Steps

1. Record `flutter --version`, Android minimum SDK, and iOS deployment target.
2. Run the existing test suite and analyzer.
3. Build at least one current debug target if the local toolchain supports it.
4. Record pre-existing warnings or failures rather than folding them into later work.

### Verification

```sh
flutter test
flutter analyze
flutter build apk --debug
```

## Phase 1: Define and Map Detailed Exercise Anatomy

This is the first product change, as requested.

### Files

- Create `lib/core/domain/muscle.dart`.
- Update `assets/data/exercise_library.json`.
- Create `test/core/muscle_test.dart`.
- Update `test/data/exercise_library_asset_test.dart`.

### Domain model

Define a stable `MuscleId` enum or sealed value with JSON IDs and friendly labels for:

- `upperChest`, `midLowerChest`
- `frontDelts`, `sideDelts`, `rearDelts`
- `lats`, `upperTraps`, `midLowerTraps`, `rhomboids`, `spinalErectors`
- `biceps`, `brachialis`, `triceps`, `forearms`
- `abs`, `obliques`, `hipFlexors`
- `quads`, `hamstrings`, `gluteMax`, `gluteMedMin`, `adductors`, `calves`, `tibialisAnterior`

Provide strict `fromId`, `id`, and display-label behavior. Unknown IDs must fail validation rather than silently map to a broad region.

### Exercise metadata

Add `primaryMuscles` and `secondaryMuscles` arrays to every one of the 200 JSON entries. Map each exercise by its actual movement rather than its old coarse group. Examples:

- Bench press: mid/lower chest primary; front delts and triceps secondary.
- Incline bench press: upper chest primary; front delts and triceps secondary.
- Pull-up/pulldown: lats primary; biceps, brachialis, and mid/lower traps secondary.
- Back squat: quads and glute max primary; hamstrings, adductors, spinal erectors, and abs secondary.
- Lateral raise: side delts primary; upper traps secondary.
- Cycling: quads primary; glute max, hamstrings, and calves secondary.
- Mobility/stretching: map the explicitly targeted anatomy; do not invent unsupported secondary targets.

### Tests written first

- Asset still contains exactly 200 exercises.
- Every entry has a non-empty primary list.
- Every ID parses as `MuscleId`.
- Lists contain no duplicates.
- A muscle cannot be both primary and secondary for one exercise.
- Representative compounds, isolation movements, cardio, and mobility entries have expected mappings.
- `MuscleId` JSON round-trips.

### Verification

```sh
flutter test test/core/muscle_test.dart test/data/exercise_library_asset_test.dart
dart format lib/core/domain/muscle.dart test/core/muscle_test.dart test/data/exercise_library_asset_test.dart
```

## Phase 2: Persist Anatomy and Upgrade Existing Libraries

### Files

- Update `lib/data/database/app_database.dart` and regenerate `app_database.g.dart`.
- Update `lib/data/services/exercise_seed_service.dart`.
- Create `lib/data/services/exercise_anatomy_service.dart`.
- Update `lib/main.dart`.
- Update `lib/features/settings/settings_screen.dart`.
- Update `lib/data/services/backup_service.dart`.
- Update `test/data/exercise_seed_service_test.dart`.
- Update `test/data/backup_service_test.dart`.
- Create `test/data/exercise_anatomy_service_test.dart`.
- Add a database migration test under `test/data/`.

### Database

1. Advance Drift schema from 2 to 3.
2. Add text columns for JSON-encoded primary and secondary muscle IDs, with safe empty-list defaults for migration.
3. Add the columns in `onUpgrade` when `from < 3`.
4. Regenerate Drift code.

### Seed and enrichment

1. New installs seed both anatomy fields from the bundled asset.
2. Existing non-custom exercises are enriched by exact stable exercise name.
3. Enrichment is idempotent and fills stale/empty bundled mappings.
4. Custom exercise anatomy is never overwritten.
5. Run enrichment during startup after the database opens and after an old backup import.
6. A failed enrichment reports a recoverable error without deleting data or preventing app startup.

### Custom exercise UX

1. Add a required primary-muscle multi-select.
2. Add an optional secondary-muscle multi-select that excludes primary selections.
3. Show an **Assign muscles** action for legacy custom exercises with no anatomy.
4. Keep the existing exercise category and broad `muscleGroup` behavior intact.

### Backup

1. Export schema version 3.
2. Include the generated exercise anatomy fields.
3. Continue accepting versions 1 and 2.
4. Up-convert old exercise JSON to empty anatomy lists before `Exercise.fromJson`.
5. Run bundled-exercise enrichment after a successful old-backup import.

### Tests written first

- v2-to-v3 migration retains all exercise and workout rows.
- New columns default safely.
- New install seeds all 200 detailed mappings.
- Existing install enrichment updates bundled exercises and leaves custom exercises untouched.
- Repeated enrichment is stable.
- Custom exercise validation rejects an empty primary list and overlap.
- Backup v3 round-trips anatomy.
- Backup v1/v2 import remains valid.

### Verification

```sh
dart run build_runner build --delete-conflicting-outputs
flutter test test/data
flutter analyze
```

## Phase 3: Add Live Set-Based Muscle Analytics

### Files

- Create `lib/core/domain/live_muscle_state.dart`.
- Update or extend `lib/core/domain/muscle_map.dart` for detailed-to-broad fallback mapping.
- Update `lib/data/repositories/analytics_repository.dart` without altering existing PR/volume semantics.
- Update `lib/data/providers.dart`.
- Create `test/core/live_muscle_state_test.dart`.
- Update `test/core/progress_analytics_test.dart` only where fallback aggregation requires it.
- Create `test/data/live_muscle_analytics_repository_test.dart`.

### Repository separation

Keep `completedSetsProvider` and its completed, weighted-set query for PR and volume charts. Add a separate live muscle query/provider that:

- Includes sessions with `ended_at IS NULL`.
- Includes all persisted set rows, not only rows with weight and reps.
- Watches exercises, sessions, session exercises, and set entries.
- Carries `isWarmup`, exercise name, primary IDs, secondary IDs, and session start time.

### Aggregation

1. Filter to the local Monday-based current week.
2. Exclude warm-up sets.
3. Add `1.0` to each primary muscle and `0.35` to each secondary muscle.
4. Aggregate contribution details by exercise.
5. Convert effective sets to a stable intensity band/continuous color input capped at 12+.
6. Produce a broad `BodyRegion` aggregation for the 2D fallback.

### Tests written first

- Active-session set is present before workout completion.
- Saving a second set increments immediately.
- Warm-up set is excluded.
- Edit, delete, and warm-up changes recompute through the watched query.
- Prior-week and future rows are excluded.
- Primary/secondary weights are exact.
- Blank-but-deliberately-saved, bodyweight, duration, and distance rows count once.
- Unknown/unassigned custom anatomy does not crash or guess.
- Intensity uses fixed thresholds rather than busiest-muscle normalization.

### Verification

```sh
flutter test test/core/live_muscle_state_test.dart test/data/live_muscle_analytics_repository_test.dart
flutter test
flutter analyze
```

## Phase 4: Prove the Native Renderer

This phase is a compatibility gate before processing the full model.

### Approval/toolchain gate

The installed Flutter SDK is 3.41.9 while `interactive_3d` 2.2.0 declares Flutter 3.44+. Before changing the global SDK, either:

1. Install/use an isolated project SDK, or
2. Obtain approval to upgrade the global stable Flutter SDK.

### Files

- Update `pubspec.yaml` and `pubspec.lock`.
- Update Android minimum SDK to 24.
- Confirm iOS deployment target remains at least 13.
- Create a temporary/prototype renderer adapter under `lib/features/exercise/widgets/`.
- Add a small licensed chest/shoulder GLB and lighting asset under `assets/models/prototype/`.

### Prototype acceptance

- Bundled GLB loads offline.
- One-finger rotation and pinch zoom work.
- Named chest/shoulder entities can be tapped.
- Runtime material override works independently on both platforms.
- The native view coexists with vertical `ListView` scrolling.
- The renderer can be disposed/recreated without a crash or leaked surface.
- Light/dark background changes remain legible.

If this gate fails, evaluate a compatible pinned version or Thermion behind the same adapter before changing analytics or UI design.

### Verification

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
```

Physical-device interaction checks are required for this phase.

## Phase 5: Build the Reproducible Z-Anatomy Asset

### Files

- Create `tools/blender/prepare_muscle_model.py`.
- Create `tools/blender/README.md` with pinned source and exact command.
- Add source/license records under `assets/models/licenses/`.
- Create `assets/models/muscular_body.glb`.
- Create `assets/models/muscular_body_manifest.json`.
- Create or update `THIRD_PARTY_NOTICES.md`.
- Create `test/data/muscle_model_manifest_test.dart`.

### Processing

1. Pin the Z-Anatomy source commit.
2. Inventory source object names and map them to app `MuscleId` values.
3. Keep only required visible/workout-relevant structures.
4. Preserve and normalize left/right entities.
5. Rename output entities deterministically.
6. Decimate carefully and share mobile-friendly materials.
7. Export GLB headlessly.
8. Validate GLB structure and manifest completeness.
9. Record attribution and CC BY-SA obligations.

### Asset acceptance

- Every `MuscleId` maps to at least one model entity.
- Every manifest entity exists in the GLB.
- No two muscle IDs accidentally claim the same entity unless explicitly documented.
- Model meets the approximate triangle/entity/size budgets.
- Front, rear, and side contours remain recognizable.
- Neutral and highlighted PBR materials look acceptable in both themes.

## Phase 6: Integrate the Live 3D Progress Card

### Files

- Create `lib/features/exercise/widgets/muscle_model_view.dart` as the app-owned renderer boundary.
- Create `lib/features/exercise/widgets/interactive_muscle_model.dart` for the native implementation.
- Create `lib/features/exercise/widgets/muscle_model_controller.dart` if controller separation is needed.
- Create `lib/features/exercise/widgets/muscle_breakdown.dart`.
- Update `lib/features/exercise/progress_screen.dart`.
- Update `lib/features/exercise/widgets/muscle_heatmap.dart` only for detailed fallback input.
- Add widget tests under `test/features/exercise/`.

### Behavior

1. Mount the model once for the Progress renderer lifecycle.
2. Apply the current live state as initial material overrides after load.
3. Diff later state and update only changed entities.
4. Do not reload the GLB after each set.
5. Add front, back, and reset-camera controls.
6. Add the fixed effective-set legend and gesture hint.
7. Map native entity selection back to `MuscleId`.
8. Show friendly muscle details and exercise contributions.
9. Add neutral/no-data copy.
10. Add loading, failure, retry, and 2D fallback states.

### Accessibility

- Add an overall semantic label and gesture hint.
- Add an expandable, keyboard/screen-reader-accessible muscle breakdown list.
- Selecting a list row selects/focuses the same muscle in the model.
- Ensure controls meet minimum touch target size and color is never the sole signal.

### Tests written first

- Fake renderer receives one load and incremental material changes.
- Provider change after a saved set updates the model command stream.
- Entity tap resolves to correct muscle details.
- Neutral, loading, failed, fallback, retry, and loaded states.
- Accessible list and 3D detail data stay identical.
- Current weekly volume and PR sections retain their completed-session behavior.

## Phase 7: License UI and Full Verification

### Files

- Update `lib/features/settings/settings_screen.dart` with attribution.
- Finalize `THIRD_PARTY_NOTICES.md`.
- Update relevant README documentation.

### Automated verification

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
flutter build apk --debug
flutter build ios --debug --no-codesign
```

### Manual acceptance

1. Open Progress with no current-week sets; neutral model appears.
2. Start a workout and save one bench-press working set.
3. Return to or reveal Progress; chest, front delts, and triceps update without finishing the session.
4. Add a pulldown set; lats, biceps, and supporting back regions update.
5. Edit, delete, and mark sets as warm-up; colors and contribution details reverse correctly.
6. Rotate, zoom, tap, reset, and use the accessible breakdown list.
7. Verify light/dark theme, scroll gesture arbitration, renderer retry, and 2D fallback.
8. Verify backup export/import, including an older backup.
9. Measure GLB size, initial load time, memory use, idle behavior, and release-size impact.

### Completion criteria

- All 200 bundled exercises have validated anatomy metadata.
- Every saved working set updates live current-week muscle state.
- Android and iOS native 3D behavior passes physical-device checks.
- No regression to PR, volume, history, logging, backup, or custom exercises.
- Attribution is visible and the derived model is distributed with the required license information.
- Analyzer, tests, and platform debug builds pass.

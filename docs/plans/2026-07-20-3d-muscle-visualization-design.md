# Live 3D Muscle Visualization Design

**Status:** Implemented
**Date:** 2026-07-20  
**Product:** Logged (Flutter, Android and iOS)

## Context

The Progress screen currently renders a stylized front/back `CustomPainter` heatmap. Its input is weekly weighted volume grouped into nine broad body regions. The 200 bundled exercises each have a single coarse `muscleGroup` value such as `chest`, `arms`, or `quads/hamstrings/glutes`.

The replacement should show a realistic, skinless male anatomical model. A user can rotate and zoom the model, tap a muscle, and see which exercises trained it. The state is cumulative from Monday through the current day, but it updates after every saved working set, including sets saved before the active workout is finished.

## Goals

- Render a realistic, interactive, fully offline 3D muscular model on Android and iOS.
- Map every bundled exercise to detailed primary and secondary muscles before exposing the new visualization.
- Update highlighted muscles after every saved, non-warm-up set.
- Include weighted, bodyweight, cardio, and mobility work.
- Keep colors comparable between weeks by using fixed effective-set thresholds.
- Let users rotate, zoom, tap, and inspect muscles.
- Preserve accessibility and a resilient 2D fallback.
- Use only a free, explicitly reusable anatomical source.

## Non-goals

- Medical diagnosis or a clinically complete anatomical atlas.
- Per-limb intensity until the workout logger records left/right performance.
- Cloud rendering, downloaded models, accounts, or network dependencies.
- Unity or a separate game-engine project.
- Replacing the existing broad muscle group used for exercise search.

## Selected Approach

Use Adamas Designs' mobile-ready `muscular.glb`, whose geometry is derived from BodyParts3D and whose naming/identification process references [Z-Anatomy](https://github.com/Z-Anatomy/Models-of-human-anatomy), rendered through [`interactive_3d`](https://pub.dev/packages/interactive_3d). The compiled GLB is distributed under CC BY-SA 4.0. `interactive_3d` provides native Filament rendering on Android and SceneKit/GLTFSceneKit rendering on iOS, named-entity selection, gestures, visibility control, and runtime PBR material overrides.

This is preferred over a WebView-based `<model-viewer>` integration because dynamic per-muscle selection and material updates would require a custom JavaScript bridge. An embedded Unity view would add disproportionate build size and integration complexity.

`interactive_3d` 2.1.0 is pinned because it contains runtime PBR material overrides while remaining compatible with Flutter 3.41.9. It requires Android API 24; the project already exceeds its iOS 12 requirement with an iOS 13 deployment target. No Flutter SDK upgrade is required.

## Architecture

### 1. Exercise anatomy

Advance the database to schema version 3 and add nullable JSON-backed primary- and secondary-muscle lists to `Exercises`. Keep the current `muscleGroup` field for search, display, old backups, and compatibility.

Extend `assets/data/exercise_library.json` so all 200 bundled exercises contain:

```json
{
  "muscleGroup": "chest",
  "primaryMuscles": ["mid_lower_chest"],
  "secondaryMuscles": ["front_delts", "triceps"]
}
```

The first implementation stage must finish and validate all 200 mappings. The 3D view must not ship with partial bundled metadata.

On an existing installation, an anatomy-enrichment service matches non-custom bundled exercises by stable exercise name and writes the new lists. If an imported or bundled entry cannot be matched, its detailed anatomy remains unassigned and is surfaced for correction rather than guessed.

New custom exercises require at least one primary muscle and allow zero or more secondary muscles. Existing custom exercises remain usable but show an **Assign muscles** action until completed.

Backup schema version 3 carries the new exercise fields. Imports remain tolerant of schema versions 1 and 2; imported bundled exercises are enriched after the transaction, while old custom exercises remain explicitly unassigned.

### 2. Muscle taxonomy

The app uses familiar fitness regions while the GLB retains realistic anatomical shapes. One app muscle ID can address multiple left/right anatomical entities.

- Chest: upper chest, mid/lower chest, serratus anterior
- Shoulders: front delts, side delts, rear delts, rotator cuff
- Back: lats, upper traps, mid/lower traps, rhomboids, spinal erectors
- Arms: biceps, brachialis, triceps, forearms
- Core: abs, obliques, hip flexors
- Lower body: quads, hamstrings, glute max, glute med/min, adductors, calves, tibialis anterior
- Neck: separately tracked for mobility and secondary shrug contribution; shown in text when the selected superficial GLB has no dedicated neck mesh

A typed `MuscleId` domain model owns stable IDs and user-facing labels. A bundled model manifest maps each `MuscleId` to the GLB entity names that must be colored or selected. The manifest decouples workout analytics from future model revisions.

### 3. Live current-week analytics

Replace the heatmap-only aggregation with a reactive live muscle-state query that watches exercises, sessions, session exercises, and set entries.

The time window is the device-local Monday start through now. Unlike the existing Progress query, it includes active sessions; `sessions.ended_at` is not required. A persisted `SetEntry` created by pressing **Save** is complete for this visualization. Warm-up rows are excluded.

Each saved working set contributes:

- `1.0` effective set to every primary muscle.
- `0.35` effective set to every secondary muscle.

This deliberately does not use weight multiplied by repetitions. It allows bodyweight and duration-based activity to register and avoids making heavy lower-body lifts dominate solely because their loads are larger. Cardio or mobility entries count as one exposure per saved set entry.

Edits, deletions, and changes between warm-up and working-set status recompute the state immediately. Both left and right meshes receive the same value because side-specific set data is not stored.

The provider returns, per muscle:

- Effective sets.
- Primary and secondary contribution totals.
- Fixed display intensity.
- Contributing exercise names and set counts.

Display bands are stable across weeks: untrained, 1–3, 4–7, 8–11, and 12+ effective sets. Rendering may interpolate within these bands, but one set must not appear as a fully trained muscle merely because it is the busiest region that week.

### 4. 3D asset and renderer

Bundle a single optimized GLB and an entity manifest under `assets/models/`. The renderer receives live muscle state through Riverpod and applies material overrides to already-loaded entities. A state update must never reload the GLB.

The Progress screen owns the renderer lifecycle. When the state changes, it updates only affected entity materials. Tapping an entity is translated through the manifest to a `MuscleId`, then to the current contribution data.

The renderer package stays behind a small app-owned widget/controller interface. This isolates native plugin behavior, permits widget-test fakes, and leaves room to replace the engine without changing analytics or UI code.

## Model Asset

The selected public derivative already provides the required muscle-only GLB, so no local Blender installation or unreproducible manual export is needed. The bundled artifact is pinned by source URL, download date, and SHA-256 in `assets/models/ATTRIBUTION.md` and `THIRD_PARTY_NOTICES.md`.

The accepted asset is 18.5 MB and contains 47 named, selectable muscle meshes with no network-fetched textures or lighting resources. An automated GLB contract test parses the binary JSON chunk and requires every expected renderer entity to exist exactly once. The app's typed manifest maps those 47 meshes onto the workout taxonomy. The derivative remains under CC BY-SA 4.0, and attribution is visible from Settings.

## Progress Experience

Replace the current figure area inside **This week's focus** while retaining its card position.

The card provides:

- One-finger 360-degree rotation.
- Two-finger zoom.
- A 3D/2D mode control plus direct drag rotation and pinch zoom.
- A neutral desaturated muscle material for untrained regions.
- A terracotta-to-amber intensity treatment that fits the current warm-earth theme.
- A fixed effective-set legend.
- A visible loading state and short gesture hint.

If the Progress view is visible when a set is saved or edited, the affected muscles update immediately. If another screen covers Progress, the latest state is applied when the model is visible again.

Tapping a muscle temporarily applies a distinct selection treatment and opens or updates a detail surface showing:

- Friendly muscle name.
- Total effective sets.
- Primary and secondary contributions.
- Exercises responsible for the current state.

No-data weeks show the fully neutral model with explanatory copy.

## Accessibility

The 3D canvas has an overall semantic label and concise interaction hint, but it is not the only route to the data. An expandable **Muscle breakdown** list exposes every muscle name, intensity, effective sets, and exercise contribution to VoiceOver and TalkBack. Selecting an item in the list focuses the same muscle in the 3D view.

Color is supplemented by text, fixed legend labels, selection state, and numeric effective-set details. Touch targets for camera controls meet platform sizing guidance.

## Error Handling and Fallback

- A permanently available 2D toggle provides an immediate fallback if the GLB or native renderer fails to load. The rest of Progress stays usable.
- Aggregate the detailed taxonomy into the existing broad `BodyRegion` values for the fallback.
- Do not silently invent anatomy for unknown exercises. Surface an **Assign muscles** action.
- A failed anatomy-enrichment pass must be retryable and must not remove existing exercise or workout data.
- Validate the bundled GLB during development and fail tests/build verification when its expected entities are missing.
- Keep model and analytics errors separate so renderer failure cannot block workout logging or other progress charts.

## Performance

- Load the bundled model once per Progress renderer lifecycle.
- Update entity materials in place instead of rebuilding the widget or model.
- Avoid re-rendering continuously while the model is idle; use the renderer's adaptive frame pacing.
- Verify smooth vertical scrolling around the embedded native view.
- Measure initial model load time, interaction frame rate, memory use, and release-build app size on physical Android and iOS devices.
- If full-quality geometry misses the budget, reduce geometry before removing muscle detail or interactions.

## Verification

### Data and domain tests

- All 200 bundled exercises have at least one valid primary muscle.
- Every referenced muscle ID exists.
- Primary and secondary lists contain no duplicates or overlap.
- Schema v2-to-v3 migration preserves all existing data.
- Existing bundled exercises are enriched idempotently.
- Custom-exercise validation requires a primary muscle.
- Backup v3 round-trips anatomy data.
- Backup v1/v2 imports remain supported and are enriched appropriately.

### Analytics tests

- A saved set in an active session updates the current week without `ended_at`.
- A primary contribution is `1.0`; a secondary contribution is `0.35`.
- Warm-ups and rows outside the current Monday-based week are excluded.
- Editing, deleting, or reclassifying a set updates the state.
- Weighted, bodyweight, duration, distance, and deliberately logged entries count consistently.
- Bilateral mesh mappings receive the same intensity.
- Fixed display bands do not normalize against the busiest muscle.

### Widget and integration tests

- Neutral, loading, loaded, and failed renderer states.
- 2D fallback and retry behavior.
- Fake entity selection opens the correct muscle details.
- The accessible breakdown list contains the same data as the model.
- Live provider changes update material commands without reloading the model.

### Physical-device acceptance flow

1. Start a workout and save a bench-press working set.
2. Verify immediate chest, front-delt, and triceps updates.
3. Save a pulldown set and verify lats and biceps.
4. Convert a set to warm-up, then edit and delete sets; verify reversal.
5. Rotate, zoom, reset, and tap highlighted muscles.
6. Verify detail contributions, light/dark themes, accessibility, scrolling, memory, and load behavior on Android and iOS.

Final verification includes `flutter analyze`, the complete Flutter test suite, and Android/iOS debug builds. The native dependency and generated model are reviewed before release.

## Implementation Order

1. Define the muscle taxonomy and add complete primary/secondary mappings to all 200 exercises.
2. Add schema v3, enrichment, custom-exercise fields, backup compatibility, and tests.
3. Implement live current-week set-based analytics, including active sessions.
4. Pin the Flutter-compatible renderer and prove native Android/iOS builds.
5. Pin, validate, and attribute the pre-optimized BodyParts3D/Z-Anatomy-named derivative.
6. Add the 3D renderer adapter, model manifest, and live material binding.
7. Build tap details, controls, legend, accessible breakdown, and fallback.
8. Complete automated and physical-device verification, then replace the old visualization by default.

## Approved Decisions

- Detailed primary/secondary fitness anatomy.
- Interactive drag rotation, pinch zoom, and muscle tapping.
- Realistic skinless male model.
- Free Z-Anatomy source with attribution and share-alike compliance.
- Effective-set intensity instead of lifted tonnage.
- Live updates after every saved working set, including during active workouts.
- Complete all 200 bundled exercise mappings before integrating the 3D UI.
- Native renderer with 2D fallback.

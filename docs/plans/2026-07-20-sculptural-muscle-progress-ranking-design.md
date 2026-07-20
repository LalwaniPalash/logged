# Sculptural Muscle Progress and Personal Ranking Design

**Status:** Approved; documentation only

**Date:** 2026-07-20

**Product:** Logged (Flutter, Android and iOS)

**Implementation:** Explicitly deferred

## Context

Logged already has a live, interactive 3D muscular model on the Progress screen. It colors detailed primary and secondary muscles from Monday through the current day and reacts to every saved working set, including sets saved while a workout is still active.

The current anatomical presentation is too close to a medical dissection: raw red muscle, bright white connective tissue, and a clinical light stage. The next design should preserve the anatomical readability of every muscle while making the model feel like a premium fitness sculpture.

The same interaction is also a natural entry point for a deeper progress system. Selecting a muscle should show its progressive overload over time and a personal rank based only on the user's own training history. The system must support externally loaded exercises, plain bodyweight exercises, added weight, assistance, repetitions, and timed work without combining incompatible measurements directly.

## Approved Outcomes

- Keep every trained and untrained muscle visible at all times.
- Restyle the existing detailed geometry as a matte graphite-bronze anatomical sculpture.
- Update the model and muscle analytics after every saved working set rather than waiting for workout completion.
- Open historical analytics when a muscle is tapped.
- Provide an all-muscles overview without adding another bottom-navigation destination.
- Measure progressive overload relative to the user's own exercise history.
- Support external resistance, bodyweight, added-weight bodyweight, assisted bodyweight, repetitions, timed holds, duration, and distance where relevant.
- Add dated bodyweight history so calculations use the user's weight at the time of a workout.
- Introduce per-muscle ranks that are earned permanently, alongside a separate momentum signal that may rise or fall.
- Continue treating a secondary muscle contribution as 35% of a primary contribution.

## Non-goals

- Estimating muscle size, body composition, hypertrophy, or medical condition.
- Comparing the user with population strength standards or other users.
- A social or global leaderboard.
- Claiming that different exercises have directly comparable kilograms.
- Removing the accessible 2D fallback or text-based muscle breakdown.
- Side-specific progress until the logger records left and right performance separately.
- Replacing the current 3D geometry solely for this visual refresh.
- Implementing any part of this design as part of the present documentation task.

## 1. Visual Direction: Sculpted Graphite Anatomy

The approved direction is **sculpted graphite anatomy**. The model remains anatomically detailed, but color, material, lighting, and staging move it away from exposed tissue and toward a deliberately designed training object.

### Resting anatomy

- Every muscle remains readable when it has not been trained.
- Untrained muscle uses a matte graphite base with a subtle warm bronze undertone.
- Neighboring muscle shapes remain distinct through lighting, roughness, and restrained tonal variation rather than saturated anatomical red.
- Tendons and other connective tissue lose the current bright-white treatment. They use a subdued warm neutral that supports the muscle forms without becoming the highest-contrast feature.

### Training intensity

- Current-week work moves a muscle through terracotta, copper, and amber.
- The existing fixed effective-set scale remains the source of intensity; colors do not normalize against whichever muscle happens to be busiest that week.
- One set produces a visible but restrained change. Higher effective-set bands become warmer and brighter without turning neon.
- The selected muscle receives a restrained gold accent distinct from its training-intensity color.

### Stage and lighting

- Replace the clinical white presentation with a warm charcoal studio stage.
- Use a soft key light to reveal muscle boundaries, a gentle rim light to separate the silhouette, and a soft grounding shadow.
- Avoid aggressive bloom, wet tissue reflections, medical white, exposed-flesh red, and gaming-style neon.
- Preserve sufficient contrast in light and dark app themes and under reduced-brightness conditions.

The first visual pass changes materials, palette, connective-tissue treatment, background, and lighting while retaining the current model and its 47 named selectable meshes. A different model is only reconsidered if this treatment cannot remove the medical character without losing anatomical clarity.

## 2. Interaction and Navigation

The Progress tab remains the single home for consistency, muscle state, volume, records, and exercise analysis. No new bottom-navigation tab is introduced.

### 3D entry point

- Drag rotates, pinch zooms, and the existing 2D fallback remains available.
- A saved non-warm-up set updates affected materials immediately, even in an active workout.
- A true tap on a muscle opens its dedicated **Muscle Progress** screen. A rotation gesture must not be mistaken for a tap.
- Returning from details preserves the selected muscle and camera state where the renderer permits it.
- An **All muscle progress** action below the 3D experience opens the complete muscle overview.

### Individual Muscle Progress screen

The screen contains:

- Muscle name and focused visual identity.
- Current rank and progress toward the next rank.
- Current momentum: improving, steady, declining, or learning baseline.
- 4-, 12-, and 24-week ranges.
- A normalized progressive-overload line chart.
- Effective-set history displayed separately from performance.
- Primary versus secondary contribution.
- Last-trained date, recent personal records, and meaningful milestones.
- Associated exercises, each with its own trend, best performance, and latest performance.
- A plain-language **How this is calculated** explanation.

Separating effective sets from performance prevents volume alone from appearing to be progressive overload.

### All Muscle Progress screen

All app muscle IDs remain present, including muscles with no qualifying history. Each row includes:

- Muscle name.
- Rank.
- Momentum.
- Progress toward the next rank.
- Recent normalized trend and compact sparkline.
- Last-trained date.

The list can be sorted by anatomical order, rank, improvement, attention needed, or last trained. A muscle without enough observations displays **Learning baseline**, not a fabricated trend.

## 3. Set Logging and Bodyweight History

The current single weight field cannot reliably distinguish external resistance, added bodyweight load, or assistance. The future data model therefore needs an explicit loading mode on each set:

- `external`: the entered value is the external resistance.
- `bodyweight`: no additional resistance or assistance.
- `bodyweightAdded`: the entered value is added to effective bodyweight resistance.
- `bodyweightAssisted`: the entered value is assistance and reduces effective bodyweight resistance.

An exercise stores a preferred loading mode, while each set can override it. The set editor remembers the last mode and value for that exercise and changes the field label to **Weight**, **Added weight**, or **Assistance**. Plain bodyweight sets require no weight entry.

### Dated bodyweight

The user can record bodyweight in Settings or Profile with a date and kg/lb unit. A calculation uses the latest bodyweight entry on or before the workout date. The current value carries forward automatically, so it is not requested during every workout.

Changing bodyweight creates a new dated entry instead of overwriting history. A current value must never be applied retroactively to workouts that occurred before its effective date.

If no appropriate bodyweight exists, the set remains valid and contributes through repetitions or duration. The UI identifies the calculation as lower precision until historical bodyweight is supplied.

### Historical compatibility

- Existing data is preserved during migration.
- Old blank-load bodyweight entries may be treated as plain bodyweight sets.
- A historical nonblank load whose meaning is ambiguous is not silently guessed as added weight or assistance.
- Ambiguous historical entries remain useful for repetitions or duration and may optionally be classified later.
- Backups gain the loading mode, measurement metadata, and dated bodyweight history while older backup versions remain importable.

## 4. Exercise Measurement Model

Each exercise has a progression measurement appropriate to its mechanics:

- External-load repetitions.
- Bodyweight repetitions.
- Added- or assisted-bodyweight repetitions.
- Timed holds.
- Duration or distance work where progress can be measured responsibly.

For movements where only a portion of body mass is resisted, exercise metadata may define a stable bodyweight-resistance factor. This is used only to compare the user with their own history for that same exercise; it is not presented as an exact biomechanical measurement.

Conceptually, repetition-based resistance is:

```text
external exercise: resisted mass = external load
plain bodyweight:   resisted mass = bodyweight × exercise factor
added bodyweight:   resisted mass = bodyweight × exercise factor + added load
assisted movement:  resisted mass = bodyweight × exercise factor − assistance
```

The resisted mass is clamped above zero. A repetition-adjusted strength estimate can then use the app's existing estimated-1RM convention. Timed holds use duration, with resistance included when available. Distance and duration exercises use an exercise-specific pace or workload signal rather than estimated 1RM.

These values are never added directly across different exercises.

## 5. Progressive Overload Calculation

Progression is calculated in two stages: exercise first, muscle second.

### Exercise-relative performance

1. Ignore warm-ups and invalid or empty set records.
2. Convert units to a stable internal representation.
3. Select the appropriate performance signal for the exercise's measurement type.
4. Establish a baseline only after enough qualifying observations across more than one session.
5. Express later performance relative to that exercise's own baseline, with the baseline represented as an index of `100`.
6. Use the best representative working-set performance for a period rather than rewarding repeated low-value sets.
7. Limit the influence of a single extreme observation and expose the underlying exercise values for transparency.

An exercise change from index `100` to `110` means the user's comparable performance for that exercise improved by approximately 10% from its established baseline. It does not mean that exercise is 10% stronger than another exercise.

### Muscle-level performance

The muscle trend combines only exercise-relative indexes:

- Primary exercise association weight: `1.0`.
- Secondary exercise association weight: `0.35`.
- Each exercise's influence is capped so one unusual record cannot control an entire muscle trend.
- A new exercise remains in **Learning baseline** until it has enough data and does not drag an established muscle index down.
- The chart can recompute from saved workout history, making edits and deletions deterministic.

Effective sets remain a parallel workload series and retain the existing primary/secondary weighting. They help explain whether the muscle is being trained but do not substitute for performance improvement.

### Live behavior

A persisted working set is complete for analytics when the user saves it. Session completion is not required. The current exercise trend, muscle trend, effective-set state, momentum, and any earned rank progress update reactively after each set. Editing, deleting, or marking the set as a warm-up recomputes those values.

## 6. Personal Muscle Ranking

Ranks describe accumulated progress against the user's own history:

1. Foundation
2. Bronze
3. Silver
4. Gold
5. Platinum
6. Elite

They are not strength standards and must never imply comparison with another person.

### Rank inputs

- Verified improvement in exercise-relative performance.
- Personal records and meaningful progression milestones.
- Consistency across distinct weeks and sessions.
- Productive effective-set exposure, subject to weekly caps.
- Primary and secondary muscle involvement using the approved `1.0` and `0.35` weights.

Repeated extra sets beyond the productive cap do not farm rank. Warm-ups, empty sets, and unsupported measurements do not award progress.

### Permanence and recalculation

- Earned rank does not fall because of rest, illness, a deload, or a period without training.
- Rank is derived from accumulated qualifying history and therefore normally moves only upward.
- Correcting or deleting historical workout data may recalculate rank because the underlying evidence changed.
- Exact point thresholds are implementation calibration values. They must be tested against synthetic beginner, intermittent, consistent, and long-term histories before being frozen.

### Momentum

Momentum is deliberately separate from rank. It compares recent exercise-relative performance with the preceding comparable period and may be:

- Improving.
- Steady.
- Declining.
- Learning baseline.

A deload may temporarily change momentum without removing a rank. The interface should avoid negative or punitive language when the data is sparse or a planned reduction in work is likely.

## 7. Accessibility and Explanation

- Color is never the only indicator of training state, rank, or momentum.
- Text labels, numerical indexes, trends, and rank progress accompany the model.
- The accessible muscle list exposes the same navigation and analytics as tapping the 3D geometry.
- Charts provide semantic summaries and do not rely solely on line color.
- The calculation explanation states that ranks are personal training markers, not medical or anatomical assessments.
- Missing bodyweight or insufficient baseline data is explained without presenting false precision.

## 8. Error Handling and Resilience

- Renderer failure does not block the all-muscles list or muscle analytics.
- The 2D fallback can open the same Muscle Progress screen.
- Missing or malformed muscle metadata excludes only the affected association and surfaces it for correction.
- Missing bodyweight falls back to reps or duration rather than discarding sets.
- Assistance greater than effective bodyweight resistance is rejected at input boundaries.
- Unit changes do not break historical trends because values are normalized internally.
- Rank and trend calculations remain reproducible after backup export/import.

## 9. Verification Requirements for Future Implementation

No verification work is performed as part of this documentation-only task. A future implementation must cover:

### Domain and calculation tests

- External-load repetitions and estimated-1RM progression.
- Plain bodyweight repetition progression.
- Bodyweight changes across dated history.
- Added-weight and assisted-bodyweight calculations.
- Timed holds with and without added resistance.
- Duration and distance measurement routing.
- Missing bodyweight fallback.
- Baseline establishment and sparse-data behavior.
- Primary `1.0` and secondary `0.35` aggregation.
- Outlier and excessive-volume caps.
- Rank permanence, milestone progression, and momentum decline.
- Edits, deletions, warm-up changes, and active-session updates.

### Data tests

- Database migration without loss of existing workouts.
- Loading-mode persistence and last-mode carry-forward.
- Dated bodyweight lookup at workout boundaries.
- Old ambiguous set preservation.
- New backup round-trip and older backup imports.

### UI and accessibility tests

- Sculptural resting, trained, and selected materials.
- All muscles remain visible when untrained.
- Connective tissue no longer renders as clinical white.
- Tap versus drag behavior.
- Navigation from 3D, 2D, and accessible list routes.
- Individual and all-muscle empty, baseline, ranked, and error states.
- Semantic chart summaries and non-color status indicators.
- Android and iOS visual review in light and dark themes.

## Approved Decisions

- Sculpted graphite-bronze is the selected visual direction.
- All untrained muscles remain visible.
- Trained muscles use a terracotta-to-copper-to-amber progression.
- Selection uses a restrained gold accent.
- Tapping a muscle opens historical analytics.
- A nested all-muscles overview is added under Progress; there is no new bottom tab.
- Progressive overload is personal and exercise-relative.
- Bodyweight, added weight, assistance, reps, and timed work are included in the full first version.
- Dated bodyweight history is acceptable and does not require per-workout re-entry.
- Rank is permanent; momentum may rise or fall.
- No implementation is authorized by this document-only request.

# PHASE 5 SPEC — Flutter practice & set-list mechanics (standalone brief for Codex)

> **You have NO prior conversation context.** Everything you need is below. Every file path, symbol,
> and line number named here was verified against the working tree at commit `0be0ba9`
> (branch `feat/set-editor-backup-ux`) on 2026-08-14. Line numbers drift as you edit — treat them as
> "look here first", and **always open the file and confirm the signature before using it.**
>
> Full audit evidence for these findings lives in `tasks/audit-2026-08-14.md` (sections B and H).
> The one-paragraph summaries in `tasks/spec-audit-fixes.md` under "PHASE 5" are superseded by this
> document.

## Project in 20 seconds

Logged is a private, 100% local, no-account Flutter workout tracker (Android + iOS, Drift +
Riverpod, feature-first). No network, no analytics, no accounts — do not add any. Phases 1–4 of an
audit remediation have shipped. This is Phase 6 of 8 in that programme; Phases 6 and 7 come after.

Baseline you must preserve: **`flutter analyze` clean, `flutter test` 272/272 green.**

---

## GROUND RULES (non-negotiable — these are distilled from `tasks/lessons.md`, read it)

1. **Verify APIs before use.** Every symbol named below exists today. Still open the file and confirm
   the signature. Never assume a method shape. Never invent one.
2. **No schema changes in this phase.** `schemaVersion` stays **12**. Nothing here needs a migration.
   If you think you need one, you have misread the task — stop and say so.
3. **Root-cause, not call-site.** When you fix a shared function, grep every caller first. A guard in
   the shared function beats a guard in each caller. This bit the project before: a fix applied to
   only the `LoadingMode.external` branch of a 4-branch `switch` left three siblings broken.
4. **Never build a `DateTime` by adding a `Duration` of days.** DST makes `now.add(Duration(days: 1))`
   land on 23:00 or 01:00. Always construct calendar-wise: `DateTime(y, m, d + 1)`.
   `lib/core/domain/streak.dart` documents this and is the reference implementation. This rule is
   load-bearing for task 5.5b.
5. **Per-set truth.** Units, `weightEntry` (`total`|`perSide`), and `sideCount` are per-SET, never
   hoisted into a shared header without a per-row deviation flag.
6. **Green tests are necessary, not sufficient.** Every finding in the source audit survived a green
   230-test suite. Add tests that would have caught the bug, not tests that describe the new code.
7. **Do not modify files outside a task's stated scope.** `git diff HEAD` must stay a clean review
   surface.
8. **Commit per task**, in the order given. Run `flutter analyze` and `flutter test` before each
   commit. Do not proceed to the next task on a red suite.

---

## ARCHITECTURE MAP (what exists today — all verified)

- **Providers**: `lib/data/providers.dart`. Already holds `databaseProvider`,
  `sessionRepositoryProvider`, `setRepositoryProvider`, `templateRepositoryProvider`,
  `exerciseRepositoryProvider`, `analyticsRepositoryProvider`, `settingsRepositoryProvider`,
  `trainingDaysProvider`, `restDaysProvider`, `workoutSettingsProvider`, `completedSetsProvider`,
  `liveMuscleStateProvider`, `muscleProgressProvider`, `bodyProgressSummaryProvider`. The existing
  `StreamProvider` declarations there are the style to copy.
- **`SetRepository`** (`lib/data/repositories/set_repository.dart`, 155 lines) —
  `add({required sessionExerciseId, required setNumber, ...})`, `edit(setId, {...})` (uses
  `Value<T?>` for nullable fields; **do not regress this**), `update(setId, companion)`,
  `shiftSetNumbers({required sessionExerciseId, required by, int fromNumber = 1})`,
  `insertWarmupSets({...})`, `delete(setId)`.
- **`SessionRepository`** (`lib/data/repositories/session_repository.dart`) —
  `details(sessionId)` → `List<SessionExerciseDetails>` (**the N+1, line ~334**),
  `reorderExercises(sessionId, orderedSessionExerciseIds)` (**line ~270 — the validation pattern to
  copy for 5.3**), `watchRecent({int limit = 10})` (line ~85), `addExercise`, `removeSessionExercise`,
  `updatePrescription`, `finish`, `seedForNextSet`, `watchTrainingDays`.
- **`TemplateRepository.watchAll()`** (`lib/data/repositories/template_repository.dart:54`).
- **Session UI**: `lib/features/session/active_session_screen.dart` (~1470 lines) plus
  `widgets/set_row.dart` and `widgets/set_editor_sheet.dart`.
  - `_ExerciseCard` renders the set list as a plain `for (final set in detail.sets) SetRow(...)`
    inside a `Column` (line ~1358).
  - The **exercise** cards are already inside a `SliverReorderableList` (line ~928). This matters
    for 5.3 — see the warning there.
  - `_nextSetNumber(detail)` (line ~999) is already `max(setNumber) + 1` with a comment. Correct.
    Leave it.
- **`isSetComplete({...})`** lives in `lib/features/session/widgets/set_row.dart:74`, not in
  `core/domain`. Pure; a `switch` over `ExerciseCategory`. Read its doc comment before task 5.4.
- **Tests** live in `test/`, mirroring `lib/`. `test/data/*_repository_test.dart` spin up an
  in-memory Drift database — copy the existing `setUp` from `test/data/set_repository_test.dart`.

---

# TASK 5.1 — B1: Streams and Futures constructed inside `build()` 🟠

### The bug
Four screens create a **new** stream or future subscription on every `build()`. Each rebuild
re-subscribes, and because every one of them falls back with `snapshot.data ?? const []`, the widget
renders its **empty state** during the reconnect. Users see the recent-sessions list, the history
list, and the template list visibly flash empty on rebuilds that have nothing to do with them
(theme change, keyboard open, an unrelated provider updating).

None of the four distinguishes *loading* from *empty*, which is what makes the flash indistinguishable
from real data loss.

### The four sites (all verified)

| File | Line | What it constructs |
|---|---|---|
| `lib/features/dashboard/dashboard_screen.dart` | 64 | `ref.watch(sessionRepositoryProvider).watchRecent(limit: 3)`, consumed by `StreamBuilder` at 205 |
| `lib/features/history/history_screen.dart` | 28 | `watchRecent(limit: 500)` inline in a `StreamBuilder` |
| `lib/features/templates/templates_screen.dart` | 173 | `watchAll()` inline in a `StreamBuilder` |
| `lib/features/exercise/progress_screen.dart` | 192 | `FutureBuilder(future: _loadExercise(_exercise!.id))` |

`active_session_screen.dart` caches its future in state correctly and is the in-repo counter-example
— do not "fix" it.

### Decided fix

Add to `lib/data/providers.dart`:

```dart
/// Most recent sessions, newest first. Family key is the row limit — the
/// dashboard wants 3, history wants 500, and they must not share a subscription
/// with the wrong limit.
final recentSessionsProvider = StreamProvider.family<List<Session>, int>(
  (ref, limit) => ref.watch(sessionRepositoryProvider).watchRecent(limit: limit),
);

final templatesProvider = StreamProvider<List<Template>>(
  (ref) => ref.watch(templateRepositoryProvider).watchAll(),
);
```

For the progress screen, **move `_loadExercise` off the widget**. It is a private method on
`_ProgressScreenState` (line 36) that reaches for `ref.read(databaseProvider)` and runs a raw
`customSelect`. Relocate that query verbatim to `AnalyticsRepository` as:

```dart
Future<List<({double kg, int reps})>> oneRepMaxPointsForExercise(int exerciseId)
```

and expose it as `FutureProvider.family<List<({double kg, int reps})>, int>`. Keep the SQL and the
`weightKg(...)` conversion **exactly as they are** — this task is about subscription lifetime, not
about changing what the chart plots. Then delete `_loadExercise` from the screen.

Consume all four with `ref.watch(...).when(...)`, and give each a **distinct loading branch**:

```dart
ref.watch(templatesProvider).when(
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (error, _) => /* short inline error text, not a crash */,
  data: (templates) => templates.isEmpty ? <the existing EmptyState> : <the existing list>,
)
```

The **loading widget must not be the empty state**. That substitution is the entire bug. Reuse the
existing `EmptyState` from `lib/core/widgets/app_widgets.dart` for the genuinely-empty case only.

### Acceptance
- [ ] No `StreamBuilder` or `FutureBuilder` remains on those four screens.
- [ ] No `.watch...()` / repository call appears inside any `build()` method on them.
- [ ] Each screen shows a spinner (or skeleton) while loading and the empty state only when the
      loaded list is genuinely empty.
- [ ] The dashboard still shows 3 recent sessions and history still shows up to 500.

### Tests
Widget tests are optional here; a provider test is not. Add `test/data/providers_test.dart` (or
extend the relevant repository test) asserting `recentSessionsProvider(3)` and
`recentSessionsProvider(500)` resolve to **different** subscriptions with the correct limits against
an in-memory DB seeded with more than 3 sessions.

---

# TASK 5.2 — H1: set numbers gap permanently after a delete 🟠

### The bug
`SetRepository.delete` (line 152) is a bare row delete — it never renumbers. `_nextSetNumber`
(`active_session_screen.dart:999`) is `max(setNumber) + 1`. So:

> Log sets 1, 2, 3 → delete set 2 → the list reads **1, 3** → the next set added is **4**.

The gap is permanent and visible on every future view of that workout, including history and the
backup export.

### Decided fix
Renumber inside `SetRepository.delete`, in the **same transaction**, so every caller benefits. Do not
patch the call site in `active_session_screen.dart` — that is the mistake ground rule 3 forbids.

```dart
Future<void> delete(int setId) => _database.transaction(() async {
  final row = await (_database.select(_database.setEntries)
        ..where((r) => r.id.equals(setId)))
      .getSingleOrNull();
  if (row == null) return;
  await (_database.delete(_database.setEntries)
        ..where((r) => r.id.equals(setId)))
      .go();
  await _renumber(row.sessionExerciseId);
});
```

`_renumber(int sessionExerciseId)` selects the remaining rows for that exercise ordered by
`setNumber` ascending and rewrites them contiguously from 1, skipping any row whose number is already
correct. Warm-up rows renumber alongside working sets — they share the same sequence today (see
`insertWarmupSets`, which shifts everything and inserts warm-ups at 1..n).

**Watch the interaction with `_showDeletedSetSnackBar`** (`active_session_screen.dart:276`): the Undo
action re-inserts the deleted set with its **original** `setNumber`. Once delete renumbers, undoing a
middle delete would create a duplicate number. Fix the undo path in the same commit: after
re-inserting, shift and renumber so the restored set lands back in its original ordinal position.
The cleanest route is `shiftSetNumbers(sessionExerciseId: ..., by: 1, fromNumber: set.setNumber)`
inside a transaction, then `add(setNumber: set.setNumber, ...)`. Add a repository method for this
rather than orchestrating two calls from the widget.

### Acceptance
- [ ] Delete the middle of 3 sets → remaining sets read 1, 2 → next add is 3.
- [ ] Undo that delete → the set returns at its original position and numbers read 1, 2, 3.
- [ ] Deleting a warm-up does not strand the working sets' numbering.

### Tests (required, `test/data/set_repository_test.dart`)
- `delete renumbers the remaining sets contiguously`
- `delete of a non-existent id is a no-op` (guards the `getSingleOrNull` path)
- `undo re-insert restores the original ordinal without duplicating a set number`

---

# TASK 5.3 — H2: sets cannot be reordered or inserted mid-list 🟠

### The bug
`onReorder` on the session screen (line ~928) reorders **exercises**, not sets. There is no way to
move a set, and no way to insert one anywhere but the end. Mis-logging the order of a drop set or
forgetting a set mid-exercise means deleting and re-entering everything after it.

### ⚠️ Read this before you pick a UI

The exercise cards are **already** inside a `SliverReorderableList`. Nesting a second reorderable
list (the sets) inside a card that is itself a drag target puts two long-press drag recognisers in
the same gesture arena. The outer one wins inconsistently, and on Android the inner drag frequently
starts an exercise drag instead. **Do not nest a `ReorderableListView` inside `_ExerciseCard`.**

### Decided fix — UI

Add an overflow action to each `SetRow` (a `PopupMenuButton`, or extend the existing
`onOpenDetails` affordance) offering:

- **Move up** — disabled on the first set
- **Move down** — disabled on the last set
- **Insert set above**

This satisfies "set-level reorder" without the gesture conflict, and it is reachable one-handed
mid-workout, which a drag handle on a small row is not.

`SetRow` currently takes `onCommit` and `onOpenDetails` (see `set_row.dart:280`). Add
`onMoveUp`, `onMoveDown`, and `onInsertAbove` as nullable `VoidCallback?` — null means "hide/disable
the item", which is how the first/last cases express themselves. Wire them from `_ExerciseCard`
through the same prop-drilling the existing callbacks use. Hide all three when the session is
completed (`_ExerciseCard` already receives `prescriptionEditable: !completed` — follow that
precedent rather than inventing a second flag; rename it to something honest like `editable` if you
use it for both, and update the single call site).

### Decided fix — repository

Both operations go through `SetRepository`, in transactions, never orchestrated from the widget:

```dart
/// Rewrites set_number for every set of [sessionExerciseId] to match the given
/// order. Mirrors SessionRepository.reorderExercises: rejects an id list that
/// is not exactly the current set of ids, so a stale UI list cannot silently
/// drop or duplicate a set.
Future<void> reorderSets({
  required int sessionExerciseId,
  required List<int> orderedSetIds,
});

/// Opens a gap at [setNumber] and inserts a new set there.
Future<int> insertSetAt({
  required int sessionExerciseId,
  required int setNumber,
  ... same optional field parameters as `add` ...
});
```

`reorderSets` **must** copy the validation from `SessionRepository.reorderExercises` (line ~270):
compare the incoming id set against the persisted id set and throw `ArgumentError.value` on any
mismatch. There is already a test for that behaviour on the session side
(`reorderExercises rejects an id from a different session`) — write its twin.

`insertSetAt` is `shiftSetNumbers(sessionExerciseId: ..., by: 1, fromNumber: setNumber)` followed by
`add(setNumber: setNumber, ...)`, both inside one `_database.transaction`.

For the inserted set's field values, reuse `SessionRepository.seedForNextSet({sessionExerciseId})` —
it already implements the prefill priority (last set in this session → prescription → last completed
session). Do not invent a second seeding rule.

### Acceptance
- [ ] Move up / move down reorders sets and the numbers stay contiguous 1..n.
- [ ] The actions are absent on a completed session.
- [ ] "Insert set above" on set 2 of 3 produces 4 sets numbered 1..4 with the new one at position 2.
- [ ] Dragging an exercise card still works — the outer reorder is not degraded.

### Tests (required)
- `reorderSets rewrites numbers to match the given order`
- `reorderSets rejects an id from a different exercise`
- `insertSetAt shifts the following sets and lands at the requested number`

---

# TASK 5.4 — H3: an entirely empty set can be saved 🟡

### The bug
`_save()` in `lib/features/session/widgets/set_editor_sheet.dart:293` validates exactly one thing:
the assisted-vs-bodyweight case. Everything else falls through to `Navigator.pop` with a
`SetEditorResult` whose every logged field is null. The set persists, renders as a blank row, and
counts as an incomplete set forever.

### Decided fix
Add a guard at the top of `_save()`, **after** the existing assistance check so the more specific
error still wins:

```dart
final hasAnyValue = (_showsReps && int.tryParse(_reps.text) != null)
    || (_showsWeight && parsedWeight != null)
    || (_showsDuration && int.tryParse(_duration.text) != null)
    || (_showsDistance && double.tryParse(_distance.text) != null);
if (!hasAnyValue) {
  setState(() => _errorText = 'Log at least one value for this set.');
  return;
}
```

Confirm the getter names against the file — `_showsReps`, `_showsWeight`, `_showsDuration`,
`_showsDistance` all exist (lines 134–150) and each already encodes the "a hidden field must still
round-trip a value the set ALREADY carries" rule. Gate on the same getters so the guard can never
demand a field the sheet is not rendering.

**RPE, notes, and the warm-up flag do not count as content.** A set that carries only an RPE is
exactly the blank row this task is removing.

`_errorText` is already rendered at line ~516 via `_EchoLine(error, isError: true)` — no new UI.

### Acceptance
- [ ] Opening the sheet on a new set and hitting Save with every field blank shows the error and
      does not pop.
- [ ] A pure-bodyweight set with only reps saves.
- [ ] A stretching/timed set with only a duration saves.
- [ ] A cardio set with only a distance saves.

### Tests (required, `test/features/set_editor_sheet_test.dart` — the file already exists)
Widget tests: one per acceptance bullet above. The blank case must assert the sheet is **still
mounted** after tapping Save.

---

# TASK 5.5a — B2: `SessionRepository.details()` is N+1 🟡

### The bug
`details(sessionId)` (line ~334) loops over the session's exercises and, per exercise, issues **two**
more queries — one for the `Exercise` row and one for its sets. A 8-exercise workout costs 17
queries, and the active session screen re-runs the whole thing on every `setState(_refresh)` — which
fires after every single set edit, add, delete, reorder, and prescription change.

### Decided fix
Two queries plus an in-memory group-by:

1. One `select(sessionExercises).join([innerJoin(exercises, exercises.id.equalsExp(sessionExercises.exerciseId))])`
   filtered on `sessionId`, ordered by `position` ascending.
2. One `select(setEntries)..where((r) => r.sessionExerciseId.isIn(linkIds))..orderBy(setNumber asc)`.
3. Group the sets into a `Map<int, List<SetEntry>>` keyed by `sessionExerciseId` and assemble the
   `SessionExerciseDetails` list in the order from query 1.

**The contract must not change.** `SessionExerciseDetails` keeps its three fields; the returned list
stays ordered by `position`; each `sets` list stays ordered by `setNumber`; an exercise with zero
sets still appears with an empty list. Existing callers must need no edits.

Do not add caching, memoisation, or a stream here. That is a different task and this one is already
the whole win.

### Acceptance
- [ ] `details()` issues exactly 2 queries regardless of exercise count.
- [ ] Ordering and empty-set behaviour are unchanged.

### Tests (required, `test/data/session_repository_test.dart`)
- `details returns exercises ordered by position with their sets ordered by set number`
- `details includes an exercise that has no sets`

---

# TASK 5.5b — B3: the dashboard never rolls over at midnight 🟡

### The bug
`dashboard_screen.dart:73` reads `DateTime.now()` inside `build()`. The value feeds
`trainingDaysThisWeek`, `_weekStates`, and `computeStreak` (lines 78–90). Nothing re-triggers a build
at midnight, so a phone left open overnight shows yesterday's greeting, yesterday's week strip, and
marks today as "missed" until something unrelated rebuilds the widget.

### Decided fix
Add to `lib/data/providers.dart`:

```dart
/// Today's date, re-emitted at each local midnight. Read this instead of
/// calling DateTime.now() inside build(), which never updates across a day
/// boundary.
final todayProvider = StreamProvider<DateTime>((ref) async* { ... });
```

Implementation notes that are **not** optional:

- Emit `dateOnly(DateTime.now())` immediately, then schedule the next emission for the next local
  midnight, then loop.
- Compute the next midnight **calendar-wise**: `DateTime(now.year, now.month, now.day + 1)`.
  **Never** `now.add(const Duration(days: 1))` — see ground rule 4. `DateTime(y, m, d + 1)` handles
  month and year rollover correctly on its own; do not special-case it.
- `dateOnly` already exists in `lib/core/domain/streak.dart`. Use it; do not write another one.
- Cancel cleanly on dispose (`ref.onDispose`) so the timer does not outlive the provider.

Then in `dashboard_screen.dart` replace `final now = DateTime.now();` with a read of `todayProvider`,
falling back to `DateTime.now()` only for the initial frame if that keeps the diff smaller:

```dart
final now = ref.watch(todayProvider).asData?.value ?? DateTime.now();
```

Grep for other `DateTime.now()` calls inside `build()` methods while you are here and fix any you
find the same way (ground rule 3). `history_screen.dart:20` has one — check whether it drives
anything date-dependent and convert it if so.

### Acceptance
- [ ] Crossing local midnight updates the greeting, the week strip, and the "missed" markers without
      any other interaction.
- [ ] No `Duration(days:)` arithmetic was used to find the next midnight.

### Tests (required)
Unit-test the next-midnight calculation as a **pure function** — extract it
(`DateTime nextLocalMidnight(DateTime from)`) so it is testable without a timer. Assert it across a
month boundary (Jan 31 → Feb 1), a year boundary (Dec 31 → Jan 1), and a leap day (Feb 28 2028 →
Feb 29 2028). Do not test the stream's timing.

---

# PHASE 5 VERIFICATION

```bash
flutter analyze          # must be clean
flutter test             # must be green, and higher than 272
```

Then **manually**, in a debug build:
1. Open History and Templates and rotate / toggle theme — neither list flashes empty.
2. Log 3 sets, delete the middle one — the remaining sets read 1 and 2, and the next add is 3.
3. Undo that delete — the set comes back in its original position.
4. Insert a set above set 2 — numbering stays contiguous.
5. Drag an exercise card — the exercise reorder still works.
6. Open the set editor on a new set, save with everything blank — it refuses.

Record what you did and did **not** verify in `tasks/todo.md`, following the format of the Phase 4
entry already there. Be explicit about anything you skipped — an honest "not verified" is worth more
than an unverified checkmark.

---

# EXPLICIT DO NOTs

- **Do not** change `schemaVersion` or `backup_service.dart`'s `_schemaVersion`. No migrations here.
- **Do not** regress `SetRepository.edit`'s `Value<T?>` signature back to plain nullables. Its
  "leave alone vs clear" semantics were the Phase 4.4 fix and are covered by two tests.
- **Do not** nest a `ReorderableListView` inside `_ExerciseCard` (see the warning in 5.3).
- **Do not** add a package. Everything here is stdlib, Drift, and Riverpod, all already present.
- **Do not** touch `active_session_screen.dart`'s cached-future pattern — it is the correct one.
- **Do not** "improve" the progress chart's SQL or maths while moving it in 5.1. Move it verbatim.
- **Do not** add network calls, analytics, crash reporting, or accounts. The local-only guarantee is
  the product.

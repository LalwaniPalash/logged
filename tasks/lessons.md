# Lessons — Logged

Format: [date] | what went wrong | rule to prevent it

- 2026-07-20 | (init) | Units are per-exercise and remembered; NEVER force user into a settings
  screen to switch kg/lb. Log row must have a one-tap kg/lb toggle; store entered value + unit,
  normalize to kg for all progress math.
- 2026-07-20 | (init) | Store weight as entered value + unit (source of truth). Derive kg for
  aggregation. Avoid lossy kg→lb→kg round trips in the display path.
- 2026-07-20 | Codex shipped exercise_library.json with a stray leading `+` (diff artifact) →
  jsonDecode threw FormatException in seedIfEmpty, and main() awaited seeding with NO try/catch →
  app crashed to a blank screen on first launch. Unit tests missed it because they inject clean
  fixture data instead of the real asset. Rule: (1) never let asset/seed failures crash startup —
  wrap in try/catch; (2) add a test that parses the REAL bundled asset, not just a fixture.
- 2026-07-20 | exercise_library.json also had a DUPLICATE name ("Close-Grip Bench Press") while the
  exercises.name column is UNIQUE → batch insert threw a constraint violation, so real seeding failed
  even after the `+` fix. Fixes: deduped the library (kept the arms variant), topped back to 200 with
  "Cable Face Pull", set seeding to InsertMode.insertOrIgnore, and the real-asset test now asserts
  name uniqueness + count>=200. Rule: any seeded list keyed by a UNIQUE column MUST be uniqueness-tested.
- 2026-07-21 | The entire `lib/` tree had never been committed (only `docs/` was tracked), so after a
  codex run touching 26 files there was NO baseline to diff against — codex modified two files outside
  its spec (`muscle_anatomy_view.dart`, `app_icons.dart`) and the changes were unreviewable. Combined
  with `--dangerously-bypass-approvals-and-sandbox`, that was also unrecoverable. Rule: commit a
  baseline BEFORE delegating to codex, never after. `git diff HEAD` is the whole point of Mode B review.
- 2026-07-21 | `seedForNextSet` passed `sessionExercise.sidesPerSet ?? 1` into a `copyWith` whose params
  all fall back via `?? this.x`. Coalescing at the CALL SITE makes the value non-null, so it always won
  and silently discarded the remembered sideCount — halving logged stretch duration. Rule: when feeding
  an optional override into a `copyWith` that already handles null, pass the raw nullable through; never
  pre-coalesce. Every sibling field in that same call was correct, which is what made it easy to miss.
- 2026-07-21 | My own read-through and the codex Mode B review each found 2 real bugs, with ZERO overlap
  (I found the sideCount clobber + a disposed-controller race; codex found delete-resets-logging-defaults
  + a setNumber collision). Rule: don't treat either pass as sufficient on its own. Also: `flutter analyze`
  clean + all tests green proved nothing here — all 4 bugs survived a green suite.
- 2026-07-21 | Before a first `git add -A`, always check what's being swept in: `dist/` held 248MB of
  APK/IPA build artifacts and a `.sqlite` device snapshot with personal data. Git history is permanent —
  audit and extend `.gitignore` BEFORE the commit, not after.
- 2026-07-21 | `path_provider_foundation` 2.6.0 moved to Dart **native assets** (via `objective_c`),
  which CocoaPods does NOT install — it never appears in Podfile.lock. An incremental iOS build
  silently skipped bundling the dylib, so `dlopen` failed at runtime, `getApplicationDocumentsDirectory()`
  threw, drift could not open the DB, and every data-backed screen fell back to its error state (the
  3D muscle sculpture "not loading" was this, not a UI bug). Rule: after ANY dependency bump, run
  `flutter clean && flutter pub get && (cd ios && pod install)` before trusting a run. A plugin missing
  from Podfile.lock is not evidence it is unused — check for native assets.
- 2026-07-21 | Seeding with `InsertMode.insertOrIgnore` means any field added to
  `exercise_library.json` later NEVER reaches an existing install — fresh installs get it, upgrades
  silently do not. `weightEntry` shipped correct and did nothing for 212 existing rows. Rule: when
  adding a library-driven column, ship a backfill alongside it. If the column is user-editable, the
  backfill must be ONE-TIME (flag in app_settings), or it overwrites the user's choice every launch.
- 2026-07-21 | Running the real app found 3 bugs that `flutter analyze` + 67 green tests did not:
  the missing backfill, the `kg/side` mis-tag, and the native-assets breakage. Two were data/asset
  problems that unit tests structurally cannot see (they inject fixtures, not the seeded user DB).
  Rule: for data-shaped features, verify against the actual on-device database — query it with
  sqlite3 before and after, and diff the counts. Green tests are necessary, not sufficient.
- 2026-07-22 | Narrowing a UI to "only show what's relevant" silently deletes capability. I made the
  set sheet category-aware and removed (a) the duration field for `bodyweight` exercises and (b) the
  loading-mode picker for exercises currently `external`. Both were the ONLY editor for those values:
  `Plank` is category `bodyweight` with a 90s/zero-rep prescription, so its hold time became
  unloggable; an assisted pull-up filed under `strength` could no longer be marked assisted. Rule:
  before hiding a control, ask "is this the only place this column can be written?" — drive visibility
  off the DATA (does this set/prescription actually use the field) rather than off the category enum.
- 2026-07-22 | Moving a per-row qualifier into a shared column header loses per-row truth. The old set
  row printed the unit on every row (`40 kg`); the new table prints `KG` once in the heading. Units are
  per-SET in this app, so a lb set silently rendered under a KG heading. Rule: when you hoist a label
  from N rows into one header, the rows MUST still flag any that deviate — silence has to mean "the
  header is accurate for me", and that needs an explicit deviation check, not an assumption.
- 2026-07-22 | Widget tests at real device sizes are the only thing that catches layout regressions:
  an overflowing RenderFlex throws and fails the test. Pinning measured heights (46pt/row vs the old
  ~215pt) turns "looks better" into an assertion. But they proved insufficient alone — my 15 passing
  tests missed both capability regressions above, which codex found by cross-referencing the seed
  asset and template service. Rule: for UI narrowing, grep the seeded DATA for rows that contradict
  the assumption, don't just test the widget in isolation.
- 2026-07-22 | `flutter test` renders text as Ahem boxes, making goldens useless for judging design.
  Loading a system TTF via `FontLoader('Roboto')` from `package:flutter/services.dart` makes them
  legible. Keep such goldens as a THROWAWAY harness — machine-specific PNGs committed to the repo
  will fail on any other machine. Generate, inspect, delete.
- 2026-07-23 | The iOS build's native-asset dylibs (sqlite3 via drift, objective_c via
  path_provider_foundation) are DOWNLOADED from github.com at build time, not vendored. In a
  no-network sandbox the build dies with `SocketException: Failed host lookup: 'github.com'` while
  "Building native assets for package:sqlite3". This is the SAME mechanism behind the simulator's
  `objective_c.framework/objective_c` dlopen failure — native assets are fragile: they must be
  fetched and correctly placed under Frameworks/, and any gap surfaces only at runtime (dead DB) or
  as a build failure. Rule: iOS release builds need real network (run the build with the sandbox
  disabled); a green APK build does NOT imply the IPA will build, because Android doesn't use these.
- 2026-07-23 | A background Bash command that ends with `echo "EXIT=$?"` (or any trailing echo)
  reports the ECHO's exit code, not the build's — the iOS build FAILED but the task notification said
  exit 0. Rule: when a command's success matters, check its own exit status / grep its log for the
  failure signature; never trust a trailing-echo exit code as the build result.
- 2026-07-23 | iOS numeric keypad (`TextInputType.numberWithOptions`) has NO return/done key, so a
  bottom sheet whose only inputs are numeric traps the keyboard over the Save button — there is no
  built-in way to dismiss it. Rule: any numeric field needs an explicit dismiss path
  (`onTapOutside` unfocus and/or `ScrollViewKeyboardDismissBehavior.onDrag`); a text field with a
  return key hides this class of bug.
- 2026-07-23 | share_plus on iOS: passing `text:` alongside `files:` appends the text as a SECOND
  activity item, so "export one backup" saved TWO files to Files.app. Verified in the plugin source
  (`FPPSharePlusPlugin.m`: after adding each file it does `if (text != nil) [items addObject:...]`).
  Rule: to attach a label to a file share without a second item, use `subject:` (metadata only),
  never `text:`.
- 2026-07-21 | Heuristics over human-written prose need negative cases. `notes.contains('/side')`
  matched both "8/side" (reps per side → sideCount 2) and "7.5-10 kg/side" (load per hand → perSide,
  sideCount 1) — opposite meanings, same substring. Rule: when parsing free text into a semantic flag,
  enumerate the strings that must NOT match and test them explicitly.

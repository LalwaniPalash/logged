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

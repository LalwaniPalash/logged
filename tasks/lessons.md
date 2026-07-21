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

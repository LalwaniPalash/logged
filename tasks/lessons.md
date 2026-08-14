# Lessons — Logged

Format: [date] | what went wrong | rule to prevent it

- 2026-07-26 | A combinatorial solver was fine on solvable inputs and pathological on unsolvable ones.
  The plate calculator's exhaustive search early-exits when it hits the target exactly, so every test
  (all solvable) passed in ~0ms — but an UNLOADABLE target has nothing to exit on and it degraded
  exponentially: 501.3 kg took 4.9s on the UI thread, and the sheet re-solves on every keystroke.
  Rule: when a search's termination depends on finding an exact answer, the benchmark that matters is
  the input with NO exact answer. Test the unsatisfiable case for latency, not just correctness.
  Corollary: a reachability DP over a quantized grid (integer hundredths) is linear where subset-sum
  search is exponential — and float weights like 2.5/1.25 stop being a hazard once quantized.
- 2026-07-26 | Fixing that solver made it return mathematically-correct but humanly-wrong answers:
  40 kg a side came back as 20+20 instead of 25+15. Two existing tests caught it. Rule: when several
  outputs are equally optimal by the metric you optimized, the choice among them is a PRODUCT
  decision, not a tie-break. Compute the value with the fast algorithm, then lay out the presentation
  with the conventional one (heaviest plate first).
- 2026-07-26 | Writing to two stores that cannot be transactional (SQLite + Apple Health) had its
  progress marker batched to the end of the loop. On a thrown write the service unwound into its
  catch-all and lost EVERY marker for the run, so the retry re-wrote all of them as duplicate health
  records. The `success == false` branch did persist, which is why it looked safe. Rule: with two
  non-atomic stores, (a) order the writes so the failure mode is a duplicate rather than a loss —
  write the external record, THEN mark it — and (b) commit the marker per item, not per batch, so a
  crash costs one item instead of the whole run. And test the THROW path separately from the
  returns-false path; they unwind through different code.
- 2026-07-26 | Staging iOS widget source at `ios/LoggedWidget/LoggedWidget.swift` was a trap: Xcode's
  Widget Extension template generates that exact filename and silently overwrote it (5114 → 2596
  bytes, dropping the app-group read). Recovered from the git index. Rule: never stage hand-written
  Swift under a filename an Xcode template generates — use a distinct name, or stage outside the
  folder the template will target.
- 2026-07-26 | Adding a Widget Extension to a Flutter app fails with `Cycle inside Runner`. Xcode
  appends "Embed Foundation Extensions" LAST, after Flutter's "Thin Binary" script phase, which
  declares no outputs — so Xcode assumes it can touch anything in `Runner.app` including `PlugIns/`,
  and the appex copy both depends on and appears to invalidate it. Fix: move "Embed Foundation
  Extensions" BEFORE "Thin Binary" in Runner → Build Phases. Also check the new extension's Minimum
  Deployment — Xcode defaults it to the newest SDK (26.4 here), which would silently never install on
  the target phones.
- 2026-07-26 | An entitlements plist can exist and be completely inert. `Runner.entitlements` declared
  HealthKit, `flutter build ios` passed, and it would have been refused at runtime — because nothing
  referenced it (`CODE_SIGN_ENTITLEMENTS` was absent from project.pbxproj). Rule: a capability is only
  real when the plist is referenced by the target; grep `CODE_SIGN_ENTITLEMENTS` before believing a
  build that "passes" proves an entitlement works. A green build does not verify capabilities.
- 2026-07-26 | `codex exec` on a large spec at xhigh spends 10+ min reading before it writes, which
  exceeds a 10-minute foreground tool timeout — it got SIGTERM'd mid-write and left the tree
  half-implemented. Rule: always run codex backgrounded, and write the spec so a resumed run reads
  the partial work first instead of duplicating it.

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
- 2026-07-23 | Adding an enum-typed column (`preferredLoadingMode`) is not enough — every WRITER and
  every READER must be updated too. The seed service (`ExerciseSeedService.seedIfEmpty`) never wrote
  the column, so all fresh-install rows silently took the schema default `external`; the reader side
  (set completion, progression, deload est-1RM, strength-standards query) each independently ignored
  loading mode. One missing field produced five distinct bugs (bodyweight Pull-Up demands a weight;
  assisted progression suggests MORE assistance; assisted improvement reads as a 1RM decline →
  false deload; strict-bodyweight pull-ups excluded from standards). Rule: when you add a column,
  grep every seed/insert path AND every query/consumer for it before calling it done — a green build
  proves nothing because defaults fill the gap. The backfill for existing installs must also CORRECT
  a wrong value, not only insert-when-missing (a fresh install already had the row, so insert-if-absent
  no-oped and marked itself done).
- 2026-07-24 | Dashboard rank hero flickered foundation<->bronze forever. Root cause: a
  `ref.listen(muscleProgressProvider)` callback (`_handleRankUpdates`) wrote `lastSeenRanks` into
  `app_settings` on EVERY emission, and `watchCoachingPreferences()` watches the whole `app_settings`
  table → that write re-emitted coaching prefs → recomputed muscleProgress → fired the listener again →
  infinite loop; `bodyProgressSummary` cycled null('Foundation') <-> data('Bronze'). Two-part fix:
  (1) guard the write — only persist when `mapEquals(previous, current)` is false; (2) `.distinct()` the
  coaching-prefs stream (+ value equality on `CoachingPreferences`) so writes to UNRELATED settings keys
  don't cascade. Rule: never write to a table inside a listener/effect that (transitively) reads a
  `.watch()` on that same table without a change-guard — it self-triggers. And a provider that
  `.watch()`es an entire k/v settings table should be `.distinct()` on a value-equal type, or every
  unrelated key write recomputes it. NOTE: `mapEquals` needs `import 'package:flutter/foundation.dart'`
  explicitly here — it was not resolved via material.dart.
- 2026-07-23 | Codex Mode-B review false positive worth remembering: it flagged the CSV parser for not
  stripping a UTF-8 BOM, assuming `String.trim()` leaves U+FEFF. Dart's `trim()` SPECIFICALLY removes
  the BOM (documented: "White_Space property … and the BOM character, 0xFEFF") — verified with a
  one-line `dart run`. Rule: validate every codex finding against real behavior before acting; a
  language-specific trim/normalize assumption is a common miss. (Also: a codex finding can be
  "real but by-design" — the import partial-commit was flagged as silent truncation, but the spec
  explicitly allows importing valid rows while showing row-numbered errors.)
- 2026-07-21 | Heuristics over human-written prose need negative cases. `notes.contains('/side')`
  matched both "8/side" (reps per side → sideCount 2) and "7.5-10 kg/side" (load per hand → perSide,
  sideCount 1) — opposite meanings, same substring. Rule: when parsing free text into a semantic flag,
  enumerate the strings that must NOT match and test them explicitly.
- 2026-07-26 | Android home-screen widget failed to add on device ("couldn't add widget", empty 4x3
  shell). Cause: `logged_widget.xml` used a bare `<View>` as a hairline divider. `RemoteViews` inflates
  through a filter that only accepts classes annotated `@RemoteView` — `android.view.View` is not one
  of them, so the launcher's inflation of `initialLayout` throws and it renders the error shell. Fixed
  by swapping the divider to `ImageView` (allowed, same visual). Rule: widget layouts may only use the
  RemoteViews-allowed views (FrameLayout/LinearLayout/RelativeLayout/GridLayout, TextView, ImageView,
  Button, ImageButton, ProgressBar, Chronometer, AnalogClock, ViewFlipper, ListView/GridView/StackView,
  ViewStub) — never a plain `<View>`. Verification: `./gradlew :app:lintDebug` catches this as
  `RemoteViewLayout` ("includes views not allowed in a RemoteView"); it is an ERROR, not a warning, so
  running lint once on any widget change would have caught it before shipping the APK.
  Toolchain note: gradle/lint here need `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`
  — the default Homebrew JDK 26 makes AGP fail with a bare "26.0.1" error.
- 2026-07-26 | Android notification showed a blank grey square instead of the logo. Two separate
  causes, both invisible in debug builds. (1) `AndroidInitializationSettings('@mipmap/ic_launcher')`
  — Android discards every colour in a notification SMALL icon and keeps only the alpha channel,
  painting the result white, so an opaque launcher square renders as a featureless block. A small
  icon must be a transparent-backgrounded silhouette; added `drawable/ic_stat_logged.xml` (vector,
  minSdk 26 renders framework VectorDrawable fine) and set it both at init and per-notification.
  Do NOT hardcode `android:tint` on it — the system tints it, and a baked tint can defeat
  `AndroidNotificationDetails.color`. (2) **The drawable was then stripped from the release APK.**
  Flutter release builds run the resource shrinker (proof: `build/app/outputs/mapping/release/
  resources.txt` exists and is full of "Marking … reachable"), and a resource referenced only by NAME
  at runtime — `Resources.getIdentifier`, which is how flutter_local_notifications resolves an icon —
  is never marked reachable. Debug builds do not shrink, so this class of bug ships silently. Fix:
  `res/raw/keep.xml` with `tools:keep="@drawable/ic_stat_logged"`. Rule: any resource named only from
  Dart/reflection must be listed in keep.xml, and the check is
  `aapt2 dump resources <apk> | grep drawable/<name>` on the RELEASE apk — not "it works in debug".
- 2026-07-26 | Sideloaded iOS installs failed with `AppexBundleMissingClassOrStoryboard`: installd
  requires an appex to declare `NSExtensionMainStoryboard` or `NSExtensionPrincipalClass`, and a
  SwiftUI `@main WidgetBundle` declares neither — Xcode's own Widget Extension template generates
  only `NSExtensionPointIdentifier = com.apple.widgetkit-extension` (verified against the template in
  Xcode 26.4, so our build was NOT malformed). Not an iOS-version issue: reproduced on iOS 26.5, and
  uninstalling first did not help. Fix: add `NSExtensionPrincipalClass` to
  `ios/LoggedWidget/Info.plist` anyway. Per Apple Developer Forums 734428 this is a genuine catch-22 —
  the key makes installation work but makes App Store Connect reject the upload as "unexpected".
  Logged is local-only and never submitted, so the trade is free; the key must be REMOVED if that
  ever changes. WidgetKit enters through the `@main` attribute, not by instantiating the named class,
  so the value only has to exist. Rule: when a plist key is required by one tool and rejected by
  another, decide by which pipeline the project actually uses — and write the reason next to the key,
  because the next person will "fix" it by deleting it.
  **CORRECTION (same day, see the next entry): "the value only has to exist" was WRONG.** It must also
  be RESOLVABLE by `NSClassFromString`, and it pointed at `LoggedWidgetBundle`, a SwiftUI *struct*.
- 2026-07-26 | The widget installed but never appeared in the iOS widget gallery, and the fix that made
  it install is what made it invisible. `NSExtensionPrincipalClass` was set to
  `$(PRODUCT_MODULE_NAME).LoggedWidgetBundle`, but a Swift **struct** has no Objective-C class
  metadata, so `NSClassFromString` returns nil. installd only checks that the key is PRESENT (install
  succeeded), while WidgetKit resolves it when it probes the appex to enumerate kinds for the gallery —
  nil principal class, extension cannot launch, zero widgets offered. Fix: declare a real
  `@objc(LoggedWidgetPrincipal) final class ...: NSObject {}` purely to be named, and point the key at
  it; `@main` still drives WidgetKit. Rule: a plist key naming a class needs a CLASS, and "it satisfied
  the installer" is not evidence the runtime can resolve it — the two checks are different code.
  Corollary: satisfying a validator with a placeholder value is a smell; make the value real.
- 2026-07-26 | **The whole app was data-dead on a sideloaded iPhone — no exercises, no templates,
  workouts un-startable, backup import silently doing nothing, muscle sculpture spinning forever — and
  all of it was ONE fault: the IPA shipped `IOSSIMULATOR` builds of the native-asset dylibs.**
  `vtool -show-build` on the shipped `objective_c` and `sqlite3` frameworks read `platform
  IOSSIMULATOR` with an x86_64+arm64 fat binary (394KB/3.4MB), against `platform IOS` arm64-only
  (198KB/1.7MB) in the last known-good IPA. A simulator dylib cannot `dlopen` on a device, so
  `path_provider_foundation` died → `getApplicationDocumentsDirectory()` threw → drift never got a path
  → **`logged.sqlite` was never created at all** (proved by an empty `Documents/` in the on-device
  container). Cause: `flutter build ios --simulator --debug`, run as a verification step, writes into
  `build/native_assets/ios/` — a SINGLE directory with no per-platform separation — and the later
  release archive copied those simulator dylibs in verbatim without rebuilding them.
  Rules: (1) never run a simulator build between `flutter clean` and shipping a device IPA — the
  simulator build silently poisons `build/native_assets/ios/` for the device build; (2) the
  ship-blocking check on any iOS release artifact is
  `vtool -show-build Runner.app/Frameworks/<pkg>.framework/<pkg> | grep platform` — it must say `IOS`,
  never `IOSSIMULATOR`, and `lipo -archs` must not list x86_64. Size alone is a tell (a fat simulator
  binary is ~2x). (3) This is the THIRD distinct native-assets failure in this project (2026-07-21
  missing dylib, 2026-07-23 no-network fetch failure, now wrong-platform dylib): treat
  `build/native_assets/` as hostile state and verify the artifact, never the build log.
  Diagnostic that made this fast, worth reusing: `xcrun devicectl device info files --device <id>
  --domain-type appDataContainer --domain-identifier <installed.bundle.id>` lists the app's real
  container, so "is there even a database file?" is answerable without any logging. Note a sideloaded
  bundle ID is rewritten (Sideloadly appended the team ID: `com.palash.logged.KDZBF8D2X2`) — use the ID
  from `devicectl device info apps`, not the one in the project.
- 2026-07-26 | The iOS widget's real blocker was NEVER the principal class — it is the App Group
  entitlement colliding with a FREE Apple account, and I diagnosed two wrong causes before reading the
  crash logs. `--domain-type systemCrashLogs` showed **24 `LoggedWidgetExtension-*.ips` reports and
  zero for the main app**, starting with the very first install that contained the appex: the extension
  has never once launched. Every report is
  `termination {namespace: CODESIGNING, indicator: "Invalid Page"}` / `EXC_BAD_ACCESS` `SIGKILL`
  `KERN_PROTECTION_FAILURE` with `codeSigningTrustLevel: 0`, and it dies ~23ms in, before dyld
  initialises (`dyld_process_snapshot_get_shared_cache failed`, empty `usedImages`) — so no line of our
  Swift ever executes. Cause: `ios/LoggedWidgetExtension.entitlements` (wired via
  `CODE_SIGN_ENTITLEMENTS`, so it is live) requests
  `com.apple.security.application-groups = group.com.palash.logged`, and a free personal team CANNOT
  provision App Groups. The re-signed appex therefore carries an entitlement its profile cannot back and
  the kernel refuses to map its pages. The host app survives the same pass because the tool strips what
  it cannot provision there; its handling of a NESTED appex is not equivalent.
  Rules: (1) when an app extension "does not appear", pull `systemCrashLogs` FIRST — an appex that is
  killed at launch is indistinguishable from one that was never installed, and I burned two hypotheses
  (Sideloadly stripping plugins, unresolvable principal class) on symptoms a 5KB crash report settled
  outright; (2) a `CODESIGNING` / `Invalid Page` termination is an entitlement-vs-profile problem, never
  a code bug — do not go read the source; (3) grep the whole `ios/` dir for `*.entitlements`, not just
  the target's own folder — this one sits at `ios/LoggedWidgetExtension.entitlements` while the sources
  are in `ios/LoggedWidget/`, and I wrongly concluded "the appex has no entitlements" from listing only
  the latter. Corollary on account tier: App Groups AND HealthKit both require a paid membership, so on
  a free account the widget cannot be validly signed, and even if it could it could not read the shared
  container it exists to read. Verify the ceiling before writing code against it.
- 2026-08-09 | A `guard let cam = cameraNode` in iOS's `SceneManager.setCameraZoomLevel` had been
  silently no-op'ing on EVERY call since the feature shipped — `cameraNode` was declared but never
  assigned anywhere in the file. "Reset view" wasn't buggy, it was inert; nothing about a green build or
  a passing test suite could reveal this because nothing asserted the optional actually got populated.
  Rule: an optional-typed piece of state that a feature depends on needs a test proving it gets SET, not
  just tests proving what happens when it's present — a permanently-nil guard clause looks identical to
  working code in every code review that doesn't grep for the assignment.
- 2026-08-09 | Android tap-to-select silently failed for muscles whose glTF mesh has multiple primitives
  (39 of 47 in `muscular.glb`) — Filament/gltfio only propagates the node name to ONE primitive's
  renderable entity, and `SelectionManager.notifySelectionChanged` dropped any entity whose name didn't
  resolve. iOS's tap handler already walks up to the nearest named ancestor to solve the exact same class
  of problem (unnamed child geometry under a named node); Android had no equivalent. Rule: when a native
  plugin implements "the same" feature on two platforms independently, a defensive pattern present on one
  side (here: name-resolution fallback) is a signal to check whether the other side needs it too — it is
  rarely a coincidence that only one platform anticipated the problem.
- 2026-08-09 | Piping a long-running download through `head -N`
  (`xcodebuild -downloadPlatform iOS | head -20`) sends SIGPIPE to the writer once `head`'s line quota is
  hit, killing the download mid-transfer — and the backgrounded task still reported exit 0 because that
  was `head`'s exit code, not the download's. Rule: never pipe a long-running download/build command
  through `head`; redirect to a log file and `tail`/`grep` it instead.
- 2026-08-09 | A previously-working `flutter build ipa` started failing with "iOS 26.5 is not installed"
  after Xcode silently auto-updated (26.4→26.6) between sessions — looked like a clean missing-component
  fix (`xcodebuild -downloadPlatform iOS`), but the actual blocker underneath was the machine's data
  volume sitting at 100% capacity (1.1GB free of 460GB), which is what made the first download attempt
  fail/truncate. Rule: when a previously-working build tool suddenly complains about a missing
  platform/component, check disk space before assuming a straightforward re-download will fix it.
- 2026-08-09 | `codex exec` hit its account usage limit mid-session (fixed reset schedule, e.g. "try
  again Aug 11"), and the failure was an `ERROR:` line inside an otherwise exit-0 log, not an obvious
  crash. Rule: when codex is unavailable for a review pass, don't skip review — do it manually against
  the same risk-area checklist the codex prompt specified, reading the actual diff and code, not just
  trusting a green test suite.
- 2026-08-09 | Android's "Reset view" made the muscle model dramatically SMALLER than on first load,
  not restored to its original framing — the opposite of what iOS's `resetCamera()` does, and the
  opposite of what "reset" should mean. Root cause: `CameraController.kt`'s `resetOrbit()` hardcoded
  `zoomLevel = 1.0f`, completely ignoring the `defaultZoom = 3.0` the Dart side sends via `setZoom()`
  right after every model load — reset didn't restore the initial state, it jumped to an unrelated
  neutral value 3x farther out. iOS never had this bug because `SceneManager.swift` captures a reset
  baseline the first time `setCameraZoomLevel` is called after load
  (`shouldCaptureNextZoomAsResetBaseline`), so its reset always matches initial framing — Android had
  no equivalent capture step. Fixed by porting the same capture-on-first-zoom-after-load pattern to
  `CameraController.kt` (`resetZoomLevel` + `shouldCaptureNextZoomAsResetBaseline`, captured in
  `setZoom()`, consumed in `resetOrbit()`). Rule: when a "reset" button's behavior diverges between
  two platforms implementing "the same" feature, don't assume the divergent one is buggy in isolation
  — read the platform that behaves CORRECTLY first, since it usually already contains the exact
  pattern (a captured baseline, a stored initial value) the broken one is missing.
- 2026-08-09 | Extending an existing per-exercise field (bias axis) to bundled/library exercises hit a
  dormant trap that only mattered once the door was opened: `exercise_anatomy_service.dart`'s
  `enrichBundledExercises()` re-syncs `biasMuscleA/B` (and primary/secondary muscles) from
  `assets/data/exercise_library.json` for every non-custom exercise on EVERY app launch — a silent
  overwrite that would have reverted any user-set bias axis on a bundled exercise on their very next
  launch, making the feature appear to work once and then "forget itself." This is the SAME failure
  class as the documented `backfillWeightEntryOnce`/`backfillPullUpOnce` guards in the same file, just
  not yet hit because no UI had ever let a user write to a bundled exercise's bias columns before. Fix:
  a per-row `biasAxisUserSet` flag (schema v9), set whenever a user explicitly calls `updateBiasAxis`
  (including clearing it back to null — a deliberate choice, not "back to default"), and the enrich
  sync now leaves `biasMuscleA/B` untouched on protected rows. Rule: before exposing an existing
  write-path to a wider set of rows than it was originally scoped for, grep for every OTHER writer of
  the same columns on those rows — a sync/backfill routine that was safe when the rows were
  unreachable by users can become a silent-revert bug the moment they become reachable.
- 2026-08-09 | "Swipe down to dismiss the keyboard, globally" looked like a 25-call-site mechanical
  edit (every `ListView`/`SingleChildScrollView`/`ReorderableListView` in the app individually passed
  `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag`), but Flutter already has a
  single global hook for exactly this: every `ScrollView.keyboardDismissBehavior` falls back to
  `ScrollBehavior.getKeyboardDismissBehavior(context)` (default `.manual`) via the ambient
  `ScrollConfiguration` that `MaterialApp` installs around its whole `Navigator` — so one
  `MaterialApp.scrollBehavior` override covers every scrollable app-wide, including dialogs/sheets
  pushed later and any screen added in the future, with zero per-widget edits. Added
  `lib/core/keyboard_dismiss_scroll_behavior.dart` (`KeyboardDismissScrollBehavior extends
  MaterialScrollBehavior`, overrides `getKeyboardDismissBehavior` to always return `.onDrag`) and wired
  it into `MaterialApp.scrollBehavior` in `main.dart`. Left the 2 existing explicit per-widget
  overrides (`plate_calculator_sheet.dart`, `set_editor_sheet.dart`) alone — redundant now but
  harmless. Rule: before doing a mechanical find-and-edit-N-call-sites task, check whether the
  framework/library exposes a single ambient/ancestor-level override point for that exact behavior —
  "global" often has a literal one-line answer, not just "apply the same edit everywhere."
- 2026-08-09 | Delegated authoring ~231 new `exercise_library.json` entries to codex, including my own
  instruction that `weightEntry: "perSide"` applies to "single-arm cable work" — wrong. `perSide` means
  two implements held simultaneously (one per hand), not unilateral/alternating-side work; it doubles
  `volumeKg`. Codex followed the bad instruction faithfully and its own schema/enum validator passed
  clean (right enum value, just semantically wrong for 40 of the 231 entries — one-arm kettlebell
  swings, single-leg cable kickbacks, single-arm curls all got silently double-counted). Schema
  validation catches "is this a valid enum value," not "is this enum value semantically correct for
  this specific exercise" — that needs a domain-level re-read of the generated data against the field's
  actual definition (`enums.dart` docstring + `WeightEntryLabel`), not just a passing validator. Rule:
  when delegating structured-data authoring, after schema validation passes, do a second manual pass
  asking "does the RULE I gave the delegate actually match the codebase's real semantics" — re-read the
  field's own doc comment, don't trust your own prompt's framing.
- 2026-08-09 | Auditing the per-set `sideCount` ("each side ×2") feature for correctness surfaced that
  it's applied inconsistently: correctly doubles reps in `setVolumeKg` and the per-exercise progress
  trend, but is silently ignored by both muscle-group SET-COUNTING paths (`live_muscle_state.dart`'s
  `MuscleSetRecord` has no `sideCount` field at all; `muscle_progress.dart`'s accumulator reads
  `record.sideCount` but never multiplies it in) — found by tracing one field's usage through every
  consumer rather than trusting that a passing test suite meant the feature was fully wired, since
  no existing test exercised `sideCount > 1` together with the set-counting assertions. Rule: when a
  per-set field has multiple consumers (volume math, trend math, set-counting), grep ALL of them and
  check each one actually reads the field, not just the one you're currently working in — a field
  correctly threaded through the DB layer and SOME consumers is easy to mistake for "correctly wired
  everywhere."
- 2026-08-09 | Design polish pass: wiring the previously-unused `StreakCard` into `dashboard_screen.dart`
  crashed the whole Home screen (`BoxConstraints forces an infinite height`, blank body) — I'd wrapped
  `StreakCard` + `StatTile` in `Row(crossAxisAlignment: CrossAxisAlignment.stretch, ...)` for equal
  height, but that Row is a direct child of a `ListView`, which gives its children UNBOUNDED height —
  `stretch` tries to fill that unbounded height and blows up. `flutter analyze` and all 227 tests stayed
  green because no widget test exists for `dashboard_screen.dart` at all; only caught because the user
  ran the actual app and sent a screenshot of the blank screen. Fix: wrap the `Row` in `IntrinsicHeight`
  — it gives the Row a bounded height computed from its children's intrinsic heights before `stretch`
  runs. Rule: `CrossAxisAlignment.stretch` on a `Row`/`Column` inside any unbounded-extent parent
  (`ListView`, `Column` without `mainAxisSize`, etc.) needs `IntrinsicHeight` (or a `SizedBox`/fixed
  height) around it — this is a distinct failure mode from the usual overflow errors and renders as a
  total blank instead of the usual red/yellow overflow banner, easy to mistake for a data-loading bug.
  Corollary: `dashboard_screen.dart` has zero test coverage — worth a widget test asserting it renders
  without throwing, the way `muscle_anatomy_view_test.dart` already does for its screen.
- 2026-08-09 | Same pass, a second wrong root-cause diagnosis: the Custom Exercise dialog's 4-segment
  `SegmentedButton` (Weight/Bodyweight/Added/Assist) letter-wrapped "Bodyweight" mid-word. I assumed the
  `AlertDialog`'s constrained max-width (~280–560dp) was the limiting factor and "fixed" it by converting
  the dialog to a full-width `showModalBottomSheet` — `flutter analyze` passed, I reasoned through the
  width math and moved on. It was STILL broken: a full 390–430pt phone width split into 4 fixed-width
  segments still isn't enough room for a 10-character word at the button's default text style, sheet or
  dialog. Caught only because the user reopened the screen and sent a screenshot. Real fix: `SegmentedButton`
  is fundamentally the wrong widget for options whose label length varies — switched to the same
  `Wrap` + `ChoiceChip` pattern already used one field above it (Category), which reflows to fit instead
  of forcing N equal-width columns. Rule: when "fixed" text-wrap/overflow bugs recur after a container-size
  fix, question whether the container was ever the actual constraint — measure the fixed-width-columns math
  (label length × N vs. available width) before trusting that "more room" solved it, and re-render to
  confirm rather than reasoning it through. A `SegmentedButton` with more than 2-3 short, fixed-vocabulary
  labels is usually the wrong widget regardless of container width.
- 2026-08-09 | This machine's AppleScript/System Events cannot drive iOS Simulator taps: `osascript`
  querying `System Events` for the Simulator app's window (`window 1`, `first window`, or by name) fails
  with "Invalid index" even right after `activate` + a settle delay, and `count of windows` returns 0 —
  consistent with the executing process lacking macOS Accessibility permission (a one-time user grant in
  System Settings, not something grantable from a script). No `idb`/`idb_companion`/`cliclick` installed
  as a fallback either. `xcrun simctl` itself has no tap/interact command, only `io screenshot` (which
  DOES work) and app lifecycle (`boot`, `install`, `launch`). Rule: for iOS Simulator visual verification
  on this machine, screenshot-and-report is the ceiling — don't burn time retrying AppleScript window
  queries with different reference forms; either ask the user to interact and describe/screenshot, or
  install `idb`/`cliclick` first if actual automated tapping is needed.

- 2026-08-14 | A full-app audit found 50+ real bugs against a baseline of `flutter analyze` clean and
  `flutter test` 230/230 green. Not one of them was visible to that suite. The single highest-value
  finding (G1: the set editor persists muscle-bias weights normalised to SUM 1.0 while the domain
  reads them as MULTIPLIERS where null means 1.0 PER MUSCLE, so opening the set sheet halves an
  exercise's credited volume) was invisible because **no test crosses the UI↔domain seam** — the
  domain tests feed multiplier-shaped weights straight to `buildMuscleProgress` and never run the
  UI's `_normalizeBiasWeights`. Two currently-green assertions are mutually contradictory as a unit:
  `muscle_progress_test.dart:58` says 3 sets = 3.0 **per muscle**, `:362` says 3 sets = 3.0 **total
  across 3 muscles**. Rule: when a value is produced by UI code and consumed by domain code, write
  ONE test that runs both halves and asserts the unit survives the trip. Unit-of-measure bugs live
  exactly and only at that seam, and testing each side separately proves nothing.

- 2026-08-14 | Three separate features computed "effective sets per muscle" three different ways —
  `buildLiveMuscleState` and `buildMuscleProgress` bias-weighted, `loadDeloadData` always `+= 1` —
  and all three were compared against the SAME `VolumeLandmarks` (MEV/MAV/MRV). The deload assessor
  could report "exceeded MRV" while the 3D sculpture showed the muscle mid-band. Rule: when several
  call sites compute the same named quantity against a shared threshold, the computation must live
  in ONE function they all call. A duplicated formula is a divergence waiting for the next edit.

- 2026-08-14 | Deriving a fundamental property of an entity from its own history cannot work for the
  first record. `Exercises` has no `isTimed` column; `isTimedExercise` infers it from existing sets
  or a template prescription. A newly created custom exercise has neither, so the seconds field never
  renders and a Copenhagen plank has to be logged as "30 reps/side". Every workaround was a trap:
  `stretching` removes the weight field, `cardio` makes `isSetComplete` demand distance so the set
  never completes, and the CSV importer has no duration column either. Rule: inference is fine as a
  FALLBACK for seeded/library data that declares itself elsewhere, never as the only source of truth
  for a user-created row. Ask for it at creation and store it.

- 2026-08-14 | Three separate features were gated on optional data that most users never enter. RPE
  has no input on the inline set row at all, yet `suggestNextSet`'s `increaseAllowed` requires
  `topSet.rpe != null` (so the weight never increases, and the fall-through suggests the exact rep
  count already performed while the rationale says "add one rep"), and one of deload's three signals
  reads `rpeAtLoadSeries`, which is empty. The feature looked implemented and was inert. Rule:
  optional input must ENHANCE a decision, never be a precondition for having one. Before gating on a
  field, grep for its writers — if the fast path does not write it, the gate is an off switch.

- 2026-08-14 | A partial current week compared against a full-week threshold breaks silently in two
  places. `_rankScore` gives `offset 0` (this week, incomplete) the LARGEST decay weight, costing
  ~11 of 100 rank points every Monday — enough to cross a rank tier, so muscles visibly rank down and
  back up weekly with no change in training. Deload's overreach signal compares `values.last` (also
  the partial week) against MRV, which is why it could effectively never fire. Rule: score completed
  periods only, or prorate explicitly. Never let "so far this week" meet a threshold calibrated on a
  whole one.

- 2026-08-14 | `streak.dart` correctly builds dates as `DateTime(y, m, d - 1)` with a comment
  explaining that subtracting a `Duration` drifts an hour across DST — and then `_rankScore` and
  `loadDeloadData` both use `Duration(days: offset * 7)` and feed the result into an EXACT-equality
  map/list lookup, so a DST transition silently drops a whole week of volume. Rule: when the codebase
  already documents a hazard and its fix, grep for every other instance of the bad pattern in the
  same commit. A lesson recorded in one file is not applied until it is applied everywhere.

- 2026-08-14 | Backups carried device-local state. `appSettings` is exported wholesale and includes
  `healthExportedSessionIds` plus the three one-time backfill flags. Restoring on a NEW phone tells
  the app those workouts are already in Apple Health when that device's store is empty, so they are
  never exported and there is no UI to reset it — the mirror image of the 2026-07-26 duplicate-record
  lesson. Rule: a portable backup carries USER data. Device-local bookkeeping (external-system sync
  markers, one-time migration flags, permission state) must be namespaced and excluded on import.

- 2026-08-14 | Six audit rounds were needed because each pass had a blind spot the previous one could
  not see: round 1 audited logic and CRUD on EXISTING records and never traced the CREATION flows,
  which is where the user's actual reported bug lived. Rounds 2-6 each came from the user saying
  "there are more". Rule: an audit organised by code layer will miss whole categories. Also sweep by
  USER JOURNEY (create → log → edit → review → export) and by the inverse question — "which columns
  have no writer?" — which alone surfaced `Sessions.notes` (dead), `RestDays.note` (dead), and the
  fact that name, category, and `bodyweightFactor` are write-once on every exercise, custom or
  bundled.

- 2026-08-14 | Phase 1.4 fixed the 1RM proxy by taking the ENTERED value instead of `totalLoadKg`,
  but only in the `LoadingMode.external` branch of `_resistedMassKg`. `totalLoadKg` applies
  `weightEntry.implements` regardless of loading mode, so a weighted pull-up logged "per hand" kept
  doubling its added plate into the performance index. Rule: when a fix is "use value A instead of
  value B", grep every branch that reads value B — a `switch` over an enum is four call sites, not
  one, and fixing the branch named in the bug report leaves the siblings broken.

- 2026-08-14 | The backup importer committed its transaction and THEN rescaled muscle-bias weights.
  The imported rows are already stamped at the current schema version, so a crash in that gap strands
  share-scale weights that no migration will ever revisit — permanently halved volume, silently.
  Rule: a data-shape conversion that a migration would otherwise own must run inside the same
  transaction as the write it corrects. "After the transaction" is only safe for idempotent work that
  something else will retry.

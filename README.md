# Logged

A private, local-first Flutter workout tracker for Android and iOS.

Everything lives in a local SQLite database. There are no accounts, no servers, no
analytics, and no network calls — the only way data leaves the device is a backup
file you export yourself, or the opt-in Health export below, which writes to the
phone's own health store.

## Install

APKs are on the [releases page](https://github.com/LalwaniPalash/logged/releases/latest).
Take `arm64-v8a` unless you know your phone is older 32-bit hardware; `universal` is the
fallback. Android 8.0 (API 26) or newer.

Sideload only, so Android warns about the unknown source and there is no auto-update.
Each release ships `SHA256SUMS.txt` if you want to check the file:

```bash
shasum -a 256 -c SHA256SUMS.txt
```

## What it does

**Logging** — templates or ad-hoc workouts; per-set reps, load, RPE, duration and
distance. Load is recorded as *entered value plus unit*, so kg and lb both stay
lossless. Each set also carries how it was loaded (external weight, strict
bodyweight, added weight, or assisted) and whether the number entered was total or
per hand, because those mean different things for every downstream calculation.

**Coaching** — next-set suggestions from your own history, warm-up ramps, a plate
calculator, rest timers with notifications, deload detection, and a training-goal
profile (maintain / build / push) that scales volume landmarks, rank thresholds,
progression aggressiveness and deload sensitivity together.

**Progress** — an offline 3D muscle model, per-muscle ranks with concrete "how to
improve" guidance, optional population strength standards, streaks, weekly volume,
and a consistency heatmap.

**Data** — zipped JSON backup (import accepts `.zip` and `.json`), CSV set-history
export, and program import from pasted text or a file.

**Extras** — three home-screen widgets to pick from (small: streak and weekly sets;
medium: those plus your last workout; large: those plus weekly volume and the shape of
that workout), per-exercise demo video links, and an opt-in manual export of completed
workouts to Apple Health or Health Connect.

## Live muscle visualization

Progress includes an offline 3D muscular model that reacts to every saved
working set, including sets in an active workout. The state covers the current
Monday through today:

- Primary muscle: `1.0` effective set per saved set.
- Secondary muscle: `0.35` effective set per saved set.
- Warm-up sets are excluded.
- Intensity uses a fixed 12-effective-set ceiling instead of relative weekly
  normalization.

The model supports drag rotation, pinch zoom, named-muscle taps, exercise-level
contribution details, an all-muscle accessible browser, and a 2D fallback.

The bundled 47-mesh GLB is 18.5 MB and loads without a network connection.

## Platform requirements

- **Android: API 26+** (8.0 Oreo). `interactive_3d`/Filament needs 24; the Health
  Connect integration in `health` raises the floor to 26.
- **iOS: 14.0+.** WidgetKit requires 14, as does `health`.

On Android 8–13, Health Connect is a separate Play Store app rather than part of the
OS. Without it installed the export reports that it is unavailable and writes
nothing.

## Development

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

Platform build checks:

```sh
flutter build apk --debug
flutter build ios --simulator --debug
```

Release artifacts land in `dist/`:

```sh
flutter build apk --release
flutter build ipa --release --no-codesign   # unsigned; sideload or codesign
```

Default workout templates are seeded unless you opt out with
`--dart-define=LOGGED_SEED_DEFAULT_TEMPLATES=false`.

### iOS extras that live in the Xcode project

The widget extension and HealthKit capability are configured in
`ios/Runner.xcodeproj`, not by the Flutter tool. If you regenerate the iOS project
you must redo them — see [`ios/LoggedWidget/README.md`](ios/LoggedWidget/README.md).
Two non-obvious constraints:

- **Embed Foundation Extensions must run before Flutter's Thin Binary phase.**
  Thin Binary declares no outputs, so Xcode assumes it may touch anything in
  `Runner.app` including `PlugIns/`; embedding the extension after it produces
  `Cycle inside Runner`.
- **App Group `group.com.palash.logged` must be on both targets**, and match
  `LoggedWidgetKeys.appGroupId` and `HomeWidgetService`. Otherwise the app writes
  to its own sandbox and the widget shows placeholders forever.

### Home-screen widgets

`HomeWidgetService` writes one flat set of strings; each variant renders the slice it
cares about. Adding a variant means registering it in `_widgetVariants` **and** on the
platform: a `Widget` struct listed in `LoggedWidgetBundle` on iOS, a provider class
plus a `<receiver>` on Android.

Android layouts may only use views annotated `@RemoteView` — notably **not** a bare
`<View>`, which makes the launcher fail to inflate and show "couldn't add widget"
instead of the widget. `./gradlew :app:lintDebug` catches this as `RemoteViewLayout`
and is worth running on any widget-layout change; it needs
`JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`, since the
default JDK 26 makes AGP fail with a bare `26.0.1` error.

## Model license

The muscular model is a CC BY-SA 4.0 derivative based on BodyParts3D with
Z-Anatomy naming/identification, compiled by Adamas Designs. See
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) and
[`assets/models/ATTRIBUTION.md`](assets/models/ATTRIBUTION.md).

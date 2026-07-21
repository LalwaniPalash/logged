# Logged

A private, local-first Flutter workout tracker for Android and iOS.

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
Android requires API 24 or newer; iOS targets 13 or newer.

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
flutter build ios --simulator --no-codesign
```

## Model license

The muscular model is a CC BY-SA 4.0 derivative based on BodyParts3D with
Z-Anatomy naming/identification, compiled by Adamas Designs. See
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) and
[`assets/models/ATTRIBUTION.md`](assets/models/ATTRIBUTION.md).

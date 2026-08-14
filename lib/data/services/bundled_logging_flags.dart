import '../../core/domain/enums.dart';

/// The single source of truth for a BUNDLED exercise's timed/distance logging
/// flags.
///
/// Two paths must agree on this: [ExerciseSeedService] writes it on fresh
/// installs, and [ExerciseAnatomyService.backfillTimedExerciseOnce] heals
/// existing installs (seeding is `insertOrIgnore`, so a new asset field never
/// reaches rows that already exist). When these two drifted apart, a
/// `Farmer Carry` — category `strength`, `"tracksDistance": true` in the asset —
/// tracked distance on a new phone and silently did not on an upgraded one.
///
/// Category implies the flag for whole modalities; the asset carries the
/// exceptions that category cannot express (an isometric hold filed under
/// `bodyweight`, a loaded carry filed under `strength`).
({bool isTimed, bool tracksDistance}) bundledLoggingFlags({
  required ExerciseCategory category,
  required bool assetIsTimed,
  required bool assetTracksDistance,
}) => (
  isTimed: category == ExerciseCategory.stretching || assetIsTimed,
  tracksDistance: category == ExerciseCategory.cardio || assetTracksDistance,
);

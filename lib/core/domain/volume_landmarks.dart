import 'dart:convert';

import 'muscle.dart';
import 'training_goal.dart';

class VolumeLandmarks {
  const VolumeLandmarks({
    required this.mev,
    required this.mav,
    required this.mrv,
  }) : assert(mev >= 0),
       assert(mav >= mev),
       assert(mrv >= mav);

  final double mev;

  /// Upper edge of the maximum-adaptive-volume band. Its lower edge is 80%.
  final double mav;
  final double mrv;

  VolumeLandmarks scaled(double factor) =>
      VolumeLandmarks(mev: mev * factor, mav: mav * factor, mrv: mrv * factor);
}

enum VolumeZone { belowMev, developing, optimal, diminishing, overreaching }

VolumeZone zoneFor(double effectiveSets, VolumeLandmarks landmarks) {
  if (effectiveSets < landmarks.mev) return VolumeZone.belowMev;
  if (effectiveSets < landmarks.mav * 0.8) return VolumeZone.developing;
  if (effectiveSets <= landmarks.mav) return VolumeZone.optimal;
  if (effectiveSets <= landmarks.mrv) return VolumeZone.diminishing;
  return VolumeZone.overreaching;
}

/// Monotonic ramp used for material brightness. Zone hue remains separate so
/// amber/red recovery-risk states are not mistaken for "more green".
double coachingIntensity(double effectiveSets, VolumeLandmarks landmarks) =>
    (effectiveSets / landmarks.mav).clamp(0.0, 1.0);

extension VolumeZoneLabel on VolumeZone {
  String get label => switch (this) {
    VolumeZone.belowMev => 'below MEV',
    VolumeZone.developing => 'developing',
    VolumeZone.optimal => 'optimal',
    VolumeZone.diminishing => 'diminishing returns',
    VolumeZone.overreaching => 'overreaching / recovery risk',
  };
}

// Reviewed defaults model broad RP-style weekly volume ranges in effective
// sets. They are coaching bands, not hard biological ceilings; published
// dose-response work (Baz-Valle 2022; Pelland et al. 2025) supports diminishing
// returns rather than a "junk volume" cutoff.
const Map<MuscleId, VolumeLandmarks> defaultLandmarks = {
  MuscleId.upperChest: VolumeLandmarks(mev: 8, mav: 18, mrv: 24),
  MuscleId.midLowerChest: VolumeLandmarks(mev: 8, mav: 18, mrv: 24),
  MuscleId.serratusAnterior: VolumeLandmarks(mev: 4, mav: 12, mrv: 18),
  MuscleId.frontDelts: VolumeLandmarks(mev: 6, mav: 14, mrv: 20),
  MuscleId.sideDelts: VolumeLandmarks(mev: 6, mav: 18, mrv: 26),
  MuscleId.rearDelts: VolumeLandmarks(mev: 6, mav: 18, mrv: 26),
  MuscleId.rotatorCuff: VolumeLandmarks(mev: 4, mav: 12, mrv: 18),
  MuscleId.lats: VolumeLandmarks(mev: 8, mav: 18, mrv: 26),
  MuscleId.upperTraps: VolumeLandmarks(mev: 6, mav: 16, mrv: 22),
  MuscleId.midLowerTraps: VolumeLandmarks(mev: 6, mav: 16, mrv: 22),
  MuscleId.rhomboids: VolumeLandmarks(mev: 6, mav: 16, mrv: 22),
  MuscleId.spinalErectors: VolumeLandmarks(mev: 4, mav: 12, mrv: 18),
  MuscleId.biceps: VolumeLandmarks(mev: 6, mav: 16, mrv: 24),
  MuscleId.brachialis: VolumeLandmarks(mev: 4, mav: 14, mrv: 20),
  MuscleId.triceps: VolumeLandmarks(mev: 6, mav: 16, mrv: 24),
  MuscleId.forearms: VolumeLandmarks(mev: 4, mav: 12, mrv: 18),
  MuscleId.abs: VolumeLandmarks(mev: 4, mav: 14, mrv: 20),
  MuscleId.obliques: VolumeLandmarks(mev: 4, mav: 12, mrv: 18),
  MuscleId.hipFlexors: VolumeLandmarks(mev: 4, mav: 10, mrv: 16),
  MuscleId.quads: VolumeLandmarks(mev: 8, mav: 18, mrv: 26),
  MuscleId.hamstrings: VolumeLandmarks(mev: 6, mav: 16, mrv: 22),
  MuscleId.gluteMax: VolumeLandmarks(mev: 8, mav: 18, mrv: 26),
  MuscleId.gluteMedMin: VolumeLandmarks(mev: 6, mav: 16, mrv: 22),
  MuscleId.adductors: VolumeLandmarks(mev: 4, mav: 12, mrv: 18),
  MuscleId.calves: VolumeLandmarks(mev: 6, mav: 18, mrv: 26),
  MuscleId.tibialisAnterior: VolumeLandmarks(mev: 4, mav: 12, mrv: 18),
  MuscleId.neck: VolumeLandmarks(mev: 3, mav: 10, mrv: 16),
};

Map<MuscleId, VolumeLandmarks> resolveLandmarks({
  TrainingGoal goal = TrainingGoal.build,
  String? overridesJson,
}) {
  final resolved = {
    for (final entry in defaultLandmarks.entries)
      entry.key: entry.value.scaled(goal.landmarkScale),
  };
  if (overridesJson == null || overridesJson.trim().isEmpty) return resolved;

  try {
    final decoded = jsonDecode(overridesJson);
    if (decoded is! Map<String, dynamic>) return resolved;
    for (final entry in decoded.entries) {
      final muscle = MuscleId.fromId(entry.key);
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      final mev = (value['mev'] as num?)?.toDouble();
      final mav = (value['mav'] as num?)?.toDouble();
      final mrv = (value['mrv'] as num?)?.toDouble();
      if (mev == null ||
          mav == null ||
          mrv == null ||
          mev < 0 ||
          mav < mev ||
          mrv < mav) {
        continue;
      }
      resolved[muscle] = VolumeLandmarks(mev: mev, mav: mav, mrv: mrv);
    }
  } on FormatException {
    return resolved;
  } on ArgumentError {
    return resolved;
  }
  return resolved;
}

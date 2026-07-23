import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/core/domain/training_goal.dart';
import 'package:logged/core/domain/volume_landmarks.dart';

void main() {
  const landmarks = VolumeLandmarks(mev: 8, mav: 20, mrv: 28);

  test('zoneFor covers every landmark boundary', () {
    expect(zoneFor(7.99, landmarks), VolumeZone.belowMev);
    expect(zoneFor(8, landmarks), VolumeZone.developing);
    expect(zoneFor(15.99, landmarks), VolumeZone.developing);
    expect(zoneFor(16, landmarks), VolumeZone.optimal);
    expect(zoneFor(20, landmarks), VolumeZone.optimal);
    expect(zoneFor(20.01, landmarks), VolumeZone.diminishing);
    expect(zoneFor(28, landmarks), VolumeZone.diminishing);
    expect(zoneFor(28.01, landmarks), VolumeZone.overreaching);
  });

  test('coaching intensity is monotonic and capped in optimal range', () {
    final values = [
      for (final sets in [0.0, 4.0, 8.0, 16.0, 20.0, 28.0, 40.0])
        coachingIntensity(sets, landmarks),
    ];
    for (var index = 1; index < values.length; index++) {
      expect(values[index], greaterThanOrEqualTo(values[index - 1]));
    }
    expect(values.first, 0);
    expect(values[4], 1);
    expect(values.last, 1);
  });

  test('goal scales defaults before an absolute per-muscle override', () {
    final maintain = resolveLandmarks(goal: TrainingGoal.maintain);
    expect(maintain[MuscleId.quads]!.mev, closeTo(5.6, 0.001));

    final overridden = resolveLandmarks(
      goal: TrainingGoal.push,
      overridesJson: '{"rear_delts":{"mev":8,"mav":16,"mrv":24}}',
    );
    expect(overridden[MuscleId.rearDelts]!.mev, 8);
    expect(
      overridden[MuscleId.quads]!.mev,
      defaultLandmarks[MuscleId.quads]!.mev * 1.25,
    );
  });

  test('invalid override JSON falls back without losing defaults', () {
    final resolved = resolveLandmarks(overridesJson: '{not json');
    expect(resolved.length, MuscleId.values.length);
    expect(
      resolved[MuscleId.sideDelts]!.mev,
      defaultLandmarks[MuscleId.sideDelts]!.mev,
    );
  });

  test('known weekly muscle counts map to their individual zones', () {
    final resolved = resolveLandmarks();
    expect(zoneFor(4, resolved[MuscleId.rearDelts]!), VolumeZone.belowMev);
    expect(zoneFor(16, resolved[MuscleId.quads]!), VolumeZone.optimal);
    expect(zoneFor(27, resolved[MuscleId.calves]!), VolumeZone.overreaching);
  });
}

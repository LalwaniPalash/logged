import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/live_muscle_state.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/core/domain/muscle_map.dart';

void main() {
  test('detailed live loads collapse into the legacy 2D fallback regions', () {
    final state = LiveMuscleState({
      MuscleId.sideDelts: const MuscleLoad(
        muscle: MuscleId.sideDelts,
        primarySets: 3,
        secondarySets: 0,
        exercises: [],
      ),
      MuscleId.upperTraps: const MuscleLoad(
        muscle: MuscleId.upperTraps,
        primarySets: 0,
        secondarySets: 3,
        exercises: [],
      ),
      MuscleId.gluteMedMin: const MuscleLoad(
        muscle: MuscleId.gluteMedMin,
        primarySets: 6,
        secondarySets: 0,
        exercises: [],
      ),
    });

    final intensities = regionIntensitiesFromLiveState(state);
    expect(intensities[BodyRegion.shoulders], closeTo(0.25, 0.0001));
    expect(intensities[BodyRegion.back], closeTo(1.05 / 12, 0.0001));
    expect(intensities[BodyRegion.glutes], closeTo(0.5, 0.0001));
  });

  test('fallback uses the strongest detailed muscle in a broad region', () {
    final state = LiveMuscleState({
      MuscleId.biceps: const MuscleLoad(
        muscle: MuscleId.biceps,
        primarySets: 2,
        secondarySets: 0,
        exercises: [],
      ),
      MuscleId.triceps: const MuscleLoad(
        muscle: MuscleId.triceps,
        primarySets: 8,
        secondarySets: 0,
        exercises: [],
      ),
    });

    expect(regionIntensitiesFromLiveState(state)[BodyRegion.arms], 8 / 12);
  });

  test('regionForMuscle exposes the detailed fallback mapping', () {
    expect(regionForMuscle(MuscleId.quads), BodyRegion.quads);
    expect(regionForMuscle(MuscleId.hamstrings), BodyRegion.hamstrings);
  });

  test(
    'exercise intensities prefer primary over secondary in the same region',
    () {
      final intensities = regionIntensitiesForExercise(
        primary: const [MuscleId.quads],
        secondary: const [MuscleId.adductors, MuscleId.hamstrings],
      );

      expect(intensities[BodyRegion.quads], 1);
      expect(intensities[BodyRegion.hamstrings], 0.45);
    },
  );
}

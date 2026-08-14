import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/live_muscle_state.dart';
import 'package:logged/core/domain/muscle.dart';

void main() {
  final monday = DateTime(2026, 7, 20, 12);

  MuscleSetRecord record({
    required DateTime date,
    String exercise = 'Bench Press',
    List<MuscleId> primary = const [MuscleId.midLowerChest],
    List<MuscleId> secondary = const [MuscleId.frontDelts, MuscleId.triceps],
    Map<MuscleId, double>? muscleBiasWeights,
    bool isWarmup = false,
  }) => MuscleSetRecord(
    date: date,
    exerciseName: exercise,
    primaryMuscles: primary,
    secondaryMuscles: secondary,
    muscleBiasWeights: muscleBiasWeights,
    isWarmup: isWarmup,
  );

  test('counts every current-week working set with role weighting', () {
    final state = buildLiveMuscleState([
      record(date: monday),
      record(date: monday),
      record(date: monday, isWarmup: true),
      record(date: DateTime(2026, 7, 19, 12)),
    ], today: monday);

    final chest = state[MuscleId.midLowerChest]!;
    final frontDelts = state[MuscleId.frontDelts]!;
    expect(chest.primarySets, 2);
    expect(chest.secondarySets, 0);
    expect(chest.effectiveSets, 2);
    expect(chest.intensity, closeTo(2 / 12, 0.0001));
    expect(frontDelts.primarySets, 0);
    expect(frontDelts.secondarySets, 2);
    expect(frontDelts.effectiveSets, closeTo(0.7, 0.0001));
  });

  test('keeps exercise-level primary and secondary contributions', () {
    final state = buildLiveMuscleState([
      record(date: monday),
      record(
        date: monday,
        exercise: 'Chest Fly',
        primary: const [MuscleId.midLowerChest],
        secondary: const [],
      ),
      record(
        date: monday,
        exercise: 'Pullover',
        primary: const [MuscleId.lats],
        secondary: const [MuscleId.midLowerChest],
      ),
    ], today: monday);

    final chest = state[MuscleId.midLowerChest]!;
    expect(chest.primarySets, 2);
    expect(chest.secondarySets, 1);
    expect(chest.effectiveSets, closeTo(2.35, 0.0001));
    expect(chest.exercises.map((item) => item.exerciseName), [
      'Bench Press',
      'Chest Fly',
      'Pullover',
    ]);
    expect(chest.exercises.last.secondarySets, 1);
  });

  test('unassigned exercise records are harmless', () {
    final state = buildLiveMuscleState([
      record(date: monday, primary: const [], secondary: const []),
    ], today: monday);
    expect(state.isEmpty, isTrue);
  });

  test('intensity caps at twelve effective sets', () {
    final state = buildLiveMuscleState([
      for (var i = 0; i < 20; i++) record(date: monday),
    ], today: monday);
    expect(state[MuscleId.midLowerChest]!.intensity, 1);
  });

  test(
    'weight maps can bias tracked primaries while absent muscles keep full default credit',
    () {
      final state = buildLiveMuscleState([
        record(
          date: monday,
          exercise: 'Leg Press',
          primary: const [
            MuscleId.quads,
            MuscleId.gluteMax,
            MuscleId.hipFlexors,
          ],
          secondary: const [MuscleId.hamstrings],
          muscleBiasWeights: const {MuscleId.quads: 2, MuscleId.gluteMax: 0},
        ),
        record(
          date: monday,
          exercise: 'Leg Press',
          primary: const [
            MuscleId.quads,
            MuscleId.gluteMax,
            MuscleId.hipFlexors,
          ],
          secondary: const [MuscleId.hamstrings],
          muscleBiasWeights: const {MuscleId.quads: 1, MuscleId.gluteMax: 1},
        ),
        record(
          date: monday,
          exercise: 'Leg Press',
          primary: const [
            MuscleId.quads,
            MuscleId.gluteMax,
            MuscleId.hipFlexors,
          ],
          secondary: const [MuscleId.hamstrings],
          muscleBiasWeights: const {MuscleId.quads: 1, MuscleId.gluteMax: 1},
        ),
      ], today: monday);

      expect(state[MuscleId.quads]!.primarySets, 4);
      expect(state[MuscleId.gluteMax]!.primarySets, 2);
      expect(state[MuscleId.hipFlexors]!.primarySets, 3);
      expect(state[MuscleId.hamstrings]!.secondarySets, 3);
    },
  );
}

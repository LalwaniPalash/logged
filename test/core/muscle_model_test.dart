import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/live_muscle_state.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/core/domain/muscle_model.dart';

void main() {
  test('every visualized entity belongs to exactly one detailed muscle', () {
    final entities = <String>{};

    for (final entry in muscleModelEntities.entries) {
      expect(entry.value, isNotEmpty);
      for (final entity in entry.value) {
        expect(entities.add(entity), isTrue, reason: '$entity is duplicated');
        expect(muscleForModelEntity(entity), entry.key);
      }
    }

    expect(
      muscleModelEntities[MuscleId.neck],
      isNull,
      reason: 'The selected superficial model has no separate neck mesh.',
    );
    expect(entities, hasLength(47));
  });

  test('expands live muscle loads into per-entity intensities', () {
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
    });

    final values = muscleModelIntensities(state);
    expect(values['delt_side'], closeTo(0.25, 0.0001));
    expect(values['trap_upper'], closeTo(1.05 / 12, 0.0001));
    expect(values['delt_front'], 0);
  });

  test('unknown renderer entity is ignored', () {
    expect(muscleForModelEntity('not_a_muscle'), isNull);
  });
}

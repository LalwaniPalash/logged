import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/exercise_muscle_name_rules.dart';
import 'package:logged/core/domain/muscle.dart';

void main() {
  test('widens ambiguous adjustable chest equipment to both chest regions', () {
    expect(chestPrimaryMusclesFromExerciseName('Pec Deck'), {
      MuscleId.midLowerChest,
      MuscleId.upperChest,
    });
    expect(chestPrimaryMusclesFromExerciseName('Machine Chest Press'), {
      MuscleId.midLowerChest,
      MuscleId.upperChest,
    });
  });

  test('keeps fixed-angle presses and flies on a single chest region', () {
    expect(chestPrimaryMusclesFromExerciseName('Barbell Bench Press'), {
      MuscleId.midLowerChest,
    });
    expect(chestPrimaryMusclesFromExerciseName('Incline Dumbbell Flyes'), {
      MuscleId.upperChest,
    });
  });

  test(
    'inverts incline and decline push-up naming relative to bench press',
    () {
      expect(chestPrimaryMusclesFromExerciseName('Decline Push-Up'), {
        MuscleId.upperChest,
      });
      expect(chestPrimaryMusclesFromExerciseName('Incline Push-Up'), {
        MuscleId.midLowerChest,
      });
      expect(
        chestPrimaryMusclesFromExerciseName('Push-Ups With Feet Elevated'),
        {MuscleId.upperChest},
      );
    },
  );
}

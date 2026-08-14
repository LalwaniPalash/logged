import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/exercise_muscle_suggestion.dart';
import 'package:logged/core/domain/muscle.dart';

void main() {
  test('suggests bundled bench anatomy for a custom bench press name', () {
    final suggestion = suggestMuscles('Barbell Bench Press');

    expect(suggestion.primary, {MuscleId.midLowerChest});
    expect(suggestion.secondary, {
      MuscleId.frontDelts,
      MuscleId.triceps,
      MuscleId.serratusAnterior,
    });
  });

  test('prefers the most specific phrase over a generic token', () {
    final suggestion = suggestMuscles('Hammer Strength Leg Press');

    expect(suggestion.primary, {MuscleId.quads, MuscleId.gluteMax});
    expect(suggestion.secondary, {MuscleId.hamstrings, MuscleId.adductors});
  });

  test('disambiguates leg curls before the generic curl keyword', () {
    final suggestion = suggestMuscles('Seated Leg Curl');

    expect(suggestion.primary, {MuscleId.hamstrings});
    expect(suggestion.secondary, {MuscleId.calves, MuscleId.gluteMax});
  });

  test('returns empty sets when no keyword matches', () {
    final suggestion = suggestMuscles('Mystery Movement');

    expect(suggestion.primary, isEmpty);
    expect(suggestion.secondary, isEmpty);
  });

  test('reuses incline chest rules for generic press matches', () {
    final suggestion = suggestMuscles('Incline Smith Press');

    expect(suggestion.primary, {MuscleId.upperChest});
    expect(suggestion.secondary, {
      MuscleId.frontDelts,
      MuscleId.triceps,
      MuscleId.serratusAnterior,
    });
  });

  test('widens ambiguous machine chest suggestions to both chest regions', () {
    final suggestion = suggestMuscles('Pec Deck');

    expect(suggestion.primary, {MuscleId.midLowerChest, MuscleId.upperChest});
    expect(suggestion.secondary, {MuscleId.frontDelts});
  });

  test('applies push-up angle inversion in auto-suggest', () {
    final suggestion = suggestMuscles('Decline Push-Up');

    expect(suggestion.primary, {MuscleId.upperChest});
    expect(suggestion.secondary, {
      MuscleId.frontDelts,
      MuscleId.triceps,
      MuscleId.serratusAnterior,
    });
  });

  test('treats landmine press as a shoulder press by default', () {
    final suggestion = suggestMuscles('Landmine Press');

    expect(suggestion.primary, {MuscleId.frontDelts, MuscleId.sideDelts});
    expect(suggestion.secondary, {
      MuscleId.triceps,
      MuscleId.upperChest,
      MuscleId.serratusAnterior,
    });
  });
}

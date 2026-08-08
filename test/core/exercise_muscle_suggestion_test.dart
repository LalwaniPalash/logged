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
}

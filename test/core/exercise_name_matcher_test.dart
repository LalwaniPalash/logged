import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/exercise_name_matcher.dart';

void main() {
  group('isDuplicateExerciseName', () {
    const existing = ['Barbell Bench Press', 'Pull-Up'];

    test('matches case-insensitively and ignores surrounding whitespace', () {
      expect(isDuplicateExerciseName('barbell bench press', existing), true);
      expect(isDuplicateExerciseName('  Pull-Up  ', existing), true);
    });

    test('does not flag distinct names', () {
      expect(isDuplicateExerciseName('Barbell Squat', existing), false);
    });

    test('does not flag an empty candidate', () {
      expect(isDuplicateExerciseName('   ', existing), false);
    });
  });
}

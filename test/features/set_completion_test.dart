import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/features/session/widgets/set_row.dart';

void main() {
  group('bodyweight completion is driven by loading mode, not category', () {
    test('a strength-category bodyweight lift completes on reps alone', () {
      // e.g. an Inverted Row filed under `strength` but logged bodyweight-only.
      expect(
        isSetComplete(
          category: ExerciseCategory.strength,
          loadingMode: LoadingMode.bodyweight,
          reps: 12,
        ),
        isTrue,
        reason: 'a bodyweight set has no weight to enter',
      );
      expect(
        setFieldsFor(
          category: ExerciseCategory.strength,
          loadingMode: LoadingMode.bodyweight,
        ),
        [SetField.reps],
        reason: 'no weight column for a pure bodyweight lift',
      );
    });

    test('assisted and added still require the load field', () {
      for (final mode in [
        LoadingMode.bodyweightAssisted,
        LoadingMode.bodyweightAdded,
      ]) {
        expect(
          isSetComplete(
            category: ExerciseCategory.strength,
            loadingMode: mode,
            reps: 12,
          ),
          isFalse,
          reason: '$mode carries a real load that must be logged',
        );
        expect(
          setFieldsFor(category: ExerciseCategory.strength, loadingMode: mode),
          contains(SetField.weight),
        );
      }
    });

    test('external strength still needs both weight and reps', () {
      expect(
        isSetComplete(
          category: ExerciseCategory.strength,
          loadingMode: LoadingMode.external,
          reps: 5,
        ),
        isFalse,
      );
      expect(
        isSetComplete(
          category: ExerciseCategory.strength,
          loadingMode: LoadingMode.external,
          reps: 5,
          weightValue: 60,
        ),
        isTrue,
      );
    });
  });
}

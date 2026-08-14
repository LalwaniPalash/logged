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

  test('a timed strength lift completes on hold time, never on reps', () {
    // A weighted Side Bridge is `strength` + external loading. The editor hides
    // and NULLS reps for a timed exercise, so a completion rule demanding reps
    // strands every set as incomplete and the rest timer never fires.
    expect(
      isSetComplete(
        category: ExerciseCategory.strength,
        loadingMode: LoadingMode.external,
        reps: null,
        weightValue: 10,
        durationSec: 45,
        timed: true,
      ),
      isTrue,
    );
    expect(
      setFieldsFor(
        category: ExerciseCategory.strength,
        loadingMode: LoadingMode.external,
        timed: true,
      ),
      const [SetField.weight, SetField.duration],
    );
  });

  test('a loaded carry completes on distance and shows a metres column', () {
    // Audit F2: a Farmer's Walk is `strength` category but measured in metres.
    expect(
      isSetComplete(
        category: ExerciseCategory.strength,
        loadingMode: LoadingMode.external,
        reps: null,
        weightValue: 32,
        distanceMeters: 40,
        tracksDistance: true,
      ),
      isTrue,
    );
    // Weight is still required — a carry with no load is not a logged carry.
    expect(
      isSetComplete(
        category: ExerciseCategory.strength,
        loadingMode: LoadingMode.external,
        reps: null,
        weightValue: null,
        distanceMeters: 40,
        tracksDistance: true,
      ),
      isFalse,
    );
    expect(
      setFieldsFor(
        category: ExerciseCategory.strength,
        loadingMode: LoadingMode.external,
        tracksDistance: true,
      ),
      const [SetField.weight, SetField.distance],
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/features/session/widgets/set_row.dart';

/// Which columns a set shows. This used to have a twin, `isSetComplete`, that
/// guessed from the same inputs whether a set counted as finished — and the
/// guess drove the rest timer. It was wrong in both directions on a real
/// phone (a seeded set fired the countdown before it was performed; a 0 kg
/// Dead Bug never fired it at all), so finishing a set is now an explicit tick
/// and only the column layout is still derived.
void main() {
  test('a strength-category bodyweight lift needs no weight column', () {
    // e.g. an Inverted Row filed under `strength` but logged bodyweight-only.
    expect(
      setFieldsFor(
        category: ExerciseCategory.strength,
        loadingMode: LoadingMode.bodyweight,
      ),
      [SetField.reps],
    );
  });

  test('assisted and added still show the load field', () {
    for (final mode in [
      LoadingMode.bodyweightAssisted,
      LoadingMode.bodyweightAdded,
    ]) {
      expect(
        setFieldsFor(category: ExerciseCategory.strength, loadingMode: mode),
        contains(SetField.weight),
        reason: '$mode carries a real load that must be logged',
      );
    }
  });

  test('a timed strength lift swaps reps for a hold time', () {
    // A weighted Side Bridge is `strength` + external loading, prescribed in
    // seconds. The editor hides and NULLS reps for it.
    expect(
      setFieldsFor(
        category: ExerciseCategory.strength,
        loadingMode: LoadingMode.external,
        timed: true,
      ),
      const [SetField.weight, SetField.duration],
    );
  });

  test('a loaded carry shows a metres column instead of reps', () {
    // Audit F2: a Farmer's Walk is `strength` category but measured in metres.
    expect(
      setFieldsFor(
        category: ExerciseCategory.strength,
        loadingMode: LoadingMode.external,
        tracksDistance: true,
      ),
      const [SetField.weight, SetField.distance],
    );
  });

  test('cardio and stretching keep their own shapes', () {
    expect(
      setFieldsFor(
        category: ExerciseCategory.cardio,
        loadingMode: LoadingMode.external,
      ),
      const [SetField.duration, SetField.distance],
    );
    expect(
      setFieldsFor(
        category: ExerciseCategory.stretching,
        loadingMode: LoadingMode.bodyweight,
      ),
      const [SetField.duration],
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/repositories/session_repository.dart';
import 'package:logged/features/session/active_session_screen.dart';

/// The full-screen rest timer used to label itself from the exercise that had
/// just been finished, so the last set of an exercise rested under the wrong
/// name and a set number that no longer existed. [nextUpAfter] resolves what
/// actually comes next.
void main() {
  Exercise exercise(int id, String name) => Exercise(
    id: id,
    name: name,
    category: ExerciseCategory.strength,
    muscleGroup: 'chest',
    primaryMuscles: '[]',
    secondaryMuscles: '[]',
    defaultUnit: WeightUnit.kg,
    weightEntry: WeightEntry.total,
    preferredLoadingMode: LoadingMode.external,
    bodyweightFactor: 1,
    isTimed: false,
    tracksDistance: false,
    anatomyEditedByUser: false,
    isCustom: false,
    isArchived: false,
    createdAt: DateTime(2026, 8, 20),
  );

  SetEntry set(int number, {required bool isDone, bool isWarmup = false}) =>
      SetEntry(
        id: number * 10,
        sessionExerciseId: 1,
        setNumber: number,
        reps: 8,
        weightValue: 60,
        unit: WeightUnit.kg,
        weightEntry: WeightEntry.total,
        sideCount: 1,
        loadingMode: LoadingMode.external,
        isWarmup: isWarmup,
        isDone: isDone,
        muscleBiasWeights: null,
      );

  SessionExerciseDetails detail({
    required int id,
    required String name,
    required List<SetEntry> sets,
    int? targetSets,
  }) => SessionExerciseDetails(
    sessionExercise: SessionExercise(
      id: id,
      sessionId: 1,
      exerciseId: id,
      position: id,
      targetSets: targetSets,
    ),
    exercise: exercise(id, name),
    sets: sets,
  );

  test('stays on the exercise while a later set is still unticked', () {
    final details = [
      detail(
        id: 1,
        name: 'Bench Press',
        sets: [set(1, isDone: true), set(2, isDone: false)],
        targetSets: 2,
      ),
      detail(id: 2, name: 'Row', sets: const []),
    ];

    expect(
      nextUpAfter(
        details: details,
        sessionExerciseId: 1,
        completedSetNumber: 1,
      ),
      (sessionExerciseId: 1, exerciseName: 'Bench Press', setNumber: 2),
    );
  });

  test('stays on the exercise while the prescription still owes a set', () {
    // Every logged set is ticked, but 3 were prescribed and only 2 exist.
    final details = [
      detail(
        id: 1,
        name: 'Bench Press',
        sets: [set(1, isDone: true), set(2, isDone: true)],
        targetSets: 3,
      ),
      detail(id: 2, name: 'Row', sets: const []),
    ];

    expect(
      nextUpAfter(
        details: details,
        sessionExerciseId: 1,
        completedSetNumber: 2,
      ),
      (sessionExerciseId: 1, exerciseName: 'Bench Press', setNumber: 3),
    );
  });

  test('warm-ups do not pay off the prescribed set count', () {
    final details = [
      detail(
        id: 1,
        name: 'Bench Press',
        sets: [
          set(1, isDone: true, isWarmup: true),
          set(2, isDone: true),
          set(3, isDone: true),
        ],
        targetSets: 3,
      ),
      detail(id: 2, name: 'Row', sets: const []),
    ];

    expect(
      nextUpAfter(
        details: details,
        sessionExerciseId: 1,
        completedSetNumber: 3,
      ),
      (sessionExerciseId: 1, exerciseName: 'Bench Press', setNumber: 4),
      reason: '2 working sets of the 3 prescribed have been done',
    );
  });

  test('an unticked warm-up above the finished set is behind, not next', () {
    final details = [
      detail(
        id: 1,
        name: 'Bench Press',
        sets: [
          set(1, isDone: false, isWarmup: true),
          set(2, isDone: true),
          set(3, isDone: true),
        ],
        targetSets: 2,
      ),
      detail(id: 2, name: 'Barbell Row', sets: const []),
    ];

    expect(
      nextUpAfter(
        details: details,
        sessionExerciseId: 1,
        completedSetNumber: 3,
      ),
      (sessionExerciseId: 2, exerciseName: 'Barbell Row', setNumber: 1),
      reason: 'the lifter has moved past set 1, ticked or not',
    );
  });

  test('names the NEXT exercise once this one is finished', () {
    final details = [
      detail(
        id: 1,
        name: 'Bench Press',
        sets: [set(1, isDone: true), set(2, isDone: true)],
        targetSets: 2,
      ),
      detail(id: 2, name: 'Barbell Row', sets: const []),
    ];

    expect(
      nextUpAfter(
        details: details,
        sessionExerciseId: 1,
        completedSetNumber: 2,
      ),
      (sessionExerciseId: 2, exerciseName: 'Barbell Row', setNumber: 1),
    );
  });

  test('points at the next exercise\'s first unticked set, not always 1', () {
    final details = [
      detail(
        id: 1,
        name: 'Bench Press',
        sets: [set(1, isDone: true)],
        targetSets: 1,
      ),
      detail(
        id: 2,
        name: 'Barbell Row',
        sets: [set(1, isDone: true), set(2, isDone: false)],
        targetSets: 2,
      ),
    ];

    expect(
      nextUpAfter(
        details: details,
        sessionExerciseId: 1,
        completedSetNumber: 1,
      ),
      (sessionExerciseId: 2, exerciseName: 'Barbell Row', setNumber: 2),
    );
  });

  test('returns null after the last set of the last exercise', () {
    final details = [
      detail(
        id: 1,
        name: 'Bench Press',
        sets: [set(1, isDone: true)],
        targetSets: 1,
      ),
    ];

    expect(
      nextUpAfter(
        details: details,
        sessionExerciseId: 1,
        completedSetNumber: 1,
      ),
      isNull,
    );
  });

  test('an exercise with no prescription is done when its sets are ticked', () {
    final details = [
      detail(id: 1, name: 'Bench Press', sets: [set(1, isDone: true)]),
      detail(id: 2, name: 'Barbell Row', sets: const []),
    ];

    expect(
      nextUpAfter(
        details: details,
        sessionExerciseId: 1,
        completedSetNumber: 1,
      ),
      (sessionExerciseId: 2, exerciseName: 'Barbell Row', setNumber: 1),
    );
  });
}

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/repositories/muscle_exercise_index.dart';

void main() {
  test('maps muscles primary-first and excludes archived exercises', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    Future<int> add(
      String name, {
      List<MuscleId> primary = const [],
      List<MuscleId> secondary = const [],
      bool archived = false,
    }) => database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: name,
            category: ExerciseCategory.strength,
            muscleGroup: 'back',
            primaryMuscles: Value(encodeMuscleIds(primary)),
            secondaryMuscles: Value(encodeMuscleIds(secondary)),
            isArchived: Value(archived),
          ),
        );

    await add('Row', primary: [MuscleId.lats], secondary: [MuscleId.biceps]);
    await add('Curl', primary: [MuscleId.biceps]);
    await add('Archived pulldown', primary: [MuscleId.lats], archived: true);
    await add('Custom pullover', primary: [MuscleId.lats]);

    final index = await MuscleExerciseIndex(database).build();

    expect(index[MuscleId.lats]!.map((match) => match.exercise.name), [
      'Custom pullover',
      'Row',
    ]);
    expect(index[MuscleId.biceps]!.map((match) => match.exercise.name), [
      'Curl',
      'Row',
    ]);
    expect(index[MuscleId.biceps]!.first.isPrimary, isTrue);
    expect(index[MuscleId.biceps]!.last.isPrimary, isFalse);
  });
}

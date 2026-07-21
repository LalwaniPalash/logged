import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/repositories/exercise_repository.dart';

void main() {
  test('updates exercise logging defaults together', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = ExerciseRepository(database);
    final id = await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Pull-up',
            category: ExerciseCategory.bodyweight,
            muscleGroup: 'back',
            defaultUnit: const Value(WeightUnit.kg),
          ),
        );

    await repository.updateLoggingDefaults(
      id,
      unit: WeightUnit.lb,
      weightEntry: WeightEntry.perSide,
      loadingMode: LoadingMode.bodyweightAdded,
    );

    final exercise = await database.select(database.exercises).getSingle();
    expect(exercise.defaultUnit, WeightUnit.lb);
    expect(exercise.weightEntry, WeightEntry.perSide);
    expect(exercise.preferredLoadingMode, LoadingMode.bodyweightAdded);
  });
}

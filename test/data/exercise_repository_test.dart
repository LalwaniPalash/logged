import 'package:drift/drift.dart' show Value;
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

  test('updates muscles for bundled exercises', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = ExerciseRepository(database);
    final id = await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Leg Press',
            category: ExerciseCategory.strength,
            muscleGroup: 'legs',
            primaryMuscles: const Value('["quads","glute_max"]'),
            secondaryMuscles: const Value('["hamstrings"]'),
          ),
        );

    await repository.updateMuscles(
      id,
      primaryMuscles: '["quads","glute_max","hamstrings"]',
      secondaryMuscles: '["adductors"]',
    );

    final exercise = await database.select(database.exercises).getSingle();
    expect(exercise.primaryMuscles, '["quads","glute_max","hamstrings"]');
    expect(exercise.secondaryMuscles, '["adductors"]');
  });
}

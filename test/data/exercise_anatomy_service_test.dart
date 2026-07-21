import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/services/exercise_anatomy_service.dart';

void main() {
  test(
    'enriches bundled exercises idempotently without changing custom ones',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Dumbbell Lateral Raise',
              category: ExerciseCategory.strength,
              muscleGroup: 'shoulders',
            ),
          );
      await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'My Raise',
              category: ExerciseCategory.strength,
              muscleGroup: 'custom',
              primaryMuscles: Value(jsonEncode(['front_delts'])),
              isCustom: const Value(true),
            ),
          );

      final asset = jsonEncode([
        {
          'name': 'Dumbbell Lateral Raise',
          'category': 'strength',
          'muscleGroup': 'shoulders',
          'primaryMuscles': ['side_delts'],
          'secondaryMuscles': ['upper_traps'],
          'defaultUnit': 'kg',
        },
      ]);
      final service = ExerciseAnatomyService(
        database,
        loadAsset: () async => asset,
      );

      expect(await service.enrichBundledExercises(), 1);
      expect(await service.enrichBundledExercises(), 0);

      final exercises = await database.select(database.exercises).get();
      final bundled = exercises.singleWhere((exercise) => !exercise.isCustom);
      final custom = exercises.singleWhere((exercise) => exercise.isCustom);
      expect(jsonDecode(bundled.primaryMuscles), ['side_delts']);
      expect(jsonDecode(bundled.secondaryMuscles), ['upper_traps']);
      expect(jsonDecode(custom.primaryMuscles), ['front_delts']);
      expect(jsonDecode(custom.secondaryMuscles), isEmpty);
    },
  );

  test(
    'backfills weightEntry once, then never overrides the user again',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Incline Dumbbell Bench Press',
              category: ExerciseCategory.strength,
              muscleGroup: 'chest',
            ),
          );
      await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'My Own Lift',
              category: ExerciseCategory.strength,
              muscleGroup: 'chest',
              isCustom: const Value(true),
            ),
          );

      const asset = '''
[
  {"name": "Incline Dumbbell Bench Press", "weightEntry": "perSide"},
  {"name": "My Own Lift", "weightEntry": "perSide"}
]
''';
      final service = ExerciseAnatomyService(
        database,
        loadAsset: () async => asset,
      );

      // First run upgrades the bundled row; the custom one is never touched.
      expect(await service.backfillWeightEntryOnce(), 1);
      final afterFirst = await database.select(database.exercises).get();
      expect(
        afterFirst
            .singleWhere((e) => e.name == 'Incline Dumbbell Bench Press')
            .weightEntry,
        WeightEntry.perSide,
      );
      expect(
        afterFirst.singleWhere((e) => e.name == 'My Own Lift').weightEntry,
        WeightEntry.total,
        reason: 'custom exercises must never be rewritten by the library',
      );

      // The user deliberately switches it back to total.
      await (database.update(
        database.exercises,
      )..where((e) => e.name.equals('Incline Dumbbell Bench Press'))).write(
        const ExercisesCompanion(weightEntry: Value(WeightEntry.total)),
      );

      // A later launch must NOT undo that choice.
      expect(await service.backfillWeightEntryOnce(), 0);
      final afterSecond = await database.select(database.exercises).get();
      expect(
        afterSecond
            .singleWhere((e) => e.name == 'Incline Dumbbell Bench Press')
            .weightEntry,
        WeightEntry.total,
        reason: 'backfill runs once; it must not fight the user every launch',
      );
    },
  );
}

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
}

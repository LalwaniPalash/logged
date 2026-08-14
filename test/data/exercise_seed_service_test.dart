import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/services/exercise_seed_service.dart';

void main() {
  test('seeding is idempotent', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final source = jsonEncode([
      {
        'name': 'Cable Lat Pulldown',
        'category': 'strength',
        'muscleGroup': 'lats',
        'primaryMuscles': ['lats'],
        'secondaryMuscles': ['biceps', 'brachialis'],
        'defaultUnit': 'lb',
      },
    ]);
    final service = ExerciseSeedService(
      database,
      loadAsset: () async => source,
    );

    await service.seedIfEmpty();
    await service.seedIfEmpty();

    final exercises = await database.select(database.exercises).get();
    expect(exercises, hasLength(1));
    expect(exercises.single.defaultUnit.name, 'lb');
    expect(exercises.single.weightEntry, WeightEntry.total);
    expect(jsonDecode(exercises.single.primaryMuscles), ['lats']);
    expect(jsonDecode(exercises.single.secondaryMuscles), [
      'biceps',
      'brachialis',
    ]);
  });

  test(
    'seeds the asset loading mode instead of defaulting to external',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final source = jsonEncode([
        {
          'name': 'Pull-Up',
          'category': 'bodyweight',
          'muscleGroup': 'back',
          'primaryMuscles': ['lats'],
          'secondaryMuscles': ['biceps'],
          'defaultUnit': 'kg',
          'preferredLoadingMode': 'bodyweightAdded',
        },
        {
          'name': 'Barbell Bench Press',
          'category': 'strength',
          'muscleGroup': 'chest',
          'primaryMuscles': ['chest'],
          'secondaryMuscles': ['front_delts'],
          'defaultUnit': 'kg',
        },
      ]);
      await ExerciseSeedService(
        database,
        loadAsset: () async => source,
      ).seedIfEmpty();

      final exercises = await database.select(database.exercises).get();
      final pullUp = exercises.singleWhere((e) => e.name == 'Pull-Up');
      final bench = exercises.singleWhere(
        (e) => e.name == 'Barbell Bench Press',
      );
      // Regression: fresh installs must not force a bodyweight lift onto the
      // `external` column default, which demanded a weight to log a rep.
      expect(pullUp.preferredLoadingMode, LoadingMode.bodyweightAdded);
      // Absent in the asset still means external.
      expect(bench.preferredLoadingMode, LoadingMode.external);
    },
  );

  test(
    'seeds timed and distance flags from category and reviewed asset fields',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final source = jsonEncode([
        {
          'name': 'Plank',
          'category': 'bodyweight',
          'muscleGroup': 'core',
          'primaryMuscles': ['abs'],
          'secondaryMuscles': ['obliques'],
          'defaultUnit': 'kg',
          'isTimed': true,
        },
        {
          'name': 'Hip Flexor Stretch',
          'category': 'stretching',
          'muscleGroup': 'hips',
          'primaryMuscles': ['hip_flexors'],
          'secondaryMuscles': [],
          'defaultUnit': 'kg',
        },
        {
          'name': 'Stationary Bike',
          'category': 'cardio',
          'muscleGroup': 'legs',
          'primaryMuscles': ['quads'],
          'secondaryMuscles': [],
          'defaultUnit': 'kg',
        },
      ]);

      await ExerciseSeedService(
        database,
        loadAsset: () async => source,
      ).seedIfEmpty();

      final exercises = await database.select(database.exercises).get();
      expect(
        exercises.singleWhere((exercise) => exercise.name == 'Plank').isTimed,
        isTrue,
      );
      expect(
        exercises
            .singleWhere((exercise) => exercise.name == 'Hip Flexor Stretch')
            .isTimed,
        isTrue,
      );
      expect(
        exercises
            .singleWhere((exercise) => exercise.name == 'Stationary Bike')
            .tracksDistance,
        isTrue,
      );
    },
  );
}

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
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

  test('syncs bundled anatomy rows to the reviewed asset', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Leg Press',
            category: ExerciseCategory.strength,
            muscleGroup: 'legs',
            primaryMuscles: const Value('["quads"]'),
            secondaryMuscles: const Value('["hamstrings"]'),
          ),
        );
    await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Barbell Back Squat',
            category: ExerciseCategory.strength,
            muscleGroup: 'legs',
            primaryMuscles: const Value('["glute_max"]'),
            secondaryMuscles: const Value('["hamstrings"]'),
          ),
        );

    final asset = jsonEncode([
      {
        'name': 'Leg Press',
        'primaryMuscles': ['quads', 'glute_max'],
        'secondaryMuscles': ['hamstrings', 'adductors'],
      },
      {
        'name': 'Barbell Back Squat',
        'primaryMuscles': ['quads', 'glute_max'],
        'secondaryMuscles': ['hamstrings', 'adductors'],
      },
    ]);
    final service = ExerciseAnatomyService(
      database,
      loadAsset: () async => asset,
    );

    expect(await service.enrichBundledExercises(), 2);

    final exercises = await database.select(database.exercises).get();
    final legPress = exercises.singleWhere(
      (exercise) => exercise.name == 'Leg Press',
    );
    final squat = exercises.singleWhere(
      (exercise) => exercise.name == 'Barbell Back Squat',
    );

    expect(jsonDecode(legPress.primaryMuscles), ['quads', 'glute_max']);
    expect(jsonDecode(legPress.secondaryMuscles), ['hamstrings', 'adductors']);
    expect(jsonDecode(squat.primaryMuscles), ['quads', 'glute_max']);
    expect(jsonDecode(squat.secondaryMuscles), ['hamstrings', 'adductors']);
  });

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

  test(
    'backfills bundled anatomy once without touching custom exercises',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Pec Deck',
              category: ExerciseCategory.strength,
              muscleGroup: 'chest',
              primaryMuscles: const Value('["mid_lower_chest"]'),
              secondaryMuscles: const Value('["front_delts"]'),
            ),
          );
      await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'My Pec Deck',
              category: ExerciseCategory.strength,
              muscleGroup: 'chest',
              primaryMuscles: const Value('["mid_lower_chest"]'),
              secondaryMuscles: const Value('["front_delts"]'),
              isCustom: const Value(true),
            ),
          );

      const asset = '''
[
  {
    "name": "Pec Deck",
    "primaryMuscles": ["mid_lower_chest", "upper_chest"],
    "secondaryMuscles": ["front_delts"]
  },
  {
    "name": "My Pec Deck",
    "primaryMuscles": ["mid_lower_chest", "upper_chest"],
    "secondaryMuscles": ["front_delts"]
  }
]
''';
      final service = ExerciseAnatomyService(
        database,
        loadAsset: () async => asset,
      );

      expect(await service.backfillMuscleAnatomyOnce(), 1);
      final afterFirst = await database.select(database.exercises).get();
      expect(
        jsonDecode(
          afterFirst.singleWhere((e) => e.name == 'Pec Deck').primaryMuscles,
        ),
        ['mid_lower_chest', 'upper_chest'],
      );
      expect(
        jsonDecode(
          afterFirst.singleWhere((e) => e.name == 'My Pec Deck').primaryMuscles,
        ),
        ['mid_lower_chest'],
        reason: 'custom exercises must never be rewritten by the library',
      );

      await (database.update(
        database.exercises,
      )..where((e) => e.name.equals('Pec Deck'))).write(
        const ExercisesCompanion(
          primaryMuscles: Value('["mid_lower_chest"]'),
          secondaryMuscles: Value('["front_delts","triceps"]'),
        ),
      );

      expect(await service.backfillMuscleAnatomyOnce(), 0);
      final afterSecond = await database.select(database.exercises).get();
      expect(
        jsonDecode(
          afterSecond.singleWhere((e) => e.name == 'Pec Deck').primaryMuscles,
        ),
        ['mid_lower_chest'],
        reason:
            'anatomy backfill runs once; it must not fight later user edits',
      );
      expect(
        jsonDecode(
          afterSecond.singleWhere((e) => e.name == 'Pec Deck').secondaryMuscles,
        ),
        ['front_delts', 'triceps'],
      );
    },
  );

  test(
    'versioned anatomy backfill skips user-edited rows and corrects clean ones',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final protectedId = await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Pec Deck',
              category: ExerciseCategory.strength,
              muscleGroup: 'chest',
              primaryMuscles: const Value('["mid_lower_chest"]'),
              secondaryMuscles: const Value('["front_delts","triceps"]'),
            ),
          );
      final cleanId = await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Leg Press',
              category: ExerciseCategory.strength,
              muscleGroup: 'legs',
              primaryMuscles: const Value('["quads"]'),
              secondaryMuscles: const Value('["hamstrings"]'),
            ),
          );
      await _ensureAnatomyEditedByUserColumn(database);
      await database.customStatement(
        'UPDATE exercises SET anatomy_edited_by_user = 1 WHERE id = ?',
        [protectedId],
      );
      await database
          .into(database.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(
              key: 'muscleAnatomyBackfilled',
              value: 'true',
            ),
          );

      final service = ExerciseAnatomyService(
        database,
        loadAsset: () async => jsonEncode([
          {
            'name': 'Pec Deck',
            'primaryMuscles': ['mid_lower_chest', 'upper_chest'],
            'secondaryMuscles': ['front_delts'],
          },
          {
            'name': 'Leg Press',
            'primaryMuscles': ['quads', 'glute_max'],
            'secondaryMuscles': ['hamstrings', 'adductors'],
          },
        ]),
      );

      expect(await service.backfillMuscleAnatomyOnce(), 1);

      final rows = await database
          .customSelect(
            'SELECT id, primary_muscles, secondary_muscles, '
            'anatomy_edited_by_user AS edited '
            'FROM exercises ORDER BY id',
          )
          .get();
      final protected = rows.singleWhere((row) => row.read<int>('id') == protectedId);
      final clean = rows.singleWhere((row) => row.read<int>('id') == cleanId);
      expect(
        protected.read<String>('primary_muscles'),
        '["mid_lower_chest"]',
      );
      expect(
        protected.read<String>('secondary_muscles'),
        '["front_delts","triceps"]',
      );
      expect(protected.read<int>('edited'), 1);
      expect(clean.read<String>('primary_muscles'), '["quads","glute_max"]');
      expect(clean.read<String>('secondary_muscles'), '["hamstrings","adductors"]');
    },
  );

  test('backfills Pull-Up once for existing installs', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final service = ExerciseAnatomyService(
      database,
      loadAsset: () async => '[]',
    );

    expect(await service.backfillPullUpOnce(), isTrue);
    expect(await service.backfillPullUpOnce(), isFalse);
    final pullUps = await (database.select(
      database.exercises,
    )..where((exercise) => exercise.name.equals('Pull-Up'))).get();
    expect(pullUps, hasLength(1));
    expect(pullUps.single.category, ExerciseCategory.bodyweight);
    expect(pullUps.single.preferredLoadingMode, LoadingMode.bodyweightAdded);
  });

  test('corrects a Pull-Up left on external by the older seed', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    // Simulate an install seeded before the loading-mode fix: Pull-Up exists
    // but is stuck on the `external` default, so it demands a bogus weight.
    await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Pull-Up',
            category: ExerciseCategory.bodyweight,
            muscleGroup: 'back',
            preferredLoadingMode: const Value(LoadingMode.external),
          ),
        );
    final service = ExerciseAnatomyService(
      database,
      loadAsset: () async => '[]',
    );

    expect(await service.backfillPullUpOnce(), isTrue);
    final pullUp = await (database.select(
      database.exercises,
    )..where((exercise) => exercise.name.equals('Pull-Up'))).getSingle();
    expect(pullUp.preferredLoadingMode, LoadingMode.bodyweightAdded);
    // Still one Pull-Up (corrected in place, not duplicated) and runs once.
    expect(await service.backfillPullUpOnce(), isFalse);
    final all = await (database.select(
      database.exercises,
    )..where((exercise) => exercise.name.equals('Pull-Up'))).get();
    expect(all, hasLength(1));
  });

  test(
    'does not override a deliberately chosen strict-bodyweight Pull-Up',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      // The user made Pull-Up strict bodyweight on purpose (not the legacy
      // `external` breakage) — the one-time heal must leave that alone.
      await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Pull-Up',
              category: ExerciseCategory.bodyweight,
              muscleGroup: 'back',
              preferredLoadingMode: const Value(LoadingMode.bodyweight),
            ),
          );
      final service = ExerciseAnatomyService(
        database,
        loadAsset: () async => '[]',
      );

      // Ran (flag set) but changed nothing.
      expect(await service.backfillPullUpOnce(), isFalse);
      final pullUp = await (database.select(
        database.exercises,
      )..where((exercise) => exercise.name.equals('Pull-Up'))).getSingle();
      expect(pullUp.preferredLoadingMode, LoadingMode.bodyweight);
    },
  );

  test(
    'backfills timed and distance flags once, correcting bundled rows only',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Plank',
              category: ExerciseCategory.bodyweight,
              muscleGroup: 'core',
            ),
          );
      await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Hip Flexor Stretch',
              category: ExerciseCategory.stretching,
              muscleGroup: 'hips',
            ),
          );
      await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Stationary Bike',
              category: ExerciseCategory.cardio,
              muscleGroup: 'legs',
            ),
          );
      await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'My Plank',
              category: ExerciseCategory.bodyweight,
              muscleGroup: 'custom',
              isCustom: const Value(true),
            ),
          );

      const asset = '''
[
  {"name": "Plank", "isTimed": true},
  {"name": "Hip Flexor Stretch"},
  {"name": "Stationary Bike"}
]
''';
      final service = ExerciseAnatomyService(
        database,
        loadAsset: () async => asset,
      );

      expect(await service.backfillTimedExerciseOnce(), 3);

      final firstPass = await database.select(database.exercises).get();
      expect(
        firstPass.singleWhere((exercise) => exercise.name == 'Plank').isTimed,
        isTrue,
        reason:
            'the backfill must CORRECT bundled rows already stored with false',
      );
      expect(
        firstPass
            .singleWhere((exercise) => exercise.name == 'Hip Flexor Stretch')
            .isTimed,
        isTrue,
      );
      expect(
        firstPass
            .singleWhere((exercise) => exercise.name == 'Stationary Bike')
            .tracksDistance,
        isTrue,
      );
      expect(
        firstPass
            .singleWhere((exercise) => exercise.name == 'My Plank')
            .isTimed,
        isFalse,
        reason: 'custom exercises must never be rewritten by the library',
      );

      await (database.update(database.exercises)
            ..where((exercise) => exercise.name.equals('Plank')))
          .write(const ExercisesCompanion(isTimed: Value(false)));

      expect(await service.backfillTimedExerciseOnce(), 0);
      final secondPass = await database.select(database.exercises).get();
      expect(
        secondPass.singleWhere((exercise) => exercise.name == 'Plank').isTimed,
        isFalse,
        reason: 'the one-time guard must not revert later user edits',
      );
    },
  );

  test(
    'backfill honours an asset distance flag on a strength-category carry',
    () async {
      // The backfill originally derived tracksDistance from `category == cardio`
      // alone while the seed path read the asset. A Farmer Carry is `strength`,
      // so it tracked distance on a fresh install and silently did not on an
      // upgraded one — audit F2 would have stayed broken for existing users.
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Farmer Carry',
              category: ExerciseCategory.strength,
              muscleGroup: 'forearms',
            ),
          );
      await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Side Bridge',
              category: ExerciseCategory.strength,
              muscleGroup: 'core',
            ),
          );

      const asset = '''
[
  {"name": "Farmer Carry", "tracksDistance": true},
  {"name": "Side Bridge", "isTimed": true}
]
''';
      final service = ExerciseAnatomyService(
        database,
        loadAsset: () async => asset,
      );

      expect(await service.backfillTimedExerciseOnce(), 2);

      final rows = await database.select(database.exercises).get();
      final carry = rows.singleWhere((row) => row.name == 'Farmer Carry');
      expect(carry.tracksDistance, isTrue);
      expect(carry.isTimed, isFalse);

      final bridge = rows.singleWhere((row) => row.name == 'Side Bridge');
      expect(bridge.isTimed, isTrue);
      expect(bridge.tracksDistance, isFalse);
    },
  );
}

Future<void> _ensureAnatomyEditedByUserColumn(AppDatabase database) async {
  final columns = await database
      .customSelect("PRAGMA table_info('exercises')")
      .get();
  final hasColumn = columns.any(
    (row) => row.read<String>('name') == 'anatomy_edited_by_user',
  );
  if (hasColumn) return;
  await database.customStatement(
    'ALTER TABLE exercises '
    'ADD COLUMN anatomy_edited_by_user INTEGER NOT NULL DEFAULT 0',
  );
}

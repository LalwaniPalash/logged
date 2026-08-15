import 'package:drift/drift.dart' show Value, Variable;
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

  test('updates muscles marks anatomy as user-edited', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = ExerciseRepository(database);
    final id = await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Chest Supported Row',
            category: ExerciseCategory.strength,
            muscleGroup: 'back',
            primaryMuscles: const Value('["lats"]'),
            secondaryMuscles: const Value('["biceps"]'),
          ),
        );
    await _ensureAnatomyEditedByUserColumn(database);

    await repository.updateMuscles(
      id,
      primaryMuscles: '["lats","rhomboids"]',
      secondaryMuscles: '["biceps"]',
    );

    final row = await database
        .customSelect(
          'SELECT anatomy_edited_by_user AS edited FROM exercises WHERE id = ?',
          variables: [Variable<int>(id)],
        )
        .getSingle();
    expect(row.read<int>('edited'), 1);
  });

  test('re-saving unchanged muscles leaves anatomy eligible for backfill', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = ExerciseRepository(database);
    final id = await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Barbell Bench Press',
            category: ExerciseCategory.strength,
            muscleGroup: 'chest',
            primaryMuscles: const Value('["pec_sternal"]'),
            secondaryMuscles: const Value('["triceps_long"]'),
          ),
        );
    await _ensureAnatomyEditedByUserColumn(database);

    // The editor sheet re-sends every field on every save, so a name-only edit
    // still routes the untouched muscles back through updateMuscles.
    await repository.updateDetails(id, name: 'Bench Press (Barbell)');
    await repository.updateMuscles(
      id,
      primaryMuscles: '["pec_sternal"]',
      secondaryMuscles: '["triceps_long"]',
    );

    final row = await database
        .customSelect(
          'SELECT anatomy_edited_by_user AS edited FROM exercises WHERE id = ?',
          variables: [Variable<int>(id)],
        )
        .getSingle();
    expect(row.read<int>('edited'), 0);
  });

  test(
    'delete returns false and keeps the row when the exercise has logged sets',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = ExerciseRepository(database);
      final exerciseId = await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Cable Row',
              category: ExerciseCategory.strength,
              muscleGroup: 'back',
            ),
          );
      final sessionId = await database
          .into(database.sessions)
          .insert(
            SessionsCompanion.insert(startedAt: DateTime(2026, 8, 14, 9)),
          );
      final sessionExerciseId = await database
          .into(database.sessionExercises)
          .insert(
            SessionExercisesCompanion.insert(
              sessionId: sessionId,
              exerciseId: exerciseId,
              position: 0,
            ),
          );
      await database
          .into(database.setEntries)
          .insert(
            SetEntriesCompanion.insert(
              sessionExerciseId: sessionExerciseId,
              setNumber: 1,
              reps: const Value(10),
            ),
          );

      final deleted = await repository.delete(exerciseId);

      final remaining = await database.select(database.exercises).get();
      expect(deleted, isFalse);
      expect(remaining.single.id, exerciseId);
    },
  );

  test(
    'delete returns false and keeps the row when the exercise is referenced by a template',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = ExerciseRepository(database);
      final exerciseId = await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Bulgarian Split Squat',
              category: ExerciseCategory.strength,
              muscleGroup: 'legs',
            ),
          );
      final templateId = await database
          .into(database.templates)
          .insert(TemplatesCompanion.insert(name: 'Leg Day', position: 0));
      await database
          .into(database.templateExercises)
          .insert(
            TemplateExercisesCompanion.insert(
              templateId: templateId,
              exerciseId: exerciseId,
              position: 0,
            ),
          );

      final deleted = await repository.delete(exerciseId);

      final remaining = await database.select(database.exercises).get();
      expect(deleted, isFalse);
      expect(remaining.single.id, exerciseId);
    },
  );

  test(
    'delete returns true and removes the row when there are no references',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = ExerciseRepository(database);
      final exerciseId = await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Sled Push',
              category: ExerciseCategory.strength,
              muscleGroup: 'legs',
            ),
          );

      final deleted = await repository.delete(exerciseId);

      final remaining = await database.select(database.exercises).get();
      expect(deleted, isTrue);
      expect(remaining, isEmpty);
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

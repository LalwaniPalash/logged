import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/services/backup_service.dart';
import 'package:logged/data/services/exercise_anatomy_service.dart';

void main() {
  test('backup payload round-trips all linked workout data', () async {
    final source = AppDatabase(NativeDatabase.memory());
    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    addTearDown(target.close);
    final exerciseId = await source
        .into(source.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Barbell Bench Press',
            category: ExerciseCategory.strength,
            muscleGroup: 'chest',
            primaryMuscles: Value(jsonEncode(['mid_lower_chest'])),
            secondaryMuscles: Value(jsonEncode(['front_delts', 'triceps'])),
            defaultUnit: const Value(WeightUnit.kg),
            weightEntry: const Value(WeightEntry.perSide),
            videoUrl: const Value('https://youtu.be/demo'),
            isCustom: const Value(false),
            isArchived: const Value(false),
          ),
        );
    final sessionId = await source
        .into(source.sessions)
        .insert(
          SessionsCompanion.insert(
            startedAt: DateTime.utc(2026, 7, 20),
            endedAt: Value(DateTime.utc(2026, 7, 20, 12)),
          ),
        );
    final linkId = await source
        .into(source.sessionExercises)
        .insert(
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: 0,
          ),
        );
    await source
        .into(source.setEntries)
        .insert(
          SetEntriesCompanion.insert(
            sessionExerciseId: linkId,
            setNumber: 1,
            reps: const Value(5),
            weightValue: const Value(100),
            unit: const Value(WeightUnit.kg),
            weightEntry: const Value(WeightEntry.perSide),
            sideCount: const Value(2),
          ),
        );
    await source
        .into(source.bodyweightEntries)
        .insert(
          BodyweightEntriesCompanion.insert(
            date: DateTime.utc(2026, 7, 1),
            value: 80,
            unit: WeightUnit.kg,
          ),
        );
    final payload = await BackupService(source).exportPayload();
    expect(payload['schemaVersion'], 7);
    await BackupService(target).replaceFromPayload(payload);
    final exercises = await target.select(target.exercises).get();
    expect(exercises, hasLength(1));
    expect(exercises.single.videoUrl, 'https://youtu.be/demo');
    expect(jsonDecode(exercises.single.primaryMuscles), ['mid_lower_chest']);
    expect(jsonDecode(exercises.single.secondaryMuscles), [
      'front_delts',
      'triceps',
    ]);
    expect(exercises.single.weightEntry, WeightEntry.perSide);
    expect(await target.select(target.sessions).get(), hasLength(1));
    final sets = await target.select(target.setEntries).get();
    expect(sets, hasLength(1));
    expect(sets.single.weightValue, 100);
    expect(sets.single.weightEntry, WeightEntry.perSide);
    expect(sets.single.sideCount, 2);
    expect(sets.single.loadingMode, LoadingMode.external);
    final bodyweights = await target.select(target.bodyweightEntries).get();
    expect(bodyweights, hasLength(1));
    expect(bodyweights.single.value, 80);
  });

  test('v2 backup imports and enriches bundled exercise anatomy', () async {
    final source = AppDatabase(NativeDatabase.memory());
    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    addTearDown(target.close);

    await source
        .into(source.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Dumbbell Lateral Raise',
            category: ExerciseCategory.strength,
            muscleGroup: 'shoulders',
          ),
        );
    final payload = await BackupService(source).exportPayload();
    payload['schemaVersion'] = 2;
    for (final exercise
        in (payload['exercises'] as List<dynamic>)
            .cast<Map<String, dynamic>>()) {
      exercise.remove('primaryMuscles');
      exercise.remove('secondaryMuscles');
    }

    final anatomyService = ExerciseAnatomyService(
      target,
      loadAsset: () async => jsonEncode([
        {
          'name': 'Dumbbell Lateral Raise',
          'primaryMuscles': ['side_delts'],
          'secondaryMuscles': ['upper_traps'],
        },
      ]),
    );
    await BackupService(
      target,
      anatomyService: anatomyService,
    ).replaceFromPayload(payload);

    final exercise = await target.select(target.exercises).getSingle();
    expect(jsonDecode(exercise.primaryMuscles), ['side_delts']);
    expect(jsonDecode(exercise.secondaryMuscles), ['upper_traps']);
  });

  test('CSV set history flattens per-hand and each-side into volume', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final exerciseId = await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            // Comma in the name proves RFC-4180 quoting.
            name: 'Row, Single-Arm',
            category: ExerciseCategory.strength,
            muscleGroup: 'back',
            defaultUnit: const Value(WeightUnit.kg),
          ),
        );
    final sessionId = await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(startedAt: DateTime.utc(2026, 7, 22, 9)),
        );
    final linkId = await db
        .into(db.sessionExercises)
        .insert(
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: 0,
          ),
        );
    await db
        .into(db.setEntries)
        .insert(
          SetEntriesCompanion.insert(
            sessionExerciseId: linkId,
            setNumber: 1,
            reps: const Value(8),
            weightValue: const Value(20),
            unit: const Value(WeightUnit.kg),
            weightEntry: const Value(WeightEntry.perSide),
            sideCount: const Value(2),
          ),
        );

    final csv = await BackupService(db).setHistoryCsv();
    final lines = csv.trim().split('\n');
    expect(lines.first, startsWith('date,exercise,set,warmup,weight,unit'));
    // 20 kg/hand × 2 hands × 8 reps × 2 sides = 640 kg.
    expect(lines[1], contains('"Row, Single-Arm"'));
    expect(lines[1], contains('kg,yes,8,yes'));
    expect(lines[1], endsWith(',640'));
  });

  test('CSV neutralises a formula-injection exercise name', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final exerciseId = await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            // A custom name a user could type to attack their own spreadsheet.
            name: '=HYPERLINK("evil")',
            category: ExerciseCategory.strength,
            muscleGroup: 'chest',
            defaultUnit: const Value(WeightUnit.kg),
          ),
        );
    final sessionId = await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(startedAt: DateTime.utc(2026, 7, 22, 9)),
        );
    final linkId = await db
        .into(db.sessionExercises)
        .insert(
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: 0,
          ),
        );
    await db
        .into(db.setEntries)
        .insert(
          SetEntriesCompanion.insert(
            sessionExerciseId: linkId,
            setNumber: 1,
            reps: const Value(5),
            weightValue: const Value(40),
            unit: const Value(WeightUnit.kg),
          ),
        );

    final csv = await BackupService(db).setHistoryCsv();
    // Leading `'` defuses the formula; the `=` never starts the cell.
    expect(csv, contains('"\'=HYPERLINK(""evil"")"'));
    expect(csv, isNot(contains(',=HYPERLINK')));
  });
}

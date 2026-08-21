import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/core/domain/muscle_progress.dart';
import 'package:logged/core/domain/workout_metrics.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/repositories/analytics_repository.dart';

void main() {
  test('live stream emits saved sets from an unfinished workout', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final exerciseId = await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Leg Press',
            category: ExerciseCategory.strength,
            muscleGroup: 'legs',
            primaryMuscles: Value(jsonEncode(['quads', 'glute_max'])),
            secondaryMuscles: Value(jsonEncode(['hamstrings', 'adductors'])),
          ),
        );
    final sessionId = await database
        .into(database.sessions)
        .insert(SessionsCompanion.insert(startedAt: DateTime(2026, 7, 20, 12)));
    final linkId = await database
        .into(database.sessionExercises)
        .insert(
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: 0,
          ),
        );
    final repository = AnalyticsRepository(database);
    final iterator = StreamIterator(repository.watchLiveMuscleSets());
    addTearDown(iterator.cancel);

    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, isEmpty);

    final setId = await database
        .into(database.setEntries)
        .insert(
          SetEntriesCompanion.insert(sessionExerciseId: linkId, setNumber: 1),
        );

    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, hasLength(1));
    final record = iterator.current.single;
    expect(record.exerciseName, 'Leg Press');
    expect(record.primaryMuscles, [MuscleId.quads, MuscleId.gluteMax]);
    expect(record.secondaryMuscles, [MuscleId.hamstrings, MuscleId.adductors]);
    expect(record.muscleBiasWeights, isNull);
    expect(record.isWarmup, isFalse);

    expect(
      await repository.loadCompletedSets(),
      isEmpty,
      reason: 'PR/volume analytics must still ignore active blank sets',
    );

    await (database.update(database.setEntries)
          ..where((set) => set.id.equals(setId)))
        .write(const SetEntriesCompanion(isWarmup: Value(true)));
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current.single.isWarmup, isTrue);

    await (database.delete(
      database.setEntries,
    )..where((set) => set.id.equals(setId))).go();
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, isEmpty);
  });

  test('muscle progress ignores an unfinished workout until it ends', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final exerciseId = await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Back Squat',
            category: ExerciseCategory.strength,
            muscleGroup: 'legs',
            primaryMuscles: Value(jsonEncode(['quads'])),
          ),
        );
    final sessionId = await database
        .into(database.sessions)
        .insert(SessionsCompanion.insert(startedAt: DateTime(2026, 7, 20, 12)));
    final linkId = await database
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
            sessionExerciseId: linkId,
            setNumber: 1,
            reps: const Value(5),
            weightValue: const Value(100),
            unit: const Value(WeightUnit.kg),
          ),
        );
    final repository = AnalyticsRepository(database);

    double scoreFor(Map<MuscleId, MuscleProgress> progress) =>
        progress[MuscleId.quads]?.rankScore ?? 0;

    expect(
      scoreFor(await repository.watchMuscleProgress().first),
      0,
      reason: 'rank must not move while the workout is still live',
    );

    await (database.update(database.sessions)
          ..where((row) => row.id.equals(sessionId)))
        .write(SessionsCompanion(endedAt: Value(DateTime(2026, 7, 20, 13))));

    expect(
      scoreFor(await repository.watchMuscleProgress().first),
      greaterThan(0),
      reason: 'finishing the workout is what banks the volume',
    );
  });

  test(
    'completed analytics use doubled volume but entered per-hand 1RM',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final exerciseId = await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Incline Dumbbell Bench Press',
              category: ExerciseCategory.strength,
              muscleGroup: 'chest',
            ),
          );
      final sessionId = await database
          .into(database.sessions)
          .insert(
            SessionsCompanion.insert(
              startedAt: DateTime(2026, 7, 20, 12),
              endedAt: Value(DateTime(2026, 7, 20, 13)),
            ),
          );
      final linkId = await database
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
              sessionExerciseId: linkId,
              setNumber: 1,
              reps: const Value(10),
              weightValue: const Value(7.5),
              unit: const Value(WeightUnit.lb),
              weightEntry: const Value(WeightEntry.perSide),
              sideCount: const Value(2),
            ),
          );

      final record = (await AnalyticsRepository(
        database,
      ).loadCompletedSets()).single;
      expect(
        record.volumeKg,
        closeTo(weightKg(15, WeightUnit.lb) * 20, 0.000001),
      );
      expect(
        record.estimatedOneRepMaxKg,
        closeTo(weightKg(7.5, WeightUnit.lb) * (1 + 10 / 30), 0.000001),
      );
    },
  );
}

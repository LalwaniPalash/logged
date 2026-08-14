import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/core/domain/muscle_bias.dart';
import 'package:logged/core/domain/warmup.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/repositories/set_repository.dart';

void main() {
  late AppDatabase database;
  late SetRepository repository;
  late int sessionExerciseId;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = SetRepository(database);

    final exerciseId = await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Barbell Row',
            category: ExerciseCategory.strength,
            muscleGroup: 'back',
          ),
        );
    final sessionId = await database
        .into(database.sessions)
        .insert(SessionsCompanion.insert(startedAt: DateTime(2026, 7, 25, 9)));
    sessionExerciseId = await database
        .into(database.sessionExercises)
        .insert(
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: 0,
          ),
        );
  });

  tearDown(() => database.close());

  test(
    'shiftSetNumbers only renumbers sets at or above the starting number',
    () async {
      await database.batch((batch) {
        batch.insertAll(database.setEntries, [
          for (var setNumber = 1; setNumber <= 3; setNumber++)
            SetEntriesCompanion.insert(
              sessionExerciseId: sessionExerciseId,
              setNumber: setNumber,
              reps: const Value(8),
              weightValue: const Value(60),
              unit: const Value(WeightUnit.kg),
            ),
        ]);
      });

      await repository.shiftSetNumbers(
        sessionExerciseId: sessionExerciseId,
        by: 2,
        fromNumber: 2,
      );

      final rows =
          await (database.select(database.setEntries)
                ..where(
                  (row) => row.sessionExerciseId.equals(sessionExerciseId),
                )
                ..orderBy([(row) => OrderingTerm.asc(row.setNumber)]))
              .get();
      expect(rows.map((row) => row.setNumber), [1, 4, 5]);
    },
  );

  test(
    'insertWarmupSets prepends warmups and shifts working sets together',
    () async {
      await database.batch((batch) {
        batch.insertAll(database.setEntries, [
          for (var setNumber = 1; setNumber <= 2; setNumber++)
            SetEntriesCompanion.insert(
              sessionExerciseId: sessionExerciseId,
              setNumber: setNumber,
              reps: const Value(5),
              weightValue: const Value(80),
              unit: const Value(WeightUnit.kg),
            ),
        ]);
      });

      await repository.insertWarmupSets(
        sessionExerciseId: sessionExerciseId,
        warmups: const [
          WarmupSet(weight: 20, reps: 8, label: 'Bar × 8'),
          WarmupSet(weight: 40, reps: 5, label: '40% × 5'),
        ],
        unit: WeightUnit.kg,
        weightEntry: WeightEntry.total,
        sideCount: 1,
        loadingMode: LoadingMode.external,
      );

      final rows =
          await (database.select(database.setEntries)
                ..where(
                  (row) => row.sessionExerciseId.equals(sessionExerciseId),
                )
                ..orderBy([(row) => OrderingTerm.asc(row.setNumber)]))
              .get();
      expect(rows.map((row) => row.setNumber), [1, 2, 3, 4]);
      expect(rows.take(2).every((row) => row.isWarmup), isTrue);
      expect(rows.skip(2).every((row) => !row.isWarmup), isTrue);
      expect(rows.map((row) => row.weightValue), [20.0, 40.0, 80.0, 80.0]);
    },
  );

  test('add and edit persist muscle bias weights', () async {
    final setId = await repository.add(
      sessionExerciseId: sessionExerciseId,
      setNumber: 1,
      reps: 8,
      weightValue: 60,
      unit: WeightUnit.kg,
      muscleBiasWeights: const {MuscleId.quads: 0.6, MuscleId.gluteMax: 0.4},
    );

    var set = await (database.select(
      database.setEntries,
    )..where((row) => row.id.equals(setId))).getSingle();
    expect(decodeMuscleBiasWeights(set.muscleBiasWeights), const {
      MuscleId.quads: 0.6,
      MuscleId.gluteMax: 0.4,
    });

    await repository.edit(
      setId,
      muscleBiasWeights: const Value<Map<MuscleId, double>?>({
        MuscleId.quads: 0.25,
        MuscleId.gluteMax: 0.75,
      }),
    );
    set = await (database.select(
      database.setEntries,
    )..where((row) => row.id.equals(setId))).getSingle();
    expect(decodeMuscleBiasWeights(set.muscleBiasWeights), const {
      MuscleId.quads: 0.25,
      MuscleId.gluteMax: 0.75,
    });
  });

  test('edit leaves unpassed fields untouched', () async {
    final setId = await repository.add(
      sessionExerciseId: sessionExerciseId,
      setNumber: 1,
      reps: 8,
      weightValue: 60,
      unit: WeightUnit.kg,
      weightEntry: WeightEntry.perSide,
      sideCount: 2,
      loadingMode: LoadingMode.bodyweightAdded,
      distanceMeters: 120,
      durationSec: 45,
      isWarmup: true,
      rpe: 8.5,
      muscleBiasWeights: const {MuscleId.quads: 1.5, MuscleId.gluteMax: 0.5},
      notes: 'Original note',
    );

    await repository.edit(setId, reps: const Value(10));

    final set = await (database.select(
      database.setEntries,
    )..where((row) => row.id.equals(setId))).getSingle();
    expect(set.reps, 10);
    expect(set.weightValue, 60);
    expect(set.unit, WeightUnit.kg);
    expect(set.weightEntry, WeightEntry.perSide);
    expect(set.sideCount, 2);
    expect(set.loadingMode, LoadingMode.bodyweightAdded);
    expect(set.distanceMeters, 120);
    expect(set.durationSec, 45);
    expect(set.isWarmup, isTrue);
    expect(set.rpe, 8.5);
    expect(decodeMuscleBiasWeights(set.muscleBiasWeights), const {
      MuscleId.quads: 1.5,
      MuscleId.gluteMax: 0.5,
    });
    expect(set.notes, 'Original note');
  });

  test('edit can explicitly clear nullable fields', () async {
    final setId = await repository.add(
      sessionExerciseId: sessionExerciseId,
      setNumber: 1,
      reps: 8,
      weightValue: 60,
      unit: WeightUnit.kg,
      weightEntry: WeightEntry.perSide,
      sideCount: 2,
      loadingMode: LoadingMode.bodyweightAdded,
      distanceMeters: 120,
      durationSec: 45,
      isWarmup: true,
      rpe: 8.5,
      muscleBiasWeights: const {MuscleId.quads: 1.5, MuscleId.gluteMax: 0.5},
      notes: 'Original note',
    );

    await repository.edit(
      setId,
      weightValue: const Value<double?>(null),
      unit: const Value<WeightUnit?>(null),
      distanceMeters: const Value<double?>(null),
      durationSec: const Value<int?>(null),
      rpe: const Value<double?>(null),
      muscleBiasWeights: const Value<Map<MuscleId, double>?>(null),
      notes: const Value<String?>(null),
    );

    final set = await (database.select(
      database.setEntries,
    )..where((row) => row.id.equals(setId))).getSingle();
    expect(set.weightValue, equals(null));
    expect(set.unit, equals(null));
    expect(set.distanceMeters, equals(null));
    expect(set.durationSec, equals(null));
    expect(set.rpe, equals(null));
    expect(set.muscleBiasWeights, equals(null));
    expect(set.notes, equals(null));
    expect(set.weightEntry, WeightEntry.perSide);
    expect(set.sideCount, 2);
    expect(set.loadingMode, LoadingMode.bodyweightAdded);
    expect(set.isWarmup, isTrue);
  });

  test('delete renumbers the remaining sets contiguously', () async {
    await database.batch((batch) {
      batch.insertAll(database.setEntries, [
        for (var setNumber = 1; setNumber <= 3; setNumber++)
          SetEntriesCompanion.insert(
            sessionExerciseId: sessionExerciseId,
            setNumber: setNumber,
            reps: const Value(5),
            weightValue: const Value(80),
            unit: const Value(WeightUnit.kg),
          ),
      ]);
    });

    final middleSet =
        await (database.select(database.setEntries)
              ..where((row) => row.sessionExerciseId.equals(sessionExerciseId))
              ..where((row) => row.setNumber.equals(2)))
            .getSingle();

    await repository.delete(middleSet.id);

    final rows =
        await (database.select(database.setEntries)
              ..where((row) => row.sessionExerciseId.equals(sessionExerciseId))
              ..orderBy([(row) => OrderingTerm.asc(row.setNumber)]))
            .get();
    expect(rows.map((row) => row.setNumber), [1, 2]);
    expect(rows.map((row) => row.reps), [5, 5]);

    await repository.add(
      sessionExerciseId: sessionExerciseId,
      setNumber: 3,
      reps: 5,
      weightValue: 80,
      unit: WeightUnit.kg,
    );

    final renumbered =
        await (database.select(database.setEntries)
              ..where((row) => row.sessionExerciseId.equals(sessionExerciseId))
              ..orderBy([(row) => OrderingTerm.asc(row.setNumber)]))
            .get();
    expect(renumbered.map((row) => row.setNumber), [1, 2, 3]);
  });

  test('delete of a non-existent id is a no-op', () async {
    await repository.add(
      sessionExerciseId: sessionExerciseId,
      setNumber: 1,
      reps: 8,
      weightValue: 60,
      unit: WeightUnit.kg,
    );

    await repository.delete(999999);

    final rows = await database.select(database.setEntries).get();
    expect(rows, hasLength(1));
    expect(rows.single.setNumber, 1);
  });

  test(
    'undo re-insert restores the original ordinal without duplicating a set number',
    () async {
      await repository.add(
        sessionExerciseId: sessionExerciseId,
        setNumber: 1,
        reps: 8,
        weightValue: 40,
        unit: WeightUnit.kg,
        isWarmup: true,
      );
      final deletedId = await repository.add(
        sessionExerciseId: sessionExerciseId,
        setNumber: 2,
        reps: 10,
        weightValue: 60,
        unit: WeightUnit.kg,
        weightEntry: WeightEntry.perSide,
        sideCount: 2,
        loadingMode: LoadingMode.bodyweightAdded,
        distanceMeters: 120,
        durationSec: 45,
        rpe: 8.5,
        muscleBiasWeights: const {MuscleId.quads: 1.5, MuscleId.gluteMax: 0.5},
        notes: 'Restore me',
      );
      await repository.add(
        sessionExerciseId: sessionExerciseId,
        setNumber: 3,
        reps: 6,
        weightValue: 80,
        unit: WeightUnit.kg,
      );

      final deletedSet = await (database.select(
        database.setEntries,
      )..where((row) => row.id.equals(deletedId))).getSingle();

      await repository.delete(deletedId);
      await repository.restoreDeletedSet(
        sessionExerciseId: deletedSet.sessionExerciseId,
        setNumber: deletedSet.setNumber,
        reps: deletedSet.reps,
        weightValue: deletedSet.weightValue,
        unit: deletedSet.unit,
        weightEntry: deletedSet.weightEntry,
        sideCount: deletedSet.sideCount,
        loadingMode: deletedSet.loadingMode,
        distanceMeters: deletedSet.distanceMeters,
        durationSec: deletedSet.durationSec,
        isWarmup: deletedSet.isWarmup,
        rpe: deletedSet.rpe,
        muscleBiasWeights: decodeMuscleBiasWeights(
          deletedSet.muscleBiasWeights,
        ),
        notes: deletedSet.notes,
      );

      final rows =
          await (database.select(database.setEntries)
                ..where(
                  (row) => row.sessionExerciseId.equals(sessionExerciseId),
                )
                ..orderBy([(row) => OrderingTerm.asc(row.setNumber)]))
              .get();
      expect(rows.map((row) => row.setNumber), [1, 2, 3]);
      expect(rows.where((row) => row.setNumber == 2), hasLength(1));
      final restored = rows.singleWhere((row) => row.setNumber == 2);
      expect(restored.reps, 10);
      expect(restored.weightEntry, WeightEntry.perSide);
      expect(restored.sideCount, 2);
      expect(restored.loadingMode, LoadingMode.bodyweightAdded);
      expect(restored.distanceMeters, 120);
      expect(restored.durationSec, 45);
      expect(restored.rpe, 8.5);
      expect(decodeMuscleBiasWeights(restored.muscleBiasWeights), const {
        MuscleId.quads: 1.5,
        MuscleId.gluteMax: 0.5,
      });
      expect(restored.notes, 'Restore me');
    },
  );
}

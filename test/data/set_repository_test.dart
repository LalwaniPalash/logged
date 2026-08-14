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
      muscleBiasWeights: const {MuscleId.quads: 0.25, MuscleId.gluteMax: 0.75},
    );
    set = await (database.select(
      database.setEntries,
    )..where((row) => row.id.equals(setId))).getSingle();
    expect(decodeMuscleBiasWeights(set.muscleBiasWeights), const {
      MuscleId.quads: 0.25,
      MuscleId.gluteMax: 0.75,
    });
  });
}

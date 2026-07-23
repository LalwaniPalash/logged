import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/repositories/session_repository.dart';

void main() {
  test(
    'seedForNextSet prefers in-session set, then prescription, then history',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = SessionRepository(database);

      final exerciseId = await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Dead Bug',
              category: ExerciseCategory.bodyweight,
              muscleGroup: 'core',
              defaultUnit: const Value(WeightUnit.lb),
              weightEntry: const Value(WeightEntry.total),
              preferredLoadingMode: const Value(LoadingMode.bodyweightAdded),
            ),
          );

      final completedSessionId = await database
          .into(database.sessions)
          .insert(
            SessionsCompanion.insert(
              startedAt: DateTime(2026, 7, 18, 12),
              endedAt: Value(DateTime(2026, 7, 18, 13)),
            ),
          );
      final completedLinkId = await database
          .into(database.sessionExercises)
          .insert(
            SessionExercisesCompanion.insert(
              sessionId: completedSessionId,
              exerciseId: exerciseId,
              position: 0,
            ),
          );
      await database
          .into(database.setEntries)
          .insert(
            SetEntriesCompanion.insert(
              sessionExerciseId: completedLinkId,
              setNumber: 1,
              reps: const Value(10),
              weightValue: const Value(25),
              unit: const Value(WeightUnit.lb),
              weightEntry: const Value(WeightEntry.total),
              loadingMode: const Value(LoadingMode.bodyweightAdded),
            ),
          );

      final activeSessionId = await database
          .into(database.sessions)
          .insert(
            SessionsCompanion.insert(startedAt: DateTime(2026, 7, 21, 12)),
          );
      final activeLinkId = await database
          .into(database.sessionExercises)
          .insert(
            SessionExercisesCompanion.insert(
              sessionId: activeSessionId,
              exerciseId: exerciseId,
              position: 0,
              minReps: const Value(8),
              sidesPerSet: const Value(2),
            ),
          );

      final seededFromHistory = await repository.seedForNextSet(
        sessionExerciseId: activeLinkId,
      );
      expect(seededFromHistory.reps, 8);
      expect(seededFromHistory.weightValue, 25);
      expect(seededFromHistory.unit, WeightUnit.lb);
      expect(seededFromHistory.loadingMode, LoadingMode.bodyweightAdded);
      expect(seededFromHistory.sideCount, 2);

      await database
          .into(database.setEntries)
          .insert(
            SetEntriesCompanion.insert(
              sessionExerciseId: activeLinkId,
              setNumber: 1,
              reps: const Value(7),
              weightValue: const Value(20),
              unit: const Value(WeightUnit.lb),
              weightEntry: const Value(WeightEntry.perSide),
              sideCount: const Value(1),
              loadingMode: const Value(LoadingMode.external),
            ),
          );

      final seededFromSession = await repository.seedForNextSet(
        sessionExerciseId: activeLinkId,
      );
      expect(seededFromSession.reps, 7);
      expect(seededFromSession.weightValue, 20);
      expect(seededFromSession.unit, WeightUnit.lb);
      expect(seededFromSession.weightEntry, WeightEntry.perSide);
      expect(seededFromSession.sideCount, 1);
      expect(seededFromSession.loadingMode, LoadingMode.external);
    },
  );

  test(
    'seedForNextSet keeps a remembered sideCount when no prescription sets one',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = SessionRepository(database);

      final exerciseId = await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Couch Stretch',
              category: ExerciseCategory.stretching,
              muscleGroup: 'hips',
            ),
          );

      // History: logged 40s each side, so sideCount 2 is worth remembering.
      final completedSessionId = await database
          .into(database.sessions)
          .insert(
            SessionsCompanion.insert(
              startedAt: DateTime(2026, 7, 18, 12),
              endedAt: Value(DateTime(2026, 7, 18, 13)),
            ),
          );
      final completedLinkId = await database
          .into(database.sessionExercises)
          .insert(
            SessionExercisesCompanion.insert(
              sessionId: completedSessionId,
              exerciseId: exerciseId,
              position: 0,
            ),
          );
      await database
          .into(database.setEntries)
          .insert(
            SetEntriesCompanion.insert(
              sessionExerciseId: completedLinkId,
              setNumber: 1,
              durationSec: const Value(40),
              sideCount: const Value(2),
            ),
          );

      // New session, ad-hoc: no sidesPerSet prescription at all.
      final activeSessionId = await database
          .into(database.sessions)
          .insert(
            SessionsCompanion.insert(startedAt: DateTime(2026, 7, 21, 12)),
          );
      final activeLinkId = await database
          .into(database.sessionExercises)
          .insert(
            SessionExercisesCompanion.insert(
              sessionId: activeSessionId,
              exerciseId: exerciseId,
              position: 0,
            ),
          );

      final seed = await repository.seedForNextSet(
        sessionExerciseId: activeLinkId,
      );
      expect(seed.durationSec, 40);
      expect(
        seed.sideCount,
        2,
        reason: 'history sideCount must survive a null prescription',
      );
    },
  );

  test(
    'lastSetsForExercise returns one previous session and excludes current',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = SessionRepository(database);
      final exerciseId = await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Dumbbell Row',
              category: ExerciseCategory.strength,
              muscleGroup: 'back',
            ),
          );

      Future<int> addSession(
        DateTime startedAt, {
        required bool complete,
        required List<(int, double, WeightUnit, WeightEntry)> sets,
      }) async {
        final sessionId = await database
            .into(database.sessions)
            .insert(
              SessionsCompanion.insert(
                startedAt: startedAt,
                endedAt: Value(
                  complete ? startedAt.add(const Duration(hours: 1)) : null,
                ),
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
        for (var index = 0; index < sets.length; index++) {
          final set = sets[index];
          await database
              .into(database.setEntries)
              .insert(
                SetEntriesCompanion.insert(
                  sessionExerciseId: linkId,
                  setNumber: index + 1,
                  reps: Value(set.$1),
                  weightValue: Value(set.$2),
                  unit: Value(set.$3),
                  weightEntry: Value(set.$4),
                ),
              );
        }
        return sessionId;
      }

      await addSession(
        DateTime(2026, 7, 1),
        complete: true,
        sets: const [(8, 30, WeightUnit.kg, WeightEntry.total)],
      );
      final latestCompletedId = await addSession(
        DateTime(2026, 7, 8),
        complete: true,
        sets: const [
          (10, 35, WeightUnit.lb, WeightEntry.perSide),
          (9, 35, WeightUnit.lb, WeightEntry.perSide),
        ],
      );
      await addSession(
        DateTime(2026, 7, 15),
        complete: false,
        sets: const [(12, 40, WeightUnit.kg, WeightEntry.total)],
      );

      final latest = await repository.lastSetsForExercise(exerciseId);
      expect(latest.map((set) => set.reps), [10, 9]);
      expect(latest.every((set) => set.unit == WeightUnit.lb), isTrue);
      expect(
        latest.every((set) => set.weightEntry == WeightEntry.perSide),
        isTrue,
      );
      expect((await repository.lastSetForExercise(exerciseId))?.reps, 9);

      final previous = await repository.lastSetsForExercise(
        exerciseId,
        excludingSessionId: latestCompletedId,
      );
      expect(previous.single.reps, 8);
      expect(previous.single.weightValue, 30);
      expect(previous.single.unit, WeightUnit.kg);
    },
  );
}

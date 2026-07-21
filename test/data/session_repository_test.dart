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
}

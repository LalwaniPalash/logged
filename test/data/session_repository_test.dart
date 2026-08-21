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

  test('reorderExercises persists the new position order', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = SessionRepository(database);

    final exerciseId = await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Bench Press',
            category: ExerciseCategory.strength,
            muscleGroup: 'chest',
          ),
        );
    final sessionId = await database
        .into(database.sessions)
        .insert(SessionsCompanion.insert(startedAt: DateTime(2026, 8, 9)));

    Future<int> addLink(int position) => database
        .into(database.sessionExercises)
        .insert(
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: position,
          ),
        );
    final first = await addLink(0);
    final second = await addLink(1);
    final third = await addLink(2);

    await repository.reorderExercises(sessionId, [third, first, second]);

    final reordered =
        await (database.select(database.sessionExercises)
              ..where((row) => row.sessionId.equals(sessionId))
              ..orderBy([(row) => OrderingTerm.asc(row.position)]))
            .get();
    expect(reordered.map((row) => row.id), [third, first, second]);
  });

  test('reorderExercises rejects an id from a different session', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = SessionRepository(database);

    final exerciseId = await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Squat',
            category: ExerciseCategory.strength,
            muscleGroup: 'legs',
          ),
        );
    final sessionId = await database
        .into(database.sessions)
        .insert(SessionsCompanion.insert(startedAt: DateTime(2026, 8, 9)));
    final otherSessionId = await database
        .into(database.sessions)
        .insert(SessionsCompanion.insert(startedAt: DateTime(2026, 8, 8)));

    final ownLink = await database
        .into(database.sessionExercises)
        .insert(
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: 0,
          ),
        );
    final foreignLink = await database
        .into(database.sessionExercises)
        .insert(
          SessionExercisesCompanion.insert(
            sessionId: otherSessionId,
            exerciseId: exerciseId,
            position: 0,
          ),
        );

    expect(
      () => repository.reorderExercises(sessionId, [foreignLink]),
      throwsArgumentError,
    );
    // The valid-but-incomplete list (missing ownLink) must also fail rather
    // than silently reordering a subset.
    expect(
      () => repository.reorderExercises(sessionId, [ownLink, foreignLink]),
      throwsArgumentError,
    );
  });

  test(
    'details returns exercises ordered by position with their sets ordered by set number',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = SessionRepository(database);

      final firstExerciseId = await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Bench Press',
              category: ExerciseCategory.strength,
              muscleGroup: 'chest',
            ),
          );
      final secondExerciseId = await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Row',
              category: ExerciseCategory.strength,
              muscleGroup: 'back',
            ),
          );
      final sessionId = await database
          .into(database.sessions)
          .insert(
            SessionsCompanion.insert(startedAt: DateTime(2026, 8, 14, 9)),
          );
      final secondLinkId = await database
          .into(database.sessionExercises)
          .insert(
            SessionExercisesCompanion.insert(
              sessionId: sessionId,
              exerciseId: secondExerciseId,
              position: 1,
            ),
          );
      final firstLinkId = await database
          .into(database.sessionExercises)
          .insert(
            SessionExercisesCompanion.insert(
              sessionId: sessionId,
              exerciseId: firstExerciseId,
              position: 0,
            ),
          );

      await database.batch((batch) {
        batch.insertAll(database.setEntries, [
          SetEntriesCompanion.insert(
            sessionExerciseId: firstLinkId,
            setNumber: 2,
            reps: const Value(6),
            weightValue: const Value(80),
            unit: const Value(WeightUnit.kg),
          ),
          SetEntriesCompanion.insert(
            sessionExerciseId: secondLinkId,
            setNumber: 1,
            reps: const Value(10),
            weightValue: const Value(50),
            unit: const Value(WeightUnit.kg),
          ),
          SetEntriesCompanion.insert(
            sessionExerciseId: firstLinkId,
            setNumber: 1,
            reps: const Value(8),
            weightValue: const Value(70),
            unit: const Value(WeightUnit.kg),
          ),
        ]);
      });

      final details = await repository.details(sessionId);

      expect(details.map((detail) => detail.sessionExercise.id), [
        firstLinkId,
        secondLinkId,
      ]);
      expect(details.first.exercise.id, firstExerciseId);
      expect(details.first.sets.map((set) => set.setNumber), [1, 2]);
      expect(details[1].exercise.id, secondExerciseId);
      expect(details[1].sets.map((set) => set.setNumber), [1]);
    },
  );

  test('details includes an exercise that has no sets', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = SessionRepository(database);

    final exerciseId = await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Face Pull',
            category: ExerciseCategory.strength,
            muscleGroup: 'shoulders',
          ),
        );
    final sessionId = await database
        .into(database.sessions)
        .insert(SessionsCompanion.insert(startedAt: DateTime(2026, 8, 14, 10)));
    final linkId = await database
        .into(database.sessionExercises)
        .insert(
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: 0,
          ),
        );

    final details = await repository.details(sessionId);

    expect(details, hasLength(1));
    expect(details.single.sessionExercise.id, linkId);
    expect(details.single.exercise.id, exerciseId);
    expect(details.single.sets, isEmpty);
  });

  test('finish without notes leaves an existing note untouched', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = SessionRepository(database);
    final sessionId = await database
        .into(database.sessions)
        .insert(
          SessionsCompanion.insert(
            startedAt: DateTime(2026, 8, 14, 7),
            notes: const Value('Felt strong today'),
          ),
        );

    await repository.finish(sessionId, endedAt: DateTime(2026, 8, 14, 8));

    final session = await (database.select(
      database.sessions,
    )..where((row) => row.id.equals(sessionId))).getSingle();
    expect(session.endedAt, DateTime(2026, 8, 14, 8));
    expect(session.notes, 'Felt strong today');
  });

  test(
    'addExercise uses max position plus one after a middle row was removed',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = SessionRepository(database);
      final sessionId = await database
          .into(database.sessions)
          .insert(
            SessionsCompanion.insert(startedAt: DateTime(2026, 8, 14, 9)),
          );
      final exerciseIds = [
        for (final name in ['A', 'B', 'C', 'D'])
          await database
              .into(database.exercises)
              .insert(
                ExercisesCompanion.insert(
                  name: 'Exercise $name',
                  category: ExerciseCategory.strength,
                  muscleGroup: 'test',
                ),
              ),
      ];

      final linkIds = <int>[
        for (var position = 0; position < 3; position++)
          await database
              .into(database.sessionExercises)
              .insert(
                SessionExercisesCompanion.insert(
                  sessionId: sessionId,
                  exerciseId: exerciseIds[position],
                  position: position,
                ),
              ),
      ];
      await (database.delete(
        database.sessionExercises,
      )..where((row) => row.id.equals(linkIds[1]))).go();

      final newLinkId = await repository.addExercise(
        sessionId: sessionId,
        exerciseId: exerciseIds[3],
      );

      final rows =
          await (database.select(database.sessionExercises)
                ..where((row) => row.sessionId.equals(sessionId))
                ..orderBy([(row) => OrderingTerm.asc(row.position)]))
              .get();
      final inserted = rows.singleWhere((row) => row.id == newLinkId);
      expect(rows.map((row) => row.position), [0, 2, 3]);
      expect(inserted.position, 3);
    },
  );

  test('addExerciseAt inserts at 0 and shifts later exercises', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = SessionRepository(database);
    final sessionId = await database
        .into(database.sessions)
        .insert(SessionsCompanion.insert(startedAt: DateTime(2026, 8, 14, 9)));
    final exerciseIds = [
      for (final name in ['A', 'B', 'C'])
        await database
            .into(database.exercises)
            .insert(
              ExercisesCompanion.insert(
                name: 'Exercise $name',
                category: ExerciseCategory.strength,
                muscleGroup: 'test',
              ),
            ),
    ];
    for (var position = 0; position < 2; position++) {
      await database
          .into(database.sessionExercises)
          .insert(
            SessionExercisesCompanion.insert(
              sessionId: sessionId,
              exerciseId: exerciseIds[position],
              position: position,
            ),
          );
    }

    final insertedId = await repository.addExerciseAt(
      sessionId: sessionId,
      exerciseId: exerciseIds[2],
      position: 0,
    );

    final rows =
        await (database.select(database.sessionExercises)
              ..where((row) => row.sessionId.equals(sessionId))
              ..orderBy([(row) => OrderingTerm.asc(row.position)]))
            .get();
    expect(rows.map((row) => row.position), [0, 1, 2]);
    expect(rows.first.id, insertedId);
  });

  test(
    'addExerciseAt inserts in the middle and keeps positions contiguous',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = SessionRepository(database);
      final sessionId = await database
          .into(database.sessions)
          .insert(
            SessionsCompanion.insert(startedAt: DateTime(2026, 8, 14, 9)),
          );
      final exerciseIds = [
        for (final name in ['A', 'B', 'C', 'D'])
          await database
              .into(database.exercises)
              .insert(
                ExercisesCompanion.insert(
                  name: 'Exercise $name',
                  category: ExerciseCategory.strength,
                  muscleGroup: 'test',
                ),
              ),
      ];
      final existingIds = <int>[];
      for (var position = 0; position < 3; position++) {
        existingIds.add(
          await database
              .into(database.sessionExercises)
              .insert(
                SessionExercisesCompanion.insert(
                  sessionId: sessionId,
                  exerciseId: exerciseIds[position],
                  position: position,
                ),
              ),
        );
      }

      final insertedId = await repository.addExerciseAt(
        sessionId: sessionId,
        exerciseId: exerciseIds[3],
        position: 1,
      );

      final rows =
          await (database.select(database.sessionExercises)
                ..where((row) => row.sessionId.equals(sessionId))
                ..orderBy([(row) => OrderingTerm.asc(row.position)]))
              .get();
      expect(rows.map((row) => row.position), [0, 1, 2, 3]);
      expect(rows.map((row) => row.id), [
        existingIds[0],
        insertedId,
        existingIds[1],
        existingIds[2],
      ]);
    },
  );

  test('addExerciseAt at length behaves like append', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = SessionRepository(database);
    final sessionId = await database
        .into(database.sessions)
        .insert(SessionsCompanion.insert(startedAt: DateTime(2026, 8, 14, 9)));
    final exerciseIds = [
      for (final name in ['A', 'B', 'C'])
        await database
            .into(database.exercises)
            .insert(
              ExercisesCompanion.insert(
                name: 'Exercise $name',
                category: ExerciseCategory.strength,
                muscleGroup: 'test',
              ),
            ),
    ];
    for (var position = 0; position < 2; position++) {
      await database
          .into(database.sessionExercises)
          .insert(
            SessionExercisesCompanion.insert(
              sessionId: sessionId,
              exerciseId: exerciseIds[position],
              position: position,
            ),
          );
    }

    final insertedId = await repository.addExerciseAt(
      sessionId: sessionId,
      exerciseId: exerciseIds[2],
      position: 2,
    );

    final rows =
        await (database.select(database.sessionExercises)
              ..where((row) => row.sessionId.equals(sessionId))
              ..orderBy([(row) => OrderingTerm.asc(row.position)]))
            .get();
    expect(rows.map((row) => row.position), [0, 1, 2]);
    expect(rows.last.id, insertedId);
  });

  test('updatePrescription writes only the fields passed', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = SessionRepository(database);
    final exerciseId = await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Front Squat',
            category: ExerciseCategory.strength,
            muscleGroup: 'legs',
          ),
        );
    final sessionId = await database
        .into(database.sessions)
        .insert(SessionsCompanion.insert(startedAt: DateTime(2026, 8, 14, 10)));
    final sessionExerciseId = await database
        .into(database.sessionExercises)
        .insert(
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: 0,
            targetSets: const Value(4),
            sidesPerSet: const Value(2),
            minReps: const Value(6),
            maxReps: const Value(8),
            targetDurationSec: const Value(90),
            targetDistanceMeters: const Value(25),
            restSeconds: const Value(150),
            eccentricSec: const Value(3),
            bottomPauseSec: const Value(1),
            concentricSec: const Value(2),
            topPauseSec: const Value(1),
            prescriptionNotes: const Value('RPE 8'),
            formUrl: const Value('https://example.com/form'),
          ),
        );

    await repository.updatePrescription(
      sessionExerciseId,
      maxReps: const Value(10),
      targetDurationSec: const Value<int?>(null),
      prescriptionNotes: const Value<String?>('Stay upright'),
    );

    final row = await (database.select(
      database.sessionExercises,
    )..where((item) => item.id.equals(sessionExerciseId))).getSingle();
    expect(row.targetSets, 4);
    expect(row.sidesPerSet, 2);
    expect(row.minReps, 6);
    expect(row.maxReps, 10);
    expect(row.targetDurationSec, equals(null));
    expect(row.targetDistanceMeters, 25);
    expect(row.restSeconds, 150);
    expect(row.eccentricSec, 3);
    expect(row.bottomPauseSec, 1);
    expect(row.concentricSec, 2);
    expect(row.topPauseSec, 1);
    expect(row.prescriptionNotes, 'Stay upright');
    expect(row.formUrl, 'https://example.com/form');
  });
}

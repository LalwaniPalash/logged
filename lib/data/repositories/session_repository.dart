import 'package:drift/drift.dart';

import '../../core/domain/enums.dart';
import '../../core/domain/streak.dart';
import '../../core/domain/workout_session_summary.dart';
import '../database/app_database.dart';

class SessionExerciseDetails {
  const SessionExerciseDetails({
    required this.sessionExercise,
    required this.exercise,
    required this.sets,
  });

  final SessionExercise sessionExercise;
  final Exercise exercise;
  final List<SetEntry> sets;
}

class SetSeed {
  const SetSeed({
    this.reps,
    this.weightValue,
    this.unit,
    this.weightEntry = WeightEntry.total,
    this.loadingMode = LoadingMode.external,
    this.durationSec,
    this.distanceMeters,
    this.sideCount = 1,
  });

  factory SetSeed.fromSetEntry(SetEntry set) => SetSeed(
    reps: set.reps,
    weightValue: set.weightValue,
    unit: set.unit,
    weightEntry: set.weightEntry,
    loadingMode: set.loadingMode,
    durationSec: set.durationSec,
    distanceMeters: set.distanceMeters,
    sideCount: set.sideCount,
  );

  final int? reps;
  final double? weightValue;
  final WeightUnit? unit;
  final WeightEntry weightEntry;
  final LoadingMode loadingMode;
  final int? durationSec;
  final double? distanceMeters;
  final int sideCount;

  SetSeed copyWith({
    int? reps,
    double? weightValue,
    WeightUnit? unit,
    WeightEntry? weightEntry,
    LoadingMode? loadingMode,
    int? durationSec,
    double? distanceMeters,
    int? sideCount,
  }) => SetSeed(
    reps: reps ?? this.reps,
    weightValue: weightValue ?? this.weightValue,
    unit: unit ?? this.unit,
    weightEntry: weightEntry ?? this.weightEntry,
    loadingMode: loadingMode ?? this.loadingMode,
    durationSec: durationSec ?? this.durationSec,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    sideCount: sideCount ?? this.sideCount,
  );
}

class SessionRepository {
  const SessionRepository(this._database);

  final AppDatabase _database;

  Stream<List<Session>> watchRecent({int limit = 10}) =>
      (_database.select(_database.sessions)
            ..orderBy([(row) => OrderingTerm.desc(row.startedAt)])
            ..limit(limit))
          .watch();

  /// Date-only stamps of every completed workout, for streak / calendar math.
  Stream<List<DateTime>> watchTrainingDays() =>
      (_database.select(
        _database.sessions,
      )..where((row) => row.endedAt.isNotNull())).watch().map(
        (rows) => rows
            .map(
              (row) => DateTime(
                row.startedAt.year,
                row.startedAt.month,
                row.startedAt.day,
              ),
            )
            .toList(),
      );

  Future<List<DateTime>> trainingDays() async {
    final rows = await (_database.select(
      _database.sessions,
    )..where((row) => row.endedAt.isNotNull())).get();
    return [for (final row in rows) dateOnly(row.startedAt)];
  }

  Future<WorkoutSessionSummary?> loadLatestCompletedSummary() async {
    final row =
        await (_database.select(_database.sessions).join([
                leftOuterJoin(
                  _database.templates,
                  _database.templates.id.equalsExp(
                    _database.sessions.templateId,
                  ),
                ),
              ])
              ..where(_database.sessions.endedAt.isNotNull())
              ..orderBy([OrderingTerm.desc(_database.sessions.startedAt)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _workoutSummaryFromRow(row);
  }

  Future<List<WorkoutSessionSummary>> loadWorkoutSummaries() async {
    final rows = await (_database.select(_database.sessions).join([
      leftOuterJoin(
        _database.templates,
        _database.templates.id.equalsExp(_database.sessions.templateId),
      ),
    ])..orderBy([OrderingTerm.asc(_database.sessions.startedAt)])).get();
    return [for (final row in rows) _workoutSummaryFromRow(row)];
  }

  Future<int> start({int? templateId, DateTime? startedAt}) => _database
      .into(_database.sessions)
      .insert(
        SessionsCompanion.insert(
          startedAt: startedAt ?? DateTime.now(),
          templateId: Value(templateId),
        ),
      );

  Future<Session?> getSession(int sessionId) => (_database.select(
    _database.sessions,
  )..where((row) => row.id.equals(sessionId))).getSingleOrNull();

  /// Deletes a session and everything under it (exercises + sets).
  Future<void> deleteSession(int sessionId) => _database.transaction(() async {
    final links = await (_database.select(
      _database.sessionExercises,
    )..where((row) => row.sessionId.equals(sessionId))).get();
    for (final link in links) {
      await (_database.delete(
        _database.setEntries,
      )..where((row) => row.sessionExerciseId.equals(link.id))).go();
    }
    await (_database.delete(
      _database.sessionExercises,
    )..where((row) => row.sessionId.equals(sessionId))).go();
    await (_database.delete(
      _database.sessions,
    )..where((row) => row.id.equals(sessionId))).go();
  });

  /// Removes a single exercise (and its sets) from a session.
  Future<void> removeSessionExercise(int sessionExerciseId) =>
      _database.transaction(() async {
        await (_database.delete(_database.setEntries)
              ..where((row) => row.sessionExerciseId.equals(sessionExerciseId)))
            .go();
        await (_database.delete(
          _database.sessionExercises,
        )..where((row) => row.id.equals(sessionExerciseId))).go();
      });

  Future<void> finish(int sessionId, {String? notes, DateTime? endedAt}) =>
      (_database.update(
        _database.sessions,
      )..where((row) => row.id.equals(sessionId))).write(
        SessionsCompanion(
          endedAt: Value(endedAt ?? DateTime.now()),
          notes: Value(notes),
        ),
      );

  Future<int> addExercise({
    required int sessionId,
    required int exerciseId,
  }) async {
    final rows = await (_database.select(
      _database.sessionExercises,
    )..where((row) => row.sessionId.equals(sessionId))).get();
    return _database
        .into(_database.sessionExercises)
        .insert(
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: rows.length,
          ),
        );
  }

  Future<void> swapExercise({
    required int sessionExerciseId,
    required int exerciseId,
  }) => _database.transaction(() async {
    await (_database.delete(
      _database.setEntries,
    )..where((set) => set.sessionExerciseId.equals(sessionExerciseId))).go();
    await (_database.update(_database.sessionExercises)
          ..where((row) => row.id.equals(sessionExerciseId)))
        .write(SessionExercisesCompanion(exerciseId: Value(exerciseId)));
  });

  Future<void> startFromTemplate({
    required int sessionId,
    required int templateId,
  }) async {
    final templateExercises =
        await (_database.select(_database.templateExercises)
              ..where((row) => row.templateId.equals(templateId))
              ..orderBy([(row) => OrderingTerm.asc(row.position)]))
            .get();
    await _database.batch((batch) {
      batch.insertAll(_database.sessionExercises, [
        for (final item in templateExercises)
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: item.exerciseId,
            position: item.position,
            targetSets: Value(item.targetSets),
            sidesPerSet: Value(item.sidesPerSet),
            minReps: Value(item.minReps),
            maxReps: Value(item.maxReps),
            targetDurationSec: Value(item.targetDurationSec),
            targetDistanceMeters: Value(item.targetDistanceMeters),
            restSeconds: Value(item.restSeconds),
            eccentricSec: Value(item.eccentricSec),
            bottomPauseSec: Value(item.bottomPauseSec),
            concentricSec: Value(item.concentricSec),
            topPauseSec: Value(item.topPauseSec),
            prescriptionNotes: Value(item.prescriptionNotes),
            formUrl: Value(item.formUrl),
          ),
      ]);
    });
  }

  Future<List<SessionExerciseDetails>> details(int sessionId) async {
    final links =
        await (_database.select(_database.sessionExercises)
              ..where((row) => row.sessionId.equals(sessionId))
              ..orderBy([(row) => OrderingTerm.asc(row.position)]))
            .get();
    final results = <SessionExerciseDetails>[];
    for (final link in links) {
      final exercise = await (_database.select(
        _database.exercises,
      )..where((row) => row.id.equals(link.exerciseId))).getSingle();
      final sets =
          await (_database.select(_database.setEntries)
                ..where((row) => row.sessionExerciseId.equals(link.id))
                ..orderBy([(row) => OrderingTerm.asc(row.setNumber)]))
              .get();
      results.add(
        SessionExerciseDetails(
          sessionExercise: link,
          exercise: exercise,
          sets: sets,
        ),
      );
    }
    return results;
  }

  /// Values to prefill a new set with, in priority order:
  /// 1. the last set already logged for this exercise in this session
  /// 2. the session-exercise prescription (template targets)
  /// 3. the last set from the most recent completed session
  Future<SetSeed> seedForNextSet({required int sessionExerciseId}) async {
    final row =
        await (_database.select(_database.sessionExercises).join([
              innerJoin(
                _database.exercises,
                _database.exercises.id.equalsExp(
                  _database.sessionExercises.exerciseId,
                ),
              ),
            ])..where(_database.sessionExercises.id.equals(sessionExerciseId)))
            .getSingle();
    final sessionExercise = row.readTable(_database.sessionExercises);
    final exercise = row.readTable(_database.exercises);
    final inSession =
        await (_database.select(_database.setEntries)
              ..where((set) => set.sessionExerciseId.equals(sessionExerciseId))
              ..orderBy([(set) => OrderingTerm.desc(set.setNumber)])
              ..limit(1))
            .getSingleOrNull();
    final previousCompleted = await lastSetForExercise(exercise.id);

    var seed = SetSeed(
      unit: exercise.defaultUnit,
      weightEntry: exercise.weightEntry,
      loadingMode: exercise.preferredLoadingMode,
    );
    if (previousCompleted != null) {
      seed = SetSeed.fromSetEntry(previousCompleted);
    }
    seed = seed.copyWith(
      reps: sessionExercise.minReps ?? sessionExercise.maxReps,
      durationSec: sessionExercise.targetDurationSec,
      distanceMeters: sessionExercise.targetDistanceMeters,
      // Left nullable on purpose: copyWith falls back to the history seed, and
      // the base seed already defaults to 1. Coalescing here would overwrite a
      // remembered per-side count whenever the prescription omits one.
      sideCount: sessionExercise.sidesPerSet,
    );
    if (inSession != null) {
      seed = SetSeed.fromSetEntry(inSession);
    }
    return seed;
  }

  Future<SetEntry?> lastSetForExercise(int exerciseId) async {
    final sets = await lastSetsForExercise(exerciseId);
    return sets.lastOrNull;
  }

  /// Every set from the most recent completed session containing [exerciseId].
  ///
  /// This deliberately selects the session first. Applying a limit directly
  /// to the joined set rows could mix sessions or return only the final set.
  Future<List<SetEntry>> lastSetsForExercise(
    int exerciseId, {
    int? excludingSessionId,
    int limit = 20,
  }) async {
    final sessionQuery =
        _database.select(_database.sessions).join([
            innerJoin(
              _database.sessionExercises,
              _database.sessionExercises.sessionId.equalsExp(
                _database.sessions.id,
              ),
            ),
          ])
          ..where(
            _database.sessionExercises.exerciseId.equals(exerciseId) &
                _database.sessions.endedAt.isNotNull() &
                (excludingSessionId == null
                    ? const Constant(true)
                    : _database.sessions.id.isNotValue(excludingSessionId)),
          )
          ..orderBy([OrderingTerm.desc(_database.sessions.startedAt)])
          ..limit(1);
    final previousSession = await sessionQuery.getSingleOrNull();
    if (previousSession == null) return const [];
    final sessionId = previousSession.readTable(_database.sessions).id;

    final query =
        _database.select(_database.setEntries).join([
            innerJoin(
              _database.sessionExercises,
              _database.sessionExercises.id.equalsExp(
                _database.setEntries.sessionExerciseId,
              ),
            ),
            innerJoin(
              _database.sessions,
              _database.sessions.id.equalsExp(
                _database.sessionExercises.sessionId,
              ),
            ),
          ])
          ..where(
            _database.sessionExercises.exerciseId.equals(exerciseId) &
                _database.sessions.id.equals(sessionId),
          )
          ..orderBy([
            OrderingTerm.asc(_database.sessionExercises.position),
            OrderingTerm.asc(_database.setEntries.setNumber),
          ])
          ..limit(limit);
    final rows = await query.get();
    return [for (final row in rows) row.readTable(_database.setEntries)];
  }

  WorkoutSessionSummary _workoutSummaryFromRow(TypedResult row) {
    final session = row.readTable(_database.sessions);
    final template = row.readTableOrNull(_database.templates);
    return WorkoutSessionSummary(
      id: session.id,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      templateName: template?.name,
    );
  }
}

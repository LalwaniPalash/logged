import 'dart:developer' as developer;

import 'package:drift/drift.dart';

import '../../core/domain/enums.dart';
import '../../core/domain/live_muscle_state.dart';
import '../../core/domain/muscle.dart';
import '../../core/domain/muscle_progress.dart' as progress;
import '../../core/domain/workout_metrics.dart';
import '../database/app_database.dart';

/// One completed, weighted set with the fields the Progress screen needs, all
/// normalized to kg.
class WorkoutSetRecord {
  const WorkoutSetRecord({
    required this.date,
    required this.muscleGroup,
    required this.exerciseId,
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
    this.weightEntry = WeightEntry.total,
    this.sideCount = 1,
  });

  final DateTime date;
  final String muscleGroup;
  final int exerciseId;
  final String exerciseName;
  final double weightKg;
  final int reps;
  final WeightEntry weightEntry;
  final int sideCount;

  double get volumeKg => weightKg * weightEntry.implements * reps * sideCount;
  double get estimatedOneRepMaxKg => weightKg * (1 + reps / 30);
}

class AnalyticsRepository {
  const AnalyticsRepository(this._database);

  final AppDatabase _database;

  static const _query =
      'SELECT s.started_at AS started, e.muscle_group AS mg, e.id AS eid, '
      'e.name AS ename, se.weight_value AS wv, se.unit AS unit, '
      'se.weight_entry AS weight_entry, se.side_count AS side_count, '
      'se.reps AS reps '
      'FROM set_entries se '
      'JOIN session_exercises sx ON sx.id = se.session_exercise_id '
      'JOIN sessions s ON s.id = sx.session_id '
      'JOIN exercises e ON e.id = sx.exercise_id '
      'WHERE s.ended_at IS NOT NULL AND se.weight_value IS NOT NULL '
      'AND se.reps IS NOT NULL AND se.reps > 0 '
      'ORDER BY s.started_at';

  static const _liveMuscleQuery =
      'SELECT s.started_at AS started, e.name AS ename, '
      'e.primary_muscles AS primary_muscles, '
      'e.secondary_muscles AS secondary_muscles, '
      'se.is_warmup AS is_warmup '
      'FROM set_entries se '
      'JOIN session_exercises sx ON sx.id = se.session_exercise_id '
      'JOIN sessions s ON s.id = sx.session_id '
      'JOIN exercises e ON e.id = sx.exercise_id '
      'ORDER BY s.started_at, se.id';

  static const _muscleProgressQuery =
      'SELECT s.started_at AS started, e.id AS eid, e.name AS ename, '
      'e.primary_muscles AS primary_muscles, '
      'e.secondary_muscles AS secondary_muscles, '
      'e.bodyweight_factor AS bodyweight_factor, '
      'se.loading_mode AS loading_mode, se.weight_value AS weight_value, '
      'se.unit AS unit, se.weight_entry AS weight_entry, '
      'se.side_count AS side_count, se.reps AS reps, '
      'se.duration_sec AS duration_sec, se.distance_meters AS distance_meters, '
      'se.is_warmup AS is_warmup '
      'FROM set_entries se '
      'JOIN session_exercises sx ON sx.id = se.session_exercise_id '
      'JOIN sessions s ON s.id = sx.session_id '
      'JOIN exercises e ON e.id = sx.exercise_id '
      'ORDER BY s.started_at, se.id';

  /// All completed, weighted sets in chronological order.
  Future<List<WorkoutSetRecord>> loadCompletedSets() async =>
      _map(await _database.customSelect(_query).get());

  /// Reactive version that re-emits whenever the underlying tables change.
  Stream<List<WorkoutSetRecord>> watchCompletedSets() => _database
      .customSelect(
        _query,
        readsFrom: {
          _database.setEntries,
          _database.sessionExercises,
          _database.sessions,
          _database.exercises,
        },
      )
      .watch()
      .map(_map);

  Future<List<MuscleSetRecord>> loadLiveMuscleSets() async =>
      _mapLiveMuscleSets(await _database.customSelect(_liveMuscleQuery).get());

  Stream<List<MuscleSetRecord>> watchLiveMuscleSets() => _database
      .customSelect(
        _liveMuscleQuery,
        readsFrom: {
          _database.setEntries,
          _database.sessionExercises,
          _database.sessions,
          _database.exercises,
        },
      )
      .watch()
      .map(_mapLiveMuscleSets);

  Stream<Map<MuscleId, progress.MuscleProgress>> watchMuscleProgress() =>
      _database
          .customSelect(
            _muscleProgressQuery,
            readsFrom: {
              _database.setEntries,
              _database.sessionExercises,
              _database.sessions,
              _database.exercises,
              _database.bodyweightEntries,
            },
          )
          .watch()
          .asyncMap(
            (rows) async => progress.buildMuscleProgress(
              records: _mapMuscleProgressRecords(rows),
              bodyweights: await _loadBodyweights(),
            ),
          );

  List<WorkoutSetRecord> _map(List<QueryRow> rows) => [
    for (final row in rows)
      WorkoutSetRecord(
        date: _dateFromColumn(row.data['started']),
        muscleGroup: row.data['mg'] as String? ?? '',
        exerciseId: row.data['eid'] as int,
        exerciseName: row.data['ename'] as String? ?? '',
        weightKg: weightKg(
          (row.data['wv'] as num).toDouble(),
          WeightUnit.values.byName(row.data['unit'] as String? ?? 'kg'),
        ),
        reps: row.data['reps'] as int,
        weightEntry: WeightEntry.values.byName(
          row.data['weight_entry'] as String? ?? 'total',
        ),
        sideCount: row.data['side_count'] as int? ?? 1,
      ),
  ];

  List<MuscleSetRecord> _mapLiveMuscleSets(List<QueryRow> rows) => [
    for (final row in rows)
      MuscleSetRecord(
        date: _dateFromColumn(row.data['started']),
        exerciseName: row.data['ename'] as String? ?? '',
        primaryMuscles: _decodeMuscles(
          row.data['primary_muscles'],
          row.data['ename'] as String? ?? '',
        ),
        secondaryMuscles: _decodeMuscles(
          row.data['secondary_muscles'],
          row.data['ename'] as String? ?? '',
        ),
        isWarmup: switch (row.data['is_warmup']) {
          final bool value => value,
          final num value => value != 0,
          _ => false,
        },
      ),
  ];

  List<progress.MusclePerformanceRecord> _mapMuscleProgressRecords(
    List<QueryRow> rows,
  ) => [
    for (final row in rows)
      progress.MusclePerformanceRecord(
        date: _dateFromColumn(row.data['started']),
        exerciseId: row.data['eid'] as int,
        exerciseName: row.data['ename'] as String? ?? '',
        primaryMuscles: _decodeMuscles(
          row.data['primary_muscles'],
          row.data['ename'] as String? ?? '',
        ),
        secondaryMuscles: _decodeMuscles(
          row.data['secondary_muscles'],
          row.data['ename'] as String? ?? '',
        ),
        loadingMode: LoadingMode.values.byName(
          row.data['loading_mode'] as String? ?? 'external',
        ),
        reps: row.data['reps'] as int?,
        weightValue: (row.data['weight_value'] as num?)?.toDouble(),
        unit: row.data['unit'] == null
            ? null
            : WeightUnit.values.byName(row.data['unit'] as String),
        weightEntry: WeightEntry.values.byName(
          row.data['weight_entry'] as String? ?? 'total',
        ),
        sideCount: row.data['side_count'] as int? ?? 1,
        durationSec: row.data['duration_sec'] as int?,
        distanceMeters: (row.data['distance_meters'] as num?)?.toDouble(),
        bodyweightFactor:
            (row.data['bodyweight_factor'] as num?)?.toDouble() ?? 1,
        isWarmup: switch (row.data['is_warmup']) {
          final bool value => value,
          final num value => value != 0,
          _ => false,
        },
      ),
  ];

  Future<List<progress.BodyweightEntry>> _loadBodyweights() async => [
    for (final row in await _database.select(_database.bodyweightEntries).get())
      progress.BodyweightEntry(
        date: row.date,
        value: row.value,
        unit: row.unit,
      ),
  ];

  List<MuscleId> _decodeMuscles(Object? value, String exerciseName) {
    try {
      return decodeMuscleIds(value as String? ?? '[]');
    } on FormatException catch (error, stackTrace) {
      developer.log(
        'Ignoring malformed muscle metadata for $exerciseName',
        name: 'logged.analytics',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    } on ArgumentError catch (error, stackTrace) {
      developer.log(
        'Ignoring unknown muscle metadata for $exerciseName',
        name: 'logged.analytics',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  // Drift stores DateTime as unix seconds by default.
  static DateTime _dateFromColumn(Object? value) {
    final seconds = (value as num).toInt();
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
}

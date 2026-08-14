import 'dart:developer' as developer;

import 'package:drift/drift.dart';

import '../../core/domain/enums.dart';
import '../../core/domain/live_muscle_state.dart';
import '../../core/domain/muscle.dart';
import '../../core/domain/muscle_bias.dart';
import '../../core/domain/muscle_progress.dart' as progress;
import '../../core/domain/streak.dart';
import '../../core/domain/training_goal.dart';
import '../../core/domain/volume_landmarks.dart';
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
    this.loadingMode = LoadingMode.external,
    this.weightEntry = WeightEntry.total,
    this.sideCount = 1,
  });

  final DateTime date;
  final String muscleGroup;
  final int exerciseId;
  final String exerciseName;
  final double weightKg;
  final int reps;
  final LoadingMode loadingMode;
  final WeightEntry weightEntry;
  final int sideCount;

  // TODO(A2b): Bodyweight-only sets still report zero tonnage here because this
  // record does not carry the dated bodyweight history needed to fold resisted
  // mass into weekly volume.
  double get volumeKg => weightKg * weightEntry.implements * reps * sideCount;
  double get estimatedOneRepMaxKg => weightKg * (1 + reps / 30);
}

/// A completed set of a benchmark lift, kept separate from [WorkoutSetRecord]
/// because strength standards must include strict-bodyweight reps (no entered
/// weight) — the weighted-sets query drops those, which hid the Pull-Up
/// benchmark for anyone training it unweighted.
class BenchmarkSetRecord {
  const BenchmarkSetRecord({
    required this.exerciseName,
    required this.loadingMode,
    required this.reps,
    required this.bodyweightFactor,
    this.enteredWeightKg,
  });

  final String exerciseName;
  final LoadingMode loadingMode;
  final int reps;
  final double bodyweightFactor;

  /// The entered load in kg, or null for a strict-bodyweight rep.
  final double? enteredWeightKg;

  /// Total resisted mass for the set, folding bodyweight in for the loading
  /// modes that need it, so a strict pull-up and a weighted pull-up compare on
  /// the same axis.
  double resistedOneRepMaxKg(double bodyweightKg) {
    final entered = enteredWeightKg ?? 0;
    final base = bodyweightKg * bodyweightFactor.clamp(0.0, 1.0);
    final load = switch (loadingMode) {
      LoadingMode.external => entered,
      LoadingMode.bodyweightAdded => base + entered,
      LoadingMode.bodyweight => base,
      LoadingMode.bodyweightAssisted =>
        (base - entered).clamp(0.0, double.infinity).toDouble(),
    };
    return load * (1 + reps / 30);
  }
}

class DeloadData {
  const DeloadData({
    required this.weeklyEffectiveSetsByMuscle,
    required this.oneRepMaxSeriesByExercise,
    required this.rpeAtLoadSeries,
    required this.repDecaySeries,
  });

  final Map<MuscleId, List<double>> weeklyEffectiveSetsByMuscle;
  final Map<int, List<double>> oneRepMaxSeriesByExercise;
  final Map<int, List<double>> rpeAtLoadSeries;
  final Map<int, List<double>> repDecaySeries;
}

class AnalyticsRepository {
  const AnalyticsRepository(this._database);

  final AppDatabase _database;

  static const _query =
      'SELECT s.started_at AS started, e.muscle_group AS mg, e.id AS eid, '
      'e.name AS ename, se.weight_value AS wv, se.unit AS unit, '
      'se.loading_mode AS loading_mode, '
      'se.weight_entry AS weight_entry, se.side_count AS side_count, '
      'se.reps AS reps '
      'FROM set_entries se '
      'JOIN session_exercises sx ON sx.id = se.session_exercise_id '
      'JOIN sessions s ON s.id = sx.session_id '
      'JOIN exercises e ON e.id = sx.exercise_id '
      'WHERE s.ended_at IS NOT NULL '
      'AND se.reps IS NOT NULL AND se.reps > 0 '
      'AND se.is_warmup = 0 '
      'ORDER BY s.started_at';

  static const _liveMuscleQuery =
      'SELECT s.started_at AS started, e.name AS ename, '
      'e.primary_muscles AS primary_muscles, '
      'e.secondary_muscles AS secondary_muscles, '
      'se.muscle_bias_weights AS muscle_bias_weights, '
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
      'se.muscle_bias_weights AS muscle_bias_weights, '
      'se.is_warmup AS is_warmup '
      'FROM set_entries se '
      'JOIN session_exercises sx ON sx.id = se.session_exercise_id '
      'JOIN sessions s ON s.id = sx.session_id '
      'JOIN exercises e ON e.id = sx.exercise_id '
      'ORDER BY s.started_at, se.id';

  static const _deloadQuery =
      'SELECT s.started_at AS started, e.id AS eid, '
      'e.primary_muscles AS primary_muscles, '
      'e.secondary_muscles AS secondary_muscles, '
      'e.bodyweight_factor AS bodyweight_factor, '
      'se.weight_value AS weight_value, se.unit AS unit, '
      'se.loading_mode AS loading_mode, '
      'se.reps AS reps, se.rpe AS rpe, se.is_warmup AS is_warmup, '
      'se.muscle_bias_weights AS muscle_bias_weights '
      'FROM set_entries se '
      'JOIN session_exercises sx ON sx.id = se.session_exercise_id '
      'JOIN sessions s ON s.id = sx.session_id '
      'JOIN exercises e ON e.id = sx.exercise_id '
      'WHERE s.ended_at IS NOT NULL '
      'AND s.started_at >= ? '
      'ORDER BY s.started_at, se.id';

  // Benchmark lifts for strength standards. Unlike [_query] this carries the
  // exercise bodyweight factor, so a strict pull-up scores its resisted mass
  // instead of the 0 kg a null weight_value gives [_query].
  static const _benchmarkQuery =
      'SELECT e.name AS ename, e.bodyweight_factor AS bodyweight_factor, '
      'se.loading_mode AS loading_mode, se.weight_value AS weight_value, '
      'se.unit AS unit, se.reps AS reps '
      'FROM set_entries se '
      'JOIN session_exercises sx ON sx.id = se.session_exercise_id '
      'JOIN sessions s ON s.id = sx.session_id '
      'JOIN exercises e ON e.id = sx.exercise_id '
      'WHERE s.ended_at IS NOT NULL '
      'AND se.reps IS NOT NULL AND se.reps > 0 '
      'AND se.is_warmup = 0 '
      'ORDER BY s.started_at, se.id';

  /// Completed benchmark-lift sets (including strict bodyweight), for standards.
  Stream<List<BenchmarkSetRecord>> watchBenchmarkSets() => _database
      .customSelect(
        _benchmarkQuery,
        readsFrom: {
          _database.setEntries,
          _database.sessionExercises,
          _database.sessions,
          _database.exercises,
        },
      )
      .watch()
      .map(_mapBenchmarkSets);

  List<BenchmarkSetRecord> _mapBenchmarkSets(List<QueryRow> rows) => [
    for (final row in rows)
      BenchmarkSetRecord(
        exerciseName: row.data['ename'] as String? ?? '',
        loadingMode: LoadingMode.values.byName(
          row.data['loading_mode'] as String? ?? 'external',
        ),
        reps: row.data['reps'] as int,
        bodyweightFactor:
            (row.data['bodyweight_factor'] as num?)?.toDouble() ?? 1,
        enteredWeightKg: switch (row.data['weight_value']) {
          final num value => weightKg(
            value.toDouble(),
            WeightUnit.values.byName(row.data['unit'] as String? ?? 'kg'),
          ),
          _ => null,
        },
      ),
  ];

  /// All completed working sets in chronological order. Warm-ups are excluded;
  /// bodyweight sets are included with `weightKg == 0`.
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

  Stream<Map<MuscleId, progress.MuscleProgress>> watchMuscleProgress({
    TrainingGoal goal = TrainingGoal.build,
    Map<MuscleId, VolumeLandmarks>? landmarks,
  }) => _database
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
          goal: goal,
          landmarks: landmarks,
        ),
      );

  Future<DeloadData> loadDeloadData({DateTime? today, int weeks = 4}) async {
    final now = today ?? DateTime.now();
    final currentWeek = startOfWeek(now);
    final lastCompletedWeek = _weekStartOffset(currentWeek, 1);
    final deloadWindowStart = _weekStartOffset(currentWeek, 11);
    final rows = await _database
        .customSelect(
          _deloadQuery,
          variables: [Variable.withDateTime(deloadWindowStart)],
        )
        .get();
    final weekStarts = [
      for (var offset = weeks - 1; offset >= 0; offset--)
        _weekStartOffset(lastCompletedWeek, offset),
    ];
    final weekIndexByStart = {
      for (var index = 0; index < weekStarts.length; index++)
        weekStarts[index]: index,
    };
    final weekly = {
      for (final muscle in MuscleId.values)
        muscle: List<double>.filled(weeks, 0),
    };
    final maxByExerciseDay = <int, Map<DateTime, double>>{};
    final rpeByExerciseLoad = <int, Map<String, List<double>>>{};
    final repsByExerciseDayLoad =
        <int, Map<DateTime, Map<String, List<int>>>>{};

    for (final row in rows) {
      final isWarmup = switch (row.data['is_warmup']) {
        final bool value => value,
        final num value => value != 0,
        _ => false,
      };
      if (isWarmup) continue;
      final date = _dateFromColumn(row.data['started']);
      final weekIndex = weekIndexByStart[startOfWeek(date)] ?? -1;
      if (weekIndex >= 0) {
        final primary = _decodeMuscles(
          row.data['primary_muscles'],
          'deload assessment',
        ).toSet();
        final secondary = _decodeMuscles(
          row.data['secondary_muscles'],
          'deload assessment',
        ).toSet().difference(primary);
        final weights = _decodeMuscleBiasWeights(
          row.data['muscle_bias_weights'],
          exerciseName: 'deload assessment',
          columnName: 'muscle_bias_weights',
        );
        for (final muscle in primary) {
          weekly[muscle]![weekIndex] +=
              primaryMuscleBiasWeight(muscle: muscle, weights: weights) ?? 1.0;
        }
        for (final muscle in secondary) {
          weekly[muscle]![weekIndex] += secondaryMuscleSetWeight;
        }
      }

      final weight = (row.data['weight_value'] as num?)?.toDouble();
      final reps = row.data['reps'] as int?;
      if (reps == null || reps <= 0) continue;
      final exerciseId = row.data['eid'] as int;
      final unit = WeightUnit.values.byName(
        row.data['unit'] as String? ?? 'kg',
      );
      final loadingMode = LoadingMode.values.byName(
        row.data['loading_mode'] as String? ?? 'external',
      );
      // A strict bodyweight set carries no weight_value. Gating every
      // per-exercise signal on a non-null weight left rep-decay, est-1RM stall
      // AND rising-RPE all dead for bodyweight-only training, so the deload
      // card could never reach its two-signal threshold — the same failure this
      // phase's rep-decay signal exists to fix, just for a different user.
      final addedKg = weight == null ? 0.0 : weightKg(weight, unit);
      final day = dateOnly(date);

      // Rep decay only needs "the same load across sets of one session", and
      // bodyweight is constant within a session, so a null weight_value is a
      // perfectly valid load key. Keying on the mode too keeps a strict set and
      // an added-load set from grouping together.
      final loadKey = '${loadingMode.name}:${addedKg.toStringAsFixed(2)}';
      final repsByDay = repsByExerciseDayLoad[exerciseId] ??= {};
      final repsByLoad = repsByDay[day] ??= {};
      (repsByLoad[loadKey] ??= []).add(reps);

      // Assisted lifts store assistance as the load, so a FALLING weight is
      // progress, not a stall. Feeding them into the est-1RM decline detector
      // manufactures false deload signals, so keep them out of it — the volume
      // and rising-RPE-at-load signals still cover assisted work.
      //
      // For a strict bodyweight lift the resisted mass is bodyweight × factor.
      // The stall detector only compares a series against ITSELF, so the
      // constant bodyweight term cancels and the factor alone is a valid
      // proxy — no BodyweightEntries lookup needed.
      // ponytail: assumes stable bodyweight; a bulking user's true est-1RM
      // rises while this proxy stays flat. Fold in the real bodyweight series
      // if that ever misfires.
      final stallLoadKg = loadingMode == LoadingMode.bodyweight
          ? ((row.data['bodyweight_factor'] as num?)?.toDouble() ?? 1.0)
          : addedKg;
      if (loadingMode != LoadingMode.bodyweightAssisted && stallLoadKg > 0) {
        final estimate = stallLoadKg * (1 + reps / 30);
        final daily = maxByExerciseDay[exerciseId] ??= {};
        if (estimate > (daily[day] ?? 0)) daily[day] = estimate;
      }

      final rpe = (row.data['rpe'] as num?)?.toDouble();
      if (rpe != null) {
        final byLoad = rpeByExerciseLoad[exerciseId] ??= {};
        (byLoad[loadKey] ??= []).add(rpe);
      }
    }

    final oneRepSeries = <int, List<double>>{};
    for (final entry in maxByExerciseDay.entries) {
      final days = entry.value.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      oneRepSeries[entry.key] = days.map((item) => item.value).toList();
    }

    final repDecaySeries = <int, List<double>>{};
    for (final entry in repsByExerciseDayLoad.entries) {
      final days = entry.value.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final series = <double>[];
      for (final day in days) {
        // List.sort is not stable in Dart, so equal set counts must tie-break
        // on the load key or the picked series varies between runs.
        final candidates =
            day.value.entries.where((load) => load.value.length >= 2).toList()
              ..sort((a, b) {
                final byCount = b.value.length.compareTo(a.value.length);
                return byCount != 0 ? byCount : a.key.compareTo(b.key);
              });
        if (candidates.isEmpty) continue;
        final repsAtLoad = candidates.first.value;
        series.add((repsAtLoad.first - repsAtLoad.last).toDouble());
      }
      if (series.isNotEmpty) repDecaySeries[entry.key] = series;
    }

    return DeloadData(
      weeklyEffectiveSetsByMuscle: weekly,
      oneRepMaxSeriesByExercise: oneRepSeries,
      rpeAtLoadSeries: {
        for (final entry in rpeByExerciseLoad.entries)
          entry.key:
              (entry.value.values.toList()
                    ..sort((a, b) => b.length.compareTo(a.length)))
                  .first,
      },
      repDecaySeries: repDecaySeries,
    );
  }

  List<WorkoutSetRecord> _map(List<QueryRow> rows) => [
    for (final row in rows)
      WorkoutSetRecord(
        date: _dateFromColumn(row.data['started']),
        muscleGroup: row.data['mg'] as String? ?? '',
        exerciseId: row.data['eid'] as int,
        exerciseName: row.data['ename'] as String? ?? '',
        weightKg: switch (row.data['wv']) {
          final num value => weightKg(
            value.toDouble(),
            WeightUnit.values.byName(row.data['unit'] as String? ?? 'kg'),
          ),
          _ => 0,
        },
        reps: row.data['reps'] as int,
        loadingMode: LoadingMode.values.byName(
          row.data['loading_mode'] as String? ?? 'external',
        ),
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
        muscleBiasWeights: _decodeMuscleBiasWeights(
          row.data['muscle_bias_weights'],
          exerciseName: row.data['ename'] as String? ?? '',
          columnName: 'muscle_bias_weights',
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
        muscleBiasWeights: _decodeMuscleBiasWeights(
          row.data['muscle_bias_weights'],
          exerciseName: row.data['ename'] as String? ?? '',
          columnName: 'muscle_bias_weights',
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

  Map<MuscleId, double>? _decodeMuscleBiasWeights(
    Object? value, {
    required String exerciseName,
    required String columnName,
  }) {
    if (value == null) return null;
    try {
      return decodeMuscleBiasWeights(value as String);
    } on FormatException catch (error, stackTrace) {
      developer.log(
        'Ignoring malformed $columnName metadata for $exerciseName',
        name: 'logged.analytics',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } on ArgumentError catch (error, stackTrace) {
      developer.log(
        'Ignoring unknown $columnName metadata for $exerciseName',
        name: 'logged.analytics',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  // Drift stores DateTime as unix seconds by default.
  static DateTime _dateFromColumn(Object? value) {
    final seconds = (value as num).toInt();
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
}

DateTime _weekStartOffset(DateTime weekStart, int weeks) =>
    DateTime(weekStart.year, weekStart.month, weekStart.day - weeks * 7);

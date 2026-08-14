import 'dart:collection';
import 'dart:math' as math;

import 'enums.dart';
import 'live_muscle_state.dart';
import 'muscle_bias.dart';
import 'muscle.dart';
import 'streak.dart';
import 'training_goal.dart';
import 'volume_landmarks.dart';
import 'workout_metrics.dart';

const exerciseBaselineObservationCount = 2;
const exerciseInfluenceCap = 0.45;

enum MuscleRank {
  foundation('Foundation'),
  bronze('Bronze'),
  silver('Silver'),
  gold('Gold'),
  platinum('Platinum'),
  elite('Elite');

  const MuscleRank(this.label);
  final String label;
}

enum MuscleMomentum {
  improving('Improving'),
  steady('Steady'),
  declining('Declining'),
  learningBaseline('Learning baseline');

  const MuscleMomentum(this.label);
  final String label;
}

class BodyweightEntry {
  const BodyweightEntry({
    required this.date,
    required this.value,
    required this.unit,
  });

  final DateTime date;
  final double value;
  final WeightUnit unit;

  double get kg => weightKg(value, unit);
}

class MusclePerformanceRecord {
  const MusclePerformanceRecord({
    required this.date,
    required this.exerciseId,
    required this.exerciseName,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.loadingMode,
    this.muscleBiasWeights,
    this.reps,
    this.weightValue,
    this.unit,
    this.weightEntry = WeightEntry.total,
    this.sideCount = 1,
    this.durationSec,
    this.distanceMeters,
    this.bodyweightFactor = 1.0,
    this.isWarmup = false,
  });

  final DateTime date;
  final int exerciseId;
  final String exerciseName;
  final List<MuscleId> primaryMuscles;
  final List<MuscleId> secondaryMuscles;
  final LoadingMode loadingMode;
  final Map<MuscleId, double>? muscleBiasWeights;
  final int? reps;
  final double? weightValue;
  final WeightUnit? unit;
  final WeightEntry weightEntry;
  final int sideCount;
  final int? durationSec;
  final double? distanceMeters;
  final double bodyweightFactor;
  final bool isWarmup;
}

class ExerciseProgressPoint {
  const ExerciseProgressPoint({
    required this.date,
    required this.exerciseId,
    required this.exerciseName,
    required this.index,
    required this.rawValue,
    required this.lowerPrecision,
  });

  final DateTime date;
  final int exerciseId;
  final String exerciseName;
  final double index;
  final double rawValue;
  final bool lowerPrecision;
}

class MuscleTrendPoint {
  const MuscleTrendPoint({required this.date, required this.index});
  final DateTime date;
  final double index;
}

class MuscleExerciseProgress {
  const MuscleExerciseProgress({
    required this.exerciseId,
    required this.exerciseName,
    required this.latestIndex,
    required this.bestIndex,
    required this.latestRawValue,
    required this.bestRawValue,
    required this.points,
    required this.lowerPrecision,
  });

  final int exerciseId;
  final String exerciseName;
  final double latestIndex;
  final double bestIndex;
  final double latestRawValue;
  final double bestRawValue;
  final List<ExerciseProgressPoint> points;
  final bool lowerPrecision;
}

class MuscleProgress {
  const MuscleProgress({
    required this.muscle,
    required this.rank,
    required this.rankScore,
    required this.rankProgress,
    required this.momentum,
    required this.points,
    required this.effectiveSetHistory,
    required this.primarySets,
    required this.secondarySets,
    required this.lastTrained,
    required this.exercises,
  });

  final MuscleId muscle;
  final MuscleRank rank;
  final double rankScore;
  final double rankProgress;
  final MuscleMomentum momentum;
  final List<MuscleTrendPoint> points;
  final Map<DateTime, double> effectiveSetHistory;
  final double primarySets;
  final int secondarySets;
  final DateTime? lastTrained;
  final List<MuscleExerciseProgress> exercises;

  double? get latestIndex => points.isEmpty ? null : points.last.index;
  double? get bestIndex => points.isEmpty
      ? null
      : points.map((point) => point.index).reduce(math.max);

  bool get isLearning => points.length < 2;
}

class BodyProgressSummary {
  const BodyProgressSummary({
    required this.rank,
    required this.rankScore,
    required this.rankProgress,
    required this.momentum,
    required this.trainedMuscles,
    required this.improvingMuscles,
    required this.strongest,
    required this.attentionNeeded,
  });

  final MuscleRank rank;
  final double rankScore;
  final double rankProgress;
  final MuscleMomentum momentum;
  final int trainedMuscles;
  final int improvingMuscles;
  final List<MuscleProgress> strongest;
  final List<MuscleProgress> attentionNeeded;

  String get nextFocusLabel => attentionNeeded.isEmpty
      ? 'Keep building balanced progress'
      : attentionNeeded.take(2).map((item) => item.muscle.label).join(' or ');
}

class _ExerciseObservation {
  const _ExerciseObservation({
    required this.record,
    required this.value,
    required this.lowerPrecision,
  });

  final MusclePerformanceRecord record;
  final double value;
  final bool lowerPrecision;
}

class _ExerciseSeries {
  const _ExerciseSeries({
    required this.exerciseId,
    required this.exerciseName,
    required this.points,
  });

  final int exerciseId;
  final String exerciseName;
  final List<ExerciseProgressPoint> points;
}

class _Accumulator {
  double primarySets = 0;
  int secondarySets = 0;
  final Map<DateTime, double> effectiveSetHistory = {};
  DateTime? lastTrained;
  final Map<int, double> exerciseWeights = {};
}

class _WeightedIndex {
  const _WeightedIndex({required this.index, required this.weight});
  final double index;
  final double weight;
}

Map<MuscleId, MuscleProgress> buildMuscleProgress({
  required Iterable<MusclePerformanceRecord> records,
  Iterable<BodyweightEntry> bodyweights = const [],
  DateTime? today,
  TrainingGoal goal = TrainingGoal.build,
  Map<MuscleId, VolumeLandmarks>? landmarks,
}) {
  final sortedRecords = records.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final sortedWeights = bodyweights.toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  final observationsByExercise = <int, List<_ExerciseObservation>>{};
  final accumulators = {
    for (final muscle in MuscleId.values) muscle: _Accumulator(),
  };

  for (final record in sortedRecords) {
    if (record.isWarmup) continue;
    final primary = record.primaryMuscles.toSet();
    final secondary = record.secondaryMuscles.toSet().difference(primary);
    if (primary.isEmpty && secondary.isEmpty) continue;

    final day = dateOnly(record.date);
    for (final muscle in primary) {
      final weight =
          primaryMuscleBiasWeight(
            muscle: muscle,
            weights: record.muscleBiasWeights,
          ) ??
          1.0;
      final acc = accumulators[muscle]!;
      acc.primarySets += weight;
      acc.lastTrained = record.date;
      acc.effectiveSetHistory[day] =
          (acc.effectiveSetHistory[day] ?? 0) + weight;
      acc.exerciseWeights[record.exerciseId] =
          (acc.exerciseWeights[record.exerciseId] ?? 0) + weight;
    }
    for (final muscle in secondary) {
      final acc = accumulators[muscle]!;
      acc.secondarySets++;
      acc.lastTrained = record.date;
      acc.effectiveSetHistory[day] =
          (acc.effectiveSetHistory[day] ?? 0) + secondaryMuscleSetWeight;
      acc.exerciseWeights[record.exerciseId] =
          (acc.exerciseWeights[record.exerciseId] ?? 0) +
          secondaryMuscleSetWeight;
    }

    final signal = _performanceSignal(record, sortedWeights);
    if (signal == null) continue;
    (observationsByExercise[record.exerciseId] ??= []).add(signal);
  }

  final seriesByExercise = <int, _ExerciseSeries>{};
  for (final entry in observationsByExercise.entries) {
    final observations = entry.value;
    if (observations.length < exerciseBaselineObservationCount) continue;
    final baseline =
        observations
            .take(exerciseBaselineObservationCount)
            .map((observation) => observation.value)
            .fold(0.0, (sum, value) => sum + value) /
        exerciseBaselineObservationCount;
    if (baseline <= 0) continue;

    final points = [
      for (final observation in observations)
        ExerciseProgressPoint(
          date: observation.record.date,
          exerciseId: observation.record.exerciseId,
          exerciseName: observation.record.exerciseName,
          index: ((observation.value / baseline) * 100).clamp(50.0, 175.0),
          rawValue: observation.value,
          lowerPrecision: observation.lowerPrecision,
        ),
    ];
    seriesByExercise[entry.key] = _ExerciseSeries(
      exerciseId: entry.key,
      exerciseName: observations.last.record.exerciseName,
      points: points,
    );
  }

  return UnmodifiableMapView({
    for (final muscle in MuscleId.values)
      muscle: _buildProgressForMuscle(
        muscle,
        accumulators[muscle]!,
        seriesByExercise,
        today ?? DateTime.now(),
        goal,
        (landmarks ?? resolveLandmarks(goal: goal))[muscle]!,
      ),
  });
}

_ExerciseObservation? _performanceSignal(
  MusclePerformanceRecord record,
  List<BodyweightEntry> bodyweights,
) {
  final sides = record.sideCount.clamp(1, 999);
  if (record.reps != null && record.reps! > 0) {
    final load = _resistedMassKg(record, bodyweights, countImplements: false);
    if (load != null && load > 0) {
      return _ExerciseObservation(
        record: record,
        value: load * (1 + record.reps! / 30),
        lowerPrecision: false,
      );
    }
    return _ExerciseObservation(
      record: record,
      value: record.reps!.toDouble() * sides,
      lowerPrecision: true,
    );
  }
  if (record.durationSec != null && record.durationSec! > 0) {
    final load = _resistedMassKg(record, bodyweights);
    return _ExerciseObservation(
      record: record,
      value: record.durationSec!.toDouble() * sides * (load ?? 1),
      lowerPrecision: load == null,
    );
  }
  if (record.distanceMeters != null && record.distanceMeters! > 0) {
    return _ExerciseObservation(
      record: record,
      value: record.distanceMeters! * sides,
      lowerPrecision: false,
    );
  }
  return null;
}

double? _resistedMassKg(
  MusclePerformanceRecord record,
  List<BodyweightEntry> bodyweights, {
  bool countImplements = true,
}) {
  // A per-hand entry is two implements of the same load. Volume-like signals
  // want both (countImplements), a 1RM proxy wants the entered value only —
  // and that holds for added/assisted plates too, not just external ones.
  final external = record.weightValue == null
      ? null
      : countImplements
      ? totalLoadKg(
          record.weightValue!,
          record.unit ?? WeightUnit.kg,
          record.weightEntry,
        )
      : weightKg(record.weightValue!, record.unit ?? WeightUnit.kg);
  final bodyweight = _bodyweightOnOrBefore(record.date, bodyweights);
  final factor = record.bodyweightFactor.clamp(0.0, 1.0);

  return switch (record.loadingMode) {
    LoadingMode.external => external,
    LoadingMode.bodyweight => bodyweight == null ? null : bodyweight * factor,
    LoadingMode.bodyweightAdded =>
      bodyweight == null ? external : bodyweight * factor + (external ?? 0),
    LoadingMode.bodyweightAssisted =>
      bodyweight == null
          ? null
          : (bodyweight * factor - (external ?? 0)) <= 0
          ? null
          : bodyweight * factor - (external ?? 0),
  };
}

double? _bodyweightOnOrBefore(DateTime date, List<BodyweightEntry> entries) {
  double? latest;
  for (final entry in entries) {
    if (!dateOnly(entry.date).isAfter(dateOnly(date))) latest = entry.kg;
  }
  return latest;
}

MuscleProgress _buildProgressForMuscle(
  MuscleId muscle,
  _Accumulator accumulator,
  Map<int, _ExerciseSeries> seriesByExercise,
  DateTime today,
  TrainingGoal goal,
  VolumeLandmarks landmarks,
) {
  final totalWeight = accumulator.exerciseWeights.values.fold(
    0.0,
    (sum, value) => sum + value,
  );
  final datedValues = <DateTime, List<_WeightedIndex>>{};
  final exercises = <MuscleExerciseProgress>[];

  if (totalWeight > 0) {
    for (final entry in accumulator.exerciseWeights.entries) {
      final series = seriesByExercise[entry.key];
      if (series == null || series.points.isEmpty) continue;
      final influence = math.min(
        entry.value / totalWeight,
        exerciseInfluenceCap,
      );
      for (final point in series.points) {
        (datedValues[dateOnly(point.date)] ??= []).add(
          _WeightedIndex(index: point.index, weight: influence),
        );
      }
      final latest = series.points.last;
      final best = series.points.reduce((a, b) => a.index >= b.index ? a : b);
      exercises.add(
        MuscleExerciseProgress(
          exerciseId: series.exerciseId,
          exerciseName: series.exerciseName,
          latestIndex: latest.index,
          bestIndex: best.index,
          latestRawValue: latest.rawValue,
          bestRawValue: best.rawValue,
          points: series.points,
          lowerPrecision: series.points.any((point) => point.lowerPrecision),
        ),
      );
    }
  }

  final points = [
    for (final entry in datedValues.entries)
      MuscleTrendPoint(
        date: entry.key,
        index: entry.value.isEmpty
            ? 100
            : entry.value.fold(
                    0.0,
                    (sum, value) => sum + value.index * value.weight,
                  ) /
                  entry.value.fold(0.0, (sum, value) => sum + value.weight),
      ),
  ]..sort((a, b) => a.date.compareTo(b.date));

  final rankScore = _rankScore(accumulator, points, today, landmarks);
  final rank = rankFromScore(rankScore, goal);
  final nextThreshold = nextRankThreshold(rank, goal);
  final currentThreshold = rankThreshold(rank, goal);
  final progress = nextThreshold == null
      ? 1.0
      : ((rankScore - currentThreshold) / (nextThreshold - currentThreshold))
            .clamp(0.0, 1.0);

  return MuscleProgress(
    muscle: muscle,
    rank: rank,
    rankScore: rankScore,
    rankProgress: progress,
    momentum: _momentum(points),
    points: points,
    effectiveSetHistory: UnmodifiableMapView(accumulator.effectiveSetHistory),
    primarySets: accumulator.primarySets,
    secondarySets: accumulator.secondarySets,
    lastTrained: accumulator.lastTrained,
    exercises: exercises..sort((a, b) => b.bestIndex.compareTo(a.bestIndex)),
  );
}

BodyProgressSummary buildBodyProgressSummary(
  Map<MuscleId, MuscleProgress> progressByMuscle, {
  TrainingGoal goal = TrainingGoal.build,
}) {
  final muscles = [
    for (final muscle in MuscleId.values) progressByMuscle[muscle],
  ].whereType<MuscleProgress>().toList();
  if (muscles.isEmpty) {
    return const BodyProgressSummary(
      rank: MuscleRank.foundation,
      rankScore: 0,
      rankProgress: 0,
      momentum: MuscleMomentum.learningBaseline,
      trainedMuscles: 0,
      improvingMuscles: 0,
      strongest: [],
      attentionNeeded: [],
    );
  }

  final averageScore =
      muscles.fold(0.0, (sum, muscle) => sum + muscle.rankScore) /
      muscles.length;
  final rank = rankFromScore(averageScore, goal);
  final nextThreshold = nextRankThreshold(rank, goal);
  final currentThreshold = rankThreshold(rank, goal);
  final rankProgress = nextThreshold == null
      ? 1.0
      : ((averageScore - currentThreshold) / (nextThreshold - currentThreshold))
            .clamp(0.0, 1.0);

  final trained = muscles
      .where((muscle) => muscle.lastTrained != null)
      .toList();
  final improving = muscles
      .where((muscle) => muscle.momentum == MuscleMomentum.improving)
      .toList();
  final declining = muscles
      .where((muscle) => muscle.momentum == MuscleMomentum.declining)
      .toList();
  final strongest = trained.toList()
    ..sort((a, b) => b.rankScore.compareTo(a.rankScore));
  final attention = muscles.toList()
    ..sort((a, b) {
      final aNever = a.lastTrained == null ? 0 : 1;
      final bNever = b.lastTrained == null ? 0 : 1;
      final byNever = aNever.compareTo(bNever);
      if (byNever != 0) return byNever;
      final byMomentum = _attentionPriority(
        a.momentum,
      ).compareTo(_attentionPriority(b.momentum));
      if (byMomentum != 0) return byMomentum;
      final byRank = a.rankScore.compareTo(b.rankScore);
      if (byRank != 0) return byRank;
      return MuscleId.values
          .indexOf(a.muscle)
          .compareTo(MuscleId.values.indexOf(b.muscle));
    });

  return BodyProgressSummary(
    rank: rank,
    rankScore: averageScore,
    rankProgress: rankProgress,
    momentum: improving.isNotEmpty
        ? MuscleMomentum.improving
        : declining.length > improving.length
        ? MuscleMomentum.declining
        : trained.length < 3
        ? MuscleMomentum.learningBaseline
        : MuscleMomentum.steady,
    trainedMuscles: trained.length,
    improvingMuscles: improving.length,
    strongest: strongest.take(4).toList(),
    attentionNeeded: attention.take(4).toList(),
  );
}

int _attentionPriority(MuscleMomentum momentum) => switch (momentum) {
  MuscleMomentum.declining => 0,
  MuscleMomentum.learningBaseline => 1,
  MuscleMomentum.steady => 2,
  MuscleMomentum.improving => 3,
};

double _rankScore(
  _Accumulator accumulator,
  List<MuscleTrendPoint> points,
  DateTime today,
  VolumeLandmarks landmarks,
) {
  final weeks = <DateTime, double>{};
  accumulator.effectiveSetHistory.forEach((day, sets) {
    final week = startOfWeek(day);
    weeks[week] = (weeks[week] ?? 0) + sets;
  });
  final lastCompletedWeek = _weekStartOffset(startOfWeek(today), 1);
  var adequacyWeighted = 0.0;
  var consistencyWeighted = 0.0;
  var weightTotal = 0.0;
  for (var offset = 0; offset < 8; offset++) {
    final weight = math.pow(0.82, offset).toDouble();
    final value = weeks[_weekStartOffset(lastCompletedWeek, offset)] ?? 0;
    adequacyWeighted += _volumeAdequacy(value, landmarks) * weight;
    if (value >= landmarks.mev) consistencyWeighted += weight;
    weightTotal += weight;
  }
  final volumeScore = weightTotal == 0
      ? 0
      : adequacyWeighted / weightTotal * 35;
  final consistencyScore = weightTotal == 0
      ? 0
      : consistencyWeighted / weightTotal * 15;

  final recent = points
      .where(
        (point) => !point.date.isBefore(
          dateOnly(today).subtract(const Duration(days: 84)),
        ),
      )
      .toList();
  var strengthScore = 0.0;
  if (recent.isNotEmpty) {
    var weighted = 0.0;
    var strengthWeights = 0.0;
    for (var index = 0; index < recent.length; index++) {
      final weight = (index + 1).toDouble();
      weighted += recent[index].index * weight;
      strengthWeights += weight;
    }
    final recentIndex = weighted / strengthWeights;
    strengthScore = ((recentIndex - 85) / 45).clamp(0.0, 1.0) * 50;
  }
  return (strengthScore + volumeScore + consistencyScore).clamp(0, 100);
}

DateTime _weekStartOffset(DateTime weekStart, int weeks) =>
    DateTime(weekStart.year, weekStart.month, weekStart.day - weeks * 7);

double _volumeAdequacy(double sets, VolumeLandmarks landmarks) {
  if (sets <= 0) return 0;
  if (sets < landmarks.mev) return sets / landmarks.mev * 0.55;
  if (sets <= landmarks.mav) {
    return 0.75 +
        (sets - landmarks.mev) /
            math.max(landmarks.mav - landmarks.mev, 1) *
            0.25;
  }
  if (sets <= landmarks.mrv) {
    return 1 -
        (sets - landmarks.mav) /
            math.max(landmarks.mrv - landmarks.mav, 1) *
            0.25;
  }
  return 0.55;
}

MuscleRank rankFromScore(double score, TrainingGoal goal) {
  if (score >= rankThreshold(MuscleRank.elite, goal)) {
    return MuscleRank.elite;
  }
  if (score >= rankThreshold(MuscleRank.platinum, goal)) {
    return MuscleRank.platinum;
  }
  if (score >= rankThreshold(MuscleRank.gold, goal)) return MuscleRank.gold;
  if (score >= rankThreshold(MuscleRank.silver, goal)) {
    return MuscleRank.silver;
  }
  if (score >= rankThreshold(MuscleRank.bronze, goal)) {
    return MuscleRank.bronze;
  }
  return MuscleRank.foundation;
}

double rankThreshold(MuscleRank rank, TrainingGoal goal) {
  final base = switch (rank) {
    MuscleRank.foundation => 0,
    MuscleRank.bronze => 18,
    MuscleRank.silver => 36,
    MuscleRank.gold => 55,
    MuscleRank.platinum => 73,
    MuscleRank.elite => 90,
  };
  return base * goal.rankThresholdScale;
}

double? nextRankThreshold(MuscleRank rank, TrainingGoal goal) => switch (rank) {
  MuscleRank.foundation => rankThreshold(MuscleRank.bronze, goal),
  MuscleRank.bronze => rankThreshold(MuscleRank.silver, goal),
  MuscleRank.silver => rankThreshold(MuscleRank.gold, goal),
  MuscleRank.gold => rankThreshold(MuscleRank.platinum, goal),
  MuscleRank.platinum => rankThreshold(MuscleRank.elite, goal),
  MuscleRank.elite => null,
};

String rankExplainer(
  MuscleProgress progress,
  TrainingGoal goal, {
  VolumeLandmarks? landmarks,
}) {
  final target = landmarks ?? resolveLandmarks(goal: goal)[progress.muscle]!;
  if (progress.lastTrained == null) {
    return 'Start with ${target.mev.round()}–${target.mav.round()} effective sets per week to build a baseline.';
  }
  if (progress.rank == MuscleRank.elite) {
    return 'Keep recent performance and weekly volume inside the ${target.mev.round()}–${target.mav.round()} set band.';
  }
  final next = MuscleRank.values[progress.rank.index + 1];
  final strength = progress.momentum == MuscleMomentum.declining
      ? 'reverse the recent performance dip'
      : 'add about 5% to a recent exercise';
  return 'To reach ${next.label}: train ${progress.muscle.label.toLowerCase()} near '
      '${target.mev.round()}–${target.mav.round()} sets for a few weeks and $strength.';
}

MuscleMomentum _momentum(List<MuscleTrendPoint> points) {
  if (points.length < 4) return MuscleMomentum.learningBaseline;
  final midpoint = points.length ~/ 2;
  final previous = points.take(midpoint).map((point) => point.index).toList();
  final recent = points.skip(midpoint).map((point) => point.index).toList();
  final previousAvg =
      previous.fold(0.0, (sum, value) => sum + value) / previous.length;
  final recentAvg =
      recent.fold(0.0, (sum, value) => sum + value) / recent.length;
  final delta = recentAvg - previousAvg;
  if (delta >= 3) return MuscleMomentum.improving;
  if (delta <= -3) return MuscleMomentum.declining;
  return MuscleMomentum.steady;
}

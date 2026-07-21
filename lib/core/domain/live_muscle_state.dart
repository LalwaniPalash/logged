import 'dart:collection';

import 'muscle.dart';
import 'streak.dart';

const secondaryMuscleSetWeight = 0.35;
const muscleIntensitySetCeiling = 12.0;

class MuscleSetRecord {
  const MuscleSetRecord({
    required this.date,
    required this.exerciseName,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.isWarmup,
  });

  final DateTime date;
  final String exerciseName;
  final List<MuscleId> primaryMuscles;
  final List<MuscleId> secondaryMuscles;
  final bool isWarmup;
}

class ExerciseMuscleContribution {
  const ExerciseMuscleContribution({
    required this.exerciseName,
    required this.primarySets,
    required this.secondarySets,
  });

  final String exerciseName;
  final int primarySets;
  final int secondarySets;

  double get effectiveSets =>
      primarySets + secondarySets * secondaryMuscleSetWeight;
}

class MuscleLoad {
  const MuscleLoad({
    required this.muscle,
    required this.primarySets,
    required this.secondarySets,
    required this.exercises,
  });

  final MuscleId muscle;
  final int primarySets;
  final int secondarySets;
  final List<ExerciseMuscleContribution> exercises;

  double get effectiveSets =>
      primarySets + secondarySets * secondaryMuscleSetWeight;

  double get intensity =>
      (effectiveSets / muscleIntensitySetCeiling).clamp(0.0, 1.0);
}

class LiveMuscleState {
  LiveMuscleState(Map<MuscleId, MuscleLoad> loads)
    : loads = UnmodifiableMapView(loads);

  final Map<MuscleId, MuscleLoad> loads;

  MuscleLoad? operator [](MuscleId muscle) => loads[muscle];
  bool get isEmpty => loads.isEmpty;
}

class _MutableContribution {
  _MutableContribution(this.exerciseName);
  final String exerciseName;
  int primarySets = 0;
  int secondarySets = 0;
}

class _MutableLoad {
  _MutableLoad(this.muscle);
  final MuscleId muscle;
  int primarySets = 0;
  int secondarySets = 0;
  final Map<String, _MutableContribution> exercises = {};
}

LiveMuscleState buildLiveMuscleState(
  Iterable<MuscleSetRecord> records, {
  DateTime? today,
}) {
  final now = dateOnly(today ?? DateTime.now());
  final weekStart = startOfWeek(now);
  final mutable = <MuscleId, _MutableLoad>{};

  for (final record in records) {
    final recordDay = dateOnly(record.date);
    if (record.isWarmup ||
        recordDay.isBefore(weekStart) ||
        recordDay.isAfter(now)) {
      continue;
    }

    final primary = record.primaryMuscles.toSet();
    for (final muscle in primary) {
      final load = mutable.putIfAbsent(muscle, () => _MutableLoad(muscle));
      load.primarySets++;
      (load.exercises[record.exerciseName] ??= _MutableContribution(
        record.exerciseName,
      )).primarySets++;
    }
    for (final muscle in record.secondaryMuscles.toSet().difference(primary)) {
      final load = mutable.putIfAbsent(muscle, () => _MutableLoad(muscle));
      load.secondarySets++;
      (load.exercises[record.exerciseName] ??= _MutableContribution(
        record.exerciseName,
      )).secondarySets++;
    }
  }

  return LiveMuscleState({
    for (final entry in mutable.entries)
      entry.key: MuscleLoad(
        muscle: entry.key,
        primarySets: entry.value.primarySets,
        secondarySets: entry.value.secondarySets,
        exercises:
            [
              for (final contribution in entry.value.exercises.values)
                ExerciseMuscleContribution(
                  exerciseName: contribution.exerciseName,
                  primarySets: contribution.primarySets,
                  secondarySets: contribution.secondarySets,
                ),
            ]..sort((a, b) {
              final byLoad = b.effectiveSets.compareTo(a.effectiveSets);
              return byLoad != 0
                  ? byLoad
                  : a.exerciseName.compareTo(b.exerciseName);
            }),
      ),
  });
}

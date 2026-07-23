import 'muscle.dart';
import 'training_goal.dart';
import 'volume_landmarks.dart';

class DeloadSignal {
  const DeloadSignal({required this.triggered, required this.reasons});

  final bool triggered;
  final List<String> reasons;
}

DeloadSignal assessDeload({
  required Map<MuscleId, List<double>> weeklyEffectiveSetsByMuscle,
  required Map<int, List<double>> oneRepMaxSeriesByExercise,
  required Map<int, List<double>> rpeAtLoadSeries,
  required Map<MuscleId, VolumeLandmarks> landmarks,
  TrainingGoal goal = TrainingGoal.build,
}) {
  final reasons = <String>[];

  final overreached = <MuscleId>[];
  for (final entry in weeklyEffectiveSetsByMuscle.entries) {
    final values = entry.value;
    if (values.length >= 2 &&
        values[values.length - 2] > landmarks[entry.key]!.mrv &&
        values.last > landmarks[entry.key]!.mrv) {
      overreached.add(entry.key);
    }
  }
  if (overreached.isNotEmpty) {
    reasons.add(
      '${overreached.map((muscle) => muscle.label).join(', ')} exceeded MRV for two weeks.',
    );
  }

  final stallTolerance = 0.01 * goal.deloadSensitivity;
  final stalledLifts = oneRepMaxSeriesByExercise.entries.where((entry) {
    final values = entry.value;
    if (values.length < 3) return false;
    final recent = values.sublist(values.length - 3);
    return recent.last <= recent.first * (1 + stallTolerance);
  }).length;
  if (stalledLifts > 0) {
    reasons.add(
      '$stalledLifts ${stalledLifts == 1 ? 'lift has' : 'lifts have'} stalled or declined across three sessions.',
    );
  }

  final rpeRise = 0.5 * goal.deloadSensitivity;
  final risingEffort = rpeAtLoadSeries.entries.where((entry) {
    final values = entry.value;
    if (values.length < 3) return false;
    final recent = values.sublist(values.length - 3);
    return recent[1] >= recent[0] &&
        recent[2] >= recent[1] &&
        recent.last - recent.first >= rpeRise;
  }).length;
  if (risingEffort > 0) {
    reasons.add(
      'RPE is rising at the same load on $risingEffort ${risingEffort == 1 ? 'lift' : 'lifts'}.',
    );
  }

  return DeloadSignal(triggered: reasons.length >= 2, reasons: reasons);
}

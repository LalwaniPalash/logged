import '../../data/database/app_database.dart';
import 'enums.dart';

const double poundsToKilograms = 0.45359237;

double weightKg(double value, WeightUnit unit) =>
    unit == WeightUnit.lb ? value * poundsToKilograms : value;

/// Total load moved, in kg. [WeightEntry.perSide] means two implements.
double totalLoadKg(double value, WeightUnit unit, WeightEntry entry) =>
    weightKg(value, unit) * entry.implements;

/// Estimated 1RM intentionally uses the entered value, not doubled total load.
double? estimatedOneRepMax({
  required double? weightValue,
  required WeightUnit? unit,
  required int? reps,
}) {
  if (weightValue == null || unit == null || reps == null || reps <= 0) {
    return null;
  }
  return weightKg(weightValue, unit) * (1 + reps / 30);
}

double setVolumeKg({
  required double? weightValue,
  required WeightUnit? unit,
  required int? reps,
  WeightEntry entry = WeightEntry.total,
  int sideCount = 1,
}) {
  if (weightValue == null || unit == null || reps == null || reps <= 0) {
    return 0;
  }
  return totalLoadKg(weightValue, unit, entry) * reps * sideCount;
}

class SessionTotals {
  const SessionTotals({
    required this.exerciseCount,
    required this.setCount,
    required this.totalVolumeKg,
  });

  final int exerciseCount;
  final int setCount;
  final double totalVolumeKg;
}

typedef SessionDetailMetrics = ({Iterable<SetEntry> sets});

SessionTotals computeSessionTotals(Iterable<SessionDetailMetrics> details) {
  var exerciseCount = 0;
  var setCount = 0;
  var totalVolumeKg = 0.0;
  for (final detail in details) {
    exerciseCount += 1;
    for (final set in detail.sets) {
      if (set.isWarmup) continue;
      final hasLoggedValue =
          (set.reps ?? 0) > 0 ||
          (set.durationSec ?? 0) > 0 ||
          (set.distanceMeters ?? 0) > 0 ||
          set.weightValue != null;
      if (hasLoggedValue) {
        setCount += 1;
      }
      totalVolumeKg += setVolumeKg(
        weightValue: set.weightValue,
        unit: set.unit,
        reps: set.reps,
        entry: set.weightEntry,
        sideCount: set.sideCount,
      );
    }
  }
  return SessionTotals(
    exerciseCount: exerciseCount,
    setCount: setCount,
    totalVolumeKg: totalVolumeKg,
  );
}

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

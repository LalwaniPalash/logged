import '../../data/database/app_database.dart';
import 'enums.dart';

class ProgressionSuggestion {
  const ProgressionSuggestion({
    this.weightValue,
    this.unit,
    this.reps,
    required this.rationale,
  });

  final double? weightValue;
  final WeightUnit? unit;
  final int? reps;
  final String rationale;
}

ProgressionSuggestion? suggestNextSet({
  required List<SetEntry> lastExerciseSets,
  int? minReps,
  int? maxReps,
  double? targetRpe,
  required WeightEntry weightEntry,
  required WeightUnit unit,
  LoadingMode loadingMode = LoadingMode.external,
  double progressionAggressiveness = 1,
}) {
  // Only progress off history logged the SAME way. A load means opposite things
  // across modes (assistance vs added plate), so an assisted set left in history
  // must not seed the suggestion after the user switches the lift to strict
  // bodyweight — that would offer the old assistance kilos as a real load.
  final workingSets = lastExerciseSets
      .where(
        (set) =>
            !set.isWarmup &&
            (set.reps ?? 0) > 0 &&
            set.loadingMode == loadingMode,
      )
      .toList();
  if (workingSets.isEmpty) return null;

  // For an assisted lift the stored load IS the assistance, so LESS weight is
  // the harder, more-progressed set and progression REMOVES assistance. Every
  // weight comparison below flips for this mode.
  final assisted = loadingMode == LoadingMode.bodyweightAssisted;

  final topSet = workingSets.reduce((best, candidate) {
    final bestWeight = _inUnit(best.weightValue, best.unit, unit) ?? 0;
    final candidateWeight =
        _inUnit(candidate.weightValue, candidate.unit, unit) ?? 0;
    if (candidateWeight != bestWeight) {
      final candidateHarder = assisted
          ? candidateWeight < bestWeight
          : candidateWeight > bestWeight;
      return candidateHarder ? candidate : best;
    }
    return (candidate.reps ?? 0) > (best.reps ?? 0) ? candidate : best;
  });
  final weight = _inUnit(topSet.weightValue, topSet.unit, unit);
  final reps = topSet.reps;

  // A missing range or effort target does not provide enough evidence to
  // progress safely. Matching history is still useful and deterministic.
  if (minReps == null || maxReps == null || targetRpe == null) {
    return ProgressionSuggestion(
      weightValue: weight,
      unit: weight == null ? null : unit,
      reps: reps,
      rationale: 'Match last time; add a rep range and target RPE to progress.',
    );
  }

  final effortAllowance = (progressionAggressiveness - 1).clamp(-0.5, 0.5);
  final increaseAllowed =
      reps != null &&
      reps >= maxReps &&
      topSet.rpe != null &&
      topSet.rpe! <= targetRpe + effortAllowance;
  if (increaseAllowed && weight != null) {
    final increment = unit == WeightUnit.kg ? 2.5 : 5.0;
    // Progress means more load for external/added lifts but LESS assistance for
    // an assisted lift (never past zero — that becomes an unassisted rep).
    final nextWeight = assisted
        ? (weight - increment).clamp(0, double.infinity).toDouble()
        : weight + increment;
    return ProgressionSuggestion(
      // Deliberately operate on the entered value. A per-hand dumbbell load
      // remains per-hand; WeightEntry is accepted to make that convention
      // explicit at every call site.
      weightValue: _roundLoad(nextWeight),
      unit: unit,
      reps: minReps,
      rationale: assisted
          ? 'Top of the range at a controlled RPE; drop one ${unit.label} of assistance.'
          : 'Top of the range at a controlled RPE; add one ${unit.label} increment.',
    );
  }

  if ((reps ?? 0) < minReps ||
      (topSet.rpe != null && topSet.rpe! > targetRpe + effortAllowance)) {
    return ProgressionSuggestion(
      weightValue: weight,
      unit: weight == null ? null : unit,
      reps: (reps ?? minReps).clamp(minReps, maxReps),
      rationale: 'Hold the load and own the rep target before increasing.',
    );
  }

  return ProgressionSuggestion(
    weightValue: weight,
    unit: weight == null ? null : unit,
    reps: ((reps ?? minReps) + 1).clamp(minReps, maxReps),
    rationale: 'Keep the load and add one rep toward the top of the range.',
  );
}

double? _inUnit(double? value, WeightUnit? source, WeightUnit target) {
  if (value == null) return null;
  if (source == null || source == target) return value;
  return source == WeightUnit.kg ? value * 2.2046226218 : value / 2.2046226218;
}

double _roundLoad(double value) => (value * 100).roundToDouble() / 100;

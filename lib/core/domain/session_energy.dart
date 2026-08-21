import 'dart:math' as math;

import 'enums.dart';
import 'workout_metrics.dart';

/// Estimated contribution of one logged set to session energy expenditure.
class SessionEnergySet {
  const SessionEnergySet({
    required this.weightValue,
    required this.unit,
    required this.weightEntry,
    required this.sideCount,
    required this.reps,
    required this.durationSec,
    required this.loadingMode,
    required this.isWarmup,
    required this.category,
    required this.muscleGroup,
    required this.bodyweightFactor,
  });

  final double? weightValue;
  final WeightUnit? unit;
  final WeightEntry weightEntry;
  final int sideCount;
  final int? reps;
  final int? durationSec;
  final LoadingMode loadingMode;
  final bool isWarmup;
  final ExerciseCategory category;
  final String muscleGroup;
  final double bodyweightFactor;
}

/// Estimated energy cost of one session, in kcal. Deliberately an ESTIMATE:
/// mechanical work for resistance sets, MET-time for cardio/timed work and the
/// rest between sets. Absolute accuracy is roughly +-25%; it is self-consistent,
/// so comparing your own sessions week to week is the honest use.
double estimateSessionKcal({
  required Iterable<SessionEnergySet> sets,
  required Duration elapsed,
  required double bodyweightKg,
}) {
  var resistanceKcal = 0.0;
  var timedKcal = 0.0;
  var workedMinutes = 0.0;

  for (final set in sets) {
    // Warm-ups are skipped BEFORE their minutes are booked as work. They
    // produce no countable work, so charging their time to `workedMinutes`
    // would delete it from the rest component too and the warm-up would cost
    // literally nothing. Skipped time falls through to rest, at 1.5 MET.
    if (set.isWarmup) continue;
    final reps = set.reps ?? 0;
    final durationSec = set.durationSec ?? 0;
    workedMinutes += durationSec / 60;
    workedMinutes += reps * 3 / 60;

    if (reps > 0) {
      final loadKg = _loadKg(set: set, bodyweightKg: bodyweightKg);
      final workJ =
          loadKg *
          9.81 *
          _romMetres(set.muscleGroup) *
          reps *
          set.sideCount *
          1.30;
      resistanceKcal += workJ / 0.22 / 4184;
    }

    if (durationSec > 0) {
      final met = switch (set.category) {
        ExerciseCategory.cardio => 6.0,
        ExerciseCategory.stretching => 2.5,
        _ => 4.0,
      };
      timedKcal += met * 3.5 * bodyweightKg / 200 * (durationSec / 60);
    }
  }

  // Seconds, not `inMinutes`: truncating to whole minutes reported a 90-second
  // session as one minute of rest and lost the remainder of every session.
  final restMinutes = math.max(0.0, elapsed.inSeconds / 60 - workedMinutes);
  final restKcal = 1.5 * 3.5 * bodyweightKg / 200 * restMinutes;
  return resistanceKcal + timedKcal + restKcal;
}

double _loadKg({required SessionEnergySet set, required double bodyweightKg}) {
  final externalKg = (set.weightValue != null && set.unit != null)
      ? totalLoadKg(set.weightValue!, set.unit!, set.weightEntry)
      : 0.0;
  final bodyweightLoad = bodyweightKg * set.bodyweightFactor;
  return switch (set.loadingMode) {
    LoadingMode.external => externalKg,
    LoadingMode.bodyweight => bodyweightLoad,
    LoadingMode.bodyweightAdded => bodyweightLoad + externalKg,
    LoadingMode.bodyweightAssisted => math.max(
      0.0,
      bodyweightLoad - externalKg,
    ),
  };
}

/// Range of motion per rep, keyed on the seed library's own `muscleGroup`
/// vocabulary. Every string here is one the library actually uses — the coarse
/// compound groups ('quads/hamstrings/glutes', 'full body/olympic') cover 141
/// exercises between them and must not silently fall through to the default.
const Map<String, double> muscleGroupRomMetres = {
  'quads': 0.50,
  'hamstrings': 0.50,
  'glutes': 0.50,
  'legs': 0.50,
  'quads/hamstrings/glutes': 0.50,
  // A clean or snatch travels further than any single-joint lift.
  'full body/olympic': 0.60,
  'back': 0.45,
  'lats': 0.45,
  'shoulders': 0.45,
  'chest': 0.40,
  'arms': 0.35,
  'biceps': 0.35,
  'triceps': 0.35,
  'core': 0.30,
  'abs': 0.30,
  'mobility/stretching': 0.30,
  'calves': 0.15,
  // Cardio is logged by duration, so it takes the MET path, not this one.
  'cardio': 0.40,
};

const double defaultRomMetres = 0.40;

double _romMetres(String muscleGroup) =>
    muscleGroupRomMetres[muscleGroup.toLowerCase()] ?? defaultRomMetres;

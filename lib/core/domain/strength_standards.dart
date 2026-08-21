import 'enums.dart';

enum UserSex { male, female, unset }

enum StrengthLevel {
  untrained('Untrained'),
  novice('Novice'),
  intermediate('Intermediate'),
  advanced('Advanced'),
  elite('Elite');

  const StrengthLevel(this.label);
  final String label;
}

class StrengthStandardResult {
  const StrengthStandardResult({
    required this.level,
    required this.ratio,
    required this.nextThreshold,
  });

  final StrengthLevel level;
  final double ratio;
  final double? nextThreshold;
}

const benchmarkLiftNames = {
  'Barbell Bench Press',
  'Barbell Back Squat',
  'Barbell Deadlift',
  'Barbell Overhead Press',
  'Barbell Bent-Over Row',
  'Pull-Up',
  'Barbell Front Squat',
  'Romanian Deadlift',
  'Barbell Incline Bench Press',
  'Close-Grip Bench Press',
  'Chin-Up',
  'Dips (Chest Focus)',
  'Push-Up',
  'Barbell Hip Thrust',
  'Standing Barbell Calf Raise',
};

/// Lifts logged bodyweight-style (own mass ± an added/assisted load), as
/// opposed to a barbell lift that must be externally loaded. Same
/// strict/weighted/assisted counting rules apply to all of them.
const _bodyweightStyleLifts = {'Pull-Up', 'Chin-Up', 'Dips (Chest Focus)', 'Push-Up'};

// Bodyweight-ratio bands. The original six lifts are adapted from public
// ExRx strength-standard tables; the nine added 2026-08-21 are adapted from
// strengthlevel.com's public standards (novice/intermediate/advanced/elite —
// their "beginner" tier folds into this app's "untrained"). These are broad
// population comparisons, kept separate from personal ranks.
//
// Chin-Up, Dips (Chest Focus) and Push-Up only publish rep-count standards,
// not load ratios (there's no external plate to weigh) — their thresholds
// below are rep counts run through the app's own bodyweight-set formula,
// ratio = 1 + reps/30 (see BenchmarkSetRecord.resistedOneRepMaxKg in
// analytics_repository.dart), so a real user's logged reps compare on the
// same axis these thresholds were derived on.
const _male = <String, List<double>>{
  'Barbell Bench Press': [0.60, 0.90, 1.20, 1.50],
  'Barbell Back Squat': [0.75, 1.25, 1.75, 2.25],
  'Barbell Deadlift': [1.00, 1.50, 2.00, 2.50],
  'Barbell Overhead Press': [0.40, 0.60, 0.80, 1.00],
  'Barbell Bent-Over Row': [0.50, 0.75, 1.00, 1.25],
  'Pull-Up': [0.95, 1.10, 1.30, 1.55],
  'Barbell Front Squat': [1.00, 1.25, 1.75, 2.25],
  'Romanian Deadlift': [1.00, 1.50, 2.00, 2.75],
  'Barbell Incline Bench Press': [0.75, 1.00, 1.50, 1.75],
  'Close-Grip Bench Press': [0.75, 1.25, 1.50, 2.00],
  // Reps [7, 13, 21, 30] -> 1 + reps/30, rounded to the nearest 0.05.
  'Chin-Up': [1.25, 1.45, 1.70, 2.00],
  // Reps [10, 20, 31, 43] -> 1 + reps/30.
  'Dips (Chest Focus)': [1.35, 1.65, 2.05, 2.45],
  // Reps [19, 39, 62, 87] -> 1 + reps/30.
  'Push-Up': [1.65, 2.30, 3.05, 3.90],
  'Barbell Hip Thrust': [1.25, 1.75, 2.75, 3.75],
  // No exact "standing" page on the source; the plain barbell calf raise
  // standard is used as the closest match.
  'Standing Barbell Calf Raise': [1.00, 1.50, 2.25, 3.25],
};

const _female = <String, List<double>>{
  'Barbell Bench Press': [0.35, 0.55, 0.80, 1.05],
  'Barbell Back Squat': [0.50, 0.85, 1.25, 1.65],
  'Barbell Deadlift': [0.65, 1.00, 1.45, 1.90],
  'Barbell Overhead Press': [0.25, 0.40, 0.55, 0.70],
  'Barbell Bent-Over Row': [0.35, 0.55, 0.75, 0.95],
  'Pull-Up': [0.85, 1.00, 1.15, 1.35],
  'Barbell Front Squat': [0.75, 1.00, 1.25, 1.50],
  'Romanian Deadlift': [0.75, 1.00, 1.50, 2.00],
  'Barbell Incline Bench Press': [0.40, 0.65, 0.95, 1.25],
  'Close-Grip Bench Press': [0.50, 0.75, 1.05, 1.35],
  // Reps [1, 6, 11, 17] -> 1 + reps/30, rounded to the nearest 0.05.
  'Chin-Up': [1.05, 1.20, 1.35, 1.55],
  // Reps [1, 9, 18, 29] -> 1 + reps/30.
  'Dips (Chest Focus)': [1.05, 1.30, 1.60, 1.95],
  // Reps [7, 18, 31, 47] -> 1 + reps/30.
  'Push-Up': [1.25, 1.60, 2.05, 2.55],
  'Barbell Hip Thrust': [1.00, 1.75, 2.50, 3.25],
  'Standing Barbell Calf Raise': [0.75, 1.25, 1.75, 2.50],
};

/// Whether a logged set may count toward a population strength standard.
///
/// Standards are load-per-bodyweight comparisons, so a set only counts when it
/// was logged the canonical way for that lift:
///  - the barbell lifts must be externally loaded with a real weight;
///  - the bodyweight-style lifts (Pull-Up, Chin-Up, Dips, Push-Up) count
///    strict (bodyweight, weight optional) or weighted (bodyweightAdded with
///    an actual plate) — an ASSISTED rep is easier than the standard assumes
///    and is excluded, as is any weighted-mode set saved with a blank load
///    (an incomplete set must not become a PR).
bool countsForStandard({
  required String lift,
  required LoadingMode mode,
  required bool hasEnteredWeight,
}) {
  if (!benchmarkLiftNames.contains(lift)) return false;
  if (_bodyweightStyleLifts.contains(lift)) {
    return switch (mode) {
      LoadingMode.bodyweight => true,
      LoadingMode.bodyweightAdded => hasEnteredWeight,
      LoadingMode.external || LoadingMode.bodyweightAssisted => false,
    };
  }
  // Barbell benchmark lifts: externally loaded, real weight only.
  return mode == LoadingMode.external && hasEnteredWeight;
}

StrengthStandardResult? standardFor({
  required String lift,
  required UserSex sex,
  required double bodyweightKg,
  required double estOneRepMaxKg,
}) {
  if (sex == UserSex.unset ||
      bodyweightKg <= 0 ||
      estOneRepMaxKg < 0 ||
      !benchmarkLiftNames.contains(lift)) {
    return null;
  }
  final thresholds = (sex == UserSex.male ? _male : _female)[lift]!;
  final ratio = estOneRepMaxKg / bodyweightKg;
  final level = ratio >= thresholds[3]
      ? StrengthLevel.elite
      : ratio >= thresholds[2]
      ? StrengthLevel.advanced
      : ratio >= thresholds[1]
      ? StrengthLevel.intermediate
      : ratio >= thresholds[0]
      ? StrengthLevel.novice
      : StrengthLevel.untrained;
  final next = level == StrengthLevel.elite
      ? null
      : thresholds[level.index] * bodyweightKg;
  return StrengthStandardResult(
    level: level,
    ratio: ratio,
    nextThreshold: next,
  );
}

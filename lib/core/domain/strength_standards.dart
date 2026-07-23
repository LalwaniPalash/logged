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
};

// Bodyweight-ratio bands adapted from public ExRx strength-standard tables.
// These are broad population comparisons, kept separate from personal ranks.
const _male = <String, List<double>>{
  'Barbell Bench Press': [0.60, 0.90, 1.20, 1.50],
  'Barbell Back Squat': [0.75, 1.25, 1.75, 2.25],
  'Barbell Deadlift': [1.00, 1.50, 2.00, 2.50],
  'Barbell Overhead Press': [0.40, 0.60, 0.80, 1.00],
  'Barbell Bent-Over Row': [0.50, 0.75, 1.00, 1.25],
  'Pull-Up': [0.95, 1.10, 1.30, 1.55],
};

const _female = <String, List<double>>{
  'Barbell Bench Press': [0.35, 0.55, 0.80, 1.05],
  'Barbell Back Squat': [0.50, 0.85, 1.25, 1.65],
  'Barbell Deadlift': [0.65, 1.00, 1.45, 1.90],
  'Barbell Overhead Press': [0.25, 0.40, 0.55, 0.70],
  'Barbell Bent-Over Row': [0.35, 0.55, 0.75, 0.95],
  'Pull-Up': [0.85, 1.00, 1.15, 1.35],
};

/// Whether a logged set may count toward a population strength standard.
///
/// Standards are load-per-bodyweight comparisons, so a set only counts when it
/// was logged the canonical way for that lift:
///  - the barbell lifts must be externally loaded with a real weight;
///  - the Pull-Up counts strict (bodyweight, weight optional) or weighted
///    (bodyweightAdded with an actual plate) — an ASSISTED pull-up is easier
///    than the standard assumes and is excluded, as is any weighted-mode set
///    saved with a blank load (an incomplete set must not become a PR).
bool countsForStandard({
  required String lift,
  required LoadingMode mode,
  required bool hasEnteredWeight,
}) {
  if (!benchmarkLiftNames.contains(lift)) return false;
  if (lift == 'Pull-Up') {
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

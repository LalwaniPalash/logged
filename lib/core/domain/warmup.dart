import 'enums.dart';
import 'plate_math.dart';

const double _epsilon = 1e-6;

class WarmupSet {
  const WarmupSet({
    required this.weight,
    required this.reps,
    required this.label,
  });

  final double weight;
  final int reps;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is WarmupSet &&
      other.weight == weight &&
      other.reps == reps &&
      other.label == label;

  @override
  int get hashCode => Object.hash(weight, reps, label);
}

List<WarmupSet> generateWarmup({
  required double workingWeight,
  required WeightUnit unit,
  required PlateInventory inventory,
  int? workingReps,
  LoadingMode loadingMode = LoadingMode.external,
  bool perImplement = false,
}) {
  if (loadingMode == LoadingMode.bodyweight ||
      loadingMode == LoadingMode.bodyweightAssisted) {
    return const [];
  }

  final barWeight = inventory.barWeightFor(unit);
  // A load at or under the bar is only meaningless for an actual BARBELL.
  // Machines, dumbbells and cable stacks are logged the same way and a 10 kg
  // working set on one of them deserves the same 40/60/80% ramp — gating the
  // whole ramp on the bar weight left "Warm-up" permanently disabled for every
  // light or non-barbell exercise, with nothing on screen saying why. The bar
  // rung itself is still barbell-only; below the bar we just skip that rung.
  final usesBar = workingWeight > barWeight + _epsilon;
  // Below roughly one plate-step there is no ramp worth logging.
  final minimumRampable = unit == WeightUnit.kg ? 5.0 : 10.0;
  if (!usesBar && workingWeight <= minimumRampable + _epsilon) return const [];

  // Below the bar, `roundToLoadable` is the wrong tool: it solves BARBELL
  // plate math and cannot express a load lighter than the bar, so every rung
  // came back at the bar weight and was then dropped for being >= working.
  // A machine or dumbbell ramp rounds to a plain increment instead.
  final simpleStep = unit == WeightUnit.kg ? 2.5 : 5.0;
  double roundRung(double target) => usesBar
      ? roundToLoadable(
          target,
          unit: unit,
          inventory: inventory,
          perImplement: perImplement,
        )
      : (target / simpleStep).round() * simpleStep;

  final barRungReps = (workingReps ?? 8).clamp(5, 8);
  final firstRung = roundRung(workingWeight * 0.4);
  final includeBarRung = usesBar && firstRung > barWeight + _epsilon;
  final candidates = <({double target, int reps, String label})>[
    if (includeBarRung)
      (target: barWeight, reps: barRungReps, label: 'Bar × $barRungReps'),
    (target: workingWeight * 0.4, reps: 5, label: '40% × 5'),
    (target: workingWeight * 0.6, reps: 3, label: '60% × 3'),
    (target: workingWeight * 0.8, reps: 2, label: '80% × 2'),
  ];

  final warmups = <WarmupSet>[];
  for (final candidate in candidates) {
    final loadable = roundRung(candidate.target);
    if (loadable <= _epsilon) continue;
    if (usesBar && loadable <= barWeight + _epsilon && !includeBarRung) {
      continue;
    }
    if (loadable >= workingWeight - _epsilon) continue;
    if (warmups.isNotEmpty &&
        (warmups.last.weight - loadable).abs() <= _epsilon) {
      continue;
    }
    warmups.add(
      WarmupSet(weight: loadable, reps: candidate.reps, label: candidate.label),
    );
  }
  return warmups;
}

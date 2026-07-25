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
  if (workingWeight <= barWeight + _epsilon) return const [];

  final barRungReps = (workingReps ?? 8).clamp(5, 8);
  final firstRung = roundToLoadable(
    workingWeight * 0.4,
    unit: unit,
    inventory: inventory,
    perImplement: perImplement,
  );
  final includeBarRung = firstRung > barWeight + _epsilon;
  final candidates = <({double target, int reps, String label})>[
    if (includeBarRung)
      (target: barWeight, reps: barRungReps, label: 'Bar × $barRungReps'),
    (target: workingWeight * 0.4, reps: 5, label: '40% × 5'),
    (target: workingWeight * 0.6, reps: 3, label: '60% × 3'),
    (target: workingWeight * 0.8, reps: 2, label: '80% × 2'),
  ];

  final warmups = <WarmupSet>[];
  for (final candidate in candidates) {
    final loadable = roundToLoadable(
      candidate.target,
      unit: unit,
      inventory: inventory,
      perImplement: perImplement,
    );
    if (loadable <= barWeight + _epsilon && !includeBarRung) continue;
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

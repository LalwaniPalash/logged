import 'muscle.dart';

typedef BiasAxis = ({MuscleId? biasMuscleA, MuscleId? biasMuscleB});
typedef MuscleBiasShares = ({double shareA, double shareB});

MuscleBiasShares resolveMuscleBiasShares(double? bias) {
  final clamped = (bias ?? 0.0).clamp(-1.0, 1.0).toDouble();
  final t = (clamped + 1) / 2;
  return (shareA: 1 - t, shareB: t);
}

double? primaryMuscleBiasWeight({
  required MuscleId muscle,
  required MuscleId? biasMuscleA,
  required MuscleId? biasMuscleB,
  required double? muscleBias,
}) {
  if (biasMuscleA == null || biasMuscleB == null) return null;
  final shares = resolveMuscleBiasShares(muscleBias);
  if (muscle == biasMuscleA) return shares.shareA;
  if (muscle == biasMuscleB) return shares.shareB;
  return null;
}

BiasAxis normalizeBiasAxis({
  required MuscleId? biasMuscleA,
  required MuscleId? biasMuscleB,
}) {
  if (biasMuscleA == null ||
      biasMuscleB == null ||
      biasMuscleA == biasMuscleB) {
    return (biasMuscleA: null, biasMuscleB: null);
  }
  return (biasMuscleA: biasMuscleA, biasMuscleB: biasMuscleB);
}

void validateBiasAxis({
  required Iterable<MuscleId> primary,
  required MuscleId? biasMuscleA,
  required MuscleId? biasMuscleB,
}) {
  final axis = normalizeBiasAxis(
    biasMuscleA: biasMuscleA,
    biasMuscleB: biasMuscleB,
  );
  if (axis.biasMuscleA == null || axis.biasMuscleB == null) return;

  final primarySet = primary.toSet();
  if (!primarySet.contains(axis.biasMuscleA) ||
      !primarySet.contains(axis.biasMuscleB)) {
    throw ArgumentError('Bias axis muscles must both be primary muscles.');
  }
}

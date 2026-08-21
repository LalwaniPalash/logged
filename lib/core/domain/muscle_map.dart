import 'live_muscle_state.dart';
import 'muscle.dart';

/// Broad body regions used by the anatomical heatmap.
enum BodyRegion {
  chest,
  shoulders,
  arms,
  core,
  back,
  quads,
  hamstrings,
  glutes,
  calves,
}

/// Maps a library `muscleGroup` string to the body regions it trains. The seed
/// library uses coarse groups (e.g. "quads/hamstrings/glutes"), so several map
/// to multiple regions.
const Map<String, List<BodyRegion>> _muscleGroupToRegions = {
  'chest': [BodyRegion.chest],
  'back': [BodyRegion.back],
  'lats': [BodyRegion.back],
  'shoulders': [BodyRegion.shoulders],
  'arms': [BodyRegion.arms],
  'biceps': [BodyRegion.arms],
  'triceps': [BodyRegion.arms],
  'core': [BodyRegion.core],
  'abs': [BodyRegion.core],
  'quads/hamstrings/glutes': [
    BodyRegion.quads,
    BodyRegion.hamstrings,
    BodyRegion.glutes,
  ],
  'quads': [BodyRegion.quads],
  'hamstrings': [BodyRegion.hamstrings],
  'glutes': [BodyRegion.glutes],
  'calves': [BodyRegion.calves],
  'full body/olympic': [
    BodyRegion.back,
    BodyRegion.quads,
    BodyRegion.glutes,
    BodyRegion.core,
  ],
};

List<BodyRegion> regionsForMuscleGroup(String muscleGroup) =>
    _muscleGroupToRegions[muscleGroup.toLowerCase()] ?? const [];

/// Turns per-muscle-group volume into a 0..1 intensity per region, normalized to
/// the busiest region so the most-trained area glows fullest. Volume from a
/// multi-region group is split evenly across its regions.
Map<BodyRegion, double> regionIntensities(Map<String, double> volumeByGroup) {
  final raw = <BodyRegion, double>{};
  volumeByGroup.forEach((group, volume) {
    final regions = regionsForMuscleGroup(group);
    if (regions.isEmpty) return;
    final share = volume / regions.length;
    for (final region in regions) {
      raw[region] = (raw[region] ?? 0) + share;
    }
  });
  if (raw.isEmpty) return const {};
  final max = raw.values.reduce((a, b) => a > b ? a : b);
  if (max <= 0) return const {};
  return {for (final e in raw.entries) e.key: (e.value / max).clamp(0.0, 1.0)};
}

const Map<MuscleId, BodyRegion> _detailedMuscleToRegion = {
  MuscleId.upperChest: BodyRegion.chest,
  MuscleId.midLowerChest: BodyRegion.chest,
  MuscleId.serratusAnterior: BodyRegion.chest,
  MuscleId.frontDelts: BodyRegion.shoulders,
  MuscleId.sideDelts: BodyRegion.shoulders,
  MuscleId.rearDelts: BodyRegion.shoulders,
  MuscleId.rotatorCuff: BodyRegion.shoulders,
  MuscleId.lats: BodyRegion.back,
  MuscleId.upperTraps: BodyRegion.back,
  MuscleId.midLowerTraps: BodyRegion.back,
  MuscleId.rhomboids: BodyRegion.back,
  MuscleId.spinalErectors: BodyRegion.back,
  MuscleId.biceps: BodyRegion.arms,
  MuscleId.brachialis: BodyRegion.arms,
  MuscleId.triceps: BodyRegion.arms,
  MuscleId.forearms: BodyRegion.arms,
  MuscleId.abs: BodyRegion.core,
  MuscleId.obliques: BodyRegion.core,
  MuscleId.hipFlexors: BodyRegion.quads,
  MuscleId.quads: BodyRegion.quads,
  MuscleId.hamstrings: BodyRegion.hamstrings,
  MuscleId.gluteMax: BodyRegion.glutes,
  MuscleId.gluteMedMin: BodyRegion.glutes,
  MuscleId.adductors: BodyRegion.quads,
  MuscleId.calves: BodyRegion.calves,
  MuscleId.tibialisAnterior: BodyRegion.calves,
  MuscleId.neck: BodyRegion.back,
};

BodyRegion? regionForMuscle(MuscleId muscle) => _detailedMuscleToRegion[muscle];

Map<BodyRegion, double> regionIntensitiesForExercise({
  required Iterable<MuscleId> primary,
  required Iterable<MuscleId> secondary,
}) {
  final intensities = <BodyRegion, double>{};
  for (final muscle in secondary) {
    final region = regionForMuscle(muscle);
    if (region == null) continue;
    intensities[region] = (intensities[region] ?? 0) < 0.45
        ? 0.45
        : intensities[region]!;
  }
  for (final muscle in primary) {
    final region = regionForMuscle(muscle);
    if (region == null) continue;
    intensities[region] = 1.0;
  }
  return intensities;
}

/// Collapses the detailed per-set state for the accessible 2D fallback. The
/// strongest detailed muscle wins within a broad region so splitting an area
/// into several anatomical IDs does not artificially inflate its color.
Map<BodyRegion, double> regionIntensitiesFromLiveState(LiveMuscleState state) {
  final result = <BodyRegion, double>{};
  for (final entry in state.loads.entries) {
    final region = _detailedMuscleToRegion[entry.key];
    if (region == null) continue;
    final current = result[region] ?? 0;
    if (entry.value.intensity > current) {
      result[region] = entry.value.intensity;
    }
  }
  return result;
}

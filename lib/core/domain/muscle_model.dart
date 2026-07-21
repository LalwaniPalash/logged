import 'live_muscle_state.dart';
import 'muscle.dart';

const muscleModelAssetPath = 'assets/models/muscular.glb';

/// Maps the app's workout-focused taxonomy onto the named superficial meshes
/// in the bundled GLB. Keeping this outside the renderer makes taps and colors
/// deterministic and testable.
const Map<MuscleId, List<String>> muscleModelEntities = {
  MuscleId.upperChest: ['pec_major_upper'],
  MuscleId.midLowerChest: ['pec_minor', 'pec_major_mid', 'pec_major_lower'],
  MuscleId.serratusAnterior: ['serratus'],
  MuscleId.frontDelts: ['delt_front'],
  MuscleId.sideDelts: ['delt_side'],
  MuscleId.rearDelts: ['delt_rear'],
  MuscleId.rotatorCuff: ['teres_minor', 'infraspinatus'],
  MuscleId.lats: ['lats', 'teres_major'],
  MuscleId.upperTraps: ['trap_upper'],
  MuscleId.midLowerTraps: ['trap_mid', 'trap_lower'],
  MuscleId.rhomboids: ['rhomboids'],
  MuscleId.spinalErectors: ['erectors'],
  MuscleId.biceps: ['bicep_long', 'bicep_short'],
  MuscleId.brachialis: ['brachialis'],
  MuscleId.triceps: ['tricep_medial', 'tricep_lateral', 'tricep_long'],
  MuscleId.forearms: [
    'forearm_flexors',
    'brachioradialis',
    'forearm_extensors',
  ],
  MuscleId.abs: ['rectus_upper', 'rectus_lower', 'transverse'],
  MuscleId.obliques: ['obliques'],
  MuscleId.hipFlexors: ['hip_flexors'],
  MuscleId.quads: [
    'rectus_femoris',
    'vastus_lateralis',
    'vastus_medialis',
    'vastus_intermedius',
  ],
  MuscleId.hamstrings: [
    'biceps_femoris_long',
    'biceps_femoris_short',
    'semimembranosus',
    'semitendinosus',
  ],
  MuscleId.gluteMax: ['glute_max'],
  MuscleId.gluteMedMin: ['glute_med', 'glute_min'],
  MuscleId.adductors: ['adductors'],
  MuscleId.calves: ['gastroc_lateral', 'gastroc_medial', 'soleus'],
  MuscleId.tibialisAnterior: ['tibialis_anterior'],
};

final Set<String> muscleModelEntityNames = {
  for (final entities in muscleModelEntities.values) ...entities,
};

final Map<String, MuscleId> _muscleByEntity = {
  for (final entry in muscleModelEntities.entries)
    for (final entity in entry.value) entity: entry.key,
};

MuscleId? muscleForModelEntity(String entityName) =>
    _muscleByEntity[entityName];

/// Returns a complete per-mesh state so untrained muscles are explicitly reset
/// when a set is edited, deleted, or changed to a warm-up.
Map<String, double> muscleModelIntensities(LiveMuscleState state) => {
  for (final entry in muscleModelEntities.entries)
    for (final entity in entry.value) entity: state[entry.key]?.intensity ?? 0,
};

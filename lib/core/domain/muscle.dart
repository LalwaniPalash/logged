import 'dart:convert';

/// Stable fitness-oriented muscle identifiers shared by exercise metadata,
/// analytics, backups, and the 3D model manifest.
enum MuscleId {
  upperChest('upper_chest', 'Upper chest'),
  midLowerChest('mid_lower_chest', 'Mid / lower chest'),
  serratusAnterior('serratus_anterior', 'Serratus anterior'),
  frontDelts('front_delts', 'Front delts'),
  sideDelts('side_delts', 'Side delts'),
  rearDelts('rear_delts', 'Rear delts'),
  rotatorCuff('rotator_cuff', 'Rotator cuff'),
  lats('lats', 'Lats'),
  upperTraps('upper_traps', 'Upper traps'),
  midLowerTraps('mid_lower_traps', 'Mid / lower traps'),
  rhomboids('rhomboids', 'Rhomboids'),
  spinalErectors('spinal_erectors', 'Spinal erectors'),
  biceps('biceps', 'Biceps'),
  brachialis('brachialis', 'Brachialis'),
  triceps('triceps', 'Triceps'),
  forearms('forearms', 'Forearms'),
  abs('abs', 'Abs'),
  obliques('obliques', 'Obliques'),
  hipFlexors('hip_flexors', 'Hip flexors'),
  quads('quads', 'Quads'),
  hamstrings('hamstrings', 'Hamstrings'),
  gluteMax('glute_max', 'Glute max'),
  gluteMedMin('glute_med_min', 'Glute med / min'),
  adductors('adductors', 'Adductors'),
  calves('calves', 'Calves'),
  tibialisAnterior('tibialis_anterior', 'Tibialis anterior'),
  neck('neck', 'Neck');

  const MuscleId(this.id, this.label);

  final String id;
  final String label;

  static MuscleId fromId(String id) {
    for (final muscle in values) {
      if (muscle.id == id) return muscle;
    }
    throw ArgumentError.value(id, 'id', 'Unknown muscle id');
  }
}

String encodeMuscleIds(Iterable<MuscleId> muscles) =>
    jsonEncode([for (final muscle in muscles) muscle.id]);

/// Decodes a stored muscle list, in order, with duplicates removed. A repeated
/// id is a data defect, not a doubling instruction: it would double a muscle's
/// set credit and give two bias sliders the same key.
List<MuscleId> decodeMuscleIds(String encoded) {
  final value = jsonDecode(encoded);
  if (value is! List<dynamic>) {
    throw const FormatException('Muscle list must be a JSON array.');
  }
  return <MuscleId>{
    for (final item in value)
      if (item is String)
        MuscleId.fromId(item)
      else
        throw const FormatException('Muscle ids must be strings.'),
  }.toList(growable: false);
}

void validateMuscleSelection({
  required Iterable<MuscleId> primary,
  required Iterable<MuscleId> secondary,
}) {
  final primarySet = primary.toSet();
  final secondarySet = secondary.toSet();
  if (primarySet.isEmpty) {
    throw ArgumentError('At least one primary muscle is required.');
  }
  if (primarySet.intersection(secondarySet).isNotEmpty) {
    throw ArgumentError('A muscle cannot be both primary and secondary.');
  }
}

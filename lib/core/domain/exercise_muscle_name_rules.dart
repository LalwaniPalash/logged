import 'exercise_name_matcher.dart';
import 'muscle.dart';

const _inclineChestPhrases = {'incline', 'low pulley', 'low cable'};
const _declineChestPhrases = {'decline', 'high pulley', 'high cable'};
const _flatChestPhrases = {'mid pulley', 'flat'};
const _adjustableChestEquipmentPhrases = {
  'pec deck',
  'cable crossover',
  'cable chest fly',
  'cable fly',
  'single-arm cable fly',
  'single-arm cable crossover',
  'machine chest fly',
  'machine chest press',
  'cable chest press',
  'standing cable chest press',
  'leverage chest press',
};
const _pushUpPhrases = {
  'push up',
  'pushup',
  'push-up',
  'push ups',
  'pushups',
  'push-ups',
};
const _feetElevatedPushUpPhrases = {
  'decline',
  'feet elevated',
  'feet on an exercise ball',
};
const _handsElevatedPushUpPhrases = {'incline'};
const _sideDeltPhrases = {
  'lateral raise',
  'side lateral raise',
  'side laterals',
  'side raise',
  'upright row',
  'y raise',
  'y-raise',
  'scaption raise',
  'scaption',
  'trap-3 raise',
  'trap 3 raise',
};
const _rearDeltPhrases = {
  'rear delt',
  'rear lateral',
  'rear fly',
  'reverse fly',
  'reverse pec deck',
  'reverse machine fly',
  'face pull',
  'pull-apart',
  'pull apart',
};
const _rotatorCuffPhrases = {
  'external rotation',
  'internal rotation',
  'w-raise',
  'w raise',
  'rotator cuff',
};
const _gluteMedMinPhrases = {
  'abduction',
  'clamshell',
  'fire hydrant',
  'band walk',
};
const _trapScapularPhrases = {'row', 'face pull', 'high row', 'row to neck'};

bool _matchesAnyPhrase(List<String> tokens, Iterable<String> phrases) =>
    mostSpecificExercisePhraseMatch(tokens, phrases) != null;

bool _exerciseNameIsPushUp(List<String> tokens) =>
    _matchesAnyPhrase(tokens, _pushUpPhrases);

bool _exerciseNameUsesAdjustableChestEquipment(List<String> tokens) =>
    _matchesAnyPhrase(tokens, _adjustableChestEquipmentPhrases);

MuscleId chestMuscleFromExerciseName(String exerciseName) {
  return chestPrimaryMusclesFromExerciseName(
        exerciseName,
      ).contains(MuscleId.upperChest)
      ? MuscleId.upperChest
      : MuscleId.midLowerChest;
}

Set<MuscleId> chestPrimaryMusclesFromExerciseName(String exerciseName) {
  final tokens = tokenizeExerciseName(exerciseName);
  if (_exerciseNameIsPushUp(tokens)) {
    if (_matchesAnyPhrase(tokens, _feetElevatedPushUpPhrases)) {
      return {MuscleId.upperChest};
    }
    if (_matchesAnyPhrase(tokens, _handsElevatedPushUpPhrases)) {
      return {MuscleId.midLowerChest};
    }
    return {MuscleId.midLowerChest};
  }
  if (_matchesAnyPhrase(tokens, _inclineChestPhrases)) {
    return {MuscleId.upperChest};
  }
  if (_matchesAnyPhrase(tokens, _declineChestPhrases) ||
      _matchesAnyPhrase(tokens, _flatChestPhrases)) {
    return {MuscleId.midLowerChest};
  }
  if (_exerciseNameUsesAdjustableChestEquipment(tokens)) {
    return {MuscleId.midLowerChest, MuscleId.upperChest};
  }
  return {MuscleId.midLowerChest};
}

MuscleId shoulderMuscleFromExerciseName(String exerciseName) {
  final tokens = tokenizeExerciseName(exerciseName);
  if (_matchesAnyPhrase(tokens, _sideDeltPhrases)) {
    return MuscleId.sideDelts;
  }
  if (_matchesAnyPhrase(tokens, _rearDeltPhrases)) {
    return MuscleId.rearDelts;
  }
  if (_matchesAnyPhrase(tokens, _rotatorCuffPhrases)) {
    return MuscleId.rotatorCuff;
  }
  return MuscleId.frontDelts;
}

MuscleId gluteMuscleFromExerciseName(String exerciseName) {
  final tokens = tokenizeExerciseName(exerciseName);
  if (_matchesAnyPhrase(tokens, _gluteMedMinPhrases)) {
    return MuscleId.gluteMedMin;
  }
  return MuscleId.gluteMax;
}

bool exerciseNameSuggestsRowOrFacePull(String exerciseName) {
  final tokens = tokenizeExerciseName(exerciseName);
  return _matchesAnyPhrase(tokens, _trapScapularPhrases);
}

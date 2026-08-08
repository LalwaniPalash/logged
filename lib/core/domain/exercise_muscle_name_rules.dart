import 'exercise_name_matcher.dart';
import 'muscle.dart';

const _inclineChestPhrases = {'incline'};
const _sideDeltPhrases = {'lateral raise', 'upright row'};
const _rearDeltPhrases = {'rear', 'reverse fly', 'face pull'};
const _rotatorCuffPhrases = {'rotation', 'rotator cuff'};
const _gluteMedMinPhrases = {
  'abduction',
  'clamshell',
  'fire hydrant',
  'band walk',
};
const _trapScapularPhrases = {'row', 'face pull'};

bool _matchesAnyPhrase(List<String> tokens, Iterable<String> phrases) =>
    mostSpecificExercisePhraseMatch(tokens, phrases) != null;

MuscleId chestMuscleFromExerciseName(String exerciseName) {
  final tokens = tokenizeExerciseName(exerciseName);
  if (_matchesAnyPhrase(tokens, _inclineChestPhrases)) {
    return MuscleId.upperChest;
  }
  return MuscleId.midLowerChest;
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

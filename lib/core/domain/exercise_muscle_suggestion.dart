import 'exercise_name_matcher.dart';
import 'exercise_muscle_name_rules.dart';
import 'muscle.dart';

typedef ExerciseMuscleSuggestion = ({
  Set<MuscleId> primary,
  Set<MuscleId> secondary,
});

const Map<String, ({List<MuscleId> primary, List<MuscleId> secondary})>
_keywordSuggestions = {
  'shoulder press': (
    primary: [MuscleId.frontDelts, MuscleId.sideDelts],
    secondary: [
      MuscleId.triceps,
      MuscleId.upperChest,
      MuscleId.upperTraps,
      MuscleId.serratusAnterior,
    ],
  ),
  'overhead press': (
    primary: [MuscleId.frontDelts, MuscleId.sideDelts],
    secondary: [
      MuscleId.triceps,
      MuscleId.upperChest,
      MuscleId.upperTraps,
      MuscleId.serratusAnterior,
    ],
  ),
  'arnold press': (
    primary: [MuscleId.frontDelts, MuscleId.sideDelts],
    secondary: [
      MuscleId.triceps,
      MuscleId.upperChest,
      MuscleId.upperTraps,
      MuscleId.serratusAnterior,
    ],
  ),
  'landmine press': (
    primary: [MuscleId.frontDelts, MuscleId.sideDelts],
    secondary: [
      MuscleId.triceps,
      MuscleId.upperChest,
      MuscleId.serratusAnterior,
    ],
  ),
  'leg press': (
    primary: [MuscleId.quads, MuscleId.gluteMax],
    secondary: [MuscleId.hamstrings, MuscleId.adductors],
  ),
  'calf raise': (primary: [MuscleId.calves], secondary: []),
  'face pull': (
    primary: [MuscleId.rearDelts, MuscleId.midLowerTraps, MuscleId.rhomboids],
    secondary: [MuscleId.rotatorCuff, MuscleId.upperTraps, MuscleId.biceps],
  ),
  'split squat': (
    primary: [MuscleId.quads, MuscleId.gluteMax],
    secondary: [
      MuscleId.hamstrings,
      MuscleId.adductors,
      MuscleId.gluteMedMin,
      MuscleId.calves,
    ],
  ),
  'romanian deadlift': (
    primary: [MuscleId.hamstrings, MuscleId.gluteMax],
    secondary: [MuscleId.spinalErectors, MuscleId.adductors, MuscleId.forearms],
  ),
  'good morning': (
    primary: [MuscleId.hamstrings, MuscleId.spinalErectors],
    secondary: [MuscleId.gluteMax, MuscleId.abs],
  ),
  'hip thrust': (
    primary: [MuscleId.gluteMax],
    secondary: [MuscleId.hamstrings, MuscleId.adductors, MuscleId.abs],
  ),
  'glute bridge': (
    primary: [MuscleId.gluteMax],
    secondary: [MuscleId.hamstrings, MuscleId.adductors, MuscleId.abs],
  ),
  'glute kickback': (
    primary: [MuscleId.gluteMax],
    secondary: [MuscleId.hamstrings],
  ),
  'tricep kickback': (
    primary: [MuscleId.triceps],
    secondary: [MuscleId.forearms],
  ),
  'leg curl': (
    primary: [MuscleId.hamstrings],
    secondary: [MuscleId.calves, MuscleId.gluteMax],
  ),
  'hamstring curl': (
    primary: [MuscleId.hamstrings],
    secondary: [MuscleId.calves, MuscleId.gluteMax],
  ),
  'bicep curl': (
    primary: [MuscleId.biceps],
    secondary: [MuscleId.brachialis, MuscleId.forearms],
  ),
  'preacher curl': (
    primary: [MuscleId.biceps],
    secondary: [MuscleId.brachialis, MuscleId.forearms],
  ),
  'hammer curl': (
    primary: [MuscleId.brachialis, MuscleId.biceps],
    secondary: [MuscleId.forearms],
  ),
  'upright row': (
    primary: [MuscleId.sideDelts],
    secondary: [MuscleId.upperTraps, MuscleId.biceps, MuscleId.forearms],
  ),
  'rear delt fly': (
    primary: [MuscleId.rearDelts],
    secondary: [
      MuscleId.rhomboids,
      MuscleId.midLowerTraps,
      MuscleId.rotatorCuff,
    ],
  ),
  'reverse fly': (
    primary: [MuscleId.rearDelts],
    secondary: [
      MuscleId.rhomboids,
      MuscleId.midLowerTraps,
      MuscleId.rotatorCuff,
    ],
  ),
  'chest fly': (
    primary: [MuscleId.midLowerChest],
    secondary: [MuscleId.frontDelts],
  ),
  'pec deck': (primary: [], secondary: []),
  'cable crossover': (primary: [], secondary: []),
  'lateral raise': (
    primary: [MuscleId.sideDelts],
    secondary: [MuscleId.upperTraps],
  ),
  'front raise': (
    primary: [MuscleId.frontDelts],
    secondary: [MuscleId.upperChest],
  ),
  'y raise': (primary: [MuscleId.sideDelts], secondary: [MuscleId.upperTraps]),
  'scaption raise': (
    primary: [MuscleId.sideDelts],
    secondary: [MuscleId.upperTraps],
  ),
  'leg extension': (
    primary: [MuscleId.quads],
    secondary: [MuscleId.hipFlexors],
  ),
  'back extension': (
    primary: [MuscleId.spinalErectors],
    secondary: [MuscleId.gluteMax, MuscleId.hamstrings],
  ),
  'tricep extension': (
    primary: [MuscleId.triceps],
    secondary: [MuscleId.forearms],
  ),
  'triceps extension': (
    primary: [MuscleId.triceps],
    secondary: [MuscleId.forearms],
  ),
  'lat pulldown': (
    primary: [MuscleId.lats],
    secondary: [
      MuscleId.biceps,
      MuscleId.brachialis,
      MuscleId.midLowerTraps,
      MuscleId.forearms,
    ],
  ),
  'pulldown': (
    primary: [MuscleId.lats],
    secondary: [
      MuscleId.biceps,
      MuscleId.brachialis,
      MuscleId.midLowerTraps,
      MuscleId.forearms,
    ],
  ),
  'pullover': (
    primary: [MuscleId.lats, MuscleId.midLowerChest],
    secondary: [MuscleId.triceps, MuscleId.abs],
  ),
  'pushdown': (primary: [MuscleId.triceps], secondary: [MuscleId.forearms]),
  'push up': (primary: [], secondary: []),
  'pushup': (primary: [], secondary: []),
  'push ups': (primary: [], secondary: []),
  'pushups': (primary: [], secondary: []),
  'pull up': (
    primary: [MuscleId.lats],
    secondary: [
      MuscleId.biceps,
      MuscleId.brachialis,
      MuscleId.midLowerTraps,
      MuscleId.forearms,
    ],
  ),
  'chin up': (
    primary: [MuscleId.lats, MuscleId.biceps],
    secondary: [MuscleId.brachialis, MuscleId.forearms],
  ),
  'deadlift': (
    primary: [MuscleId.hamstrings, MuscleId.gluteMax],
    secondary: [MuscleId.spinalErectors, MuscleId.adductors, MuscleId.forearms],
  ),
  'squat': (
    primary: [MuscleId.quads, MuscleId.gluteMax],
    secondary: [
      MuscleId.hamstrings,
      MuscleId.adductors,
      MuscleId.spinalErectors,
      MuscleId.abs,
    ],
  ),
  'lunge': (
    primary: [MuscleId.quads, MuscleId.gluteMax],
    secondary: [
      MuscleId.hamstrings,
      MuscleId.adductors,
      MuscleId.gluteMedMin,
      MuscleId.calves,
    ],
  ),
  'dip': (
    primary: [MuscleId.triceps],
    secondary: [MuscleId.midLowerChest, MuscleId.frontDelts],
  ),
  'shrug': (
    primary: [MuscleId.upperTraps],
    secondary: [MuscleId.forearms, MuscleId.neck],
  ),
  'crunch': (primary: [MuscleId.abs], secondary: [MuscleId.obliques]),
  'plank': (
    primary: [MuscleId.abs],
    secondary: [
      MuscleId.obliques,
      MuscleId.gluteMax,
      MuscleId.spinalErectors,
      MuscleId.serratusAnterior,
    ],
  ),
  'sit up': (primary: [MuscleId.abs], secondary: [MuscleId.hipFlexors]),
  'twist': (
    primary: [MuscleId.obliques],
    secondary: [MuscleId.abs, MuscleId.hipFlexors],
  ),
  'woodchopper': (
    primary: [MuscleId.obliques],
    secondary: [MuscleId.abs, MuscleId.serratusAnterior],
  ),
  'rotation': (
    primary: [MuscleId.obliques, MuscleId.spinalErectors],
    secondary: [MuscleId.rhomboids],
  ),
  'adduction': (primary: [MuscleId.adductors], secondary: []),
  'carry': (
    primary: [MuscleId.forearms, MuscleId.upperTraps],
    secondary: [
      MuscleId.abs,
      MuscleId.obliques,
      MuscleId.spinalErectors,
      MuscleId.calves,
    ],
  ),
  'row': (
    primary: [MuscleId.lats, MuscleId.midLowerTraps, MuscleId.rhomboids],
    secondary: [
      MuscleId.rearDelts,
      MuscleId.biceps,
      MuscleId.brachialis,
      MuscleId.spinalErectors,
      MuscleId.forearms,
    ],
  ),
  'curl': (
    primary: [MuscleId.biceps],
    secondary: [MuscleId.brachialis, MuscleId.forearms],
  ),
  'bench press': (primary: [], secondary: []),
  'chest press': (primary: [], secondary: []),
  'abduction': (primary: [], secondary: []),
  'press': (primary: [], secondary: []),
  'fly': (primary: [], secondary: []),
  'raise': (primary: [], secondary: []),
  'extension': (primary: [MuscleId.triceps], secondary: [MuscleId.forearms]),
  'thrust': (primary: [], secondary: []),
};

ExerciseMuscleSuggestion _dynamicSuggestionForMatch(
  String match,
  String exerciseName,
) {
  switch (match) {
    case 'bench press':
    case 'chest press':
    case 'press':
      return (
        primary: chestPrimaryMusclesFromExerciseName(exerciseName),
        secondary: {
          MuscleId.frontDelts,
          MuscleId.triceps,
          MuscleId.serratusAnterior,
        },
      );
    case 'fly':
    case 'pec deck':
    case 'cable crossover':
      return (
        primary: chestPrimaryMusclesFromExerciseName(exerciseName),
        secondary: {MuscleId.frontDelts},
      );
    case 'push up':
    case 'pushup':
    case 'push ups':
    case 'pushups':
      return (
        primary: chestPrimaryMusclesFromExerciseName(exerciseName),
        secondary: {
          MuscleId.frontDelts,
          MuscleId.triceps,
          MuscleId.serratusAnterior,
        },
      );
    case 'raise':
      return (
        primary: {shoulderMuscleFromExerciseName(exerciseName)},
        secondary: {MuscleId.upperTraps},
      );
    case 'abduction':
      return (
        primary: {gluteMuscleFromExerciseName(exerciseName)},
        secondary: {},
      );
    case 'thrust':
      return (
        primary: {gluteMuscleFromExerciseName(exerciseName)},
        secondary: {MuscleId.hamstrings, MuscleId.adductors, MuscleId.abs},
      );
  }

  final suggestion = _keywordSuggestions[match]!;
  final primary = suggestion.primary.toSet();
  final secondary = suggestion.secondary.toSet()..removeAll(primary);
  return (primary: primary, secondary: secondary);
}

ExerciseMuscleSuggestion suggestMuscles(String exerciseName) {
  final tokens = tokenizeExerciseName(exerciseName);
  final match = mostSpecificExercisePhraseMatch(
    tokens,
    _keywordSuggestions.keys,
  );
  if (match == null) {
    return (primary: <MuscleId>{}, secondary: <MuscleId>{});
  }

  return _dynamicSuggestionForMatch(match, exerciseName);
}

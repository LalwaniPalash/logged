import 'dart:convert';
import 'dart:io';

import 'package:logged/core/domain/exercise_muscle_name_rules.dart';
import 'package:logged/core/domain/exercise_muscle_suggestion.dart';
import 'package:logged/core/domain/exercise_name_matcher.dart';
import 'package:logged/core/domain/muscle.dart';

typedef Anatomy = ({List<MuscleId> primary, List<MuscleId> secondary});
typedef ReviewedRow = ({Anatomy anatomy, String family, String reason});

const _assetPath = 'assets/data/exercise_library.json';
const _changelogPath = 'MUSCLE_AUDIT_CHANGELOG.md';

void main(List<String> args) {
  final write = args.contains('--write');
  final baselineHead = args.contains('--baseline-head');
  final assetFile = File(_assetPath);
  final rows = (jsonDecode(assetFile.readAsStringSync()) as List<dynamic>)
      .cast<Map<String, dynamic>>();

  final updatedRows = <Map<String, dynamic>>[];
  final changes = <Map<String, Object?>>[];
  var suggestionMismatchCount = 0;
  for (final row in rows) {
    final currentPrimary = _decodeRowMuscles(row['primaryMuscles']);
    final currentSecondary = _decodeRowMuscles(row['secondaryMuscles']);
    final suggestion = suggestMuscles(row['name']! as String);
    if (suggestion.primary.isNotEmpty &&
        !_sameAnatomy(
          (
            primary: _dedupe(suggestion.primary.toList()),
            secondary: _dedupe(suggestion.secondary.toList()),
          ),
          currentPrimary,
          currentSecondary,
        )) {
      suggestionMismatchCount++;
    }
    final reviewed = _reviewRow(row);
    if (reviewed == null) {
      updatedRows.add(row);
      continue;
    }

    if (_sameAnatomy(reviewed.anatomy, currentPrimary, currentSecondary)) {
      updatedRows.add(row);
      continue;
    }

    updatedRows.add({
      ...row,
      'primaryMuscles': [
        for (final muscle in reviewed.anatomy.primary) muscle.id,
      ],
      'secondaryMuscles': [
        for (final muscle in reviewed.anatomy.secondary) muscle.id,
      ],
    });
    changes.add({
      'name': row['name'],
      'muscleGroup': row['muscleGroup'],
      'family': reviewed.family,
      'reason': reviewed.reason,
      'originalPrimary': [for (final muscle in currentPrimary) muscle.id],
      'originalSecondary': [for (final muscle in currentSecondary) muscle.id],
      'updatedPrimary': [
        for (final muscle in reviewed.anatomy.primary) muscle.id,
      ],
      'updatedSecondary': [
        for (final muscle in reviewed.anatomy.secondary) muscle.id,
      ],
    });
  }

  stdout.writeln('Reviewed ${rows.length} rows.');
  stdout.writeln('Proposed changes: ${changes.length}');
  stdout.writeln(
    'Current rows that disagree with suggestMuscles(): $suggestionMismatchCount',
  );
  final countsByGroup = <String, int>{};
  for (final change in changes) {
    final group = change['muscleGroup']! as String;
    countsByGroup.update(group, (count) => count + 1, ifAbsent: () => 1);
  }
  for (final entry
      in countsByGroup.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))) {
    stdout.writeln('${entry.key}: ${entry.value}');
  }

  if (!write) {
    for (final change in changes.take(40)) {
      stdout.writeln(
        '${change['name']} | '
        'P ${change['originalPrimary']} -> ${change['updatedPrimary']} | '
        'S ${change['originalSecondary']} -> ${change['updatedSecondary']} | '
        '${change['reason']}',
      );
    }
    return;
  }

  assetFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(updatedRows)}\n',
  );
  final changelogChanges = baselineHead
      ? _diffAgainstHead(updatedRows)
      : changes;
  File(_changelogPath).writeAsStringSync(
    _buildChangelog(changelogChanges, baselineHead: baselineHead),
  );
}

ReviewedRow? _reviewRow(Map<String, dynamic> row) {
  final name = row['name']! as String;
  final tokens = tokenizeExerciseName(name);

  return _reviewPushUps(name, tokens) ??
      _reviewChestPresses(name, tokens) ??
      _reviewChestFlyes(name, tokens) ??
      _reviewDips(name, tokens) ??
      _reviewShoulderPresses(name, tokens) ??
      _reviewShoulderRaises(name, tokens) ??
      _reviewRearDeltAndRotatorCuff(name, tokens) ??
      _reviewPulldownsAndPullUps(name, tokens) ??
      _reviewRows(name, tokens) ??
      _reviewShrugs(name, tokens) ??
      _reviewHipIsolation(name, tokens) ??
      _reviewLegExtensionsAndCurls(name, tokens) ??
      _reviewArmIsolations(name, tokens) ??
      _reviewGluteBridgeAndKickback(name, tokens) ??
      _reviewBackExtensions(name, tokens) ??
      _reviewDeadlifts(name, tokens) ??
      _reviewLungesAndStepUps(name, tokens) ??
      _reviewSquatsAndPresses(name, tokens) ??
      _reviewCore(name, tokens) ??
      _reviewCarries(name, tokens);
}

ReviewedRow? _reviewPushUps(String name, List<String> tokens) {
  if (!_matches(tokens, {
    'push up',
    'pushup',
    'push-up',
    'push ups',
    'pushups',
    'push-ups',
  })) {
    return null;
  }
  if (_matches(tokens, {
    'handstand push-up',
    'handstand pushup',
    'handstand push-ups',
    'handstand pushups',
    'handstand push ups',
  })) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.frontDelts, MuscleId.sideDelts],
        secondary: [
          MuscleId.triceps,
          MuscleId.upperTraps,
          MuscleId.serratusAnterior,
        ],
      ),
      family: 'Shoulders',
      reason:
          'Inverted handstand push-up mechanics are an overhead press, so the front and side delts share primary load.',
    );
  }
  if (_matches(tokens, {'scapular push-up', 'push-up plus'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.serratusAnterior],
        secondary: [
          MuscleId.midLowerChest,
          MuscleId.frontDelts,
          MuscleId.triceps,
        ],
      ),
      family: 'Chest',
      reason:
          'Scapular-only push-up variations primarily train serratus-driven protraction rather than chest pressing.',
    );
  }
  if (_matches(tokens, {
    'close-grip push-up',
    'close triceps position',
    'close-grip push-up off of a dumbbell',
    'deficit close-grip push-up',
  })) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.triceps],
        secondary: [
          ..._pushUpPrimary(name),
          MuscleId.frontDelts,
          MuscleId.serratusAnterior,
          if (_isUnstableOrUnilateralPushUp(tokens)) MuscleId.abs,
        ],
      ),
      family: 'Chest',
      reason:
          'Close-grip push-up variants shift the limiting joint action toward elbow extension, making triceps the primary driver.',
    );
  }
  return (
    anatomy: _anatomy(
      primary: _pushUpPrimary(name),
      secondary: [
        MuscleId.frontDelts,
        MuscleId.triceps,
        MuscleId.serratusAnterior,
        if (_matches(tokens, {'push up to side plank'})) MuscleId.obliques,
        if (_isUnstableOrUnilateralPushUp(tokens)) MuscleId.abs,
      ],
    ),
    family: 'Chest',
    reason:
        _matches(tokens, {'incline'}) ||
            _matches(tokens, {'decline', 'feet elevated'})
        ? 'Push-up angle names invert bench semantics: feet-elevated decline push-ups bias the upper chest, while hands-elevated incline push-ups stay mid/lower-chest dominant.'
        : 'Standard push-up variations remain chest-driven, with instability or unilateral demands adding core support without replacing chest as the prime mover.',
  );
}

ReviewedRow? _reviewChestPresses(String name, List<String> tokens) {
  if (_matches(tokens, {
    'close-grip bench press',
    'smith machine close-grip bench press',
    'decline close-grip bench to skull crusher',
    'reverse triceps bench press',
  })) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.triceps],
        secondary: [MuscleId.midLowerChest, MuscleId.frontDelts],
      ),
      family: 'Chest',
      reason:
          'Close-grip benching shortens shoulder horizontal adduction and makes elbow extension the main strength bottleneck.',
    );
  }
  if (!_matches(tokens, {'bench press', 'chest press'}) ||
      _matches(tokens, {
        'bench dip',
        'bench jump',
        'bench sprint',
        'bench pull',
        'wrist curl',
        'leg raise',
        'leg pull-in',
        'curl over incline bench',
      })) {
    return null;
  }

  final primary = _chestPrimary(name);
  if (_matches(tokens, {
    'reverse-grip bench press',
    'guillotine bench press',
  })) {
    primary
      ..clear()
      ..add(MuscleId.upperChest);
  }
  return (
    anatomy: _anatomy(
      primary: primary,
      secondary: [
        MuscleId.frontDelts,
        MuscleId.triceps,
        MuscleId.serratusAnterior,
      ],
    ),
    family: 'Chest',
    reason: primary.length == 2
        ? 'Generic cable or machine chest presses can bias clavicular or sternal fibers by seat or handle height, so both chest regions stay primary for the bias slider.'
        : 'Pressing angle or grip in the exercise name gives a specific chest emphasis, while front delts and triceps stay secondary press contributors.',
  );
}

ReviewedRow? _reviewChestFlyes(String name, List<String> tokens) {
  if (_matches(tokens, {
    'rear delt',
    'reverse fly',
    'reverse pec deck',
    'reverse machine fly',
    'rear lateral',
    'back flyes',
    'sled reverse flye',
  })) {
    return null;
  }
  if (!_matches(tokens, {
    'fly',
    'flye',
    'pec deck',
    'cable crossover',
    'low cable crossover',
    'single-arm cable crossover',
  })) {
    return null;
  }
  if (_matches(tokens, {'lying crossover'})) return null;

  final primary = _chestPrimary(name);
  final secondary = [
    MuscleId.frontDelts,
    if (_matches(tokens, {'bodyweight flyes'})) MuscleId.triceps,
    if (_matches(tokens, {'bodyweight flyes'})) MuscleId.abs,
  ];
  return (
    anatomy: _anatomy(primary: primary, secondary: secondary),
    family: 'Chest',
    reason: primary.length == 2
        ? 'Adjustable cable and pec-deck fly patterns can hit upper or mid/lower chest without renaming the exercise, so both chest regions stay primary.'
        : 'Named fly angle or fixed free-weight setup identifies one chest region, with the front delts only assisting shoulder positioning.',
  );
}

ReviewedRow? _reviewDips(String name, List<String> tokens) {
  if (_matches(tokens, {'jerk dip squat'})) return null;
  if (!_matches(tokens, {'dip', 'dips'})) return null;
  if (_matches(tokens, {'chest focus', 'ring dips'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.midLowerChest],
        secondary: [MuscleId.frontDelts, MuscleId.triceps, MuscleId.abs],
      ),
      family: 'Chest',
      reason:
          'Forward-leaning or ring-based chest-dip setups increase shoulder horizontal adduction demand and move the prime stress toward the pecs.',
    );
  }
  return (
    anatomy: _anatomy(
      primary: [MuscleId.triceps],
      secondary: [
        MuscleId.midLowerChest,
        MuscleId.frontDelts,
        if (_matches(tokens, {'dip'}) &&
            !_matches(tokens, {'machine tricep dip'}))
          MuscleId.abs,
      ],
    ),
    family: 'Chest',
    reason:
        'Triceps-focused and default dip patterns remain elbow-extension dominant, with chest and front delts assisting the compound press.',
  );
}

ReviewedRow? _reviewShoulderPresses(String name, List<String> tokens) {
  if (_matches(tokens, {
    'thruster',
    'squat-to-press',
    'clean & press',
    'press to',
  })) {
    return null;
  }
  if (!_matches(tokens, {
    'shoulder press',
    'overhead press',
    'military press',
    'arnold press',
    'landmine press',
  })) {
    return null;
  }
  return (
    anatomy: _anatomy(
      primary: [MuscleId.frontDelts, MuscleId.sideDelts],
      secondary: [
        MuscleId.triceps,
        MuscleId.upperChest,
        MuscleId.upperTraps,
        MuscleId.serratusAnterior,
      ],
    ),
    family: 'Shoulders',
    reason:
        'Overhead pressing trains both front and side delts as true co-primaries, while triceps and scapular upward rotators support lockout.',
  );
}

ReviewedRow? _reviewShoulderRaises(String name, List<String> tokens) {
  if (_matches(tokens, {'front raise', 'front delt raise', 'shoulder raise'}) &&
      !_matches(tokens, {'side', 'lateral', 'rear', 'y raise', 'w-raise'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.frontDelts],
        secondary: [MuscleId.upperChest],
      ),
      family: 'Shoulders',
      reason:
          'Front raise variations isolate shoulder flexion, which is front-delt dominant with only minor upper-chest assistance.',
    );
  }
  if (_matches(tokens, {
    'lateral raise',
    'side lateral raise',
    'side laterals',
    'single-arm cable raise',
    'bayesian lateral raise',
    'lean-away cable lateral raise',
    'standing low-pulley deltoid raise',
  })) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.sideDelts],
        secondary: [MuscleId.upperTraps],
      ),
      family: 'Shoulders',
      reason:
          'Lateral-raise patterns are shoulder-abduction isolations, so side delts stay primary while traps only assist scapular rotation.',
    );
  }
  if (_matches(tokens, {
    'y raise',
    'y-raise',
    'prone y-raise',
    'trap-3 raise',
  })) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.sideDelts],
        secondary: [
          MuscleId.midLowerTraps,
          MuscleId.rearDelts,
          MuscleId.rotatorCuff,
          MuscleId.upperTraps,
        ],
      ),
      family: 'Shoulders',
      reason:
          'Y-raise and trap-3 patterns are still abduction-driven shoulder raises, so side delts lead while lower-trap and cuff muscles stabilize the scapula.',
    );
  }
  if (_matches(tokens, {'scaption raise'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.sideDelts],
        secondary: [MuscleId.rotatorCuff, MuscleId.upperTraps],
      ),
      family: 'Shoulders',
      reason:
          'Scaption lives in the scapular plane but remains primarily a side-delt raise, with cuff muscles stabilizing the humerus.',
    );
  }
  return null;
}

ReviewedRow? _reviewRearDeltAndRotatorCuff(String name, List<String> tokens) {
  if (_matches(tokens, {'face pull'})) {
    return (
      anatomy: _anatomy(
        primary: [
          MuscleId.rearDelts,
          MuscleId.midLowerTraps,
          MuscleId.rhomboids,
        ],
        secondary: [MuscleId.rotatorCuff, MuscleId.upperTraps, MuscleId.biceps],
      ),
      family: 'Shoulders',
      reason:
          'Face pulls blend rear-delt shoulder horizontal abduction with scapular retraction, so rear delts, mid/lower traps, and rhomboids all contribute substantially.',
    );
  }
  if (_matches(tokens, {
    'rear delt',
    'rear-delt',
    'reverse fly',
    'reverse machine fly',
    'reverse pec deck',
    'back flyes',
    'rear lateral',
    'sled reverse flye',
  })) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.rearDelts],
        secondary: [
          MuscleId.rhomboids,
          MuscleId.midLowerTraps,
          MuscleId.rotatorCuff,
        ],
      ),
      family: 'Shoulders',
      reason:
          'Rear-delt fly patterns isolate horizontal abduction, with scapular retractors and the cuff supporting the shoulder position.',
    );
  }
  if (_matches(tokens, {'rear delt row', 'rear-delt row', 'rear-delt rows'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.rearDelts, MuscleId.rhomboids],
        secondary: [MuscleId.midLowerTraps, MuscleId.biceps, MuscleId.lats],
      ),
      family: 'Shoulders',
      reason:
          'Rear-delt row variants pull high and wide, so rear delts share the prime load with the retractors rather than the lats alone.',
    );
  }
  if (_matches(tokens, {'w-raise', 'w raise'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.rotatorCuff],
        secondary: [MuscleId.rearDelts, MuscleId.midLowerTraps],
      ),
      family: 'Shoulders',
      reason:
          'W-raise patterns add external rotation to the raise, so the cuff becomes the main target while rear delts and lower traps assist.',
    );
  }
  if (_matches(tokens, {'external rotation', 'internal rotation'})) {
    return (
      anatomy: _anatomy(primary: [MuscleId.rotatorCuff], secondary: []),
      family: 'Shoulders',
      reason:
          'Internal and external rotation drills are direct rotator-cuff work rather than generic shoulder pressing or raising.',
    );
  }
  if (tokens.contains('upright') && tokens.contains('row')) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.sideDelts],
        secondary: [
          MuscleId.upperTraps,
          MuscleId.biceps,
          MuscleId.forearms,
          if (_matches(tokens, {'one-arm', 'cable', 'smith machine'}))
            MuscleId.midLowerTraps,
        ],
      ),
      family: 'Shoulders',
      reason:
          'Upright rows combine shoulder abduction with scapular elevation, so side delts and upper traps share the prime load.',
    );
  }
  return null;
}

ReviewedRow? _reviewPulldownsAndPullUps(String name, List<String> tokens) {
  if (_matches(tokens, {'shrug', 'row', 'deadlift'})) return null;
  if (_matches(tokens, {'scapular pull-up'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.lats, MuscleId.midLowerTraps],
        secondary: [MuscleId.rhomboids, MuscleId.forearms],
      ),
      family: 'Back',
      reason:
          'Scapular pull-ups train depression and upward-control of the scapula without full elbow flexion, so lats and lower traps lead while biceps drop out.',
    );
  }
  if (_matches(tokens, {'chin-up', 'one arm chin-up'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.lats, MuscleId.biceps],
        secondary: [
          MuscleId.brachialis,
          MuscleId.forearms,
          MuscleId.midLowerTraps,
        ],
      ),
      family: 'Back',
      reason:
          'Supinated chin-up patterns increase elbow-flexor demand enough for biceps to share the prime load with the lats.',
    );
  }
  if (_matches(tokens, {
    'straight-arm pulldown',
    'rope straight-arm pulldown',
    'bayesian cable pullover',
  })) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.lats],
        secondary: [MuscleId.midLowerTraps, MuscleId.triceps, MuscleId.abs],
      ),
      family: 'Back',
      reason:
          'Straight-arm pulldown and cable-pullover patterns intentionally minimize elbow flexion, so biceps should not stay in the assistance list.',
    );
  }
  if (_matches(tokens, {'pullover'}) &&
      !_matches(tokens, {'front raise and pullover'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.lats, MuscleId.midLowerChest],
        secondary: [MuscleId.triceps, MuscleId.abs],
      ),
      family: 'Back',
      reason:
          'Pullover patterns bridge shoulder extension and adduction, so lats and chest share the main load while elbow flexors stay minimized.',
    );
  }
  if (!_matches(tokens, {'pulldown', 'pull-up', 'pull up'})) return null;

  if (_matches(tokens, {'wide-grip', 'behind the neck', 'behind-the-neck'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.lats],
        secondary: [
          MuscleId.midLowerTraps,
          MuscleId.rhomboids,
          MuscleId.biceps,
          MuscleId.brachialis,
          MuscleId.forearms,
        ],
      ),
      family: 'Back',
      reason:
          'Wide-grip and behind-the-neck pulldowns stay lat-dominant but bias scapular retraction more than close neutral-grip versions.',
    );
  }

  final primary = [MuscleId.lats];
  final secondary = [
    MuscleId.biceps,
    MuscleId.brachialis,
    MuscleId.midLowerTraps,
    MuscleId.forearms,
  ];
  if (_matches(tokens, {'pull-up', 'pull up', 'weighted pull ups'})) {
    return (
      anatomy: _anatomy(primary: primary, secondary: secondary),
      family: 'Back',
      reason:
          'Standard pull-up and pulldown patterns stay lat-dominant, with elbow flexors and lower traps supporting the vertical pull.',
    );
  }
  if (_matches(tokens, {'underhand', 'close-grip', 'neutral-grip', 'v-bar'})) {
    return (
      anatomy: _anatomy(primary: primary, secondary: secondary),
      family: 'Back',
      reason:
          'Close, neutral, and underhand vertical pulls keep the lats primary while making the elbow flexors especially relevant in secondary work.',
    );
  }
  return (
    anatomy: _anatomy(primary: primary, secondary: secondary),
    family: 'Back',
    reason:
        'Vertical pulling remains lat-led unless the name clearly signals a scapular-only or straight-arm isolation pattern.',
  );
}

ReviewedRow? _reviewRows(String name, List<String> tokens) {
  if (!_matches(tokens, {'row', 'rows'}) ||
      ((tokens.contains('upright') && tokens.contains('row')) ||
          _matches(tokens, {'rear delt row', 'rotational row'}))) {
    return null;
  }
  if (_matches(tokens, {'renegade row'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.lats, MuscleId.abs, MuscleId.obliques],
        secondary: [
          MuscleId.rearDelts,
          MuscleId.biceps,
          MuscleId.brachialis,
          MuscleId.triceps,
          MuscleId.frontDelts,
        ],
      ),
      family: 'Back',
      reason:
          'Renegade rows remain rows first, but the anti-rotation plank makes trunk bracing share the movement with the lats.',
    );
  }
  if (_matches(tokens, {'high row', 'high pulley row', 'row to neck'})) {
    return (
      anatomy: _anatomy(
        primary: [
          MuscleId.rearDelts,
          MuscleId.midLowerTraps,
          MuscleId.rhomboids,
        ],
        secondary: [
          MuscleId.lats,
          MuscleId.biceps,
          MuscleId.brachialis,
          MuscleId.forearms,
          MuscleId.upperTraps,
        ],
      ),
      family: 'Back',
      reason:
          'High-row paths pull the elbow higher and wider, shifting the emphasis toward rear delts and scapular retractors over low-row lat dominance.',
    );
  }

  final supported = _matches(tokens, {
    'chest-supported',
    'seal row',
    'lying t-bar row',
    'lying cambered barbell row',
    'prone incline row',
    'bench mid rows',
    'machine seated row',
    'cable seated row',
    'seated cable rows',
    'seated one-arm cable pulley rows',
    'inverted row',
    'suspended row',
    'sled row',
  });

  return (
    anatomy: _anatomy(
      primary: [MuscleId.lats, MuscleId.midLowerTraps, MuscleId.rhomboids],
      secondary: [
        MuscleId.rearDelts,
        MuscleId.biceps,
        MuscleId.brachialis,
        if (!supported) MuscleId.spinalErectors,
        MuscleId.forearms,
      ],
    ),
    family: 'Back',
    reason: supported
        ? 'Chest-supported, seal, seated, and suspension rows remove the lower-back stabilization demand, so spinal erectors should not stay in secondary.'
        : 'Unsupported rows share prime work between lats and scapular retractors, with erectors only assisting to hold torso position.',
  );
}

ReviewedRow? _reviewShrugs(String name, List<String> tokens) {
  if (!_matches(tokens, {'shrug'})) return null;
  return (
    anatomy: _anatomy(
      primary: [MuscleId.upperTraps],
      secondary: [
        MuscleId.forearms,
        if (_matches(tokens, {'behind the back', 'behind-the-back'}))
          MuscleId.rhomboids
        else
          MuscleId.neck,
      ],
    ),
    family: 'Back',
    reason:
        'Shrugs are upper-trap dominant, with grip always assisting and behind-the-back setups adding more scapular retraction than neck carryover.',
  );
}

ReviewedRow? _reviewHipIsolation(String name, List<String> tokens) {
  if (_matches(tokens, {'leg press'})) return null;
  if (_matches(tokens, {'adduction', 'adductions'})) {
    return (
      anatomy: _anatomy(primary: [MuscleId.adductors], secondary: []),
      family: 'Legs',
      reason:
          'Hip-adduction movements directly load the adductors; quads should not appear as the prime mover for those drills.',
    );
  }
  if (_matches(tokens, {'abduction', 'abductions'})) {
    return (
      anatomy: _anatomy(primary: [MuscleId.gluteMedMin], secondary: []),
      family: 'Legs',
      reason:
          'Hip-abduction drills train the glute med/min complex directly rather than the larger hip extensors.',
    );
  }
  return null;
}

ReviewedRow? _reviewLegExtensionsAndCurls(String name, List<String> tokens) {
  if (_matches(tokens, {'leg extension', 'leg extensions'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.quads],
        secondary: [MuscleId.hipFlexors],
      ),
      family: 'Legs',
      reason:
          'Knee-extension isolations are quadriceps work first, with hip flexors only assisting in the seated setup.',
    );
  }
  if (_matches(tokens, {
    'leg curl',
    'leg curls',
    'hamstring curl',
    'nordic curl',
    'nordic hamstring curl',
    'glute ham raise',
    'glute-ham raise',
  })) {
    final secondary = [
      MuscleId.calves,
      MuscleId.gluteMax,
      if (_matches(tokens, {'natural glute ham raise'}))
        MuscleId.spinalErectors,
    ];
    return (
      anatomy: _anatomy(primary: [MuscleId.hamstrings], secondary: secondary),
      family: 'Legs',
      reason:
          'Leg-curl and glute-ham patterns are knee-flexion dominant hamstring work, with calves and glutes assisting but not leading.',
    );
  }
  return null;
}

ReviewedRow? _reviewArmIsolations(String name, List<String> tokens) {
  if (_matches(tokens, {'jefferson curl'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.hamstrings, MuscleId.spinalErectors],
        secondary: [MuscleId.gluteMax],
      ),
      family: 'Hamstrings',
      reason:
          'Jefferson curls are loaded hamstring-lengthening hinges, with the spinal erectors and glutes supporting the rounded descent.',
    );
  }
  if (_matches(tokens, {'lower back curl'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.spinalErectors],
        secondary: [MuscleId.hamstrings, MuscleId.gluteMax],
      ),
      family: 'Back',
      reason:
          'Lower-back curls are spinal-extension work first, so the erectors should lead over the arm-curl family.',
    );
  }
  if (_matches(tokens, {'razor curl'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.hamstrings],
        secondary: [MuscleId.gluteMax, MuscleId.calves, MuscleId.abs],
      ),
      family: 'Hamstrings',
      reason:
          'Razor curls are a bodyweight knee-flexion hamstring drill, not an elbow-flexor curl despite the name.',
    );
  }
  if (_matches(tokens, {'finger curl', 'finger curls'})) {
    return (
      anatomy: _anatomy(primary: [MuscleId.forearms], secondary: []),
      family: 'Arms',
      reason:
          'Finger-curl work targets the forearm flexors and grip rather than the elbow-flexor muscles.',
    );
  }
  if (_matches(tokens, {'straight raises on incline bench'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.frontDelts],
        secondary: [MuscleId.upperChest],
      ),
      family: 'Shoulders',
      reason:
          'Straight raises on an incline bench are still shoulder-flexion work, so the front delts outrank the chest.',
    );
  }
  if (_matches(tokens, {'curl', 'curls'}) &&
      !_matches(tokens, {
        'leg curl',
        'hamstring curl',
        'wrist curl',
        'jefferson curl',
        'razor curl',
        'lower back curl',
      })) {
    if (_matches(tokens, {'hammer curl', 'rope hammer curl', 'hammer'})) {
      return (
        anatomy: _anatomy(
          primary: [MuscleId.brachialis, MuscleId.biceps],
          secondary: [MuscleId.forearms],
        ),
        family: 'Arms',
        reason:
            'Hammer-curl setups bias the brachialis and brachioradialis more than a supinated curl, while the biceps still assist strongly.',
      );
    }
    if (_matches(tokens, {'reverse curl', 'reverse curls', 'zottman'})) {
      return (
        anatomy: _anatomy(
          primary: [MuscleId.brachialis, MuscleId.forearms],
          secondary: [MuscleId.biceps],
        ),
        family: 'Arms',
        reason:
            'Pronated curl patterns shift the load away from the supinated biceps peak and toward the brachialis and forearm extensors.',
      );
    }
    return (
      anatomy: _anatomy(
        primary: [MuscleId.biceps],
        secondary: [MuscleId.brachialis, MuscleId.forearms],
      ),
      family: 'Arms',
      reason:
          'Curl variations that are not hamstring or wrist work remain elbow-flexor movements led by the biceps.',
    );
  }
  return null;
}

ReviewedRow? _reviewGluteBridgeAndKickback(String name, List<String> tokens) {
  if (_matches(tokens, {
    'hip thrust',
    'glute bridge',
    'butt lift',
    'kas glute bridge',
    'pelvic tilt into bridge',
    'physioball hip bridge',
    'single leg glute bridge',
  })) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.gluteMax],
        secondary: [
          MuscleId.hamstrings,
          MuscleId.adductors,
          if (_matches(tokens, {'single leg'})) MuscleId.gluteMedMin,
          MuscleId.abs,
        ],
      ),
      family: 'Legs',
      reason:
          'Bridge and thrust patterns are hip-extension dominant glute-max work, with hamstrings and trunk bracing assisting the lockout.',
    );
  }
  if (_matches(tokens, {
    'glute kickback',
    'cable glute kickback',
    'cable diagonal kickback',
    'one-legged cable kickback',
    'hip extension',
  })) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.gluteMax],
        secondary: [MuscleId.hamstrings],
      ),
      family: 'Legs',
      reason:
          'Kickback and hip-extension isolations load hip extension directly, making glute max the prime mover with hamstrings assisting.',
    );
  }
  return null;
}

ReviewedRow? _reviewBackExtensions(String name, List<String> tokens) {
  if (_matches(tokens, {
    '45 glute-biased back extension',
    '45° glute-biased back extension',
  })) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.gluteMax, MuscleId.hamstrings],
        secondary: [MuscleId.spinalErectors, MuscleId.abs],
      ),
      family: 'Legs',
      reason:
          'A glute-biased back-extension setup turns the hinge into hip-extension work, leaving the erectors as stabilizers instead of prime movers.',
    );
  }
  if (_matches(tokens, {
    '45 hamstring back extension',
    '45° hamstring back extension',
  })) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.hamstrings, MuscleId.gluteMax],
        secondary: [MuscleId.spinalErectors, MuscleId.abs],
      ),
      family: 'Legs',
      reason:
          'Hamstring-biased back extensions still hinge at the hip, so hamstrings and glutes drive the motion while the erectors hold posture.',
    );
  }
  if (_matches(tokens, {'reverse hyperextension'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.gluteMax, MuscleId.hamstrings],
        secondary: [MuscleId.spinalErectors],
      ),
      family: 'Legs',
      reason:
          'Reverse hyperextension is a hip-extension movement, so glutes and hamstrings should lead over spinal erectors.',
    );
  }
  if (_matches(tokens, {'back extension', 'hyperextensions'})) {
    return (
      anatomy: _anatomy(
        primary: [
          MuscleId.spinalErectors,
          MuscleId.gluteMax,
          MuscleId.hamstrings,
        ],
        secondary: [MuscleId.abs],
      ),
      family: 'Legs',
      reason:
          'Generic back extensions share the work between erectors and the hip extensors, while the trunk braces isometrically.',
    );
  }
  return null;
}

ReviewedRow? _reviewDeadlifts(String name, List<String> tokens) {
  if (!_matches(tokens, {
    'deadlift',
    'rdl',
    'romanian',
    'stiff-leg',
    'stiff-legged',
  })) {
    return null;
  }

  if (_matches(tokens, {'rack pull', 'rack pulls'})) {
    return (
      anatomy: _anatomy(
        primary: [
          MuscleId.spinalErectors,
          MuscleId.gluteMax,
          MuscleId.upperTraps,
        ],
        secondary: [MuscleId.hamstrings, MuscleId.lats, MuscleId.forearms],
      ),
      family: 'Back',
      reason:
          'Rack pulls shorten the knee and hip range enough that the erectors and traps move closer to the front of the exercise than in a full deadlift.',
    );
  }

  if (_matches(tokens, {'jefferson deadlift'})) {
    return (
      anatomy: _anatomy(
        primary: [
          MuscleId.quads,
          MuscleId.gluteMax,
          MuscleId.hamstrings,
          MuscleId.adductors,
        ],
        secondary: [
          MuscleId.spinalErectors,
          MuscleId.forearms,
          MuscleId.upperTraps,
          MuscleId.abs,
        ],
      ),
      family: 'Legs',
      reason:
          'Jefferson deadlifts use a wide staggered stance and demand both knee and hip extension, so quads and adductors belong with the hip extensors.',
    );
  }

  if (_matches(tokens, {
    'romanian',
    'rdl',
    'stiff-leg',
    'stiff-legged',
    'b-stance rdl',
    'single-leg rdl',
    'deficit rdl',
    'snatch-grip rdl',
    'zercher rdl',
    'jefferson rdl',
  })) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.hamstrings, MuscleId.gluteMax],
        secondary: [
          MuscleId.spinalErectors,
          if (!_matches(tokens, {'snatch-grip rdl'})) MuscleId.adductors,
          if (_matches(tokens, {'wide stance', 'sumo', 'jefferson'}))
            MuscleId.adductors,
          if (!_matches(tokens, {'bodyweight'})) MuscleId.forearms,
        ],
      ),
      family: 'Legs',
      reason:
          'RDL and stiff-leg hinges are hip-extension movements led by hamstrings and glute max, with erectors stabilizing rather than driving the lift.',
    );
  }

  if (_matches(tokens, {'trap bar deadlift'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.quads, MuscleId.gluteMax, MuscleId.hamstrings],
        secondary: [
          MuscleId.spinalErectors,
          MuscleId.forearms,
          MuscleId.upperTraps,
          MuscleId.abs,
        ],
      ),
      family: 'Legs',
      reason:
          'Trap-bar deadlifts blend squat and hinge mechanics, so quads join the hip extensors as primary contributors.',
    );
  }

  final hasWideOrSumo = _matches(tokens, {'sumo', 'wide stance', 'jefferson'});
  return (
    anatomy: _anatomy(
      primary: [MuscleId.hamstrings, MuscleId.gluteMax],
      secondary: [
        MuscleId.spinalErectors,
        if (hasWideOrSumo) MuscleId.adductors,
        MuscleId.quads,
        MuscleId.upperTraps,
        MuscleId.lats,
        MuscleId.forearms,
        MuscleId.abs,
      ],
    ),
    family: 'Legs',
    reason: hasWideOrSumo
        ? 'Wide-stance and sumo pulls still hinge through the hip extensors, but the wide setup recruits the adductors enough that they should appear in the anatomy.'
        : 'Conventional deadlifts remain hip-extension dominant, with erectors, traps, and lats stabilizing the bar path rather than replacing hamstrings and glutes as the prime movers.',
  );
}

ReviewedRow? _reviewSquatsAndPresses(String name, List<String> tokens) {
  if (_matches(tokens, {'leg press'})) {
    if (_matches(tokens, {'abduction bias'})) {
      return (
        anatomy: _anatomy(
          primary: [MuscleId.gluteMax, MuscleId.gluteMedMin],
          secondary: [MuscleId.quads, MuscleId.adductors],
        ),
        family: 'Legs',
        reason:
            'An explicit abduction-biased single-leg press shifts the lift toward the glutes and hip stabilizers rather than the usual quad-led default.',
      );
    }
    if (_matches(tokens, {'narrow stance', 'close stance'})) {
      return (
        anatomy: _anatomy(
          primary: [MuscleId.quads],
          secondary: [MuscleId.gluteMax, MuscleId.hamstrings, MuscleId.calves],
        ),
        family: 'Legs',
        reason:
            'A narrow leg-press stance shortens the hip contribution and makes the movement more quad-dominant than the default setup.',
      );
    }
    if (_matches(tokens, {'wide stance', 'abduction bias'})) {
      return (
        anatomy: _anatomy(
          primary: [MuscleId.quads, MuscleId.gluteMax],
          secondary: [MuscleId.adductors, MuscleId.hamstrings],
        ),
        family: 'Legs',
        reason:
            'Wide or abduction-biased leg-press setups keep quads and glutes primary while adding clear adductor involvement.',
      );
    }
    return (
      anatomy: _anatomy(
        primary: [MuscleId.quads, MuscleId.gluteMax],
        secondary: [MuscleId.hamstrings, MuscleId.adductors],
      ),
      family: 'Legs',
      reason:
          'Default leg-press mechanics vary by foot placement enough to justify both quads and glute max as primaries.',
    );
  }
  if (_matches(tokens, {'hack squat'})) {
    if (_matches(tokens, {'narrow stance', 'cyclist', 'heel-elevated'})) {
      return (
        anatomy: _anatomy(
          primary: [MuscleId.quads],
          secondary: [MuscleId.gluteMax, MuscleId.hamstrings, MuscleId.calves],
        ),
        family: 'Legs',
        reason:
            'Narrow and cyclist hack-squat setups push the knees further forward and make the movement more quad dominant.',
      );
    }
    if (_matches(tokens, {'wide stance'})) {
      return (
        anatomy: _anatomy(
          primary: [MuscleId.quads, MuscleId.gluteMax],
          secondary: [MuscleId.adductors, MuscleId.hamstrings],
        ),
        family: 'Legs',
        reason:
            'A wide hack-squat stance adds meaningful adductor recruitment without changing the main quad-and-glute drivers.',
      );
    }
    return (
      anatomy: _anatomy(
        primary: [MuscleId.quads, MuscleId.gluteMax],
        secondary: [MuscleId.hamstrings, MuscleId.adductors],
      ),
      family: 'Legs',
      reason:
          'Hack squats load both knee and hip extension heavily, so quads and glute max should share the primary slot.',
    );
  }
  if (!_matches(tokens, {'squat'})) return null;

  if (_matches(tokens, {'deep squat hold'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.adductors, MuscleId.gluteMax, MuscleId.quads],
        secondary: [MuscleId.calves, MuscleId.abs, MuscleId.spinalErectors],
      ),
      family: 'Legs',
      reason:
          'A deep squat hold is as much an adductor mobility and end-range hip position drill as it is a standard squat pattern.',
    );
  }
  if (_matches(tokens, {
    'cossack squat',
    'walking cossack squat',
    'zercher cossack squat',
    'lateral lunge',
    'lateral squat',
    'plie',
    'frog squat',
  })) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.adductors, MuscleId.gluteMax, MuscleId.quads],
        secondary: [MuscleId.hamstrings, MuscleId.gluteMedMin, MuscleId.calves],
      ),
      family: 'Legs',
      reason:
          'Lateral, plie, and Cossack patterns load hip adduction and frontal-plane control enough that the adductors need to appear up front.',
    );
  }
  if (_matches(tokens, {'curtsy squat'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.gluteMax, MuscleId.gluteMedMin],
        secondary: [MuscleId.quads, MuscleId.adductors, MuscleId.calves],
      ),
      family: 'Legs',
      reason:
          'Curtsy squats lean heavily on the glutes and hip stabilizers because the crossed stance increases frontal-plane control demands.',
    );
  }
  if (_matches(tokens, {'front squat', 'front squats'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.quads],
        secondary: [
          MuscleId.gluteMax,
          MuscleId.adductors,
          MuscleId.abs,
          MuscleId.spinalErectors,
        ],
      ),
      family: 'Legs',
      reason:
          'Front-squat torso mechanics bias knee extension, so quads stay primary while glutes and trunk muscles support the upright posture.',
    );
  }
  if (_matches(tokens, {'zercher squat', 'zercher squats'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.quads],
        secondary: [
          MuscleId.gluteMax,
          MuscleId.hamstrings,
          MuscleId.abs,
          MuscleId.spinalErectors,
        ],
      ),
      family: 'Legs',
      reason:
          'Zercher squats remain knee-extension dominant even though the front rack increases trunk demand and posterior-chain assistance.',
    );
  }
  if (_matches(tokens, {
    'narrow stance',
    'cyclist',
    'sissy squat',
    'spanish squat',
    'heel-elevated',
    'peterson step-up',
    'atg split squat',
  })) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.quads],
        secondary: [MuscleId.gluteMax, MuscleId.hamstrings, MuscleId.calves],
      ),
      family: 'Legs',
      reason:
          'Narrow or heels-elevated squat setups bias knee travel and lengthen the quads far more than the hip extensors.',
    );
  }
  if (_matches(tokens, {'wide stance', 'sumo', 'jefferson'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.quads, MuscleId.gluteMax],
        secondary: [
          MuscleId.hamstrings,
          MuscleId.adductors,
          MuscleId.spinalErectors,
          MuscleId.abs,
        ],
      ),
      family: 'Legs',
      reason:
          'Wide-stance squat patterns stay quad-and-glute driven but should explicitly carry adductors because the stance changes the hip demand.',
    );
  }
  if (_matches(tokens, {'single-leg squat'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.quads, MuscleId.gluteMax],
        secondary: [
          MuscleId.hamstrings,
          MuscleId.gluteMedMin,
          MuscleId.calves,
          MuscleId.abs,
        ],
      ),
      family: 'Legs',
      reason:
          'Single-leg squats keep the usual quad-and-glute drive but add meaningful hip-stability and balance work from glute med/min and the trunk.',
    );
  }
  return (
    anatomy: _anatomy(
      primary: [MuscleId.quads, MuscleId.gluteMax],
      secondary: [
        MuscleId.hamstrings,
        MuscleId.adductors,
        MuscleId.abs,
        if (_matches(tokens, {
          'barbell',
          'smith machine',
          'back squat',
          'box squat',
          'weighted squat',
          'squat with chains',
          'squat with bands',
        }))
          MuscleId.spinalErectors,
      ],
    ),
    family: 'Legs',
    reason:
        'Most squat patterns train both knee and hip extension enough for quads and glute max to share the primary slot.',
  );
}

ReviewedRow? _reviewLungesAndStepUps(String name, List<String> tokens) {
  if (!_matches(tokens, {'lunge', 'split squat', 'step-up', 'step up'})) {
    return null;
  }
  if (_matches(tokens, {'crossover', 'cross-body'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.quads, MuscleId.gluteMax],
        secondary: [
          MuscleId.hamstrings,
          MuscleId.adductors,
          MuscleId.gluteMedMin,
          MuscleId.calves,
          MuscleId.obliques,
        ],
      ),
      family: 'Legs',
      reason:
          'Cross-body lunge and step-up paths add frontal-plane control, so adductors and hip stabilizers join the usual quad-and-glute pattern.',
    );
  }
  return (
    anatomy: _anatomy(
      primary: [MuscleId.quads, MuscleId.gluteMax],
      secondary: [
        MuscleId.hamstrings,
        MuscleId.adductors,
        MuscleId.gluteMedMin,
        MuscleId.calves,
        if (_matches(tokens, {'knee raise'})) MuscleId.hipFlexors,
      ],
    ),
    family: 'Legs',
    reason:
        'Lunge, split-squat, and step-up patterns combine knee and hip extension, while adductors and hip stabilizers support single-leg balance.',
  );
}

ReviewedRow? _reviewCore(String name, List<String> tokens) {
  if (_matches(tokens, {'neck rotation'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.neck],
        secondary: [MuscleId.upperTraps],
      ),
      family: 'Core',
      reason:
          'Neck rotation drills are cervical work, not trunk-rotation exercises for the obliques.',
    );
  }
  if (_matches(tokens, {'landmine 180', 'landmine 180s', 'landmine 180 s'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.obliques, MuscleId.abs],
        secondary: [MuscleId.frontDelts, MuscleId.spinalErectors],
      ),
      family: 'Core',
      reason:
          'Landmine 180 patterns are rotational trunk drills first, so the obliques should share the lead with the abs.',
    );
  }
  if (_matches(tokens, {'rotation', 'rotational', 'twist', 'woodchopper'})) {
    if (_matches(tokens, {'thoracic rotation'})) {
      return (
        anatomy: _anatomy(
          primary: [MuscleId.obliques, MuscleId.spinalErectors],
          secondary: [MuscleId.rhomboids],
        ),
        family: 'Core',
        reason:
            'Thoracic rotation still centers on oblique-driven rotation, but the thoracic extensors contribute enough to stay alongside them.',
      );
    }
    if (_matches(tokens, {'pallof press with rotation'})) {
      return (
        anatomy: _anatomy(
          primary: [MuscleId.obliques],
          secondary: [MuscleId.abs, MuscleId.frontDelts, MuscleId.rotatorCuff],
        ),
        family: 'Core',
        reason:
            'Adding rotation to the Pallof pattern makes the obliques the main target, with the trunk and shoulder only supporting the anti-rotation task.',
      );
    }
    return (
      anatomy: _anatomy(
        primary: [MuscleId.obliques],
        secondary: [
          MuscleId.abs,
          if (_matches(tokens, {'landmine rotation'})) MuscleId.frontDelts,
          if (_matches(tokens, {'landmine rotation'})) MuscleId.spinalErectors,
          if (_matches(tokens, {'rotational row'})) MuscleId.lats,
          if (_matches(tokens, {'rotational row'})) MuscleId.rearDelts,
          if (_matches(tokens, {'rotational row'})) MuscleId.biceps,
        ],
      ),
      family: 'Core',
      reason:
          'Rotation and twist patterns are oblique-led unless the name clearly makes them a row or throw with other major prime movers.',
    );
  }
  if (_matches(tokens, {'pallof press'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.obliques],
        secondary: [MuscleId.abs, MuscleId.frontDelts],
      ),
      family: 'Core',
      reason:
          'Pallof pressing is an anti-rotation drill, so the obliques should lead over the abs-only crunch family.',
    );
  }
  if (_matches(tokens, {'plank', 'ab wheel', 'rollout', 'dead bug'})) {
    if (_matches(tokens, {'side plank'})) {
      return (
        anatomy: _anatomy(
          primary: [MuscleId.obliques],
          secondary: [
            MuscleId.abs,
            MuscleId.gluteMedMin,
            MuscleId.serratusAnterior,
          ],
        ),
        family: 'Core',
        reason:
            'Side planks are anti-lateral-flexion drills, so the obliques stay primary rather than the abs-only front-plank pattern.',
      );
    }
    if (_matches(tokens, {'copenhagen plank'})) {
      return (
        anatomy: _anatomy(
          primary: [MuscleId.adductors, MuscleId.obliques],
          secondary: [MuscleId.abs, MuscleId.gluteMedMin],
        ),
        family: 'Core',
        reason:
            'Copenhagen planks split the main load between the obliques and the adductors because the top leg holds a strong adduction isometric.',
      );
    }
    final primary = [MuscleId.abs];
    final secondary = [
      MuscleId.obliques,
      if (_matches(tokens, {'plank'})) MuscleId.gluteMax,
      if (_matches(tokens, {'plank'}) && !_matches(tokens, {'rkc plank'}))
        MuscleId.spinalErectors,
      if (_matches(tokens, {'plank'})) MuscleId.serratusAnterior,
      if (_matches(tokens, {'rkc plank'})) MuscleId.quads,
      if (_matches(tokens, {'dead bug'})) MuscleId.hipFlexors,
      if (_matches(tokens, {'dead bug'})) MuscleId.serratusAnterior,
      if (_matches(tokens, {'ab wheel', 'rollout'})) MuscleId.lats,
      if (_matches(tokens, {'ab wheel', 'rollout'})) MuscleId.frontDelts,
      if (_matches(tokens, {'ab wheel', 'rollout'})) MuscleId.serratusAnterior,
    ];
    return (
      anatomy: _anatomy(primary: primary, secondary: secondary),
      family: 'Core',
      reason:
          'Planks, rollouts, and dead bugs are anti-extension patterns, so the abs stay primary while obliques and other stabilizers assist.',
    );
  }
  if (_matches(tokens, {
    'crunch',
    'crunches',
    'sit-up',
    'sit-ups',
    'sit up',
    'reverse crunch',
  })) {
    if (_matches(tokens, {
      'bicycle crunch',
      'cross-body crunch',
      'bosu ball cable crunch with side bends',
      'kneeling cable crunch with alternating oblique twists',
    })) {
      return (
        anatomy: _anatomy(
          primary: [MuscleId.abs, MuscleId.obliques],
          secondary: [MuscleId.hipFlexors],
        ),
        family: 'Core',
        reason:
            'Crunch variations that add rotation or side-bending meaningfully load both rectus abdominis and the obliques.',
      );
    }
    if (_matches(tokens, {'oblique crunch'})) {
      return (
        anatomy: _anatomy(
          primary: [MuscleId.obliques],
          secondary: [MuscleId.abs],
        ),
        family: 'Core',
        reason:
            'Oblique-crunch variations add trunk rotation or side-bending, so the obliques should outrank the rectus-dominant crunch pattern.',
      );
    }
    final secondary = [
      if (_matches(tokens, {'sit-up', 'sit up', 'garhammer raise'}))
        MuscleId.hipFlexors,
      if (_matches(tokens, {'crunch'})) MuscleId.obliques,
    ];
    return (
      anatomy: _anatomy(primary: [MuscleId.abs], secondary: secondary),
      family: 'Core',
      reason:
          'Crunches and sit-up variations remain spinal-flexion drills led by the abs, with obliques or hip flexors only assisting depending on the pattern.',
    );
  }
  return null;
}

ReviewedRow? _reviewCarries(String name, List<String> tokens) {
  if (!_matches(tokens, {'carry'})) return null;
  if (_matches(tokens, {'sandbag carry'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.upperTraps, MuscleId.forearms, MuscleId.abs],
        secondary: [
          MuscleId.obliques,
          MuscleId.spinalErectors,
          MuscleId.gluteMax,
        ],
      ),
      family: 'Core',
      reason:
          'Front-loaded sandbag carries demand more anterior trunk bracing than a standard farmer carry, so the abs belong in the primary list.',
    );
  }
  if (_matches(tokens, {'suitcase carry', 'offset farmer carry'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.obliques, MuscleId.forearms],
        secondary: [
          MuscleId.upperTraps,
          MuscleId.abs,
          MuscleId.spinalErectors,
          MuscleId.calves,
        ],
      ),
      family: 'Core',
      reason:
          'Asymmetric carries are anti-lateral-flexion drills, so the loaded-side obliques share the prime work with the grip.',
    );
  }
  if (_matches(tokens, {'waiter'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.rotatorCuff, MuscleId.frontDelts],
        secondary: [
          MuscleId.upperTraps,
          MuscleId.abs,
          MuscleId.obliques,
          MuscleId.triceps,
        ],
      ),
      family: 'Core',
      reason:
          'A waiter carry is an overhead stability hold, so the cuff and front delts matter more than raw grip challenge.',
    );
  }
  if (_matches(tokens, {'bottom-up carry'})) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.forearms, MuscleId.rotatorCuff],
        secondary: [
          MuscleId.frontDelts,
          MuscleId.upperTraps,
          MuscleId.abs,
          MuscleId.obliques,
          MuscleId.triceps,
        ],
      ),
      family: 'Core',
      reason:
          'Bottom-up carries challenge grip and cuff stability first, with the rest of the trunk supporting the stacked position.',
    );
  }
  if (_matches(tokens, {'overhead carry'})) {
    return (
      anatomy: _anatomy(
        primary: [
          MuscleId.frontDelts,
          MuscleId.rotatorCuff,
          MuscleId.upperTraps,
        ],
        secondary: [
          MuscleId.abs,
          MuscleId.obliques,
          MuscleId.triceps,
          MuscleId.calves,
        ],
      ),
      family: 'Core',
      reason:
          'Overhead carries require the shoulder complex to hold the load first, while the trunk and legs stabilize the gait.',
    );
  }
  if (_matches(tokens, {
    'farmer carry',
    'dumbbell farmer carry',
    'sandbag carry',
  })) {
    return (
      anatomy: _anatomy(
        primary: [MuscleId.forearms, MuscleId.upperTraps],
        secondary: [
          MuscleId.abs,
          MuscleId.obliques,
          MuscleId.spinalErectors,
          MuscleId.calves,
          if (_matches(tokens, {'sandbag carry'})) MuscleId.gluteMax,
        ],
      ),
      family: 'Core',
      reason:
          'Symmetric loaded carries are grip-and-trap dominant while the trunk and gait muscles support the position.',
    );
  }
  return null;
}

List<MuscleId> _pushUpPrimary(String name) {
  final primary = _chestPrimary(name);
  if (primary.contains(MuscleId.midLowerChest) &&
      primary.contains(MuscleId.upperChest)) {
    return [MuscleId.midLowerChest, MuscleId.upperChest];
  }
  return primary;
}

List<MuscleId> _chestPrimary(String name) {
  final resolved = chestPrimaryMusclesFromExerciseName(name);
  if (resolved.contains(MuscleId.midLowerChest) &&
      resolved.contains(MuscleId.upperChest)) {
    return [MuscleId.midLowerChest, MuscleId.upperChest];
  }
  if (resolved.contains(MuscleId.upperChest)) {
    return [MuscleId.upperChest];
  }
  return [MuscleId.midLowerChest];
}

bool _isUnstableOrUnilateralPushUp(List<String> tokens) => _matches(tokens, {
  'single-arm',
  'ring push-up',
  'suspended push-up',
  'exercise ball',
  'bear crawl',
  'mechanical-advantage',
  'mechanical advantage',
  'deficit',
});

bool _matches(List<String> tokens, Iterable<String> phrases) =>
    mostSpecificExercisePhraseMatch(tokens, phrases) != null;

List<MuscleId> _decodeRowMuscles(Object? value) {
  final items = (value as List<dynamic>? ?? const <dynamic>[]);
  return [
    for (final item in items)
      if (item is String) MuscleId.fromId(item),
  ];
}

Anatomy _anatomy({
  required List<MuscleId> primary,
  required List<MuscleId> secondary,
}) {
  final dedupedPrimary = _dedupe(primary);
  final dedupedSecondary = [
    for (final muscle in _dedupe(secondary))
      if (!dedupedPrimary.contains(muscle)) muscle,
  ];
  validateMuscleSelection(primary: dedupedPrimary, secondary: dedupedSecondary);
  return (primary: dedupedPrimary, secondary: dedupedSecondary);
}

List<MuscleId> _dedupe(List<MuscleId> muscles) {
  final seen = <MuscleId>{};
  return [
    for (final muscle in muscles)
      if (seen.add(muscle)) muscle,
  ];
}

bool _sameAnatomy(
  Anatomy reviewed,
  List<MuscleId> originalPrimary,
  List<MuscleId> originalSecondary,
) {
  return _sameList(reviewed.primary, originalPrimary) &&
      _sameList(reviewed.secondary, originalSecondary);
}

bool _sameList(List<MuscleId> left, List<MuscleId> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

String _buildChangelog(
  List<Map<String, Object?>> changes, {
  bool baselineHead = false,
}) {
  final buffer = StringBuffer()
    ..writeln('# Muscle Audit Changelog')
    ..writeln()
    ..writeln(
      'Systematic content-correction pass over `assets/data/exercise_library.json`.',
    )
    ..writeln()
    ..writeln('- Total changed rows: ${changes.length}')
    ..writeln();

  if (baselineHead) {
    buffer
      ..writeln(
        'Baseline note: the working-tree asset was already dirty at task start, so this review file is diffed against `HEAD` anatomy for a complete reviewer-visible baseline.',
      )
      ..writeln();
  }

  final byGroup = <String, List<Map<String, Object?>>>{};
  for (final change in changes) {
    final group = change['muscleGroup']! as String;
    byGroup.putIfAbsent(group, () => []).add(change);
  }

  final groups = byGroup.keys.toList()
    ..sort((a, b) {
      final countCompare = byGroup[b]!.length.compareTo(byGroup[a]!.length);
      return countCompare != 0 ? countCompare : a.compareTo(b);
    });

  for (final group in groups) {
    final rows = byGroup[group]!
      ..sort((a, b) => (a['name']! as String).compareTo(b['name']! as String));
    buffer
      ..writeln('## ${_titleCase(group)} (${rows.length})')
      ..writeln();
    for (final change in rows) {
      buffer.writeln(
        '- ${change['name']}: '
        'primary ${change['originalPrimary']} -> ${change['updatedPrimary']}; '
        'secondary ${change['originalSecondary']} -> ${change['updatedSecondary']}. '
        '${change['reason']}',
      );
    }
    buffer.writeln();
  }

  return buffer.toString();
}

List<Map<String, Object?>> _diffAgainstHead(
  List<Map<String, dynamic>> currentRows,
) {
  final result = Process.runSync('git', ['show', 'HEAD:$_assetPath']);
  if (result.exitCode != 0 || result.stdout is! String) {
    throw StateError('Unable to load HEAD copy of $_assetPath for changelog.');
  }
  final headRows = (jsonDecode(result.stdout as String) as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final currentByName = {
    for (final row in currentRows) row['name']! as String: row,
  };

  final changes = <Map<String, Object?>>[];
  for (final base in headRows) {
    final name = base['name']! as String;
    final current = currentByName[name];
    if (current == null) continue;
    final basePrimary = _decodeRowMuscles(base['primaryMuscles']);
    final baseSecondary = _decodeRowMuscles(base['secondaryMuscles']);
    final currentPrimary = _decodeRowMuscles(current['primaryMuscles']);
    final currentSecondary = _decodeRowMuscles(current['secondaryMuscles']);
    if (_sameList(basePrimary, currentPrimary) &&
        _sameList(baseSecondary, currentSecondary)) {
      continue;
    }
    final reviewed = _reviewRow(current);
    changes.add({
      'name': name,
      'muscleGroup': current['muscleGroup'],
      'family': reviewed?.family ?? current['muscleGroup'],
      'reason': reviewed?.reason ?? 'Exercise anatomy corrected during audit.',
      'originalPrimary': [for (final muscle in basePrimary) muscle.id],
      'originalSecondary': [for (final muscle in baseSecondary) muscle.id],
      'updatedPrimary': [for (final muscle in currentPrimary) muscle.id],
      'updatedSecondary': [for (final muscle in currentSecondary) muscle.id],
    });
  }
  return changes;
}

String _titleCase(String input) => input
    .split('/')
    .map(
      (chunk) => chunk
          .split(' ')
          .map(
            (word) => word.isEmpty
                ? word
                : '${word[0].toUpperCase()}${word.substring(1)}',
          )
          .join(' '),
    )
    .join(' / ');

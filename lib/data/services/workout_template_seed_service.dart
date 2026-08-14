import 'package:drift/drift.dart';

import '../database/app_database.dart';

class WorkoutTemplateSeedService {
  const WorkoutTemplateSeedService(this._database);

  final AppDatabase _database;

  /// Bumped whenever [_templates] changes so existing installs pick up the
  /// new prescriptions on next launch (seeding is otherwise insert-only —
  /// see [_shouldRefreshDefaultTemplate]).
  static const _templatePlanVersion = 'v8';
  static const _templatePlanVersionKey = 'templatePlanVersion';

  static final List<_TemplateSeed> _templates = [
    _TemplateSeed('Monday — Push A', [
      _p(
        'Barbell Bench Press',
        4,
        5,
        8,
        180,
        'Tempo 3-1-1-0 · challenging 5–8RM — you hit 55 kg×8 on Aug 6',
      ),
      _p(
        'Pec Deck',
        2,
        10,
        15,
        75,
        'Highest angle · tempo 2-0-1-1 · ~27 kg · full stretch, squeeze 1s',
      ),
      _p(
        'Cable Crossover - Low Pulley',
        2,
        12,
        15,
        75,
        'Low-to-high · tempo 2-0-1-1 · 8–11 kg/side · targets lower sternal fibres',
      ),
      _p(
        'Barbell Overhead Press',
        4,
        6,
        8,
        150,
        'Tempo 2-1-1-0 · challenging 6–8RM · no barbell OHP logged yet — let week 1 set the real number (~30–35 kg first guess)',
      ),
      _p(
        'Dumbbell Lateral Raise',
        2,
        15,
        20,
        60,
        'Strict · tempo 3-0-1-0 · 4.5–6 kg/hand',
      ),
      _p(
        'Lean-Away Cable Lateral Raise',
        2,
        15,
        20,
        60,
        'Bayesian — lean away from the stack · tempo 2-0-1-2 · 5–7.5 kg',
      ),
      _p(
        'JM Press',
        3,
        8,
        10,
        120,
        'Tempo 2-1-1-0 · start bar + 5–10 kg/side, learn the bar path light first',
      ),
      _p(
        'Tate Press',
        2,
        10,
        15,
        75,
        'Elbows flared out to the sides · tempo 2-1-1-0 · 8–12 kg/hand',
      ),
      _p(
        'Cable Pullover',
        2,
        10,
        15,
        75,
        'Or Dumbbell Pullover · tempo 3-0-1-1 · 10–15 kg cable (12–16 kg single DB) · elbows nearly locked, deep lat/rib stretch',
      ),
      _p(
        'Cable Serratus Punch',
        2,
        12,
        15,
        45,
        'Or Push-Up Plus · tempo 2-0-2-0 · light, 5–10 kg · extra protraction at full extension',
      ),
      _p(
        'Face Pull',
        2,
        15,
        20,
        60,
        'Cable rope · tempo 2-0-1-2 · 20–32 kg — closes the Push A rear-delt gap',
      ),
      _p(
        'External Rotation with Cable',
        2,
        12,
        15,
        45,
        'Elbow pinned to ribs · tempo 2-0-2-0 · 2.5–5 kg — stays light permanently, never to failure',
      ),
      _p('Dead Bug', 3, 8, null, 60, '8/side · tempo 3-1-3-0 · bodyweight'),
      _p('Hanging Knee Raise', 3, 12, 15, 60, 'Tempo 2-0-1-1 · bodyweight'),
      ..._pushStretches,
    ]),
    _TemplateSeed('Tuesday — Pull A', [
      _p(
        'T-Bar Row',
        4,
        6,
        8,
        180,
        'Landmine row · tempo 2-1-1-0 · challenging 6–8RM — you\'re at 50 kg×8, near the old ceiling',
      ),
      _p(
        'Wide-Grip Lat Pulldown',
        3,
        10,
        15,
        120,
        'Wide overhand · tempo 2-1-1-0 · 35–45 kg — depress scapulae before pulling',
      ),
      _p(
        'Straight-Arm Pulldown',
        2,
        12,
        15,
        75,
        'Tempo 2-0-1-1 · 20–30 kg · the only lat exercise with zero bicep involvement',
      ),
      _p(
        'Reverse Pec Deck',
        3,
        10,
        15,
        75,
        'Rear delt machine · tempo 2-0-1-2 · 18–22 kg · 2s hold at full extension',
      ),
      _p('Face Pull', 2, 15, 20, 60, 'Cable rope · tempo 2-0-1-2 · 20–32 kg'),
      _p(
        'Spider Curl',
        2,
        10,
        14,
        75,
        'Incline bench, face-down · tempo 2-0-2-0 · 10–14 kg total — strictest curl, no body English possible',
      ),
      _p('Incline Dumbbell Curl', 2, 10, 12, 75, 'Tempo 2-0-1-1 · 6–9 kg/hand'),
      _p(
        'Bird Dog',
        2,
        8,
        null,
        45,
        '8/side · 2s hold each rep · bodyweight — never to failure, stop when form breaks',
      ),
      _duration(
        'Stationary Bike',
        1,
        20 * 60,
        null,
        'Zone 2 · HR 99–118 bpm · 25 min from week 4',
      ),
      ..._pullStretches,
    ]),
    _TemplateSeed('Wednesday — Legs A', [
      _p(
        'Barbell Back Squat',
        4,
        5,
        8,
        180,
        '"Week A" · tempo 3-1-1-0 · challenging 5–8RM — alternates weekly with Zercher Squat (swap manually every other week)',
      ),
      _p(
        'Nordic Hamstring Curl',
        2,
        5,
        null,
        120,
        'As slow as controllable · bodyweight, hand-assisted at the bottom for the first 4–6 weeks — never to failure, ~50% hamstring injury risk reduction',
      ),
      _p(
        'Barbell Romanian Deadlift',
        4,
        8,
        10,
        120,
        '"Week A" · tempo 3-0-1-0 · 40–70 kg — alternates weekly with B-Stance RDL (swap manually every other week)',
      ),
      _p(
        'Cossack Squat',
        3,
        8,
        10,
        90,
        'Bodyweight to start, progress to a goblet-held dumbbell · tempo 3-1-1-0 · 8–10/side',
      ),
      _p(
        'Hip Airplane',
        2,
        6,
        8,
        60,
        'Slow and controlled · bodyweight · 6–8/side — single-leg hip control',
      ),
      _p(
        'Leg Press',
        3,
        10,
        12,
        90,
        'Bilateral · tempo 3-1-1-0 · 140–190 kg — knee to 90° max, no deeper on the operated side',
      ),
      _p(
        'Leg Extension',
        2,
        12,
        15,
        75,
        'Tempo 2-0-1-2 · 75–85 kg · 2s hold at full extension',
      ),
      _p(
        'Copenhagen Plank',
        2,
        null,
        null,
        45,
        '20–30s/side static hold · bent-knee first, progress to straight-leg · bodyweight',
      ),
      _p(
        'Tibialis Anterior Raise',
        3,
        15,
        20,
        60,
        'Cable, low pulley · tempo 2-0-1-2 · 18–36 kg',
      ),
      _p(
        'Standing Calf Raise',
        3,
        10,
        15,
        60,
        'Hack squat machine · tempo 2-1-2-1 · knees near-locked, full stretch at bottom',
      ),
      _p(
        'Ab Wheel Rollout',
        3,
        8,
        12,
        75,
        'From knees · tempo 3-1-1-0 · bodyweight',
      ),
      ..._legStretches,
    ]),
    _TemplateSeed('Thursday — Push B', [
      _p(
        'Incline Dumbbell Press',
        3,
        10,
        15,
        120,
        '45° · tempo 3-0-1-0 · ~16 kg/hand',
      ),
      _p(
        'Dumbbell Decline Bench Press',
        3,
        10,
        15,
        90,
        'Tempo 3-0-1-0 · 12–16 kg/hand — or barbell decline ~35 kg, interchangeable',
      ),
      _p(
        'Cable Crossover - Mid Pulley',
        2,
        12,
        15,
        75,
        'Standing, both pulleys at chest height · tempo 2-0-1-2 · 7.5–10 kg/side · peaks at midline',
      ),
      _p(
        'Pec Deck',
        2,
        10,
        15,
        75,
        'Flat setting · tempo 2-0-1-1 · 25–30 kg · peaks at stretch',
      ),
      _p('Arnold Press', 3, 10, 15, 90, 'Tempo 2-0-1-0 · ~18 kg/hand'),
      _p(
        'Dumbbell Lateral Raise',
        2,
        15,
        20,
        60,
        'Strict · tempo 3-0-1-0 · 4.5–6 kg/hand — second weekly hit',
      ),
      _p('Face Pull', 2, 15, 20, 60, 'Cable rope · tempo 2-0-1-2 · 20–32 kg'),
      _p(
        'Cable Y-Raise',
        2,
        12,
        15,
        60,
        'Incline bench, face-down, thumbs up · tempo 2-0-1-1 · 2–4 kg/hand, dead light — lower-trap posture work',
      ),
      _p(
        'PJR Pullover',
        2,
        10,
        15,
        75,
        'Tempo 3-1-1-0 · 10–14 kg single DB — triceps long head at deepest stretch, upper arms stay still',
      ),
      _p(
        'Cable Tricep Pushdown',
        2,
        12,
        15,
        75,
        'Straight bar · tempo 2-0-1-2 · 20–30 kg — lateral + medial heads',
      ),
      _p(
        'Pallof Press',
        3,
        10,
        null,
        60,
        'Seated cable · 10/side · tempo 2-2-2-0 · 10–15 kg',
      ),
      _p(
        'Paused Bottom-Half Dumbbell Press',
        2,
        8,
        null,
        75,
        'Shoulder weak point · tempo 2-2-1-0 · 50–60% of Arnold press working weight — run after Arnold press',
      ),
      ..._pushStretches,
    ]),
    _TemplateSeed('Friday — Pull B', [
      _p(
        'Barbell Deadlift',
        4,
        3,
        5,
        210,
        'Conventional · plus 1 warm-up @ 60% · tempo 1-0-1-0 · challenging 3–5RM — you pulled 110 kg×2 on Aug 7, true working weight is likely ~95–102 kg now',
      ),
      _p(
        'Neutral-Grip Lat Pulldown',
        3,
        10,
        15,
        120,
        'Close neutral grip · tempo 2-1-1-0 · 37–47 kg — wide overhand (Tue) + close neutral (Fri) = complete lat development',
      ),
      _p(
        'Chest-Supported Row',
        3,
        10,
        12,
        90,
        'Incline DB row, wide elbows · tempo 2-0-1-1 · 10–16 kg/hand',
      ),
      _p(
        'Meadows Row',
        3,
        10,
        12,
        90,
        'Landmine, 10–12/side, finish one side then switch · tempo 2-0-1-1 · start ~20–30 kg — heaviest at the bottom stretch',
      ),
      _p(
        'Kelso Shrug',
        2,
        12,
        15,
        60,
        'Pull shoulder blades back and together, not up · tempo 2-0-2-0 · 10–16 kg/hand',
      ),
      _p(
        'Reverse Pec Deck',
        3,
        10,
        15,
        75,
        'Rear delt machine · tempo 2-0-1-2 · 18–22 kg — fourth weekly rear-delt session',
      ),
      _p(
        'Side Plank',
        2,
        null,
        null,
        45,
        '30–45s/side static hold · bodyweight — stop when form breaks, don\'t grind to failure',
      ),
      _p(
        'EZ-Bar Preacher Curl',
        2,
        10,
        12,
        75,
        'Tempo 2-0-1-2 · 15–16 kg EZ bar',
      ),
      _p(
        'Hammer Curl',
        2,
        12,
        null,
        60,
        '12/side alternating · tempo 2-0-1-0 · 8–14 kg/hand',
      ),
      _p(
        'Suitcase Carry',
        3,
        null,
        null,
        90,
        'Static hold version · 30–40s/side · heaviest DB you can hold without your torso tilting toward the weight',
      ),
      _duration(
        'Stationary Bike',
        1,
        20 * 60,
        null,
        'Zone 2 · HR 99–118 bpm · 25 min from week 4',
      ),
      ..._pullStretches,
    ]),
    _TemplateSeed('Saturday — Legs B', [
      _p(
        'Leg Press',
        4,
        10,
        12,
        120,
        'Bilateral · tempo 3-1-1-0 · 140–190 kg — heavier than Wednesday, you\'re warmer and deadlift isn\'t ahead of you',
      ),
      _p(
        'ATG Split Squat',
        3,
        8,
        10,
        120,
        'Replaces Bulgarian split squat · tempo 3-1-1-0 · 8–10/side · start at your current Bulgarian load (~9 kg/hand), moderate depth — weeks 1–4 are depth-finding, not load-finding',
      ),
      _p(
        'Cossack Squat',
        3,
        8,
        10,
        90,
        'Tempo 3-1-1-0 · 8–10/side — second weekly frontal-plane hip session, progress load from Wednesday',
      ),
      _p(
        'Reverse Nordic',
        2,
        8,
        10,
        60,
        'The lengthened-position quad exercise the programme was missing · as slow as controllable · bodyweight',
      ),
      _p(
        'Poliquin Step-Up',
        2,
        10,
        12,
        75,
        'Heel-elevated reverse step-up on a box · tempo 2-1-1-0 · 10–12/side · light DBs or bodyweight, free leg never bears weight',
      ),
      _p(
        'Lying Leg Curl',
        2,
        10,
        12,
        75,
        'Tempo 2-0-1-2 · 45–60 kg · 2s hold at full contraction',
      ),
      _p(
        'Leg Extension',
        2,
        12,
        15,
        75,
        'Tempo 2-0-1-2 · 75–85 kg — second weekly quad isolation hit, progress from Wednesday',
      ),
      _p(
        'Spanish Squat',
        3,
        12,
        15,
        90,
        'Best-evidenced patellar tendon exercise, no elastic band needed · tempo 3-1-1-0 · bodyweight to start, hold a light-moderate DB/plate at chest once easy',
      ),
      _p(
        'Tibialis Anterior Raise',
        3,
        15,
        20,
        60,
        'Cable, low pulley · tempo 2-0-1-2 · 18–36 kg — second weekly hit, progress from Wednesday',
      ),
      _p(
        'Seated Calf Raise',
        3,
        10,
        15,
        60,
        'Barbell on knees · tempo 2-1-2-1 · 20–36 kg',
      ),
      _p(
        'Hanging Leg Raise',
        3,
        8,
        12,
        75,
        'Straight-leg raise, or lying leg raise if grip/shoulder is the limiter · tempo 2-0-1-1 · bodyweight',
      ),
      _p(
        'Plank',
        3,
        null,
        null,
        90,
        'Forearm plank · max hold to form failure · bodyweight — log time every set, beat last week',
      ),
      ..._legStretches,
    ]),
  ];

  /// Post-workout stretching (unchanged from v7): the hip flexor stretch runs
  /// every training day, the rest vary by day type per the plan's stretching
  /// table — Push/Pull/Legs each get a different subset, not all six.
  static const _hipFlexorStretch = _PrescriptionSeed(
    'Hip Flexor Stretch',
    targetSets: 1,
    sidesPerSet: 2,
    targetDurationSec: 40,
    prescriptionNotes: '40s each side — reduces anterior pelvic tilt',
  );
  static const _doorwayChestStretch = _PrescriptionSeed(
    'Doorway Chest Stretch',
    targetSets: 1,
    targetDurationSec: 40,
    prescriptionNotes:
        '40s · doorway or wall — counters internal rotation from pressing volume',
  );
  static const _hamstringStretch = _PrescriptionSeed(
    'Hamstring Stretch',
    targetSets: 1,
    sidesPerSet: 2,
    targetDurationSec: 40,
    prescriptionNotes:
        '40s/side · standing on bench — post-RDL/squat maintenance',
  );
  static const _calfStretch = _PrescriptionSeed(
    'Standing Calf Stretch',
    targetSets: 1,
    sidesPerSet: 2,
    targetDurationSec: 40,
    prescriptionNotes:
        '40s/side · step edge — maintains dorsiflexion for squat depth',
  );
  static const _shoulderStretch = _PrescriptionSeed(
    'Cross-Body Shoulder Stretch',
    targetSets: 1,
    sidesPerSet: 2,
    targetDurationSec: 30,
    prescriptionNotes: '30s/side — rear delt/posterior capsule maintenance',
  );
  static const _hip9090Stretch = _PrescriptionSeed(
    '90/90 Hip Switch',
    targetSets: 1,
    sidesPerSet: 2,
    targetDurationSec: 45,
    prescriptionNotes: '45s/side — hip rotation for squat mechanics',
  );

  static const List<_PrescriptionSeed> _pushStretches = [
    _hipFlexorStretch,
    _doorwayChestStretch,
    _shoulderStretch,
  ];
  static const List<_PrescriptionSeed> _pullStretches = [
    _hipFlexorStretch,
    _hamstringStretch,
    _shoulderStretch,
  ];
  static const List<_PrescriptionSeed> _legStretches = [
    _hipFlexorStretch,
    _hamstringStretch,
    _calfStretch,
    _hip9090Stretch,
  ];

  Future<void> seedIfEmpty() async {
    final existingTemplates = await _database.select(_database.templates).get();

    final exerciseRows = await _database.select(_database.exercises).get();
    final exerciseIds = {
      for (final exercise in exerciseRows) exercise.name: exercise.id,
    };

    final storedVersion =
        await (_database.select(_database.appSettings)
              ..where((row) => row.key.equals(_templatePlanVersionKey)))
            .getSingleOrNull();
    final needsPlanUpgrade = storedVersion?.value != _templatePlanVersion;

    await _database.transaction(() async {
      for (
        var templateIndex = 0;
        templateIndex < _templates.length;
        templateIndex++
      ) {
        final template = _templates[templateIndex];
        final existingTemplate = existingTemplates
            .where((row) => row.name == template.name)
            .firstOrNull;
        final templateId =
            existingTemplate?.id ??
            await _database
                .into(_database.templates)
                .insert(
                  TemplatesCompanion.insert(
                    name: template.name,
                    position: templateIndex,
                  ),
                );

        if (existingTemplate != null &&
            !needsPlanUpgrade &&
            !await _shouldRefreshDefaultTemplate(existingTemplate.id)) {
          continue;
        }

        await _replaceTemplateExercises(
          templateId: templateId,
          template: template,
          exerciseIds: exerciseIds,
        );
      }

      if (needsPlanUpgrade) {
        await _database
            .into(_database.appSettings)
            .insertOnConflictUpdate(
              AppSettingsCompanion.insert(
                key: _templatePlanVersionKey,
                value: _templatePlanVersion,
              ),
            );
      }
    });
  }

  Future<bool> _shouldRefreshDefaultTemplate(int templateId) async {
    final rows = await (_database.select(
      _database.templateExercises,
    )..where((row) => row.templateId.equals(templateId))).get();
    if (rows.isEmpty) return true;

    final hasAnyPrescription = rows.any(
      (row) =>
          row.targetSets != null ||
          row.minReps != null ||
          row.maxReps != null ||
          row.targetDurationSec != null ||
          row.targetDistanceMeters != null ||
          row.restSeconds != null ||
          row.sidesPerSet != null ||
          row.eccentricSec != null ||
          row.bottomPauseSec != null ||
          row.concentricSec != null ||
          row.topPauseSec != null ||
          row.prescriptionNotes != null ||
          row.formUrl != null,
    );
    return !hasAnyPrescription;
  }

  Future<void> _replaceTemplateExercises({
    required int templateId,
    required _TemplateSeed template,
    required Map<String, int> exerciseIds,
  }) async {
    await (_database.delete(
      _database.templateExercises,
    )..where((row) => row.templateId.equals(templateId))).go();
    await _database.batch((batch) {
      batch.insertAll(_database.templateExercises, [
        for (
          var exerciseIndex = 0;
          exerciseIndex < template.exercises.length;
          exerciseIndex++
        )
          if (exerciseIds[template.exercises[exerciseIndex].exerciseName] !=
              null)
            template.exercises[exerciseIndex].toCompanion(
              templateId: templateId,
              exerciseId:
                  exerciseIds[template.exercises[exerciseIndex].exerciseName]!,
              position: exerciseIndex,
            ),
      ]);
    });
  }
}

class _TemplateSeed {
  const _TemplateSeed(this.name, this.exercises);
  final String name;
  final List<_PrescriptionSeed> exercises;
}

class _PrescriptionSeed {
  const _PrescriptionSeed(
    this.exerciseName, {
    this.targetSets,
    this.sidesPerSet,
    this.minReps,
    this.maxReps,
    this.targetDurationSec,
    this.restSeconds,
    this.eccentricSec,
    this.bottomPauseSec,
    this.concentricSec,
    this.topPauseSec,
    this.prescriptionNotes,
  });

  final String exerciseName;
  final int? targetSets;
  final int? sidesPerSet;
  final int? minReps;
  final int? maxReps;
  final int? targetDurationSec;
  final int? restSeconds;
  final int? eccentricSec;
  final int? bottomPauseSec;
  final int? concentricSec;
  final int? topPauseSec;
  final String? prescriptionNotes;

  TemplateExercisesCompanion toCompanion({
    required int templateId,
    required int exerciseId,
    required int position,
  }) => TemplateExercisesCompanion.insert(
    templateId: templateId,
    exerciseId: exerciseId,
    position: position,
    targetSets: Value(targetSets),
    sidesPerSet: Value(sidesPerSet),
    minReps: Value(minReps),
    maxReps: Value(maxReps),
    targetDurationSec: Value(targetDurationSec),
    targetDistanceMeters: const Value(null),
    restSeconds: Value(restSeconds),
    eccentricSec: Value(eccentricSec),
    bottomPauseSec: Value(bottomPauseSec),
    concentricSec: Value(concentricSec),
    topPauseSec: Value(topPauseSec),
    prescriptionNotes: Value(prescriptionNotes),
    formUrl: const Value(null),
  );
}

/// Number of sides one set covers, read from the prescription note.
///
/// "8/side", "15–20/side", "40s each side" describe work repeated on each side,
/// so one set covers two. "7.5–10 kg/side" instead describes the *load* on each
/// side of a simultaneous two-handed movement (a cable crossover) — that is a
/// per-hand weight entry, not two sides of work, and must not be counted twice.
int? _sidesFromNotes(String notes) {
  if (RegExp(r'(kg|lb)\s*/\s*side', caseSensitive: false).hasMatch(notes)) {
    return null;
  }
  return notes.contains('each side') || notes.contains('/side') ? 2 : null;
}

_PrescriptionSeed _p(
  String exerciseName,
  int targetSets,
  int? minReps,
  int? maxReps,
  int? restSeconds,
  String notes,
) {
  final tempo = _tempoFromNotes(notes);
  return _PrescriptionSeed(
    exerciseName,
    targetSets: targetSets,
    sidesPerSet: _sidesFromNotes(notes),
    minReps: minReps,
    maxReps: maxReps,
    restSeconds: restSeconds,
    eccentricSec: tempo?[0],
    bottomPauseSec: tempo?[1],
    concentricSec: tempo?[2],
    topPauseSec: tempo?[3],
    prescriptionNotes: _notesWithoutTempo(notes),
  );
}

_PrescriptionSeed _duration(
  String exerciseName,
  int targetSets,
  int targetDurationSec,
  int? restSeconds,
  String notes,
) => _PrescriptionSeed(
  exerciseName,
  targetSets: targetSets,
  targetDurationSec: targetDurationSec,
  restSeconds: restSeconds,
  sidesPerSet: notes.contains('each side') || notes.contains('/side')
      ? 2
      : null,
  prescriptionNotes: notes,
);

List<int>? _tempoFromNotes(String notes) {
  final match = RegExp(
    r'tempo\s+(\d+)-(\d+)-(\d+)-(\d+)',
    caseSensitive: false,
  ).firstMatch(notes);
  if (match == null) return null;
  return [for (var i = 1; i <= 4; i++) int.parse(match.group(i)!)];
}

String _notesWithoutTempo(String notes) => notes
    .replaceFirst(
      RegExp(r'(^| · )tempo\s+\d+-\d+-\d+-\d+', caseSensitive: false),
      '',
    )
    .replaceAll(RegExp(r'\s+·\s+·\s+'), ' · ')
    .trim();

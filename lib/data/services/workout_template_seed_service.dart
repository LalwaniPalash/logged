import 'package:drift/drift.dart';

import '../database/app_database.dart';

class WorkoutTemplateSeedService {
  const WorkoutTemplateSeedService(this._database);

  final AppDatabase _database;

  static final List<_TemplateSeed> _templates = [
    _TemplateSeed('Monday — Push A', [
      _p(
        'Barbell Bench Press',
        4,
        5,
        8,
        180,
        'Tempo 3-1-1-0 · challenging 5–8RM',
      ),
      _p('Pec Deck', 4, 10, 15, 75, 'Highest angle · tempo 2-0-1-1 · ~25 kg'),
      _p(
        'Cable Crossover - Low Pulley',
        3,
        12,
        15,
        75,
        'Low-to-high · tempo 2-0-1-1 · 7.5–10 kg/side',
      ),
      _p(
        'Barbell Overhead Press',
        4,
        6,
        8,
        150,
        'Tempo 2-1-1-0 · challenging 6–8RM',
      ),
      _p(
        'Dumbbell Lateral Raise',
        4,
        15,
        20,
        60,
        'Strict · tempo 3-0-1-0 · 4–5 kg/hand',
      ),
      _p(
        'Cable Lateral Raise',
        3,
        15,
        null,
        60,
        '15/side · tempo 2-0-1-2 · 5–7.5 kg',
      ),
      _p(
        'Overhead Cable Tricep Extension',
        4,
        10,
        12,
        75,
        'Rope, low pulley · tempo 3-1-1-0 · 10–15 kg',
      ),
      _p('Dead Bug', 3, 8, null, 60, '8/side · tempo 3-1-3-0 · bodyweight'),
      _p('Hanging Knee Raise', 3, 12, 15, 60, 'Tempo 2-0-1-1 · bodyweight'),
      ..._allStretches,
    ]),
    _TemplateSeed('Tuesday — Pull A', [
      _p(
        'T-Bar Row',
        4,
        6,
        8,
        180,
        'Landmine row · tempo 2-1-1-0 · challenging 6–8RM',
      ),
      _p(
        'Wide-Grip Lat Pulldown',
        4,
        8,
        10,
        120,
        'Wide overhand · tempo 2-1-1-0 · 35–45 kg',
      ),
      _p(
        'Straight-Arm Pulldown',
        3,
        12,
        15,
        75,
        'Cable · tempo 2-0-1-1 · 15–22 kg',
      ),
      _p(
        'Reverse Pec Deck',
        5,
        15,
        null,
        75,
        'Rear delt machine · tempo 2-0-1-2 · 15–20 kg',
      ),
      _p('Face Pull', 3, 15, 20, 60, 'Cable rope · tempo 2-0-1-2 · 10–15 kg'),
      _p(
        'EZ Bar Curl',
        3,
        8,
        12,
        75,
        'Strict standing · tempo 2-0-1-1 · 15–22 kg total',
      ),
      _p('Incline Dumbbell Curl', 3, 10, 12, 75, 'Tempo 2-0-1-1 · 6–8 kg/hand'),
      _duration(
        'Stationary Bike',
        1,
        20 * 60,
        null,
        'Zone 2 · HR 99–118 bpm · 25 min from week 4',
      ),
      ..._allStretches,
    ]),
    _TemplateSeed('Wednesday — Legs A', [
      _p(
        'Barbell Back Squat',
        4,
        5,
        8,
        180,
        'Tempo 3-1-1-0 · challenging 5–8RM',
      ),
      _p(
        'Barbell Romanian Deadlift',
        4,
        8,
        10,
        120,
        'Tempo 3-0-1-0 · 40–70 kg barbell',
      ),
      _p('Leg Press', 3, 10, 12, 90, 'Bilateral · tempo 3-1-1-0 · 80–140 kg'),
      _p(
        'Leg Extension',
        3,
        12,
        15,
        75,
        'Tempo 2-0-1-2 · progress from rehab weight',
      ),
      _p(
        'Hip Abduction',
        3,
        15,
        20,
        60,
        'Cable ankle cuff · 15–20/side · tempo 2-0-1-2 · 5–15 kg',
      ),
      _p(
        'Tibialis Anterior Raise',
        3,
        15,
        20,
        60,
        'Tempo 2-0-1-2 · bodyweight or light ankle weight',
      ),
      _p(
        'Standing Calf Raise',
        4,
        12,
        15,
        60,
        'Tempo 2-1-2-1 · bodyweight + 20–40 kg or machine',
      ),
      _p(
        'Ab Wheel Rollout',
        3,
        8,
        12,
        75,
        'From knees · tempo 3-1-1-0 · bodyweight',
      ),
      ..._allStretches,
    ]),
    _TemplateSeed('Thursday — Push B', [
      _p(
        'Incline Dumbbell Bench Press',
        4,
        8,
        10,
        120,
        '45° · tempo 3-0-1-0 · progress from last session',
      ),
      _p(
        'Decline Bench Press',
        4,
        10,
        12,
        90,
        'Dumbbell decline · tempo 3-0-1-0 · 12–16 kg/hand',
      ),
      _p(
        'Cable Crossover - Mid Pulley',
        3,
        12,
        15,
        75,
        'Standing cable fly · tempo 2-0-1-2 · 7.5–10 kg/side',
      ),
      _p('Pec Deck', 3, 12, 15, 75, 'Flat setting · tempo 2-0-1-1 · 25–30 kg'),
      _p('Arnold Press', 4, 10, 12, 90, 'Tempo 2-0-1-0 · 8–10 kg/hand'),
      _p(
        'Dumbbell Lateral Raise',
        3,
        15,
        20,
        60,
        'Strict · tempo 3-0-1-0 · 4–5 kg/hand',
      ),
      _p('Face Pull', 3, 15, 20, 60, 'Cable rope · tempo 2-0-1-2 · 10–15 kg'),
      _p(
        'Dumbbell Tricep Extension',
        4,
        12,
        15,
        75,
        'Overhead single DB · tempo 2-1-1-0 · 14–18 kg',
      ),
      _p(
        'Cable Tricep Pushdown',
        3,
        12,
        15,
        75,
        'Straight bar · tempo 2-0-1-2 · 20–30 kg',
      ),
      _p(
        'Pallof Press',
        3,
        10,
        null,
        60,
        'Seated cable · 10/side · tempo 2-2-2-0 · 5–8 kg',
      ),
      _p(
        'Paused Bottom-Half Dumbbell Press',
        2,
        8,
        null,
        75,
        'Shoulder weak point · tempo 2-2-1-0 · 50–60% Arnold press load',
      ),
      ..._allStretches,
    ]),
    _TemplateSeed('Friday — Pull B', [
      _p(
        'Barbell Deadlift',
        4,
        3,
        5,
        210,
        'Plus 1 warm-up @ 60% · tempo 1-0-1-0 · challenging 3–5RM',
      ),
      _p(
        'Neutral-Grip Lat Pulldown',
        4,
        8,
        10,
        120,
        'Close neutral · tempo 2-1-1-0 · 37–47 kg',
      ),
      _p(
        'Chest-Supported Row',
        4,
        10,
        12,
        90,
        'Incline DB row, wide elbows · tempo 2-0-1-1 · 10–16 kg/hand',
      ),
      _p(
        'Dumbbell Single-Arm Row',
        3,
        10,
        12,
        90,
        '10–12/side · tempo 2-0-1-1 · 20–32 kg',
      ),
      _p(
        'Reverse Pec Deck',
        4,
        15,
        null,
        75,
        'Rear delt machine · tempo 2-0-1-2 · 15–22 kg',
      ),
      _p(
        'EZ-Bar Preacher Curl',
        3,
        10,
        12,
        75,
        'Tempo 2-0-1-2 · 10–16 kg EZ bar',
      ),
      _p(
        'Hammer Curl',
        3,
        12,
        null,
        60,
        '12/side alternating · tempo 2-0-1-0 · 8–12 kg/hand',
      ),
      _duration(
        'Stationary Bike',
        1,
        20 * 60,
        null,
        'Zone 2 · HR 99–118 bpm · 25 min from week 4',
      ),
      ..._allStretches,
    ]),
    _TemplateSeed('Saturday — Legs B', [
      _p('Leg Press', 4, 10, 12, 120, 'Bilateral · tempo 3-1-1-0 · 100–160 kg'),
      _p(
        'Dumbbell Bulgarian Split Squat',
        3,
        8,
        10,
        120,
        '8–10/leg · tempo 3-1-1-0 · 8–14 kg/hand or bodyweight',
      ),
      _p('Lying Leg Curl', 4, 10, 12, 75, 'Tempo 2-0-1-2 · 25–45 kg'),
      _p(
        'Leg Extension',
        3,
        12,
        15,
        75,
        'Tempo 2-0-1-2 · progress from Wednesday',
      ),
      _p(
        'Hip Abduction',
        3,
        15,
        20,
        60,
        'Cable ankle cuff · 15–20/side · tempo 2-0-1-2 · 5–15 kg',
      ),
      _p(
        'Tibialis Anterior Raise',
        3,
        15,
        20,
        60,
        'Tempo 2-0-1-2 · bodyweight or ankle weight',
      ),
      _p('Seated Calf Raise', 4, 15, 20, 60, 'Tempo 2-1-2-1 · 20–40 kg'),
      _p(
        'Hanging Leg Raise',
        3,
        8,
        12,
        75,
        'Straight-leg raise · tempo 2-0-1-1 · bodyweight',
      ),
      _p(
        'Plank',
        3,
        null,
        null,
        90,
        'Forearm plank · max hold to form failure · bodyweight',
      ),
      ..._allStretches,
    ]),
  ];

  static const List<_PrescriptionSeed> _allStretches = [
    _PrescriptionSeed(
      'Hip Flexor Stretch',
      targetSets: 1,
      sidesPerSet: 2,
      targetDurationSec: 40,
      prescriptionNotes: '40s each side',
    ),
    _PrescriptionSeed(
      'Doorway Chest Stretch',
      targetSets: 1,
      targetDurationSec: 40,
      prescriptionNotes: '40s · doorway or wall',
    ),
    _PrescriptionSeed(
      'Hamstring Stretch',
      targetSets: 1,
      sidesPerSet: 2,
      targetDurationSec: 40,
      prescriptionNotes: '40s/side · standing on bench',
    ),
    _PrescriptionSeed(
      'Standing Calf Stretch',
      targetSets: 1,
      sidesPerSet: 2,
      targetDurationSec: 40,
      prescriptionNotes: '40s/side · step edge',
    ),
    _PrescriptionSeed(
      'Cross-Body Shoulder Stretch',
      targetSets: 1,
      sidesPerSet: 2,
      targetDurationSec: 30,
      prescriptionNotes: '30s/side',
    ),
    _PrescriptionSeed(
      '90/90 Hip Switch',
      targetSets: 1,
      sidesPerSet: 2,
      targetDurationSec: 45,
      prescriptionNotes: '45s/side',
    ),
  ];

  Future<void> seedIfEmpty() async {
    final existingTemplates = await _database.select(_database.templates).get();

    final exerciseRows = await _database.select(_database.exercises).get();
    final exerciseIds = {
      for (final exercise in exerciseRows) exercise.name: exercise.id,
    };

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
            !await _shouldRefreshDefaultTemplate(existingTemplate.id)) {
          continue;
        }

        await _replaceTemplateExercises(
          templateId: templateId,
          template: template,
          exerciseIds: exerciseIds,
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
    sidesPerSet: notes.contains('each side') || notes.contains('/side')
        ? 2
        : null,
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

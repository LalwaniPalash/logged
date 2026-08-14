import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/domain/enums.dart';
import '../../core/domain/muscle.dart';
import '../../core/domain/muscle_bias.dart';

part 'app_database.g.dart';

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get category => textEnum<ExerciseCategory>()();
  TextColumn get muscleGroup => text()();
  TextColumn get primaryMuscles => text().withDefault(const Constant('[]'))();
  TextColumn get secondaryMuscles => text().withDefault(const Constant('[]'))();
  TextColumn get defaultUnit =>
      textEnum<WeightUnit>().withDefault(const Constant('kg'))();
  TextColumn get weightEntry =>
      textEnum<WeightEntry>().withDefault(const Constant('total'))();
  TextColumn get preferredLoadingMode =>
      textEnum<LoadingMode>().withDefault(const Constant('external'))();
  RealColumn get bodyweightFactor => real().withDefault(const Constant(1.0))();
  // Optional demo/form video (e.g. a YouTube link) that belongs to the exercise
  // itself, so it shows in any workout the exercise appears in. A per-template
  // override still lives on TemplateExercises/SessionExercises.formUrl.
  TextColumn get videoUrl => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Templates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get position => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class TemplateExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get templateId => integer().references(Templates, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get position => integer()();
  IntColumn get targetSets => integer().nullable()();
  IntColumn get sidesPerSet => integer().nullable()();
  IntColumn get minReps => integer().nullable()();
  IntColumn get maxReps => integer().nullable()();
  IntColumn get targetDurationSec => integer().nullable()();
  RealColumn get targetDistanceMeters => real().nullable()();
  IntColumn get restSeconds => integer().nullable()();
  IntColumn get eccentricSec => integer().nullable()();
  IntColumn get bottomPauseSec => integer().nullable()();
  IntColumn get concentricSec => integer().nullable()();
  IntColumn get topPauseSec => integer().nullable()();
  TextColumn get prescriptionNotes => text().nullable()();
  TextColumn get formUrl => text().nullable()();
}

class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get templateId => integer().nullable().references(Templates, #id)();
  TextColumn get notes => text().nullable()();
}

class SessionExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get position => integer()();
  IntColumn get targetSets => integer().nullable()();
  IntColumn get sidesPerSet => integer().nullable()();
  IntColumn get minReps => integer().nullable()();
  IntColumn get maxReps => integer().nullable()();
  IntColumn get targetDurationSec => integer().nullable()();
  RealColumn get targetDistanceMeters => real().nullable()();
  IntColumn get restSeconds => integer().nullable()();
  IntColumn get eccentricSec => integer().nullable()();
  IntColumn get bottomPauseSec => integer().nullable()();
  IntColumn get concentricSec => integer().nullable()();
  IntColumn get topPauseSec => integer().nullable()();
  TextColumn get prescriptionNotes => text().nullable()();
  TextColumn get formUrl => text().nullable()();
}

class SetEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionExerciseId =>
      integer().references(SessionExercises, #id)();
  IntColumn get setNumber => integer()();
  IntColumn get reps => integer().nullable()();
  RealColumn get weightValue => real().nullable()();
  TextColumn get unit => textEnum<WeightUnit>().nullable()();
  TextColumn get weightEntry =>
      textEnum<WeightEntry>().withDefault(const Constant('total'))();
  IntColumn get sideCount => integer().withDefault(const Constant(1))();
  TextColumn get loadingMode =>
      textEnum<LoadingMode>().withDefault(const Constant('external'))();
  RealColumn get distanceMeters => real().nullable()();
  IntColumn get durationSec => integer().nullable()();
  BoolColumn get isWarmup => boolean().withDefault(const Constant(false))();
  RealColumn get rpe => real().nullable()();
  TextColumn get muscleBiasWeights => text().nullable()();
  TextColumn get notes => text().nullable()();
}

class BodyweightEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime().unique()();
  RealColumn get value => real()();
  TextColumn get unit => textEnum<WeightUnit>()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Manually logged rest days (one row per date). Scheduled weekly rest days are
/// derived from [AppSettings], not stored here.
class RestDays extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime().unique()();
  TextColumn get note => text().nullable()();
}

/// Simple key/value store for app preferences (rest schedule, weekly goal), kept
/// in the database so it travels with JSON backups.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Exercises,
    Templates,
    TemplateExercises,
    Sessions,
    SessionExercises,
    SetEntries,
    BodyweightEntries,
    RestDays,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'logged'));

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      // v2: rest-day logging, weekly-goal/rest-schedule settings, set RPE.
      if (from < 2) {
        await migrator.createTable(restDays);
        await migrator.createTable(appSettings);
        await migrator.addColumn(setEntries, setEntries.rpe);
      }
      // v3: detailed primary/secondary exercise anatomy for the live
      // muscle visualization. JSON text keeps backups simple and avoids a
      // join table for two small, fixed-role lists.
      if (from < 3) {
        await migrator.addColumn(exercises, exercises.primaryMuscles);
        await migrator.addColumn(exercises, exercises.secondaryMuscles);
      }
      // v4: loading-mode metadata and dated bodyweight history for
      // exercise-relative personal muscle progress.
      if (from < 4) {
        await migrator.addColumn(exercises, exercises.preferredLoadingMode);
        await migrator.addColumn(exercises, exercises.bodyweightFactor);
        await migrator.addColumn(setEntries, setEntries.loadingMode);
        await migrator.createTable(bodyweightEntries);
      }
      if (from < 4) {
        await migrator.createTable(templates);
        await migrator.createTable(templateExercises);
      }
      // v5: per-exercise prescriptions for templates and sessions. Session
      // rows snapshot template targets so historical workouts keep the plan
      // that was active when they were started.
      if (from >= 4 && from < 5) {
        await migrator.addColumn(
          templateExercises,
          templateExercises.targetSets,
        );
        await migrator.addColumn(templateExercises, templateExercises.minReps);
        await migrator.addColumn(templateExercises, templateExercises.maxReps);
        await migrator.addColumn(
          templateExercises,
          templateExercises.targetDurationSec,
        );
        await migrator.addColumn(
          templateExercises,
          templateExercises.targetDistanceMeters,
        );
        await migrator.addColumn(
          templateExercises,
          templateExercises.restSeconds,
        );
        await migrator.addColumn(
          templateExercises,
          templateExercises.eccentricSec,
        );
        await migrator.addColumn(
          templateExercises,
          templateExercises.bottomPauseSec,
        );
        await migrator.addColumn(
          templateExercises,
          templateExercises.concentricSec,
        );
        await migrator.addColumn(
          templateExercises,
          templateExercises.topPauseSec,
        );
        await migrator.addColumn(
          templateExercises,
          templateExercises.prescriptionNotes,
        );
        await migrator.addColumn(templateExercises, templateExercises.formUrl);
      }
      if (from < 5) {
        await migrator.addColumn(sessionExercises, sessionExercises.targetSets);
        await migrator.addColumn(sessionExercises, sessionExercises.minReps);
        await migrator.addColumn(sessionExercises, sessionExercises.maxReps);
        await migrator.addColumn(
          sessionExercises,
          sessionExercises.targetDurationSec,
        );
        await migrator.addColumn(
          sessionExercises,
          sessionExercises.targetDistanceMeters,
        );
        await migrator.addColumn(
          sessionExercises,
          sessionExercises.restSeconds,
        );
        await migrator.addColumn(
          sessionExercises,
          sessionExercises.eccentricSec,
        );
        await migrator.addColumn(
          sessionExercises,
          sessionExercises.bottomPauseSec,
        );
        await migrator.addColumn(
          sessionExercises,
          sessionExercises.concentricSec,
        );
        await migrator.addColumn(
          sessionExercises,
          sessionExercises.topPauseSec,
        );
        await migrator.addColumn(
          sessionExercises,
          sessionExercises.prescriptionNotes,
        );
        await migrator.addColumn(sessionExercises, sessionExercises.formUrl);
      }
      if (from < 6) {
        await migrator.addColumn(exercises, exercises.weightEntry);
        await migrator.addColumn(setEntries, setEntries.weightEntry);
        await migrator.addColumn(setEntries, setEntries.sideCount);
        if (from >= 4) {
          await migrator.addColumn(
            templateExercises,
            templateExercises.sidesPerSet,
          );
        }
        await migrator.addColumn(
          sessionExercises,
          sessionExercises.sidesPerSet,
        );
      }
      // v7: per-exercise demo/form video link (nullable — null means no video,
      // so existing rows need no backfill).
      if (from < 7) {
        await migrator.addColumn(exercises, exercises.videoUrl);
      }
      if (from < 10) {
        await migrator.addColumn(setEntries, setEntries.muscleBiasWeights);
      }
      if (from >= 8 && from < 10) {
        final legacyBiasRows = await customSelect(
          'SELECT se.id AS set_id, se.muscle_bias AS muscle_bias, '
          'e.bias_muscle_a AS bias_muscle_a, '
          'e.bias_muscle_b AS bias_muscle_b '
          'FROM set_entries se '
          'JOIN session_exercises sx ON sx.id = se.session_exercise_id '
          'JOIN exercises e ON e.id = sx.exercise_id '
          'WHERE se.muscle_bias IS NOT NULL',
        ).get();
        for (final row in legacyBiasRows) {
          final encoded = _legacyMuscleBiasWeights(
            bias: (row.data['muscle_bias'] as num?)?.toDouble(),
            biasMuscleAId: row.data['bias_muscle_a'] as String?,
            biasMuscleBId: row.data['bias_muscle_b'] as String?,
          );
          if (encoded == null) continue;
          await customUpdate(
            'UPDATE set_entries '
            'SET muscle_bias_weights = ? '
            'WHERE id = ?',
            variables: [
              Variable<String>(encoded),
              Variable<int>(row.read<int>('set_id')),
            ],
            updates: {setEntries},
            updateKind: UpdateKind.update,
          );
        }

        await migrator.alterTable(TableMigration(setEntries));
        await migrator.alterTable(TableMigration(exercises));
      }
      if (from < 11) {
        await rescaleStoredMuscleBiasWeights(this);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement(
        'CREATE INDEX IF NOT EXISTS set_entries_session_exercise_idx '
        'ON set_entries(session_exercise_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS session_exercises_exercise_idx '
        'ON session_exercises(exercise_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS sessions_started_at_idx '
        'ON sessions(started_at)',
      );
    },
  );
}

Future<void> rescaleStoredMuscleBiasWeights(AppDatabase database) async {
  final rows = await database
      .customSelect(
        'SELECT id AS set_id, muscle_bias_weights AS muscle_bias_weights '
        'FROM set_entries '
        'WHERE muscle_bias_weights IS NOT NULL',
      )
      .get();
  for (final row in rows) {
    final encoded = rescaleEncodedMuscleBiasWeightsToMeanOne(
      row.data['muscle_bias_weights'] as String?,
    );
    if (encoded == null) continue;
    await database.customUpdate(
      'UPDATE set_entries '
      'SET muscle_bias_weights = ? '
      'WHERE id = ?',
      variables: [
        Variable<String>(encoded),
        Variable<int>(row.read<int>('set_id')),
      ],
      updates: {database.setEntries},
      updateKind: UpdateKind.update,
    );
  }
}

String? _legacyMuscleBiasWeights({
  required double? bias,
  required String? biasMuscleAId,
  required String? biasMuscleBId,
}) {
  if (biasMuscleAId == null || biasMuscleBId == null) return null;

  try {
    final biasMuscleA = _decodeLegacyMuscle(biasMuscleAId);
    final biasMuscleB = _decodeLegacyMuscle(biasMuscleBId);
    if (biasMuscleA == biasMuscleB) return null;

    final shares = resolveMuscleBiasShares(bias);
    return encodeMuscleBiasWeights({
      biasMuscleA: shares.shareA,
      biasMuscleB: shares.shareB,
    });
  } on ArgumentError {
    return null;
  }
}

MuscleId _decodeLegacyMuscle(String value) {
  try {
    return MuscleId.fromId(value);
  } on ArgumentError {
    return MuscleId.values.byName(value);
  }
}

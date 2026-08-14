import 'package:drift/drift.dart';

import '../../core/domain/streak.dart';
import '../../core/domain/enums.dart';
import '../database/app_database.dart';

class TemplateExerciseDetails {
  const TemplateExerciseDetails({
    required this.templateExercise,
    required this.exercise,
  });

  final TemplateExercise templateExercise;
  final Exercise exercise;
}

class ProgramImportExercise {
  const ProgramImportExercise({
    required this.day,
    required this.exerciseName,
    required this.targetSets,
    this.exerciseId,
    this.createCustom = false,
    this.minReps,
    this.maxReps,
    this.restSeconds,
    this.rpe,
    this.notes,
  });

  final String day;
  final String exerciseName;
  final int targetSets;
  final int? exerciseId;
  final bool createCustom;
  final int? minReps;
  final int? maxReps;
  final int? restSeconds;
  final double? rpe;
  final String? notes;
}

class TemplateRepository {
  const TemplateRepository(this._database);

  final AppDatabase _database;

  Stream<List<Template>> watchAll() => (_database.select(
    _database.templates,
  )..orderBy([(row) => OrderingTerm.asc(row.position)])).watch();

  Future<int> create(String name) async {
    final count = (await _database.select(_database.templates).get()).length;
    return _database
        .into(_database.templates)
        .insert(TemplatesCompanion.insert(name: name, position: count));
  }

  Future<void> rename(int id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    return (_database.update(_database.templates)
          ..where((row) => row.id.equals(id)))
        .write(TemplatesCompanion(name: Value(trimmed)));
  }

  /// Removes only the reusable plan. Historical workout data is preserved and
  /// its nullable source-template link is cleared first for FK integrity.
  Future<void> delete(int id) => _database.transaction(() async {
    await (_database.update(_database.sessions)
          ..where((row) => row.templateId.equals(id)))
        .write(const SessionsCompanion(templateId: Value(null)));
    await (_database.delete(
      _database.templateExercises,
    )..where((row) => row.templateId.equals(id))).go();
    await (_database.delete(
      _database.templates,
    )..where((row) => row.id.equals(id))).go();
    await _normalizePositions();
  });

  Future<int> duplicate(int id) => _database.transaction(() async {
    final source = await (_database.select(
      _database.templates,
    )..where((row) => row.id.equals(id))).getSingle();
    final exercises =
        await (_database.select(_database.templateExercises)
              ..where((row) => row.templateId.equals(id))
              ..orderBy([(row) => OrderingTerm.asc(row.position)]))
            .get();
    final rows = await _database.select(_database.templates).get();
    final nextPosition = rows.isEmpty
        ? 0
        : rows.map((row) => row.position).reduce((a, b) => a > b ? a : b) + 1;
    final copyId = await _database
        .into(_database.templates)
        .insert(
          TemplatesCompanion.insert(
            name: '${source.name} (copy)',
            position: nextPosition,
          ),
        );
    await _database.batch((batch) {
      batch.insertAll(_database.templateExercises, [
        for (final item in exercises)
          TemplateExercisesCompanion.insert(
            templateId: copyId,
            exerciseId: item.exerciseId,
            position: item.position,
            targetSets: Value(item.targetSets),
            sidesPerSet: Value(item.sidesPerSet),
            minReps: Value(item.minReps),
            maxReps: Value(item.maxReps),
            targetDurationSec: Value(item.targetDurationSec),
            targetDistanceMeters: Value(item.targetDistanceMeters),
            restSeconds: Value(item.restSeconds),
            eccentricSec: Value(item.eccentricSec),
            bottomPauseSec: Value(item.bottomPauseSec),
            concentricSec: Value(item.concentricSec),
            topPauseSec: Value(item.topPauseSec),
            prescriptionNotes: Value(item.prescriptionNotes),
            formUrl: Value(item.formUrl),
          ),
      ]);
    });
    return copyId;
  });

  Future<List<Template>> importProgram(List<ProgramImportExercise> items) =>
      _database.transaction(() async {
        if (items.isEmpty) {
          throw ArgumentError.value(items, 'items', 'must not be empty');
        }
        if (items.any(
          (item) =>
              item.exerciseId == null &&
              (!item.createCustom || item.exerciseName.trim().isEmpty),
        )) {
          throw ArgumentError('Every imported exercise needs a mapping.');
        }
        final existingTemplates = await _database
            .select(_database.templates)
            .get();
        var nextPosition = existingTemplates.isEmpty
            ? 0
            : existingTemplates
                      .map((template) => template.position)
                      .reduce((a, b) => a > b ? a : b) +
                  1;
        final byDay = <String, List<ProgramImportExercise>>{};
        for (final item in items) {
          (byDay[item.day.trim()] ??= []).add(item);
        }
        final customIds = <String, int>{};
        final imported = <Template>[];
        for (final entry in byDay.entries) {
          final templateId = await _database
              .into(_database.templates)
              .insert(
                TemplatesCompanion.insert(
                  name: entry.key,
                  position: nextPosition++,
                ),
              );
          for (var index = 0; index < entry.value.length; index++) {
            final item = entry.value[index];
            var exerciseId = item.exerciseId;
            if (exerciseId == null) {
              final key = item.exerciseName.trim().toLowerCase();
              exerciseId = customIds[key];
              exerciseId ??= await _database
                  .into(_database.exercises)
                  .insert(
                    ExercisesCompanion.insert(
                      name: item.exerciseName.trim(),
                      category: ExerciseCategory.strength,
                      muscleGroup: 'custom',
                      isCustom: const Value(true),
                    ),
                  );
              customIds[key] = exerciseId;
            }
            final noteParts = [
              if (item.rpe != null) 'RPE ${item.rpe}',
              if ((item.notes ?? '').trim().isNotEmpty) item.notes!.trim(),
            ];
            await _database
                .into(_database.templateExercises)
                .insert(
                  TemplateExercisesCompanion.insert(
                    templateId: templateId,
                    exerciseId: exerciseId,
                    position: index,
                    targetSets: Value(item.targetSets),
                    minReps: Value(item.minReps),
                    maxReps: Value(item.maxReps),
                    restSeconds: Value(item.restSeconds),
                    prescriptionNotes: Value(
                      noteParts.isEmpty ? null : noteParts.join(' · '),
                    ),
                  ),
                );
          }
          imported.add(
            await (_database.select(
              _database.templates,
            )..where((template) => template.id.equals(templateId))).getSingle(),
          );
        }
        return imported;
      });

  /// Builds a half-volume template from the most recent week that contains
  /// completed training — not "this week", which is empty exactly when a
  /// deload is most warranted.
  Future<Template> createDeloadWeek() => _database.transaction(() async {
    final latestCompleted = await _database
        .customSelect(
          'SELECT MAX(started_at) AS latest '
          'FROM sessions '
          'WHERE ended_at IS NOT NULL',
        )
        .getSingle();
    final latestValue = latestCompleted.data['latest'];
    if (latestValue == null) {
      throw StateError(
        'Complete at least one workout before generating a deload.',
      );
    }
    final weekStart = startOfWeek(
      DateTime.fromMillisecondsSinceEpoch((latestValue as num).toInt() * 1000),
    );
    final rows = await _database
        .customSelect(
          'SELECT sx.exercise_id AS exercise_id, MIN(sx.position) AS position, '
          'COUNT(se.id) AS set_count '
          'FROM set_entries se '
          'JOIN session_exercises sx ON sx.id = se.session_exercise_id '
          'JOIN sessions s ON s.id = sx.session_id '
          'WHERE s.ended_at IS NOT NULL AND s.started_at >= ? '
          'AND se.is_warmup = 0 '
          'GROUP BY sx.exercise_id ORDER BY position',
          variables: [Variable.withDateTime(weekStart)],
        )
        .get();
    if (rows.isEmpty) {
      throw StateError(
        'Complete at least one workout before generating a deload.',
      );
    }
    final templates = await _database.select(_database.templates).get();
    final position = templates.isEmpty
        ? 0
        : templates
                  .map((template) => template.position)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    final weekKey = weekStart.toIso8601String().substring(0, 10);
    final id = await _database
        .into(_database.templates)
        .insert(
          TemplatesCompanion.insert(
            name: 'Deload · $weekKey',
            position: position,
          ),
        );
    await _database.batch((batch) {
      batch.insertAll(_database.templateExercises, [
        for (var index = 0; index < rows.length; index++)
          TemplateExercisesCompanion.insert(
            templateId: id,
            exerciseId: rows[index].read<int>('exercise_id'),
            position: index,
            targetSets: Value(
              ((rows[index].read<int>('set_count')) / 2).ceil().clamp(1, 999),
            ),
            prescriptionNotes: const Value(
              'Deload: use an easy load and leave 3–4 reps in reserve.',
            ),
          ),
      ]);
    });
    return (_database.select(
      _database.templates,
    )..where((row) => row.id.equals(id))).getSingle();
  });

  Future<void> reorder(List<int> orderedIds) => _database.transaction(() async {
    if (orderedIds.toSet().length != orderedIds.length) {
      throw ArgumentError.value(
        orderedIds,
        'orderedIds',
        'must not contain duplicates',
      );
    }
    final existing = await _database.select(_database.templates).get();
    if (existing
            .map((row) => row.id)
            .toSet()
            .difference(orderedIds.toSet())
            .isNotEmpty ||
        orderedIds
            .toSet()
            .difference(existing.map((row) => row.id).toSet())
            .isNotEmpty) {
      throw ArgumentError.value(
        orderedIds,
        'orderedIds',
        'must contain every template exactly once',
      );
    }
    for (var position = 0; position < orderedIds.length; position++) {
      await (_database.update(_database.templates)
            ..where((row) => row.id.equals(orderedIds[position])))
          .write(TemplatesCompanion(position: Value(position)));
    }
  });

  Future<void> replaceExercises(int templateId, List<int> exerciseIds) =>
      replaceExerciseDetails(templateId, [
        for (var index = 0; index < exerciseIds.length; index++)
          TemplateExercisesCompanion.insert(
            templateId: templateId,
            exerciseId: exerciseIds[index],
            position: index,
          ),
      ]);

  Future<void> replaceExerciseDetails(
    int templateId,
    List<TemplateExercisesCompanion> exercises,
  ) => _database.transaction(() async {
    await (_database.delete(
      _database.templateExercises,
    )..where((row) => row.templateId.equals(templateId))).go();
    await _database.batch((batch) {
      batch.insertAll(_database.templateExercises, exercises);
    });
  });

  Future<List<int>> exerciseIds(int templateId) async =>
      (await (_database.select(_database.templateExercises)
                ..where((row) => row.templateId.equals(templateId))
                ..orderBy([(row) => OrderingTerm.asc(row.position)]))
              .get())
          .map((row) => row.exerciseId)
          .toList();

  Future<List<Exercise>> exercises(int templateId) async {
    final details = await exerciseDetails(templateId);
    return details.map((item) => item.exercise).toList();
  }

  Future<List<TemplateExerciseDetails>> exerciseDetails(int templateId) async {
    final rows =
        await (_database.select(_database.templateExercises).join([
                innerJoin(
                  _database.exercises,
                  _database.exercises.id.equalsExp(
                    _database.templateExercises.exerciseId,
                  ),
                ),
              ])
              ..where(_database.templateExercises.templateId.equals(templateId))
              ..orderBy([
                OrderingTerm.asc(_database.templateExercises.position),
              ]))
            .get();
    return rows
        .map(
          (row) => TemplateExerciseDetails(
            templateExercise: row.readTable(_database.templateExercises),
            exercise: row.readTable(_database.exercises),
          ),
        )
        .toList();
  }

  Future<void> _normalizePositions() async {
    final templates = await (_database.select(
      _database.templates,
    )..orderBy([(row) => OrderingTerm.asc(row.position)])).get();
    for (var position = 0; position < templates.length; position++) {
      await (_database.update(_database.templates)
            ..where((row) => row.id.equals(templates[position].id)))
          .write(TemplatesCompanion(position: Value(position)));
    }
  }
}

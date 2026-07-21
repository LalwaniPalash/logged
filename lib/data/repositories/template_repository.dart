import 'package:drift/drift.dart';

import '../database/app_database.dart';

class TemplateExerciseDetails {
  const TemplateExerciseDetails({
    required this.templateExercise,
    required this.exercise,
  });

  final TemplateExercise templateExercise;
  final Exercise exercise;
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
}

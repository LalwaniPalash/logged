import 'package:drift/drift.dart';

import '../../core/domain/enums.dart';
import '../database/app_database.dart';

class ExerciseRepository {
  const ExerciseRepository(this._database);

  final AppDatabase _database;

  Stream<List<Exercise>> watchAvailable() =>
      (_database.select(_database.exercises)
            ..where((row) => row.isArchived.equals(false))
            ..orderBy([(row) => OrderingTerm.asc(row.name)]))
          .watch();

  Future<List<Exercise>> all() => _database.select(_database.exercises).get();

  Future<int> add(ExercisesCompanion exercise) =>
      _database.into(_database.exercises).insert(exercise);

  Future<void> updateDetails(
    int exerciseId, {
    String? name,
    ExerciseCategory? category,
    double? bodyweightFactor,
    bool? isTimed,
    bool? tracksDistance,
  }) =>
      (_database.update(
        _database.exercises,
      )..where((row) => row.id.equals(exerciseId))).write(
        ExercisesCompanion(
          name: name == null ? const Value.absent() : Value(name),
          category: category == null ? const Value.absent() : Value(category),
          bodyweightFactor: bodyweightFactor == null
              ? const Value.absent()
              : Value(bodyweightFactor),
          isTimed: isTimed == null ? const Value.absent() : Value(isTimed),
          tracksDistance: tracksDistance == null
              ? const Value.absent()
              : Value(tracksDistance),
        ),
      );

  Future<void> updateDefaultUnit(int exerciseId, WeightUnit unit) =>
      (_database.update(_database.exercises)
            ..where((row) => row.id.equals(exerciseId)))
          .write(ExercisesCompanion(defaultUnit: Value(unit)));

  /// Sets (or clears, with null) the exercise's demo/form video link.
  Future<void> updateVideoUrl(int exerciseId, String? url) =>
      (_database.update(_database.exercises)
            ..where((row) => row.id.equals(exerciseId)))
          .write(ExercisesCompanion(videoUrl: Value(url)));

  Future<void> updateLoggingDefaults(
    int exerciseId, {
    required WeightUnit unit,
    required WeightEntry weightEntry,
    required LoadingMode loadingMode,
  }) =>
      (_database.update(
        _database.exercises,
      )..where((row) => row.id.equals(exerciseId))).write(
        ExercisesCompanion(
          defaultUnit: Value(unit),
          weightEntry: Value(weightEntry),
          preferredLoadingMode: Value(loadingMode),
        ),
      );

  Future<void> updateMuscles(
    int exerciseId, {
    required String primaryMuscles,
    required String secondaryMuscles,
  }) =>
      (_database.update(
        _database.exercises,
      )..where((row) => row.id.equals(exerciseId))).write(
        ExercisesCompanion(
          primaryMuscles: Value(primaryMuscles),
          secondaryMuscles: Value(secondaryMuscles),
        ),
      );

  Future<void> archive(int exerciseId, {required bool archived}) =>
      (_database.update(_database.exercises)
            ..where((row) => row.id.equals(exerciseId)))
          .write(ExercisesCompanion(isArchived: Value(archived)));

  Future<bool> delete(int exerciseId) => _database.transaction(() async {
    final sessionReferences = await _countReferences(
      tableName: 'session_exercises',
      exerciseId: exerciseId,
    );
    final templateReferences = await _countReferences(
      tableName: 'template_exercises',
      exerciseId: exerciseId,
    );
    if (sessionReferences > 0 || templateReferences > 0) {
      return false;
    }
    final deleted = await (_database.delete(
      _database.exercises,
    )..where((row) => row.id.equals(exerciseId))).go();
    return deleted > 0;
  });

  Future<int> _countReferences({
    required String tableName,
    required int exerciseId,
  }) async {
    final row = await _database
        .customSelect(
          'SELECT COUNT(*) AS row_count FROM $tableName WHERE exercise_id = ?',
          variables: [Variable<int>(exerciseId)],
        )
        .getSingle();
    return (row.data['row_count'] as num?)?.toInt() ?? 0;
  }
}

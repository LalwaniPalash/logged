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
}

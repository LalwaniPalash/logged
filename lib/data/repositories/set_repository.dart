import 'package:drift/drift.dart';

import '../../core/domain/enums.dart';
import '../database/app_database.dart';

class SetRepository {
  const SetRepository(this._database);

  final AppDatabase _database;

  Future<int> add({
    required int sessionExerciseId,
    required int setNumber,
    int? reps,
    double? weightValue,
    WeightUnit? unit,
    WeightEntry weightEntry = WeightEntry.total,
    int sideCount = 1,
    LoadingMode loadingMode = LoadingMode.external,
    double? distanceMeters,
    int? durationSec,
    bool isWarmup = false,
    double? rpe,
    String? notes,
  }) => _database
      .into(_database.setEntries)
      .insert(
        SetEntriesCompanion.insert(
          sessionExerciseId: sessionExerciseId,
          setNumber: setNumber,
          reps: Value(reps),
          weightValue: Value(weightValue),
          unit: Value(unit),
          weightEntry: Value(weightEntry),
          sideCount: Value(sideCount),
          loadingMode: Value(loadingMode),
          distanceMeters: Value(distanceMeters),
          durationSec: Value(durationSec),
          isWarmup: Value(isWarmup),
          rpe: Value(rpe),
          notes: Value(notes),
        ),
      );

  /// Edits the logged fields of an existing set.
  Future<void> edit(
    int setId, {
    int? reps,
    double? weightValue,
    WeightUnit? unit,
    WeightEntry? weightEntry,
    int? sideCount,
    LoadingMode? loadingMode,
    double? distanceMeters,
    int? durationSec,
    double? rpe,
    bool? isWarmup,
    String? notes,
  }) =>
      (_database.update(
        _database.setEntries,
      )..where((row) => row.id.equals(setId))).write(
        SetEntriesCompanion(
          reps: Value(reps),
          weightValue: Value(weightValue),
          unit: Value(unit),
          weightEntry: Value(weightEntry ?? WeightEntry.total),
          sideCount: Value(sideCount ?? 1),
          loadingMode: Value(loadingMode ?? LoadingMode.external),
          distanceMeters: Value(distanceMeters),
          durationSec: Value(durationSec),
          rpe: Value(rpe),
          isWarmup: Value(isWarmup ?? false),
          notes: Value(notes),
        ),
      );

  Future<void> update(int setId, SetEntriesCompanion entry) =>
      (_database.update(
        _database.setEntries,
      )..where((row) => row.id.equals(setId))).write(entry);

  Future<void> delete(int setId) => (_database.delete(
    _database.setEntries,
  )..where((row) => row.id.equals(setId))).go();
}

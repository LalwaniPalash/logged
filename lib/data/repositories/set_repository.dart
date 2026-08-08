import 'package:drift/drift.dart';

import '../../core/domain/enums.dart';
import '../../core/domain/warmup.dart';
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
    double? muscleBias,
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
          muscleBias: Value(muscleBias),
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
    double? muscleBias,
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
          muscleBias: Value(muscleBias),
          isWarmup: Value(isWarmup ?? false),
          notes: Value(notes),
        ),
      );

  Future<void> update(int setId, SetEntriesCompanion entry) =>
      (_database.update(
        _database.setEntries,
      )..where((row) => row.id.equals(setId))).write(entry);

  Future<void> shiftSetNumbers({
    required int sessionExerciseId,
    required int by,
    int fromNumber = 1,
  }) async {
    if (by == 0) return;
    await _database.customUpdate(
      'UPDATE set_entries '
      'SET set_number = set_number + ? '
      'WHERE session_exercise_id = ? AND set_number >= ?',
      variables: [
        Variable<int>(by),
        Variable<int>(sessionExerciseId),
        Variable<int>(fromNumber),
      ],
      updates: {_database.setEntries},
      updateKind: UpdateKind.update,
    );
  }

  Future<void> insertWarmupSets({
    required int sessionExerciseId,
    required List<WarmupSet> warmups,
    required WeightUnit unit,
    required WeightEntry weightEntry,
    required int sideCount,
    required LoadingMode loadingMode,
  }) async {
    if (warmups.isEmpty) return;
    await _database.transaction(() async {
      await shiftSetNumbers(
        sessionExerciseId: sessionExerciseId,
        by: warmups.length,
      );
      await _database.batch((batch) {
        batch.insertAll(_database.setEntries, [
          for (var index = 0; index < warmups.length; index++)
            SetEntriesCompanion.insert(
              sessionExerciseId: sessionExerciseId,
              setNumber: index + 1,
              reps: Value(warmups[index].reps),
              weightValue: Value(warmups[index].weight),
              unit: Value(unit),
              weightEntry: Value(weightEntry),
              sideCount: Value(sideCount),
              loadingMode: Value(loadingMode),
              isWarmup: const Value(true),
              muscleBias: const Value(null),
            ),
        ]);
      });
    });
  }

  Future<void> delete(int setId) => (_database.delete(
    _database.setEntries,
  )..where((row) => row.id.equals(setId))).go();
}

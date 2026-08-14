import 'package:drift/drift.dart';

import '../../core/domain/enums.dart';
import '../../core/domain/muscle.dart';
import '../../core/domain/muscle_bias.dart';
import '../../core/domain/warmup.dart';
import '../database/app_database.dart';

class SetRepository {
  const SetRepository(this._database);

  final AppDatabase _database;

  Future<void> _renumber(int sessionExerciseId) async {
    final rows =
        await (_database.select(_database.setEntries)
              ..where((row) => row.sessionExerciseId.equals(sessionExerciseId))
              ..orderBy([(row) => OrderingTerm.asc(row.setNumber)]))
            .get();
    for (var index = 0; index < rows.length; index++) {
      final expectedNumber = index + 1;
      if (rows[index].setNumber == expectedNumber) continue;
      await update(
        rows[index].id,
        SetEntriesCompanion(setNumber: Value(expectedNumber)),
      );
    }
  }

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
    Map<MuscleId, double>? muscleBiasWeights,
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
          muscleBiasWeights: Value(encodeMuscleBiasWeights(muscleBiasWeights)),
          notes: Value(notes),
        ),
      );

  /// Edits the logged fields of an existing set.
  Future<void> edit(
    int setId, {
    Value<int?> reps = const Value.absent(),
    Value<double?> weightValue = const Value.absent(),
    Value<WeightUnit?> unit = const Value.absent(),
    WeightEntry? weightEntry,
    int? sideCount,
    LoadingMode? loadingMode,
    Value<double?> distanceMeters = const Value.absent(),
    Value<int?> durationSec = const Value.absent(),
    Value<double?> rpe = const Value.absent(),
    Value<Map<MuscleId, double>?> muscleBiasWeights = const Value.absent(),
    bool? isWarmup,
    Value<String?> notes = const Value.absent(),
  }) =>
      (_database.update(
        _database.setEntries,
      )..where((row) => row.id.equals(setId))).write(
        SetEntriesCompanion(
          reps: reps,
          weightValue: weightValue,
          unit: unit,
          weightEntry: weightEntry == null
              ? const Value.absent()
              : Value(weightEntry),
          sideCount: sideCount == null
              ? const Value.absent()
              : Value(sideCount),
          loadingMode: loadingMode == null
              ? const Value.absent()
              : Value(loadingMode),
          distanceMeters: distanceMeters,
          durationSec: durationSec,
          rpe: rpe,
          muscleBiasWeights: muscleBiasWeights.present
              ? Value(encodeMuscleBiasWeights(muscleBiasWeights.value))
              : const Value.absent(),
          isWarmup: isWarmup == null ? const Value.absent() : Value(isWarmup),
          notes: notes,
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
              muscleBiasWeights: const Value(null),
            ),
        ]);
      });
    });
  }

  Future<int> restoreDeletedSet({
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
    Map<MuscleId, double>? muscleBiasWeights,
    String? notes,
  }) => _database.transaction(() async {
    await shiftSetNumbers(
      sessionExerciseId: sessionExerciseId,
      by: 1,
      fromNumber: setNumber,
    );
    return add(
      sessionExerciseId: sessionExerciseId,
      setNumber: setNumber,
      reps: reps,
      weightValue: weightValue,
      unit: unit,
      weightEntry: weightEntry,
      sideCount: sideCount,
      loadingMode: loadingMode,
      distanceMeters: distanceMeters,
      durationSec: durationSec,
      isWarmup: isWarmup,
      rpe: rpe,
      muscleBiasWeights: muscleBiasWeights,
      notes: notes,
    );
  });

  Future<void> delete(int setId) => _database.transaction(() async {
    final row = await (_database.select(
      _database.setEntries,
    )..where((entry) => entry.id.equals(setId))).getSingleOrNull();
    if (row == null) return;
    await (_database.delete(
      _database.setEntries,
    )..where((entry) => entry.id.equals(setId))).go();
    await _renumber(row.sessionExerciseId);
  });
}

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../../core/domain/enums.dart';
import '../database/app_database.dart';

/// Keeps bundled exercise anatomy aligned with the reviewed asset without
/// overwriting user-created exercises.
class ExerciseAnatomyService {
  ExerciseAnatomyService(this._database, {Future<String> Function()? loadAsset})
    : _loadAsset =
          loadAsset ??
          (() => rootBundle.loadString('assets/data/exercise_library.json'));

  final AppDatabase _database;
  final Future<String> Function() _loadAsset;

  static const _weightEntryBackfillKey = 'weightEntryBackfilled';
  static const _pullUpBackfillKey = 'pullUpExerciseBackfilled';

  /// Returns how many bundled exercise rows changed.
  Future<int> enrichBundledExercises() async {
    final source = jsonDecode(await _loadAsset()) as List<dynamic>;
    final anatomyByName = <String, ({String primary, String secondary})>{
      for (final raw in source.cast<Map<String, dynamic>>())
        raw['name']! as String: (
          primary: jsonEncode(
            (raw['primaryMuscles'] as List<dynamic>?) ?? const [],
          ),
          secondary: jsonEncode(
            (raw['secondaryMuscles'] as List<dynamic>?) ?? const [],
          ),
        ),
    };

    final bundled = await (_database.select(
      _database.exercises,
    )..where((exercise) => exercise.isCustom.equals(false))).get();
    final changes = <(int, String, String)>[];
    for (final exercise in bundled) {
      final anatomy = anatomyByName[exercise.name];
      if (anatomy == null) continue;
      if (exercise.primaryMuscles == anatomy.primary &&
          exercise.secondaryMuscles == anatomy.secondary) {
        continue;
      }
      changes.add((exercise.id, anatomy.primary, anatomy.secondary));
    }

    if (changes.isEmpty) return 0;
    await _database.batch((batch) {
      for (final change in changes) {
        batch.update(
          _database.exercises,
          ExercisesCompanion(
            primaryMuscles: Value(change.$2),
            secondaryMuscles: Value(change.$3),
          ),
          where: (exercise) => exercise.id.equals(change.$1),
        );
      }
    });
    return changes.length;
  }

  /// One-time backfill of `weightEntry` from the bundled library.
  ///
  /// Seeding uses [InsertMode.insertOrIgnore], so per-hand flags added to the
  /// library after a user's first launch never reach their existing rows.
  ///
  /// Unlike anatomy this runs exactly once, guarded by a flag in app settings:
  /// `weightEntry` is user-editable (the set editor's per-hand toggle writes it
  /// back via `updateLoggingDefaults`), so re-running it every launch would
  /// silently undo the user's own choices. Custom exercises are never touched.
  Future<int> backfillWeightEntryOnce() async {
    final alreadyRun =
        await (_database.select(_database.appSettings)
              ..where((row) => row.key.equals(_weightEntryBackfillKey)))
            .getSingleOrNull();
    if (alreadyRun != null) return 0;

    final source = jsonDecode(await _loadAsset()) as List<dynamic>;
    final entryByName = <String, WeightEntry>{
      for (final raw in source.cast<Map<String, dynamic>>())
        raw['name']! as String: WeightEntry.values.byName(
          raw['weightEntry'] as String? ?? 'total',
        ),
    };

    final bundled = await (_database.select(
      _database.exercises,
    )..where((exercise) => exercise.isCustom.equals(false))).get();
    final changes = <(int, WeightEntry)>[];
    for (final exercise in bundled) {
      final entry = entryByName[exercise.name];
      if (entry == null || exercise.weightEntry == entry) continue;
      changes.add((exercise.id, entry));
    }

    await _database.batch((batch) {
      for (final change in changes) {
        batch.update(
          _database.exercises,
          ExercisesCompanion(weightEntry: Value(change.$2)),
          where: (exercise) => exercise.id.equals(change.$1),
        );
      }
      batch.insert(
        _database.appSettings,
        AppSettingsCompanion.insert(
          key: _weightEntryBackfillKey,
          value: 'true',
        ),
        mode: InsertMode.insertOrReplace,
      );
    });
    return changes.length;
  }

  Future<bool> backfillPullUpOnce() async {
    final alreadyRun = await (_database.select(
      _database.appSettings,
    )..where((row) => row.key.equals(_pullUpBackfillKey))).getSingleOrNull();
    if (alreadyRun != null) return false;
    final existing = await (_database.select(
      _database.exercises,
    )..where((exercise) => exercise.name.equals('Pull-Up'))).getSingleOrNull();
    var changed = false;
    await _database.transaction(() async {
      if (existing == null) {
        await _database
            .into(_database.exercises)
            .insert(
              ExercisesCompanion.insert(
                name: 'Pull-Up',
                category: ExerciseCategory.bodyweight,
                muscleGroup: 'back',
                primaryMuscles: const Value('["lats"]'),
                secondaryMuscles: const Value(
                  '["biceps","brachialis","mid_lower_traps","forearms"]',
                ),
                preferredLoadingMode: const Value(LoadingMode.bodyweightAdded),
                bodyweightFactor: const Value(1),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        changed = true;
      } else if (existing.preferredLoadingMode == LoadingMode.external) {
        // Only heal the exact legacy-seed breakage: a Pull-Up left on the
        // `external` column default, which demanded a bogus weight. A user who
        // deliberately picked strict `bodyweight` (or anything else) is left
        // alone — over-correcting would fight their choice.
        await (_database.update(_database.exercises)
              ..where((exercise) => exercise.id.equals(existing.id)))
            .write(
              const ExercisesCompanion(
                preferredLoadingMode: Value(LoadingMode.bodyweightAdded),
              ),
            );
        changed = true;
      }
      await _database
          .into(_database.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(key: _pullUpBackfillKey, value: 'true'),
          );
    });
    return changed;
  }
}

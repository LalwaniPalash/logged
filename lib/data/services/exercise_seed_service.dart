import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../../core/domain/enums.dart';
import '../database/app_database.dart';

class ExerciseSeedService {
  ExerciseSeedService(this._database, {Future<String> Function()? loadAsset})
    : _loadAsset = loadAsset ?? (() => rootBundle.loadString(_assetPath));

  static const _assetPath = 'assets/data/exercise_library.json';
  final AppDatabase _database;
  final Future<String> Function() _loadAsset;

  Future<void> seedIfEmpty() async {
    final source = await _loadAsset();
    final data = jsonDecode(source) as List<dynamic>;
    await _database.batch((batch) {
      batch.insertAll(
        _database.exercises,
        [
          for (final raw in data.cast<Map<String, dynamic>>())
            ExercisesCompanion.insert(
              name: raw['name']! as String,
              category: ExerciseCategory.values.byName(
                raw['category']! as String,
              ),
              muscleGroup: raw['muscleGroup']! as String,
              primaryMuscles: Value(
                jsonEncode(
                  (raw['primaryMuscles'] as List<dynamic>?) ?? const [],
                ),
              ),
              secondaryMuscles: Value(
                jsonEncode(
                  (raw['secondaryMuscles'] as List<dynamic>?) ?? const [],
                ),
              ),
              defaultUnit: Value(
                WeightUnit.values.byName(raw['defaultUnit']! as String),
              ),
              weightEntry: Value(
                WeightEntry.values.byName(
                  raw['weightEntry'] as String? ?? 'total',
                ),
              ),
              // Without this, every seeded exercise fell back to the column
              // default `external`, so a bodyweight lift like Pull-Up demanded a
              // weight to log on fresh installs. Honour the asset's mode.
              preferredLoadingMode: Value(
                LoadingMode.values.byName(
                  raw['preferredLoadingMode'] as String? ?? 'external',
                ),
              ),
              isCustom: const Value(false),
              isArchived: const Value(false),
            ),
        ],
        mode: InsertMode
            .insertOrIgnore, // a stray duplicate name can't nuke the seed
      );
    });
  }
}

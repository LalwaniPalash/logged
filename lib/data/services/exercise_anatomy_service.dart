import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

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
}

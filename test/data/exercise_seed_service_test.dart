import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/services/exercise_seed_service.dart';

void main() {
  test('seeding is idempotent', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final source = jsonEncode([
      {
        'name': 'Cable Lat Pulldown',
        'category': 'strength',
        'muscleGroup': 'lats',
        'primaryMuscles': ['lats'],
        'secondaryMuscles': ['biceps', 'brachialis'],
        'defaultUnit': 'lb',
      },
    ]);
    final service = ExerciseSeedService(
      database,
      loadAsset: () async => source,
    );

    await service.seedIfEmpty();
    await service.seedIfEmpty();

    final exercises = await database.select(database.exercises).get();
    expect(exercises, hasLength(1));
    expect(exercises.single.defaultUnit.name, 'lb');
    expect(exercises.single.weightEntry, WeightEntry.total);
    expect(jsonDecode(exercises.single.primaryMuscles), ['lats']);
    expect(jsonDecode(exercises.single.secondaryMuscles), [
      'biceps',
      'brachialis',
    ]);
  });
}

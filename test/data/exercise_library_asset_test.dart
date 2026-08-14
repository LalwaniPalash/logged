import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/services/exercise_seed_service.dart';
import 'package:logged/data/services/workout_template_seed_service.dart';

/// These tests read the REAL bundled asset from disk (not a fixture), so a
/// corrupt or malformed library file fails CI instead of only crashing at
/// runtime on a user's first launch.
void main() {
  final assetFile = File('assets/data/exercise_library.json');

  test('bundled exercise library is valid JSON with clean leading bytes', () {
    expect(
      assetFile.existsSync(),
      isTrue,
      reason: 'assets/data/exercise_library.json must exist',
    );
    final raw = assetFile.readAsStringSync();
    // Guard specifically against the diff-artifact bug (a stray leading char).
    expect(
      raw.trimLeft().startsWith('['),
      isTrue,
      reason: 'Library must start with a JSON array, no stray prefix bytes',
    );
    expect(() => jsonDecode(raw), returnsNormally);
  });

  test('every entry has valid fields and enum values', () {
    final data = jsonDecode(assetFile.readAsStringSync()) as List<dynamic>;
    expect(
      data,
      hasLength(1278),
      reason: 'Every bundled exercise must have reviewed anatomy metadata',
    );

    final names = <String>{};
    for (final raw in data.cast<Map<String, dynamic>>()) {
      final name = raw['name'] as String?;
      expect(
        name != null && name.trim().isNotEmpty,
        isTrue,
        reason: 'Every exercise needs a non-empty name',
      );
      expect(
        names.add(name!),
        isTrue,
        reason: 'Duplicate exercise name: $name',
      );
      // These byName lookups throw if the asset uses an unknown category/unit.
      expect(
        () => ExerciseCategory.values.byName(raw['category'] as String),
        returnsNormally,
      );
      expect(
        () => WeightUnit.values.byName(raw['defaultUnit'] as String),
        returnsNormally,
      );
      expect(
        () =>
            WeightEntry.values.byName(raw['weightEntry'] as String? ?? 'total'),
        returnsNormally,
      );
      expect((raw['muscleGroup'] as String).trim(), isNotEmpty);

      final primary = (raw['primaryMuscles'] as List<dynamic>?)?.cast<String>();
      final secondary = (raw['secondaryMuscles'] as List<dynamic>?)
          ?.cast<String>();
      expect(primary, isNotNull, reason: '$name is missing primaryMuscles');
      expect(
        primary,
        isNotEmpty,
        reason: '$name needs at least one primary muscle',
      );
      expect(secondary, isNotNull, reason: '$name is missing secondaryMuscles');

      final primarySet = primary!.toSet();
      final secondarySet = secondary!.toSet();
      expect(
        primarySet,
        hasLength(primary.length),
        reason: '$name contains duplicate primary muscles',
      );
      expect(
        secondarySet,
        hasLength(secondary.length),
        reason: '$name contains duplicate secondary muscles',
      );
      expect(
        primarySet.intersection(secondarySet),
        isEmpty,
        reason: '$name lists the same muscle as primary and secondary',
      );

      for (final id in [...primary, ...secondary]) {
        expect(
          () => MuscleId.fromId(id),
          returnsNormally,
          reason: '$name references unknown muscle $id',
        );
      }
    }
  });

  test('representative exercises have movement-specific anatomy', () {
    final data = (jsonDecode(assetFile.readAsStringSync()) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    Map<String, dynamic> exercise(String name) =>
        data.singleWhere((entry) => entry['name'] == name);

    expect(exercise('Barbell Bench Press')['primaryMuscles'], [
      'mid_lower_chest',
    ]);
    expect(
      exercise('Barbell Bench Press')['secondaryMuscles'],
      containsAll(['front_delts', 'triceps']),
    );
    expect(exercise('Pec Deck')['primaryMuscles'], [
      'mid_lower_chest',
      'upper_chest',
    ]);
    expect(exercise('Cable Crossover - Low Pulley')['primaryMuscles'], [
      'upper_chest',
    ]);
    expect(exercise('Decline Push-Up')['primaryMuscles'], ['upper_chest']);
    expect(exercise('Landmine Press')['primaryMuscles'], [
      'front_delts',
      'side_delts',
    ]);
    expect(exercise('Cable Lat Pulldown')['primaryMuscles'], ['lats']);
    expect(
      exercise('Barbell Back Squat')['primaryMuscles'],
      containsAll(['quads', 'glute_max']),
    );
    expect(exercise('Zercher Squat')['primaryMuscles'], ['quads']);
    expect(
      exercise('Zercher Squat')['secondaryMuscles'],
      containsAll(['glute_max', 'hamstrings']),
    );
    expect(exercise('Dumbbell Lateral Raise')['primaryMuscles'], [
      'side_delts',
    ]);
    expect(exercise('Dumbbell Lateral Raise')['weightEntry'], 'perSide');
    expect(exercise('Dumbbell Bench Press')['weightEntry'], 'perSide');
    expect(exercise('Dumbbell Bicep Curl')['weightEntry'], 'perSide');
    expect(exercise('Dumbbell Chest Fly')['weightEntry'], 'perSide');
    expect(
      exercise('Dumbbell Lateral Raise')['secondaryMuscles'],
      contains('upper_traps'),
    );
    expect(exercise('Dumbbell Shrug')['primaryMuscles'], ['upper_traps']);
    expect(
      exercise('Dumbbell Shrug')['secondaryMuscles'],
      containsAll(['forearms', 'neck']),
    );
    expect(exercise('Stationary Bike')['primaryMuscles'], ['quads']);
    expect(exercise('Hip Flexor Stretch')['primaryMuscles'], ['hip_flexors']);
    expect(exercise('Smith Machine One-Arm Upright Row')['primaryMuscles'], [
      'side_delts',
    ]);
    expect(
      exercise('Smith Machine One-Arm Upright Row')['secondaryMuscles'],
      containsAll(['upper_traps', 'mid_lower_traps']),
    );
    expect(
      exercise('Smith Machine One-Arm Upright Row')['weightEntry'],
      'perSide',
    );
    expect(exercise('Wide-Grip Pulldown Behind The Neck')['primaryMuscles'], [
      'lats',
    ]);
    expect(
      exercise('Wide-Grip Pulldown Behind The Neck')['secondaryMuscles'],
      containsAll(['biceps', 'rhomboids']),
    );
  });

  test('seeds the real asset through the real seeding path', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final service = ExerciseSeedService(
      database,
      loadAsset: assetFile.readAsString,
    );

    await service.seedIfEmpty();

    final rows = await database.select(database.exercises).get();
    final expected = (jsonDecode(assetFile.readAsStringSync()) as List).length;
    expect(rows, hasLength(expected));
  });

  test(
    'seeds the default workout plan templates when templates are empty',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await ExerciseSeedService(
        database,
        loadAsset: assetFile.readAsString,
      ).seedIfEmpty();
      await WorkoutTemplateSeedService(database).seedIfEmpty();

      final templates = await database.select(database.templates).get();
      final templateExercises = await database
          .select(database.templateExercises)
          .get();
      final exercises = await database.select(database.exercises).get();
      final exerciseNamesById = {
        for (final exercise in exercises) exercise.id: exercise.name,
      };

      expect(templates.map((template) => template.name), [
        'Monday — Push A',
        'Tuesday — Pull A',
        'Wednesday — Legs A',
        'Thursday — Push B',
        'Friday — Pull B',
        'Saturday — Legs B',
      ]);
      expect(templateExercises, hasLength(89));

      final monday = templates.firstWhere(
        (template) => template.name == 'Monday — Push A',
      );
      final mondayNames =
          (templateExercises
                  .where((item) => item.templateId == monday.id)
                  .toList()
                ..sort((a, b) => a.position.compareTo(b.position)))
              .map((item) => exerciseNamesById[item.exerciseId])
              .toList();
      expect(mondayNames, contains('Cable Crossover - Low Pulley'));
      expect(mondayNames, contains('Cross-Body Shoulder Stretch'));
      final mondayBench = templateExercises.firstWhere(
        (item) =>
            item.templateId == monday.id &&
            exerciseNamesById[item.exerciseId] == 'Barbell Bench Press',
      );
      expect(mondayBench.targetSets, 4);
      expect(mondayBench.minReps, 5);
      expect(mondayBench.maxReps, 8);
      expect(mondayBench.restSeconds, 180);
      expect(mondayBench.eccentricSec, 3);
      expect(mondayBench.bottomPauseSec, 1);
      expect(mondayBench.concentricSec, 1);
      expect(mondayBench.topPauseSec, 0);
      final hipFlexorStretch = templateExercises.firstWhere(
        (item) =>
            item.templateId == monday.id &&
            exerciseNamesById[item.exerciseId] == 'Hip Flexor Stretch',
      );
      expect(hipFlexorStretch.sidesPerSet, 2);

      final thursday = templates.firstWhere(
        (template) => template.name == 'Thursday — Push B',
      );
      final thursdayNames =
          (templateExercises
                  .where((item) => item.templateId == thursday.id)
                  .toList()
                ..sort((a, b) => a.position.compareTo(b.position)))
              .map((item) => exerciseNamesById[item.exerciseId])
              .toList();
      expect(thursdayNames, contains('Cable Crossover - Mid Pulley'));
    },
  );

  test(
    'upgrades existing default templates with prescription details',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await ExerciseSeedService(
        database,
        loadAsset: assetFile.readAsString,
      ).seedIfEmpty();

      final bench =
          await (database.select(database.exercises)..where(
                (exercise) => exercise.name.equals('Barbell Bench Press'),
              ))
              .getSingle();
      final templateId = await database
          .into(database.templates)
          .insert(
            TemplatesCompanion.insert(name: 'Monday — Push A', position: 0),
          );
      await database
          .into(database.templateExercises)
          .insert(
            TemplateExercisesCompanion.insert(
              templateId: templateId,
              exerciseId: bench.id,
              position: 0,
              targetSets: const Value.absent(),
            ),
          );

      await WorkoutTemplateSeedService(database).seedIfEmpty();

      final templates = await database.select(database.templates).get();
      final monday = templates.firstWhere(
        (template) => template.name == 'Monday — Push A',
      );
      final rows =
          (await (database.select(
              database.templateExercises,
            )..where((row) => row.templateId.equals(monday.id))).get())
            ..sort((a, b) => a.position.compareTo(b.position));
      final exercises = await database.select(database.exercises).get();
      final exerciseNamesById = {
        for (final exercise in exercises) exercise.id: exercise.name,
      };

      expect(rows, hasLength(17));
      expect(exerciseNamesById[rows.first.exerciseId], 'Barbell Bench Press');
      expect(rows.first.targetSets, 4);
      expect(rows.first.minReps, 5);
      expect(rows.first.maxReps, 8);
      expect(rows.first.eccentricSec, 3);
      expect(
        rows.map((row) => exerciseNamesById[row.exerciseId]),
        contains('Hip Flexor Stretch'),
      );
      expect(
        templates.map((template) => template.name),
        containsAll([
          'Monday — Push A',
          'Tuesday — Pull A',
          'Wednesday — Legs A',
          'Thursday — Push B',
          'Friday — Pull B',
          'Saturday — Legs B',
        ]),
      );
    },
  );

  test(
    'upgrades a fully-prescribed pre-v8 template on the next launch',
    () async {
      // Simulates an install that already ran the old plan: the template has
      // COMPLETE prescriptions (so the empty-prescription refresh path alone
      // would skip it), and no `templatePlanVersion` app_settings row exists
      // yet. seedIfEmpty() must still replace its exercises with the new
      // plan content — this is what gets a real device off a stale plan.
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await ExerciseSeedService(
        database,
        loadAsset: assetFile.readAsString,
      ).seedIfEmpty();

      final squat =
          await (database.select(database.exercises)..where(
                (exercise) => exercise.name.equals('Barbell Back Squat'),
              ))
              .getSingle();
      final templateId = await database
          .into(database.templates)
          .insert(
            TemplatesCompanion.insert(name: 'Wednesday — Legs A', position: 2),
          );
      await database
          .into(database.templateExercises)
          .insert(
            TemplateExercisesCompanion.insert(
              templateId: templateId,
              exerciseId: squat.id,
              position: 0,
              targetSets: const Value(4),
              minReps: const Value(5),
              maxReps: const Value(8),
              restSeconds: const Value(180),
              prescriptionNotes: const Value('stale pre-upgrade prescription'),
            ),
          );

      await WorkoutTemplateSeedService(database).seedIfEmpty();

      final rows =
          (await (database.select(
              database.templateExercises,
            )..where((row) => row.templateId.equals(templateId))).get())
            ..sort((a, b) => a.position.compareTo(b.position));

      expect(
        rows.length,
        greaterThan(1),
        reason:
            'stale full prescriptions must not block the version-gated upgrade',
      );
      expect(
        rows.first.prescriptionNotes,
        isNot('stale pre-upgrade prescription'),
      );
      expect(rows.first.prescriptionNotes, contains('Zercher Squat'));

      final storedVersion =
          await (database.select(database.appSettings)
                ..where((row) => row.key.equals('templatePlanVersion')))
              .getSingleOrNull();
      expect(storedVersion?.value, 'v8');

      // A second run must not error and must leave the upgraded content alone.
      await WorkoutTemplateSeedService(database).seedIfEmpty();
      final rowsAfterSecondRun = await (database.select(
        database.templateExercises,
      )..where((row) => row.templateId.equals(templateId))).get();
      expect(rowsAfterSecondRun.length, rows.length);
    },
  );
}

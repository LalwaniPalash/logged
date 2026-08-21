import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/session_energy.dart';

void main() {
  SessionEnergySet set({
    double? weightValue,
    WeightUnit? unit = WeightUnit.kg,
    WeightEntry weightEntry = WeightEntry.total,
    int sideCount = 1,
    int? reps,
    int? durationSec,
    LoadingMode loadingMode = LoadingMode.external,
    bool isWarmup = false,
    ExerciseCategory category = ExerciseCategory.strength,
    String muscleGroup = 'chest',
    double bodyweightFactor = 1,
  }) => SessionEnergySet(
    weightValue: weightValue,
    unit: weightValue == null ? null : unit,
    weightEntry: weightEntry,
    sideCount: sideCount,
    reps: reps,
    durationSec: durationSec,
    loadingMode: loadingMode,
    isWarmup: isWarmup,
    category: category,
    muscleGroup: muscleGroup,
    bodyweightFactor: bodyweightFactor,
  );

  test('plain barbell set uses the resistance work path', () {
    final kcal = estimateSessionKcal(
      sets: [set(weightValue: 100, reps: 10, muscleGroup: 'chest')],
      elapsed: const Duration(minutes: 1),
      bodyweightKg: 80,
    );
    expect(kcal, closeTo(6.5919, 0.001));
  });

  test('bodyweight set uses bodyweight times factor', () {
    final kcal = estimateSessionKcal(
      sets: [
        set(
          reps: 10,
          loadingMode: LoadingMode.bodyweight,
          muscleGroup: 'quads',
          bodyweightFactor: 0.75,
        ),
      ],
      elapsed: const Duration(minutes: 1),
      bodyweightKg: 80,
    );
    expect(kcal, closeTo(5.2064, 0.001));
  });

  test('assisted set subtracts assistance and never goes negative', () {
    final kcal = estimateSessionKcal(
      sets: [
        set(
          weightValue: 90,
          reps: 8,
          loadingMode: LoadingMode.bodyweightAssisted,
          muscleGroup: 'back',
          bodyweightFactor: 1,
        ),
      ],
      elapsed: const Duration(minutes: 1),
      bodyweightKg: 80,
    );
    expect(kcal, closeTo(1.26, 0.001));
  });

  test('cardio duration uses the MET path, not the work path', () {
    final kcal = estimateSessionKcal(
      sets: [
        set(
          durationSec: 600,
          category: ExerciseCategory.cardio,
          loadingMode: LoadingMode.bodyweight,
          muscleGroup: 'legs',
        ),
      ],
      elapsed: const Duration(minutes: 10),
      bodyweightKg: 80,
    );
    expect(kcal, 84);
  });

  test('warmups add no work but their minutes still count as rest', () {
    final kcal = estimateSessionKcal(
      sets: [
        set(weightValue: 60, reps: 10, muscleGroup: 'chest', isWarmup: true),
      ],
      elapsed: const Duration(minutes: 10),
      bodyweightKg: 80,
    );
    // 10 min entirely at rest MET: 1.5 * 3.5 * 80 / 200 * 10 = 21.0.
    // Identical to the zero-set session below, which is the point — a warm-up
    // adds no work, so its minutes are worth exactly what standing there is.
    expect(kcal, closeTo(21, 0.001));
  });

  test('session with zero sets returns only the rest component', () {
    final kcal = estimateSessionKcal(
      sets: const [],
      elapsed: const Duration(minutes: 10),
      bodyweightKg: 80,
    );
    expect(kcal, 21);
  });

  test('every muscle group in the seed library has an explicit ROM', () async {
    // Guards the failure this table already had once: it was keyed on 'quads'
    // and 'legs' while the library ships 'quads/hamstrings/glutes' and
    // 'full body/olympic', so 141 exercises silently took the default ROM.
    // Assert against the asset itself, never a hand-copied list of groups.
    final raw = await File('assets/data/exercise_library.json').readAsString();
    final decoded = jsonDecode(raw);
    final entries = (decoded is List ? decoded : decoded['exercises'] as List)
        .cast<Map<String, dynamic>>();
    final groups = {
      for (final entry in entries)
        ((entry['muscleGroup'] ?? entry['muscle_group']) as String)
            .toLowerCase(),
    };
    expect(groups, isNotEmpty);
    expect(
      groups.where((group) => !muscleGroupRomMetres.containsKey(group)),
      isEmpty,
      reason: 'add these groups to muscleGroupRomMetres with a real ROM',
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/progression.dart';
import 'package:logged/data/database/app_database.dart';

void main() {
  SetEntry set({
    int reps = 8,
    double? weight = 80,
    WeightUnit unit = WeightUnit.kg,
    WeightEntry entry = WeightEntry.total,
    double? rpe = 8,
    bool warmup = false,
  }) => SetEntry(
    id: 1,
    sessionExerciseId: 1,
    setNumber: 1,
    reps: reps,
    weightValue: weight,
    unit: weight == null ? null : unit,
    weightEntry: entry,
    sideCount: 1,
    loadingMode: LoadingMode.external,
    isWarmup: warmup,
    rpe: rpe,
  );

  group('double progression matrix', () {
    for (final entry in WeightEntry.values) {
      test('hit top range increases kg entered value for ${entry.name}', () {
        final result = suggestNextSet(
          lastExerciseSets: [set(reps: 10, entry: entry)],
          minReps: 6,
          maxReps: 10,
          targetRpe: 8,
          weightEntry: entry,
          unit: WeightUnit.kg,
        )!;
        expect(result.weightValue, 82.5);
        expect(result.reps, 6);
      });

      test('hit top range increases lb entered value for ${entry.name}', () {
        final result = suggestNextSet(
          lastExerciseSets: [
            set(reps: 10, weight: 180, unit: WeightUnit.lb, entry: entry),
          ],
          minReps: 6,
          maxReps: 10,
          targetRpe: 8,
          weightEntry: entry,
          unit: WeightUnit.lb,
        )!;
        expect(result.weightValue, 185);
        expect(result.reps, 6);
      });
    }

    test('mid-range adds one rep without changing load', () {
      final result = suggestNextSet(
        lastExerciseSets: [set(reps: 8)],
        minReps: 6,
        maxReps: 10,
        targetRpe: 8,
        weightEntry: WeightEntry.total,
        unit: WeightUnit.kg,
      )!;
      expect(result.weightValue, 80);
      expect(result.reps, 9);
    });

    test('missed reps and high RPE both hold load', () {
      for (final previous in [set(reps: 4), set(reps: 10, rpe: 9.5)]) {
        final result = suggestNextSet(
          lastExerciseSets: [previous],
          minReps: 6,
          maxReps: 10,
          targetRpe: 8,
          weightEntry: WeightEntry.total,
          unit: WeightUnit.kg,
        )!;
        expect(result.weightValue, 80);
      }
    });

    test('missing prescription matches last time', () {
      final result = suggestNextSet(
        lastExerciseSets: [set(reps: 7)],
        weightEntry: WeightEntry.total,
        unit: WeightUnit.kg,
      )!;
      expect(result.weightValue, 80);
      expect(result.reps, 7);
      expect(result.rationale, contains('Match last time'));
    });

    test('warmups are ignored and mixed units are converted', () {
      final result = suggestNextSet(
        lastExerciseSets: [
          set(reps: 12, weight: 20, warmup: true),
          set(reps: 8, weight: 220.46226218, unit: WeightUnit.lb),
        ],
        minReps: 6,
        maxReps: 10,
        targetRpe: 8,
        weightEntry: WeightEntry.total,
        unit: WeightUnit.kg,
      )!;
      expect(result.weightValue, closeTo(100, 0.001));
      expect(result.reps, 9);
    });
  });
}

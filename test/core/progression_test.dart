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
    LoadingMode mode = LoadingMode.external,
  }) => SetEntry(
    id: 1,
    sessionExerciseId: 1,
    setNumber: 1,
    reps: reps,
    weightValue: weight,
    unit: weight == null ? null : unit,
    weightEntry: entry,
    sideCount: 1,
    loadingMode: mode,
    isWarmup: warmup,
    rpe: rpe,
    muscleBias: null,
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

  group('assisted lifts progress by REMOVING assistance', () {
    test('hitting the top of the range drops the assistance load', () {
      final result = suggestNextSet(
        lastExerciseSets: [
          set(reps: 10, weight: 20, mode: LoadingMode.bodyweightAssisted),
        ],
        minReps: 6,
        maxReps: 10,
        targetRpe: 8,
        weightEntry: WeightEntry.total,
        unit: WeightUnit.kg,
        loadingMode: LoadingMode.bodyweightAssisted,
      )!;
      // Less assistance, not more — the assisted lift got harder.
      expect(result.weightValue, 17.5);
      expect(result.reps, 6);
      expect(result.rationale, contains('assistance'));
    });

    test('the least-assisted set is treated as the top set', () {
      final result = suggestNextSet(
        lastExerciseSets: [
          set(reps: 10, weight: 30, mode: LoadingMode.bodyweightAssisted),
          set(reps: 10, weight: 15, mode: LoadingMode.bodyweightAssisted),
        ],
        minReps: 6,
        maxReps: 10,
        targetRpe: 8,
        weightEntry: WeightEntry.total,
        unit: WeightUnit.kg,
        loadingMode: LoadingMode.bodyweightAssisted,
      )!;
      // Progresses from the harder (15 kg assist) set, not the 30 kg one.
      expect(result.weightValue, 12.5);
    });

    test('assistance never goes below zero', () {
      final result = suggestNextSet(
        lastExerciseSets: [
          set(reps: 10, weight: 1, mode: LoadingMode.bodyweightAssisted),
        ],
        minReps: 6,
        maxReps: 10,
        targetRpe: 8,
        weightEntry: WeightEntry.total,
        unit: WeightUnit.kg,
        loadingMode: LoadingMode.bodyweightAssisted,
      )!;
      expect(result.weightValue, 0);
    });

    test('history logged in a different mode is not reused', () {
      // Last session was assisted (20 kg assistance); the user has since
      // switched the lift to strict bodyweight. The old assistance kilos must
      // NOT leak in as a load for the new mode.
      final result = suggestNextSet(
        lastExerciseSets: [
          set(reps: 10, weight: 20, mode: LoadingMode.bodyweightAssisted),
        ],
        minReps: 6,
        maxReps: 10,
        targetRpe: 8,
        weightEntry: WeightEntry.total,
        unit: WeightUnit.kg,
        loadingMode: LoadingMode.bodyweight,
      );
      expect(result, isNull);
    });
  });
}

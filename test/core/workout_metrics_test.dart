import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/workout_metrics.dart';
import 'package:logged/data/database/app_database.dart';

void main() {
  test('converts pounds to kilograms precisely', () {
    expect(weightKg(100, WeightUnit.lb), closeTo(45.359237, 0.000001));
    expect(weightKg(35, WeightUnit.kg), 35);
  });

  test('calculates Epley estimated 1RM in normalized kilograms', () {
    expect(
      estimatedOneRepMax(weightValue: 100, unit: WeightUnit.lb, reps: 10),
      closeTo(60.479, 0.001),
    );
  });

  test('calculates volume only for valid weighted repetitions', () {
    expect(
      setVolumeKg(weightValue: 100, unit: WeightUnit.lb, reps: 10),
      closeTo(453.59237, 0.000001),
    );
    expect(setVolumeKg(weightValue: 20, unit: WeightUnit.kg, reps: null), 0);
  });

  test('doubles per-hand load for volume but not for estimated 1RM', () {
    expect(
      setVolumeKg(
        weightValue: 7.5,
        unit: WeightUnit.lb,
        reps: 10,
        entry: WeightEntry.perSide,
      ),
      closeTo(weightKg(15, WeightUnit.lb) * 10, 0.000001),
    );
    expect(
      estimatedOneRepMax(weightValue: 7.5, unit: WeightUnit.lb, reps: 10),
      closeTo(weightKg(7.5, WeightUnit.lb) * (1 + 10 / 30), 0.000001),
    );
  });

  test('computes session totals across exercises and excludes warmups', () {
    final totals = computeSessionTotals([
      (
        sets: [
          SetEntry(
            id: 1,
            sessionExerciseId: 1,
            setNumber: 1,
            reps: 8,
            weightValue: 20,
            unit: WeightUnit.kg,
            weightEntry: WeightEntry.perSide,
            sideCount: 2,
            loadingMode: LoadingMode.external,
            isWarmup: false,
            isDone: false,
            muscleBiasWeights: null,
          ),
          SetEntry(
            id: 2,
            sessionExerciseId: 1,
            setNumber: 2,
            reps: 5,
            weightValue: 10,
            unit: WeightUnit.kg,
            weightEntry: WeightEntry.total,
            sideCount: 1,
            loadingMode: LoadingMode.external,
            isWarmup: true,
            isDone: false,
            muscleBiasWeights: null,
          ),
        ],
      ),
      (
        sets: [
          SetEntry(
            id: 3,
            sessionExerciseId: 2,
            setNumber: 1,
            reps: 10,
            weightValue: 100,
            unit: WeightUnit.lb,
            weightEntry: WeightEntry.total,
            sideCount: 1,
            loadingMode: LoadingMode.external,
            isWarmup: false,
            isDone: false,
            muscleBiasWeights: null,
          ),
        ],
      ),
    ]);

    expect(totals.exerciseCount, 2);
    expect(totals.setCount, 2);
    expect(totals.totalVolumeKg, closeTo(1093.59237, 0.000001));
  });
}

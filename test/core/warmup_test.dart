import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/plate_math.dart';
import 'package:logged/core/domain/warmup.dart';

void main() {
  test('generateWarmup is empty for bodyweight lifts', () {
    expect(
      generateWarmup(
        workingWeight: 100,
        unit: WeightUnit.kg,
        inventory: PlateInventory(),
        loadingMode: LoadingMode.bodyweight,
      ),
      isEmpty,
    );
  });

  test('generateWarmup is empty for assisted bodyweight lifts', () {
    expect(
      generateWarmup(
        workingWeight: 40,
        unit: WeightUnit.kg,
        inventory: PlateInventory(),
        loadingMode: LoadingMode.bodyweightAssisted,
      ),
      isEmpty,
    );
  });

  test(
    'at or below the bar there is no BAR rung, but there is still a ramp',
    () {
      // This used to assert `isEmpty`. That was wrong: it left "Warm-up"
      // permanently disabled for every machine, dumbbell and light exercise,
      // because the bar weight is a barbell concept the rest of them never meet.
      final warmups = generateWarmup(
        workingWeight: 20,
        unit: WeightUnit.kg,
        inventory: PlateInventory(),
      );

      expect(warmups, isNotEmpty);
      expect(warmups.any((warmup) => warmup.label.startsWith('Bar')), isFalse);
      expect(warmups.every((warmup) => warmup.weight < 20), isTrue);
    },
  );

  test(
    'generateWarmup returns ascending, loadable rungs below the working weight',
    () {
      final inventory = PlateInventory();
      final warmups = generateWarmup(
        workingWeight: 100,
        unit: WeightUnit.kg,
        inventory: inventory,
      );

      expect(warmups.map((set) => set.weight), [20.0, 40.0, 60.0, 80.0]);
      for (var index = 0; index < warmups.length; index++) {
        expect(
          warmups[index].weight,
          roundToLoadable(
            warmups[index].weight,
            unit: WeightUnit.kg,
            inventory: inventory,
          ),
        );
        if (index > 0) {
          expect(warmups[index].weight, greaterThan(warmups[index - 1].weight));
        }
        expect(warmups[index].weight, lessThan(100));
      }
    },
  );

  test('generateWarmup collapses duplicate snapped rungs', () {
    final warmups = generateWarmup(
      workingWeight: 40,
      unit: WeightUnit.kg,
      inventory: PlateInventory(kgPlateSizes: const [5]),
    );

    expect(warmups, const [WarmupSet(weight: 30, reps: 2, label: '80% × 2')]);
  });

  test('a sub-bar machine load still gets a warm-up ramp', () {
    // Regression: gating the whole ramp on the 20 kg bar weight left "Warm-up"
    // permanently disabled for every light or non-barbell exercise. A 10 kg
    // machine set is a real working set and deserves 40/60/80% rungs.
    final warmups = generateWarmup(
      workingWeight: 10,
      unit: WeightUnit.kg,
      inventory: PlateInventory(),
      workingReps: 10,
    );

    expect(warmups, isNotEmpty);
    expect(
      warmups.every((warmup) => warmup.weight < 10),
      isTrue,
      reason: 'a warm-up rung is never at or above the working weight',
    );
    expect(
      warmups.any((warmup) => warmup.label.startsWith('Bar')),
      isFalse,
      reason: 'there is no bar rung below the bar',
    );
  });

  test('a load below one plate step has no ramp worth logging', () {
    expect(
      generateWarmup(
        workingWeight: 4,
        unit: WeightUnit.kg,
        inventory: PlateInventory(),
      ),
      isEmpty,
    );
  });

  test('a real barbell load keeps its bar rung', () {
    final warmups = generateWarmup(
      workingWeight: 100,
      unit: WeightUnit.kg,
      inventory: PlateInventory(),
      workingReps: 5,
    );

    expect(warmups.first.label, startsWith('Bar'));
    expect(warmups.first.weight, PlateInventory().barWeightFor(WeightUnit.kg));
  });
}

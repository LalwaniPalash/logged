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
    'generateWarmup is empty when the working load is at or below the bar',
    () {
      expect(
        generateWarmup(
          workingWeight: 20,
          unit: WeightUnit.kg,
          inventory: PlateInventory(),
        ),
        isEmpty,
      );
      expect(
        generateWarmup(
          workingWeight: 15,
          unit: WeightUnit.kg,
          inventory: PlateInventory(),
        ),
        isEmpty,
      );
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
}

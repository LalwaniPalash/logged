import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/plate_math.dart';

void main() {
  test('solvePlates finds an exact kg match', () {
    final solution = solvePlates(
      targetTotal: 100,
      unit: WeightUnit.kg,
      inventory: PlateInventory(),
    );

    expect(solution.perSidePlates, [25.0, 15.0]);
    expect(solution.achievedTotal, 100);
    expect(solution.shortfall, 0);
    expect(solution.isExact, isTrue);
  });

  test(
    'solvePlates returns the closest load under target and never rounds up',
    () {
      final solution = solvePlates(
        targetTotal: 103.6,
        unit: WeightUnit.kg,
        inventory: PlateInventory(),
      );

      expect(solution.achievedTotal, 102.5);
      expect(solution.shortfall, closeTo(1.1, 1e-9));
      expect(solution.achievedTotal, lessThanOrEqualTo(103.6));
    },
  );

  test('solvePlates respects pair-count exhaustion and falls back smaller', () {
    final solution = solvePlates(
      targetTotal: 120,
      unit: WeightUnit.kg,
      inventory: PlateInventory(kgPairCounts: {25: 1, 20: 1, 5: 1}),
    );

    expect(solution.perSidePlates, [25.0, 20.0, 5.0]);
    expect(solution.achievedTotal, 120);
    expect(solution.shortfall, 0);
  });

  test('solvePlates follows the default lb bar and plates', () {
    final solution = solvePlates(
      targetTotal: 225,
      unit: WeightUnit.lb,
      inventory: PlateInventory(),
    );

    expect(solution.perSidePlates, [45.0, 45.0]);
    expect(solution.achievedTotal, 225);
    expect(solution.shortfall, 0);
  });

  test('solvePlates reports the bar honestly when target is below it', () {
    final solution = solvePlates(
      targetTotal: 10,
      unit: WeightUnit.kg,
      inventory: PlateInventory(),
    );

    expect(solution.perSidePlates, isEmpty);
    expect(solution.achievedTotal, 20);
    expect(solution.shortfall, -10);
  });

  test('solvePlates supports per-implement loading', () {
    final solution = solvePlates(
      targetTotal: 32.5,
      unit: WeightUnit.kg,
      inventory: PlateInventory(),
      perImplement: true,
    );

    expect(solution.perSidePlates, [10.0, 2.5]);
    expect(solution.achievedTotal, 32.5);
    expect(solution.shortfall, 0);
  });

  test(
    'PlateInventory.fromJson falls back to defaults for malformed values',
    () {
      final inventory = PlateInventory.fromJson({
        'kg': {
          'barWeight': -5,
          'plateSizes': ['wat'],
          'pairCounts': {'25': 'oops'},
        },
        'lb': 'nope',
      });

      expect(inventory.kgBarWeight, 20);
      expect(inventory.kgPlateSizes, standardPlateSizesFor(WeightUnit.kg));
      expect(inventory.lbBarWeight, 45);
      expect(inventory.lbPlateSizes, standardPlateSizesFor(WeightUnit.lb));
    },
  );

  // An unloadable target has no exact match to early-exit on. The original
  // exhaustive search degraded exponentially there — 501.3 kg cost ~4.9s — and
  // the sheet re-solves on every keystroke, so this is a UI-freeze guard.
  test('solves unloadable heavy targets fast enough to run per keystroke', () {
    final inventory = PlateInventory();
    final elapsed = <int>[];
    for (final target in [101.3, 253.1, 301.9, 501.3]) {
      final stopwatch = Stopwatch()..start();
      final solution = solvePlates(
        targetTotal: target,
        unit: WeightUnit.kg,
        inventory: inventory,
      );
      stopwatch.stop();
      elapsed.add(stopwatch.elapsedMilliseconds);
      expect(
        solution.achievedTotal,
        lessThan(target),
        reason: 'an unloadable target must resolve strictly under, never over',
      );
    }
    expect(
      elapsed.reduce((a, b) => a + b),
      lessThan(500),
      reason: 'four heavy unloadable solves must stay far under a frame budget',
    );
  });

  test('falls back to greedy past any real barbell load without allocating', () {
    final solution = solvePlates(
      targetTotal: 100000,
      unit: WeightUnit.kg,
      inventory: PlateInventory(),
    );

    expect(solution.achievedTotal, lessThanOrEqualTo(100000));
    expect(solution.perSidePlates.first, 25.0);
    expect(solution.shortfall, greaterThanOrEqualTo(0));
  });
}

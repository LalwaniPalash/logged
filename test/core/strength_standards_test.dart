import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/strength_standards.dart';

void main() {
  group('countsForStandard gates which sets feed a benchmark', () {
    test('barbell lifts only count when externally loaded with a weight', () {
      expect(
        countsForStandard(
          lift: 'Barbell Bench Press',
          mode: LoadingMode.external,
          hasEnteredWeight: true,
        ),
        isTrue,
      );
      // A mis-tagged bodyweight/assisted bench, or one saved with no load, is out.
      expect(
        countsForStandard(
          lift: 'Barbell Bench Press',
          mode: LoadingMode.bodyweight,
          hasEnteredWeight: false,
        ),
        isFalse,
      );
      expect(
        countsForStandard(
          lift: 'Barbell Bench Press',
          mode: LoadingMode.external,
          hasEnteredWeight: false,
        ),
        isFalse,
      );
    });

    test('pull-up counts strict or weighted, never assisted', () {
      expect(
        countsForStandard(
          lift: 'Pull-Up',
          mode: LoadingMode.bodyweight,
          hasEnteredWeight: false,
        ),
        isTrue,
        reason: 'strict bodyweight pull-up needs no entered load',
      );
      expect(
        countsForStandard(
          lift: 'Pull-Up',
          mode: LoadingMode.bodyweightAdded,
          hasEnteredWeight: true,
        ),
        isTrue,
      );
      // Added mode with a blank plate would masquerade as a strict PR — out.
      expect(
        countsForStandard(
          lift: 'Pull-Up',
          mode: LoadingMode.bodyweightAdded,
          hasEnteredWeight: false,
        ),
        isFalse,
      );
      // Assisted is easier than the standard assumes — out.
      expect(
        countsForStandard(
          lift: 'Pull-Up',
          mode: LoadingMode.bodyweightAssisted,
          hasEnteredWeight: true,
        ),
        isFalse,
      );
    });

    test('chin-up follows the same rules as pull-up', () {
      expect(
        countsForStandard(
          lift: 'Chin-Up',
          mode: LoadingMode.bodyweight,
          hasEnteredWeight: false,
        ),
        isTrue,
      );
      expect(
        countsForStandard(
          lift: 'Chin-Up',
          mode: LoadingMode.bodyweightAssisted,
          hasEnteredWeight: true,
        ),
        isFalse,
      );
    });

    test('a new barbell lift is gated by hasEnteredWeight like the others', () {
      expect(
        countsForStandard(
          lift: 'Barbell Front Squat',
          mode: LoadingMode.external,
          hasEnteredWeight: true,
        ),
        isTrue,
      );
      expect(
        countsForStandard(
          lift: 'Barbell Front Squat',
          mode: LoadingMode.external,
          hasEnteredWeight: false,
        ),
        isFalse,
      );
    });

    test('non-benchmark lifts never count', () {
      expect(
        countsForStandard(
          lift: 'Cable Fly',
          mode: LoadingMode.external,
          hasEnteredWeight: true,
        ),
        isFalse,
      );
    });
  });

  for (final sex in [UserSex.male, UserSex.female]) {
    test('${sex.name} standards cross every level boundary', () {
      final results = [
        for (final load
            in sex == UserSex.male
                ? [40.0, 60.0, 90.0, 120.0, 150.0]
                : [20.0, 35.0, 55.0, 80.0, 105.0])
          standardFor(
            lift: 'Barbell Bench Press',
            sex: sex,
            bodyweightKg: 100,
            estOneRepMaxKg: load,
          )!.level,
      ];
      expect(results, StrengthLevel.values);
    });
  }

  test('weighted pull-up uses total resisted mass including bodyweight', () {
    final result = standardFor(
      lift: 'Pull-Up',
      sex: UserSex.male,
      bodyweightKg: 80,
      estOneRepMaxKg: 80 + 24,
    )!;
    expect(result.ratio, 1.3);
    expect(result.level, StrengthLevel.advanced);
  });

  test('a new barbell lift crosses every level boundary', () {
    final results = [
      for (final load in [55.0, 70.0, 95.0, 125.0, 170.0])
        standardFor(
          lift: 'Barbell Front Squat',
          sex: UserSex.male,
          bodyweightKg: 70,
          estOneRepMaxKg: load,
        )!.level,
    ];
    expect(results, StrengthLevel.values);
  });

  test('unset sex and unknown lifts do not produce a standard', () {
    expect(
      standardFor(
        lift: 'Barbell Bench Press',
        sex: UserSex.unset,
        bodyweightKg: 80,
        estOneRepMaxKg: 100,
      ),
      isNull,
    );
    expect(
      standardFor(
        lift: 'Cable Fly',
        sex: UserSex.male,
        bodyweightKg: 80,
        estOneRepMaxKg: 100,
      ),
      isNull,
    );
  });
}

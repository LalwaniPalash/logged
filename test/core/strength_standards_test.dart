import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/strength_standards.dart';

void main() {
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

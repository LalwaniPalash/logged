import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/muscle.dart';

void main() {
  test('muscle ids use stable JSON names and friendly labels', () {
    expect(MuscleId.upperChest.id, 'upper_chest');
    expect(MuscleId.upperChest.label, 'Upper chest');
    expect(MuscleId.tibialisAnterior.id, 'tibialis_anterior');
    expect(MuscleId.tibialisAnterior.label, 'Tibialis anterior');
  });

  test('muscle ids round-trip through JSON ids', () {
    for (final muscle in MuscleId.values) {
      expect(MuscleId.fromId(muscle.id), muscle);
    }
  });

  test('unknown muscle ids fail loudly', () {
    expect(() => MuscleId.fromId('unknown'), throwsArgumentError);
  });

  test('database muscle lists encode and decode in stable order', () {
    final encoded = encodeMuscleIds([MuscleId.sideDelts, MuscleId.upperTraps]);
    expect(encoded, '["side_delts","upper_traps"]');
    expect(decodeMuscleIds(encoded), [MuscleId.sideDelts, MuscleId.upperTraps]);
  });

  test('a repeated muscle id decodes once, in first-seen order', () {
    expect(
      decodeMuscleIds('["quads","glute_max","quads"]'),
      [MuscleId.quads, MuscleId.gluteMax],
    );
  });

  test('custom muscle selections require primary muscles and no overlap', () {
    expect(
      () => validateMuscleSelection(primary: const [], secondary: const []),
      throwsArgumentError,
    );
    expect(
      () => validateMuscleSelection(
        primary: const [MuscleId.sideDelts],
        secondary: const [MuscleId.sideDelts],
      ),
      throwsArgumentError,
    );
    expect(
      () => validateMuscleSelection(
        primary: const [MuscleId.sideDelts],
        secondary: const [MuscleId.upperTraps],
      ),
      returnsNormally,
    );
  });
}

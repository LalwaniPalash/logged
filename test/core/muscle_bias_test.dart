import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/core/domain/muscle_bias.dart';

void main() {
  group('resolveMuscleBiasShares', () {
    test('null bias splits legacy axis shares evenly', () {
      final shares = resolveMuscleBiasShares(null);
      expect(shares.shareA, 0.5);
      expect(shares.shareB, 0.5);
    });

    test('out-of-range bias still clamps for migration math', () {
      expect(resolveMuscleBiasShares(-5), resolveMuscleBiasShares(-1));
      expect(resolveMuscleBiasShares(5), resolveMuscleBiasShares(1));
    });
  });

  group('primaryMuscleBiasWeight', () {
    test('returns null when there is no explicit weight map', () {
      expect(
        primaryMuscleBiasWeight(muscle: MuscleId.quads, weights: null),
        isNull,
      );
    });

    test('returns matching weights for a two-muscle distribution', () {
      const weights = {MuscleId.quads: 0.25, MuscleId.gluteMax: 0.75};
      expect(
        primaryMuscleBiasWeight(muscle: MuscleId.quads, weights: weights),
        0.25,
      );
      expect(
        primaryMuscleBiasWeight(muscle: MuscleId.gluteMax, weights: weights),
        0.75,
      );
    });

    test('supports three-way distributions', () {
      const weights = {
        MuscleId.quads: 0.5,
        MuscleId.gluteMax: 0.3,
        MuscleId.hamstrings: 0.2,
      };
      expect(
        primaryMuscleBiasWeight(muscle: MuscleId.quads, weights: weights),
        0.5,
      );
      expect(
        primaryMuscleBiasWeight(muscle: MuscleId.gluteMax, weights: weights),
        0.3,
      );
      expect(
        primaryMuscleBiasWeight(muscle: MuscleId.hamstrings, weights: weights),
        0.2,
      );
    });

    test('returns null for muscles absent from the map', () {
      const weights = {MuscleId.quads: 0.6, MuscleId.gluteMax: 0.4};
      expect(
        primaryMuscleBiasWeight(muscle: MuscleId.hamstrings, weights: weights),
        isNull,
      );
    });
  });

  test('encodes and decodes muscle bias weights', () {
    const weights = {
      MuscleId.quads: 0.6,
      MuscleId.gluteMax: 0.4,
      MuscleId.hamstrings: 0.2,
    };
    final encoded = encodeMuscleBiasWeights(weights);
    expect(decodeMuscleBiasWeights(encoded), const {
      MuscleId.gluteMax: 0.4,
      MuscleId.hamstrings: 0.2,
      MuscleId.quads: 0.6,
    });
  });

  test('rescales share-scale weights to mean-1 multipliers', () {
    final even = rescaleMuscleBiasWeightsToMeanOne(const {
      MuscleId.quads: 1 / 3,
      MuscleId.gluteMax: 1 / 3,
      MuscleId.hamstrings: 1 / 3,
    })!;
    expect(even[MuscleId.quads], closeTo(1.0, 1e-9));
    expect(even[MuscleId.gluteMax], closeTo(1.0, 1e-9));
    expect(even[MuscleId.hamstrings], closeTo(1.0, 1e-9));

    final biased = rescaleMuscleBiasWeightsToMeanOne(const {
      MuscleId.quads: 0.5,
      MuscleId.gluteMax: 0.3,
      MuscleId.hamstrings: 0.2,
    })!;
    expect(biased[MuscleId.quads], closeTo(1.5, 1e-9));
    expect(biased[MuscleId.gluteMax], closeTo(0.9, 1e-9));
    expect(biased[MuscleId.hamstrings], closeTo(0.6, 1e-9));
  });
}

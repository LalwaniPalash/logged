import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/deload.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/core/domain/volume_landmarks.dart';

void main() {
  DeloadSignal signal({
    List<double> volume = const [8, 8, 8, 8],
    Map<int, List<double>> strength = const {
      1: [100, 102, 104],
    },
    Map<int, List<double>> rpe = const {
      1: [8, 8, 8],
    },
    Map<int, List<double>> repDecay = const {},
  }) => assessDeload(
    weeklyEffectiveSetsByMuscle: {MuscleId.quads: volume},
    oneRepMaxSeriesByExercise: strength,
    rpeAtLoadSeries: rpe,
    repDecaySeries: repDecay,
    landmarks: defaultLandmarks,
  );

  test('zero and one signal do not trigger a deload', () {
    expect(signal().triggered, isFalse);
    expect(signal(volume: const [8, 8, 27, 28]).triggered, isFalse);
    expect(
      signal(
        strength: const {
          1: [100, 100, 99],
        },
      ).triggered,
      isFalse,
    );
    expect(
      signal(
        rpe: const {
          1: [7, 7.5, 8],
        },
      ).triggered,
      isFalse,
    );
    expect(
      signal(
        repDecay: const {
          1: [1, 1.5, 2],
        },
      ).triggered,
      isFalse,
    );
  });

  test('any two signals trigger with specific reasons', () {
    final result = signal(
      volume: const [8, 8, 27, 28],
      strength: const {
        1: [100, 100, 99],
      },
    );
    expect(result.triggered, isTrue);
    expect(result.reasons, hasLength(2));
    expect(result.reasons.first, contains('Quads'));
  });

  test('all three signals are retained', () {
    final result = signal(
      volume: const [8, 8, 27, 28],
      strength: const {
        1: [100, 100, 99],
      },
      rpe: const {
        1: [7, 7.5, 8],
      },
    );
    expect(result.triggered, isTrue);
    expect(result.reasons, hasLength(3));
  });

  test('a widening rep-decay series fires without any RPE data', () {
    final result = signal(
      strength: const {},
      rpe: const {},
      repDecay: const {
        1: [1, 2, 3],
      },
    );

    expect(result.triggered, isFalse);
    expect(
      result.reasons,
      contains('Reps are falling further across sets on 1 lift.'),
    );
  });
}

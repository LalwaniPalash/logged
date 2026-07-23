import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/deload.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/core/domain/volume_landmarks.dart';

void main() {
  DeloadSignal signal({
    List<double> volume = const [8, 8],
    List<double> strength = const [100, 102, 104],
    List<double> rpe = const [8, 8, 8],
  }) => assessDeload(
    weeklyEffectiveSetsByMuscle: {MuscleId.quads: volume},
    oneRepMaxSeriesByExercise: {1: strength},
    rpeAtLoadSeries: {1: rpe},
    landmarks: defaultLandmarks,
  );

  test('zero and one signal do not trigger a deload', () {
    expect(signal().triggered, isFalse);
    expect(signal(volume: const [27, 28]).triggered, isFalse);
    expect(signal(strength: const [100, 100, 99]).triggered, isFalse);
    expect(signal(rpe: const [7, 7.5, 8]).triggered, isFalse);
  });

  test('any two signals trigger with specific reasons', () {
    final result = signal(
      volume: const [27, 28],
      strength: const [100, 100, 99],
    );
    expect(result.triggered, isTrue);
    expect(result.reasons, hasLength(2));
    expect(result.reasons.first, contains('Quads'));
  });

  test('all three signals are retained', () {
    final result = signal(
      volume: const [27, 28],
      strength: const [100, 100, 99],
      rpe: const [7, 7.5, 8],
    );
    expect(result.triggered, isTrue);
    expect(result.reasons, hasLength(3));
  });
}

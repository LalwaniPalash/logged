import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/core/domain/muscle_progress.dart';
import 'package:logged/core/domain/workout_metrics.dart';
import 'package:logged/core/domain/training_goal.dart';

void main() {
  MusclePerformanceRecord record({
    required DateTime date,
    int exerciseId = 1,
    String exerciseName = 'Bench Press',
    List<MuscleId> primary = const [MuscleId.midLowerChest],
    List<MuscleId> secondary = const [MuscleId.triceps],
    LoadingMode loadingMode = LoadingMode.external,
    double? weightValue = 100,
    WeightUnit? unit = WeightUnit.kg,
    WeightEntry weightEntry = WeightEntry.total,
    int sideCount = 1,
    int? reps = 5,
    int? durationSec,
    double? distanceMeters,
    double bodyweightFactor = 1,
    bool isWarmup = false,
  }) => MusclePerformanceRecord(
    date: date,
    exerciseId: exerciseId,
    exerciseName: exerciseName,
    primaryMuscles: primary,
    secondaryMuscles: secondary,
    loadingMode: loadingMode,
    weightValue: weightValue,
    unit: unit,
    weightEntry: weightEntry,
    sideCount: sideCount,
    reps: reps,
    durationSec: durationSec,
    distanceMeters: distanceMeters,
    bodyweightFactor: bodyweightFactor,
    isWarmup: isWarmup,
  );

  test('builds exercise-relative muscle indexes with secondary weighting', () {
    final progress = buildMuscleProgress(
      records: [
        record(date: DateTime(2026, 7, 1), weightValue: 100, reps: 5),
        record(date: DateTime(2026, 7, 8), weightValue: 100, reps: 5),
        record(date: DateTime(2026, 7, 15), weightValue: 110, reps: 5),
      ],
      today: DateTime(2026, 7, 20),
    );

    final chest = progress[MuscleId.midLowerChest]!;
    final triceps = progress[MuscleId.triceps]!;
    expect(chest.points.last.index, closeTo(110, 0.01));
    expect(chest.primarySets, 3);
    expect(triceps.secondarySets, 3);
    expect(triceps.points.last.index, closeTo(110, 0.01));
  });

  test('uses dated bodyweight for bodyweight-added repetitions', () {
    final progress = buildMuscleProgress(
      bodyweights: [
        BodyweightEntry(
          date: DateTime(2026, 7, 1),
          value: 80,
          unit: WeightUnit.kg,
        ),
      ],
      records: [
        record(
          date: DateTime(2026, 7, 1),
          loadingMode: LoadingMode.bodyweightAdded,
          weightValue: 10,
          reps: 5,
          bodyweightFactor: 1,
        ),
        record(
          date: DateTime(2026, 7, 8),
          loadingMode: LoadingMode.bodyweightAdded,
          weightValue: 10,
          reps: 5,
          bodyweightFactor: 1,
        ),
        record(
          date: DateTime(2026, 7, 15),
          loadingMode: LoadingMode.bodyweightAdded,
          weightValue: 20,
          reps: 5,
          bodyweightFactor: 1,
        ),
      ],
      today: DateTime(2026, 7, 20),
    );

    expect(
      progress[MuscleId.midLowerChest]!.points.last.index,
      closeTo(111.11, 0.01),
    );
  });

  test('uses doubled per-hand load for resisted muscle signals', () {
    final progress = buildMuscleProgress(
      records: [
        record(
          date: DateTime(2026, 7, 1),
          weightValue: 7.5,
          unit: WeightUnit.lb,
          weightEntry: WeightEntry.perSide,
          reps: 10,
        ),
        record(
          date: DateTime(2026, 7, 8),
          weightValue: 7.5,
          unit: WeightUnit.lb,
          weightEntry: WeightEntry.perSide,
          reps: 10,
        ),
      ],
    );

    expect(
      progress[MuscleId.midLowerChest]!.exercises.single.latestRawValue,
      closeTo(weightKg(15, WeightUnit.lb) * (1 + 10 / 30), 0.000001),
    );
  });

  test('keeps rank and momentum separate', () {
    final progress = buildMuscleProgress(
      records: [
        record(date: DateTime(2026, 7, 1), weightValue: 100, reps: 5),
        record(date: DateTime(2026, 7, 8), weightValue: 110, reps: 5),
        record(date: DateTime(2026, 7, 15), weightValue: 120, reps: 5),
        record(date: DateTime(2026, 7, 22), weightValue: 80, reps: 5),
      ],
      today: DateTime(2026, 7, 29),
    );

    final chest = progress[MuscleId.midLowerChest]!;
    expect(chest.rankScore, greaterThanOrEqualTo(0));
    expect(chest.momentum, MuscleMomentum.declining);
  });

  test('over-assisted bodyweight rows fall back to lower precision reps', () {
    final progress = buildMuscleProgress(
      bodyweights: [
        BodyweightEntry(
          date: DateTime(2026, 7, 1),
          value: 80,
          unit: WeightUnit.kg,
        ),
      ],
      records: [
        record(
          date: DateTime(2026, 7, 1),
          loadingMode: LoadingMode.bodyweightAssisted,
          weightValue: 90,
          reps: 5,
        ),
        record(
          date: DateTime(2026, 7, 8),
          loadingMode: LoadingMode.bodyweightAssisted,
          weightValue: 90,
          reps: 5,
        ),
      ],
    );

    final exercise = progress[MuscleId.midLowerChest]!.exercises.single;
    expect(exercise.lowerPrecision, isTrue);
    expect(exercise.latestRawValue, 5);
  });

  test(
    'routes timed holds and distance work into comparable exercise signals',
    () {
      final progress = buildMuscleProgress(
        records: [
          record(
            date: DateTime(2026, 7, 1),
            exerciseId: 2,
            exerciseName: 'Plank',
            weightValue: null,
            reps: null,
            durationSec: 30,
          ),
          record(
            date: DateTime(2026, 7, 8),
            exerciseId: 2,
            exerciseName: 'Plank',
            weightValue: null,
            reps: null,
            durationSec: 30,
          ),
          record(
            date: DateTime(2026, 7, 15),
            exerciseId: 2,
            exerciseName: 'Plank',
            weightValue: null,
            reps: null,
            durationSec: 45,
          ),
          record(
            date: DateTime(2026, 7, 1),
            exerciseId: 3,
            exerciseName: 'Carry',
            weightValue: null,
            reps: null,
            distanceMeters: 100,
          ),
          record(
            date: DateTime(2026, 7, 8),
            exerciseId: 3,
            exerciseName: 'Carry',
            weightValue: null,
            reps: null,
            distanceMeters: 100,
          ),
          record(
            date: DateTime(2026, 7, 15),
            exerciseId: 3,
            exerciseName: 'Carry',
            weightValue: null,
            reps: null,
            distanceMeters: 125,
          ),
        ],
      );

      final exercises = progress[MuscleId.midLowerChest]!.exercises;
      expect(
        exercises
            .firstWhere((exercise) => exercise.exerciseName == 'Plank')
            .latestIndex,
        150,
      );
      expect(
        exercises
            .firstWhere((exercise) => exercise.exerciseName == 'Carry')
            .latestIndex,
        125,
      );
    },
  );

  test('builds an overall body summary from all muscle ranks', () {
    final progress = buildMuscleProgress(
      records: [
        for (var week = 0; week < 8; week++)
          record(
            date: DateTime(2026, 7, 1 + week),
            weightValue: 100 + week * 5,
            reps: 5,
          ),
      ],
      today: DateTime(2026, 7, 20),
    );
    final summary = buildBodyProgressSummary(progress);

    expect(summary.rank, MuscleRank.foundation);
    expect(summary.trainedMuscles, 2);
    expect(summary.strongest.first.muscle, MuscleId.midLowerChest);
    expect(summary.attentionNeeded, isNotEmpty);
    expect(summary.nextFocusLabel, isNotEmpty);
  });

  test('rank thresholds scale with the coaching goal', () {
    expect(rankFromScore(40, TrainingGoal.maintain), MuscleRank.silver);
    expect(rankFromScore(40, TrainingGoal.build), MuscleRank.silver);
    expect(rankFromScore(40, TrainingGoal.push), MuscleRank.bronze);
    expect(
      rankFromScore(
        rankThreshold(MuscleRank.gold, TrainingGoal.build),
        TrainingGoal.build,
      ),
      MuscleRank.gold,
    );
  });

  test('neglect lowers a recent-state rank score', () {
    final records = [
      for (var week = 0; week < 8; week++)
        for (var set = 0; set < 8; set++)
          record(
            date: DateTime(2026, 5, 25 + week * 7),
            weightValue: 100 + week * 3,
          ),
    ];
    final recent = buildMuscleProgress(
      records: records,
      today: DateTime(2026, 7, 20),
    )[MuscleId.midLowerChest]!;
    final neglected = buildMuscleProgress(
      records: records,
      today: DateTime(2026, 11, 20),
    )[MuscleId.midLowerChest]!;
    expect(neglected.rankScore, lessThan(recent.rankScore));
  });

  test('rank explainer gives a concrete next action', () {
    final progress = buildMuscleProgress(
      records: [record(date: DateTime(2026, 7, 20))],
      today: DateTime(2026, 7, 20),
    )[MuscleId.midLowerChest]!;
    expect(rankExplainer(progress, TrainingGoal.build), contains('sets'));
  });
}

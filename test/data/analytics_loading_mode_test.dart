import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/live_muscle_state.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/core/domain/muscle_bias.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/repositories/analytics_repository.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<int> addExercise({
    required String name,
    required ExerciseCategory category,
    required LoadingMode mode,
    double bodyweightFactor = 1,
    String muscleGroup = 'back',
    String primaryMuscles = '["lats"]',
    String secondaryMuscles = '[]',
  }) => database
      .into(database.exercises)
      .insert(
        ExercisesCompanion.insert(
          name: name,
          category: category,
          muscleGroup: muscleGroup,
          primaryMuscles: Value(primaryMuscles),
          secondaryMuscles: Value(secondaryMuscles),
          preferredLoadingMode: Value(mode),
          bodyweightFactor: Value(bodyweightFactor),
        ),
      );

  Future<void> logSet({
    required int exerciseId,
    required DateTime day,
    required int reps,
    double? weight,
    required LoadingMode mode,
    double? rpe,
    String? muscleBiasWeights,
  }) async {
    final sessionId = await database
        .into(database.sessions)
        .insert(
          SessionsCompanion.insert(
            startedAt: day,
            endedAt: Value(day.add(const Duration(hours: 1))),
          ),
        );
    final linkId = await database
        .into(database.sessionExercises)
        .insert(
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: 0,
          ),
        );
    await database
        .into(database.setEntries)
        .insert(
          SetEntriesCompanion.insert(
            sessionExerciseId: linkId,
            setNumber: 1,
            reps: Value(reps),
            weightValue: Value(weight),
            unit: weight == null
                ? const Value.absent()
                : const Value(WeightUnit.kg),
            loadingMode: Value(mode),
            rpe: Value(rpe),
            muscleBiasWeights: Value(muscleBiasWeights),
          ),
        );
  }

  test(
    'completed and benchmark queries both include a strict bodyweight pull-up',
    () async {
      final pullUpId = await addExercise(
        name: 'Pull-Up',
        category: ExerciseCategory.bodyweight,
        mode: LoadingMode.bodyweight,
      );
      await logSet(
        exerciseId: pullUpId,
        day: DateTime(2026, 7, 20, 12),
        reps: 8,
        weight: null, // strict bodyweight: no entered load
        mode: LoadingMode.bodyweight,
      );

      final repository = AnalyticsRepository(database);
      final completed = await repository.watchCompletedSets().first;
      expect(completed, hasLength(1));
      expect(completed.single.exerciseName, 'Pull-Up');
      expect(completed.single.weightKg, 0);

      final benchmark = await repository.watchBenchmarkSets().first;
      expect(benchmark, hasLength(1));
      final record = benchmark.single;
      expect(record.exerciseName, 'Pull-Up');
      expect(record.enteredWeightKg, isNull);
      // Bodyweight folds in: 80 kg * (1 + 8/30).
      expect(record.resistedOneRepMaxKg(80), closeTo(80 * (1 + 8 / 30), 1e-9));
    },
  );

  test('a falling assisted load is not counted as a stalled 1RM', () async {
    final assistedId = await addExercise(
      name: 'Assisted Pull-Up',
      category: ExerciseCategory.strength,
      mode: LoadingMode.bodyweightAssisted,
    );
    final benchId = await addExercise(
      name: 'Barbell Bench Press',
      category: ExerciseCategory.strength,
      mode: LoadingMode.external,
    );
    // Assistance drops 20 -> 10 kg across weeks: real progress, not a decline.
    await logSet(
      exerciseId: assistedId,
      day: DateTime(2026, 7, 6, 12),
      reps: 8,
      weight: 20,
      mode: LoadingMode.bodyweightAssisted,
    );
    await logSet(
      exerciseId: assistedId,
      day: DateTime(2026, 7, 20, 12),
      reps: 8,
      weight: 10,
      mode: LoadingMode.bodyweightAssisted,
    );
    await logSet(
      exerciseId: benchId,
      day: DateTime(2026, 7, 20, 12),
      reps: 5,
      weight: 100,
      mode: LoadingMode.external,
    );

    final data = await AnalyticsRepository(
      database,
    ).loadDeloadData(today: DateTime(2026, 7, 22));

    expect(
      data.oneRepMaxSeriesByExercise.containsKey(assistedId),
      isFalse,
      reason: 'assisted lifts must not feed the est-1RM decline detector',
    );
    expect(
      data.oneRepMaxSeriesByExercise.containsKey(benchId),
      isTrue,
      reason: 'externally loaded lifts still contribute a 1RM series',
    );
  });

  test(
    'deload weekly effective sets apply stored primary-muscle bias',
    () async {
      final legPressId = await addExercise(
        name: 'Leg Press',
        category: ExerciseCategory.strength,
        mode: LoadingMode.external,
        muscleGroup: 'legs',
        primaryMuscles: '["quads","glute_max"]',
        secondaryMuscles: '["hamstrings"]',
      );
      await logSet(
        exerciseId: legPressId,
        day: DateTime(2026, 8, 10, 12),
        reps: 10,
        weight: 180,
        mode: LoadingMode.external,
        muscleBiasWeights: encodeMuscleBiasWeights(const {
          MuscleId.quads: 1.5,
          MuscleId.gluteMax: 0.5,
        }),
      );

      final data = await AnalyticsRepository(
        database,
      ).loadDeloadData(today: DateTime(2026, 8, 14));

      expect(data.weeklyEffectiveSetsByMuscle[MuscleId.quads]!.last, 1.5);
      expect(data.weeklyEffectiveSetsByMuscle[MuscleId.gluteMax]!.last, 0.5);
      expect(
        data.weeklyEffectiveSetsByMuscle[MuscleId.hamstrings]!.last,
        secondaryMuscleSetWeight,
      );
    },
  );
}

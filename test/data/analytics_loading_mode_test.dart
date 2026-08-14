import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/live_muscle_state.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/core/domain/muscle_bias.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/repositories/analytics_repository.dart';

final DynamicLibrary _libc = Platform.isMacOS
    ? DynamicLibrary.open('/usr/lib/libSystem.B.dylib')
    : DynamicLibrary.open('libc.so.6');

typedef _SetEnvNative = Int32 Function(Pointer<Int8>, Pointer<Int8>, Int32);
typedef _SetEnvDart = int Function(Pointer<Int8>, Pointer<Int8>, int);
typedef _UnsetEnvNative = Int32 Function(Pointer<Int8>);
typedef _UnsetEnvDart = int Function(Pointer<Int8>);
typedef _TzSetNative = Void Function();
typedef _TzSetDart = void Function();
typedef _MallocNative = Pointer<Void> Function(IntPtr);
typedef _MallocDart = Pointer<Void> Function(int);
typedef _FreeNative = Void Function(Pointer<Void>);
typedef _FreeDart = void Function(Pointer<Void>);

final _SetEnvDart _setEnv = _libc.lookupFunction<_SetEnvNative, _SetEnvDart>(
  'setenv',
);
final _UnsetEnvDart _unsetEnv = _libc
    .lookupFunction<_UnsetEnvNative, _UnsetEnvDart>('unsetenv');
final _TzSetDart _tzSet = _libc.lookupFunction<_TzSetNative, _TzSetDart>(
  'tzset',
);
final _MallocDart _malloc = _libc.lookupFunction<_MallocNative, _MallocDart>(
  'malloc',
);
final _FreeDart _free = _libc.lookupFunction<_FreeNative, _FreeDart>('free');

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  Pointer<Int8> nativeCString(String value) {
    final units = utf8.encode(value);
    final pointer = _malloc(units.length + 1).cast<Int8>();
    for (var index = 0; index < units.length; index++) {
      pointer[index] = units[index];
    }
    pointer[units.length] = 0;
    return pointer;
  }

  Future<T> withLocalTimeZone<T>(
    String timeZone,
    FutureOr<T> Function() body,
  ) async {
    if (!Platform.isMacOS && !Platform.isLinux) {
      return body();
    }
    final key = nativeCString('TZ');
    final original = Platform.environment['TZ'];
    final value = nativeCString(timeZone);
    _setEnv(key, value, 1);
    _tzSet();
    _free(value.cast<Void>());
    try {
      return await body();
    } finally {
      if (original == null) {
        _unsetEnv(key);
      } else {
        final restore = nativeCString(original);
        _setEnv(key, restore, 1);
        _free(restore.cast<Void>());
      }
      _tzSet();
      _free(key.cast<Void>());
    }
  }

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
      ).loadDeloadData(today: DateTime(2026, 8, 17));

      expect(data.weeklyEffectiveSetsByMuscle[MuscleId.quads]!.last, 1.5);
      expect(data.weeklyEffectiveSetsByMuscle[MuscleId.gluteMax]!.last, 0.5);
      expect(
        data.weeklyEffectiveSetsByMuscle[MuscleId.hamstrings]!.last,
        secondaryMuscleSetWeight,
      );
    },
  );

  test(
    'deload data ends at the last completed week, not the current partial one',
    () async {
      final squatId = await addExercise(
        name: 'Back Squat',
        category: ExerciseCategory.strength,
        mode: LoadingMode.external,
        muscleGroup: 'quads',
        primaryMuscles: '["quads"]',
      );
      for (var set = 0; set < 3; set++) {
        await logSet(
          exerciseId: squatId,
          day: DateTime(2026, 8, 17, 12, set),
          reps: 5,
          weight: 100,
          mode: LoadingMode.external,
        );
      }

      final data = await AnalyticsRepository(
        database,
      ).loadDeloadData(today: DateTime(2026, 8, 17), weeks: 4);

      expect(data.weeklyEffectiveSetsByMuscle[MuscleId.quads], [0, 0, 0, 0]);
    },
  );

  test(
    'deload week keys survive the late-October DST boundary',
    () => withLocalTimeZone('Europe/Berlin', () async {
      final squatId = await addExercise(
        name: 'Front Squat',
        category: ExerciseCategory.strength,
        mode: LoadingMode.external,
        muscleGroup: 'quads',
        primaryMuscles: '["quads"]',
      );
      await logSet(
        exerciseId: squatId,
        day: DateTime(2026, 10, 19, 12),
        reps: 5,
        weight: 100,
        mode: LoadingMode.external,
      );

      final data = await AnalyticsRepository(
        database,
      ).loadDeloadData(today: DateTime(2026, 11, 2), weeks: 4);

      expect(data.weeklyEffectiveSetsByMuscle[MuscleId.quads], [0, 0, 1, 0]);
    }),
    skip: !Platform.isMacOS && !Platform.isLinux
        ? 'requires tzset-supported local timezone changes'
        : null,
  );

  test('rep decay is tracked from first-set to last-set rep loss', () async {
    final squatId = await addExercise(
      name: 'Paused Squat',
      category: ExerciseCategory.strength,
      mode: LoadingMode.external,
      muscleGroup: 'quads',
      primaryMuscles: '["quads"]',
    );
    final day = DateTime(2026, 8, 10, 12);
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
            exerciseId: squatId,
            position: 0,
          ),
        );
    await database.batch((batch) {
      batch.insertAll(database.setEntries, [
        SetEntriesCompanion.insert(
          sessionExerciseId: linkId,
          setNumber: 1,
          reps: const Value(10),
          weightValue: const Value(100),
          unit: const Value(WeightUnit.kg),
        ),
        SetEntriesCompanion.insert(
          sessionExerciseId: linkId,
          setNumber: 2,
          reps: const Value(8),
          weightValue: const Value(100),
          unit: const Value(WeightUnit.kg),
        ),
      ]);
    });

    final data = await AnalyticsRepository(
      database,
    ).loadDeloadData(today: DateTime(2026, 8, 17));

    expect(data.repDecaySeries[squatId], [2]);
  });

  test('1RM stall series is bounded to the last 12 weeks', () async {
    final oldLiftId = await addExercise(
      name: 'Old Bench',
      category: ExerciseCategory.strength,
      mode: LoadingMode.external,
      muscleGroup: 'chest',
      primaryMuscles: '["mid_lower_chest"]',
    );
    for (final day in [
      DateTime(2026, 2, 1, 12),
      DateTime(2026, 2, 15, 12),
      DateTime(2026, 3, 1, 12),
    ]) {
      await logSet(
        exerciseId: oldLiftId,
        day: day,
        reps: 5,
        weight: 100,
        mode: LoadingMode.external,
      );
    }

    final data = await AnalyticsRepository(
      database,
    ).loadDeloadData(today: DateTime(2026, 8, 14));

    expect(data.oneRepMaxSeriesByExercise.containsKey(oldLiftId), isFalse);
  });

  test(
    'bodyweight-only training still produces rep-decay and stall signals',
    () async {
      final pullUpId = await addExercise(
        name: 'Strict Pull-Up',
        category: ExerciseCategory.bodyweight,
        mode: LoadingMode.bodyweight,
        bodyweightFactor: 1,
        muscleGroup: 'back',
        primaryMuscles: '["lats"]',
      );
      // Three training days, each with two strict sets and no weight_value at
      // all. Rep decay widens 1 -> 2 -> 3 across the days.
      for (final (index, day) in [
        DateTime(2026, 7, 20, 12),
        DateTime(2026, 7, 27, 12),
        DateTime(2026, 8, 3, 12),
      ].indexed) {
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
                exerciseId: pullUpId,
                position: 0,
              ),
            );
        await database.batch((batch) {
          batch.insertAll(database.setEntries, [
            SetEntriesCompanion.insert(
              sessionExerciseId: linkId,
              setNumber: 1,
              reps: const Value(10),
              loadingMode: const Value(LoadingMode.bodyweight),
            ),
            SetEntriesCompanion.insert(
              sessionExerciseId: linkId,
              setNumber: 2,
              reps: Value(10 - (index + 1)),
              loadingMode: const Value(LoadingMode.bodyweight),
            ),
          ]);
        });
      }

      final data = await AnalyticsRepository(
        database,
      ).loadDeloadData(today: DateTime(2026, 8, 10));

      // Rep decay is captured despite every set having a null weight_value.
      expect(data.repDecaySeries[pullUpId], [1, 2, 3]);
      // The est-1RM proxy uses bodyweightFactor, so a strict lift now has a
      // series the stall detector can read instead of being dropped entirely.
      expect(data.oneRepMaxSeriesByExercise[pullUpId], hasLength(3));
    },
  );
}

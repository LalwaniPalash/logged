import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/core/domain/muscle_progress.dart';
import 'package:logged/core/domain/plate_math.dart';
import 'package:logged/core/domain/training_goal.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/repositories/settings_repository.dart';

void main() {
  test(
    'rest timer auto-start defaults on and persists when toggled off',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = SettingsRepository(database);

      expect(
        (await repository.readRestTimerPreferences()).autoStartEnabled,
        isTrue,
        reason: 'auto-start is the standard default',
      );

      await repository.setRestTimerAutoStartEnabled(false);
      expect(
        (await repository.readRestTimerPreferences()).autoStartEnabled,
        isFalse,
      );
      // Other rest-timer prefs are untouched by the toggle.
      expect((await repository.readRestTimerPreferences()).defaultSeconds, 90);
    },
  );

  test('CoachingPreferences has value equality', () {
    expect(
      const CoachingPreferences(trainingGoal: TrainingGoal.build),
      const CoachingPreferences(trainingGoal: TrainingGoal.build),
    );
    expect(
      const CoachingPreferences(trainingGoal: TrainingGoal.build),
      isNot(const CoachingPreferences(trainingGoal: TrainingGoal.push)),
    );
  });

  test(
    'watchCoachingPreferences ignores unrelated app_settings writes',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = SettingsRepository(database);

      final seen = <CoachingPreferences>[];
      final sub = repository.watchCoachingPreferences().listen(seen.add);
      addTearDown(sub.cancel);

      await pumpEventQueue();
      expect(seen, hasLength(1));
      expect(seen.single.trainingGoal, TrainingGoal.build);

      // Writing lastSeenRanks is what the Dashboard rank listener does; it must
      // NOT re-emit coaching preferences (that fed the foundation<->bronze loop).
      await repository.setLastSeenRanks({
        MuscleId.values.first: MuscleRank.bronze,
      });
      await pumpEventQueue();
      expect(
        seen,
        hasLength(1),
        reason: 'an unrelated settings write must not re-emit coaching prefs',
      );

      // A genuine coaching change still emits.
      await repository.setTrainingGoal(TrainingGoal.push);
      await pumpEventQueue();
      expect(seen, hasLength(2));
      expect(seen.last.trainingGoal, TrainingGoal.push);
    },
  );

  test('watchPlateInventory ignores unrelated app_settings writes', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = SettingsRepository(database);

    final seen = <PlateInventory>[];
    final sub = repository.watchPlateInventory().listen(seen.add);
    addTearDown(sub.cancel);

    await pumpEventQueue();
    expect(seen, hasLength(1));
    expect(seen.single, PlateInventory());

    await repository.setTrainingGoal(TrainingGoal.push);
    await pumpEventQueue();
    expect(
      seen,
      hasLength(1),
      reason: 'an unrelated settings write must not re-emit plate inventory',
    );

    await repository.setPlateInventory(
      PlateInventory(kgBarWeight: 15, kgPlateSizes: const [25, 10, 5]),
    );
    await pumpEventQueue();
    expect(seen, hasLength(2));
    expect(seen.last.kgBarWeight, 15);
    expect(seen.last.kgPlateSizes, [25.0, 10.0, 5.0]);
  });

  test(
    'readPlateInventory falls back to defaults on malformed stored JSON',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = SettingsRepository(database);

      await database
          .into(database.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: 'plateInventory',
              value: '{definitely not json',
            ),
          );

      final inventory = await repository.readPlateInventory();
      expect(inventory, PlateInventory());
    },
  );
}

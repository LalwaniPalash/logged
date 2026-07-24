import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/core/domain/muscle_progress.dart';
import 'package:logged/core/domain/training_goal.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/repositories/settings_repository.dart';

void main() {
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

  test('watchCoachingPreferences ignores unrelated app_settings writes', () async {
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
  });
}

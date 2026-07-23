import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/domain/live_muscle_state.dart';
import '../core/domain/muscle.dart';
import '../core/domain/muscle_progress.dart'
    show BodyProgressSummary, MuscleProgress, buildBodyProgressSummary;
import '../core/domain/workout_settings.dart';
import '../core/services/notification_service.dart';
import 'database/app_database.dart';
import 'repositories/analytics_repository.dart';
import 'repositories/bodyweight_repository.dart';
import 'repositories/exercise_repository.dart';
import 'repositories/rest_day_repository.dart';
import 'repositories/session_repository.dart';
import 'repositories/set_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/template_repository.dart';

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError(),
);
final notificationServiceProvider = Provider<NotificationClient>(
  (ref) => NotificationService(),
);
final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(ref.watch(databaseProvider)),
);
final templateRepositoryProvider = Provider<TemplateRepository>(
  (ref) => TemplateRepository(ref.watch(databaseProvider)),
);
final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(databaseProvider)),
);
final setRepositoryProvider = Provider<SetRepository>(
  (ref) => SetRepository(ref.watch(databaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);
final restDayRepositoryProvider = Provider<RestDayRepository>(
  (ref) => RestDayRepository(ref.watch(databaseProvider)),
);
final bodyweightRepositoryProvider = Provider<BodyweightRepository>(
  (ref) => BodyweightRepository(ref.watch(databaseProvider)),
);

/// Date-only stamps of completed workouts (drives the streak + calendar).
final trainingDaysProvider = StreamProvider<List<DateTime>>(
  (ref) => ref.watch(sessionRepositoryProvider).watchTrainingDays(),
);

/// Manually logged rest days.
final restDaysProvider = StreamProvider<List<DateTime>>(
  (ref) => ref.watch(restDayRepositoryProvider).watch(),
);

final bodyweightEntriesProvider = StreamProvider<List<BodyweightEntry>>(
  (ref) => ref.watch(bodyweightRepositoryProvider).watch(),
);

/// Schedule preferences (rest weekdays + weekly goal).
final workoutSettingsProvider = StreamProvider<WorkoutSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);
final restTimerPreferencesProvider = StreamProvider<RestTimerPreferences>(
  (ref) => ref.watch(settingsRepositoryProvider).watchRestTimerPreferences(),
);
final reminderPreferencesProvider = StreamProvider<ReminderPreferences>(
  (ref) => ref.watch(settingsRepositoryProvider).watchReminderPreferences(),
);

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepository(ref.watch(databaseProvider)),
);

/// All completed, weighted sets (drives the Progress analytics).
final completedSetsProvider = StreamProvider<List<WorkoutSetRecord>>(
  (ref) => ref.watch(analyticsRepositoryProvider).watchCompletedSets(),
);

/// Current Monday-to-now muscle state. Unlike PR and volume analytics, this
/// includes saved sets from the active workout and updates after every edit.
final liveMuscleStateProvider = StreamProvider<LiveMuscleState>(
  (ref) => ref
      .watch(analyticsRepositoryProvider)
      .watchLiveMuscleSets()
      .map(buildLiveMuscleState),
);

final muscleProgressProvider = StreamProvider<Map<MuscleId, MuscleProgress>>(
  (ref) => ref.watch(analyticsRepositoryProvider).watchMuscleProgress(),
);

final bodyProgressSummaryProvider = Provider<AsyncValue<BodyProgressSummary>>((
  ref,
) {
  final progress = ref.watch(muscleProgressProvider);
  return progress.whenData(buildBodyProgressSummary);
});

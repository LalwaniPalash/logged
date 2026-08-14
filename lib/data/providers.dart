import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/domain/live_muscle_state.dart';
import '../core/domain/deload.dart';
import '../core/domain/muscle.dart';
import '../core/domain/muscle_progress.dart'
    show BodyProgressSummary, MuscleProgress, buildBodyProgressSummary;
import '../core/domain/plate_math.dart';
import '../core/domain/volume_landmarks.dart';
import '../core/domain/streak.dart';
import '../core/domain/training_goal.dart';
import '../core/domain/workout_settings.dart';
import '../core/services/health_export_service.dart';
import '../core/services/home_widget_service.dart';
import '../core/services/notification_service.dart';
import 'database/app_database.dart';
import 'repositories/analytics_repository.dart';
import 'repositories/bodyweight_repository.dart';
import 'repositories/exercise_repository.dart';
import 'repositories/muscle_exercise_index.dart';
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
final homeWidgetServiceProvider = Provider<HomeWidgetClient>(
  (ref) => HomeWidgetService(
    sessions: ref.watch(sessionRepositoryProvider),
    analytics: ref.watch(analyticsRepositoryProvider),
    restDays: ref.watch(restDayRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
  ),
);
final healthExportServiceProvider = Provider<HealthExportClient>(
  (ref) => HealthExportService(
    sessions: ref.watch(sessionRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
  ),
);
final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(ref.watch(databaseProvider)),
);
final muscleExerciseIndexProvider = Provider<MuscleExerciseIndex>(
  (ref) => MuscleExerciseIndex(ref.watch(databaseProvider)),
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
final coachingPreferencesProvider = StreamProvider<CoachingPreferences>(
  (ref) => ref.watch(settingsRepositoryProvider).watchCoachingPreferences(),
);
final plateInventoryProvider = StreamProvider<PlateInventory>(
  (ref) => ref.watch(settingsRepositoryProvider).watchPlateInventory(),
);
final healthExportPreferencesProvider = StreamProvider<HealthExportPreferences>(
  (ref) => ref.watch(settingsRepositoryProvider).watchHealthExportPreferences(),
);
final effectiveVolumeLandmarksProvider =
    Provider<AsyncValue<Map<MuscleId, VolumeLandmarks>>>((ref) {
      return ref
          .watch(coachingPreferencesProvider)
          .whenData(
            (preferences) => resolveLandmarks(
              goal: preferences.trainingGoal,
              overridesJson: preferences.volumeLandmarkOverrides,
            ),
          );
    });

String currentWeekKey([DateTime? now]) =>
    startOfWeek(now ?? DateTime.now()).toIso8601String().substring(0, 10);

final deloadSignalProvider = FutureProvider<DeloadSignal?>((ref) async {
  // Keep the assessment live when a completed workout changes.
  ref.watch(completedSetsProvider);
  final coaching = await ref.watch(coachingPreferencesProvider.future);
  final dismissed = await ref
      .watch(settingsRepositoryProvider)
      .readDeloadDismissedWeek();
  if (dismissed == currentWeekKey()) return null;
  final data = await ref.watch(analyticsRepositoryProvider).loadDeloadData();
  final signal = assessDeload(
    weeklyEffectiveSetsByMuscle: data.weeklyEffectiveSetsByMuscle,
    oneRepMaxSeriesByExercise: data.oneRepMaxSeriesByExercise,
    rpeAtLoadSeries: data.rpeAtLoadSeries,
    landmarks: resolveLandmarks(
      goal: coaching.trainingGoal,
      overridesJson: coaching.volumeLandmarkOverrides,
    ),
    goal: coaching.trainingGoal,
  );
  return signal.triggered ? signal : null;
});

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepository(ref.watch(databaseProvider)),
);

/// All completed working sets (drives the Progress analytics). Warm-ups are
/// excluded; bodyweight sets are included and contribute 0 kg of tonnage.
final completedSetsProvider = StreamProvider<List<WorkoutSetRecord>>(
  (ref) => ref.watch(analyticsRepositoryProvider).watchCompletedSets(),
);

/// Benchmark-lift sets for Strength Standards. Carries the bodyweight factor
/// that [completedSetsProvider] does not, so a strict pull-up scores its real
/// resisted mass rather than 0 kg.
final benchmarkSetsProvider = StreamProvider<List<BenchmarkSetRecord>>(
  (ref) => ref.watch(analyticsRepositoryProvider).watchBenchmarkSets(),
);

/// Current Monday-to-now muscle state. Unlike PR and volume analytics, this
/// includes saved sets from the active workout and updates after every edit.
final liveMuscleStateProvider = StreamProvider<LiveMuscleState>(
  (ref) => ref
      .watch(analyticsRepositoryProvider)
      .watchLiveMuscleSets()
      .map(buildLiveMuscleState),
);

final muscleProgressProvider = StreamProvider<Map<MuscleId, MuscleProgress>>((
  ref,
) async* {
  final coaching = await ref.watch(coachingPreferencesProvider.future);
  final landmarks = resolveLandmarks(
    goal: coaching.trainingGoal,
    overridesJson: coaching.volumeLandmarkOverrides,
  );
  yield* ref
      .watch(analyticsRepositoryProvider)
      .watchMuscleProgress(goal: coaching.trainingGoal, landmarks: landmarks);
});

final bodyProgressSummaryProvider = Provider<AsyncValue<BodyProgressSummary>>((
  ref,
) {
  final progress = ref.watch(muscleProgressProvider);
  final goal =
      ref.watch(coachingPreferencesProvider).asData?.value.trainingGoal ??
      TrainingGoal.build;
  return progress.whenData(
    (values) => buildBodyProgressSummary(values, goal: goal),
  );
});

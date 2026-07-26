import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/rest_day_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../domain/home_widget_snapshot.dart';
import '../domain/streak.dart';
import '../domain/workout_session_summary.dart';

abstract interface class HomeWidgetClient {
  Future<void> refresh();
}

class HomeWidgetService implements HomeWidgetClient {
  const HomeWidgetService({
    required SessionRepository sessions,
    required AnalyticsRepository analytics,
    required RestDayRepository restDays,
    required SettingsRepository settings,
  }) : _sessions = sessions,
       _analytics = analytics,
       _restDays = restDays,
       _settings = settings;

  /// Every variant the user can pick from the launcher / widget gallery, as
  /// (Android provider class, iOS widget kind) pairs. Each one reads the same
  /// shared key/value data and renders the slice it cares about, so adding a
  /// variant never changes what this service writes — only what it notifies.
  static const _widgetVariants = <(String, String)>[
    ('LoggedStreakWidgetProvider', 'LoggedStreakWidget'),
    ('LoggedWidgetProvider', 'LoggedWidget'),
    ('LoggedSummaryWidgetProvider', 'LoggedSummaryWidget'),
  ];

  /// Must match the App Group on BOTH the Runner and LoggedWidgetExtension
  /// targets, and `LoggedWidgetKeys.appGroupId` in `ios/LoggedWidget`. On iOS the
  /// widget reads its values out of this shared container; without it the app
  /// writes to its own sandbox and the widget renders placeholders forever.
  /// Android ignores it — the provider reads `home_widget`'s own preferences.
  static const _iosAppGroupId = 'group.com.palash.logged';

  final SessionRepository _sessions;
  final AnalyticsRepository _analytics;
  final RestDayRepository _restDays;
  final SettingsRepository _settings;

  @override
  Future<void> refresh() async {
    try {
      await HomeWidget.setAppGroupId(_iosAppGroupId);
      final trainingDays = await _sessions.trainingDays();
      final restDays = await _restDays.all();
      final workoutSettings = await _settings.read();
      final completedSets = await _analytics.loadCompletedSets();
      final lastWorkout = await _sessions.loadLatestCompletedSummary();
      final lastWorkoutTotals = await _lastWorkoutTotals(lastWorkout);
      final snapshot = HomeWidgetSnapshot(
        streakDays: computeStreak(
          trainingDays: trainingDays,
          restWeekdays: workoutSettings.restWeekdays,
          loggedRestDays: restDays,
        ),
        setsThisWeek: completedSetsThisWeek(completedSets),
        weeklyVolumeKg: weeklyVolumeKg(completedSets),
        lastWorkout: lastWorkout,
        lastWorkoutSets: lastWorkoutTotals.sets,
        lastWorkoutExercises: lastWorkoutTotals.exercises,
      );
      for (final entry in snapshot.toWidgetData().entries) {
        await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
      }
      for (final (androidProvider, iosKind) in _widgetVariants) {
        await HomeWidget.updateWidget(name: androidProvider, iOSName: iosKind);
      }
    } on MissingPluginException catch (error) {
      debugPrint('Home widget plugin unavailable: $error');
    } on PlatformException catch (error) {
      debugPrint('Home widget update unavailable: $error');
    } on ArgumentError catch (error) {
      debugPrint('Home widget update misconfigured: $error');
    } on Object catch (error) {
      debugPrint('Home widget refresh failed: $error');
    }
  }

  /// Working-set and exercise counts for the summary widget. Warm-ups are
  /// excluded so the number matches what the session screen calls a set, and an
  /// exercise only counts once it has a working set logged against it.
  Future<({int sets, int exercises})> _lastWorkoutTotals(
    WorkoutSessionSummary? lastWorkout,
  ) async {
    if (lastWorkout == null) return (sets: 0, exercises: 0);
    final details = await _sessions.details(lastWorkout.id);
    var sets = 0;
    var exercises = 0;
    for (final detail in details) {
      final workingSets = detail.sets.where((set) => !set.isWarmup).length;
      if (workingSets == 0) continue;
      sets += workingSets;
      exercises++;
    }
    return (sets: sets, exercises: exercises);
  }
}

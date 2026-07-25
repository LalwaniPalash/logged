import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/rest_day_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../domain/home_widget_snapshot.dart';
import '../domain/streak.dart';

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

  static const _androidProviderName = 'LoggedWidgetProvider';
  static const _iosWidgetName = 'LoggedWidget';

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
      final snapshot = HomeWidgetSnapshot(
        streakDays: computeStreak(
          trainingDays: trainingDays,
          restWeekdays: workoutSettings.restWeekdays,
          loggedRestDays: restDays,
        ),
        setsThisWeek: completedSetsThisWeek(completedSets),
        lastWorkout: lastWorkout,
      );
      for (final entry in snapshot.toWidgetData().entries) {
        await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
      }
      await HomeWidget.updateWidget(
        name: _androidProviderName,
        iOSName: _iosWidgetName,
      );
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
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/streak.dart';
import '../../core/services/notification_service.dart';
import '../../data/providers.dart';
import '../../data/repositories/rest_day_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/settings_repository.dart';

const _reminderHorizonDays = 28;
const _reminderIdBase = 200000000;

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  return ReminderScheduler(
    notifications: ref.watch(notificationServiceProvider),
    settings: ref.watch(settingsRepositoryProvider),
    sessions: ref.watch(sessionRepositoryProvider),
    restDays: ref.watch(restDayRepositoryProvider),
  );
});

/// A date is eligible only when it is scheduled for training and has neither
/// a completed workout nor a one-off rest-day entry.
bool shouldRemindOnDay({
  required DateTime day,
  required Set<int> restWeekdays,
  required Set<DateTime> trainingDays,
  required Set<DateTime> loggedRestDays,
}) {
  final date = dateOnly(day);
  return !trainingDays.map(dateOnly).contains(date) &&
      !isRestDay(
        date,
        restWeekdays: restWeekdays,
        loggedRestDays: loggedRestDays.map(dateOnly).toSet(),
      );
}

/// Builds a rolling set of one-shot alerts. This handles one-off future rest
/// days and today's completed workout, which a blind weekly repeating alarm
/// cannot suppress. The rolling window is refreshed on app open and settings
/// or workout changes, and remains below iOS's 64-pending-alert limit.
List<DateTime> buildReminderSchedule({
  required DateTime now,
  required int hour,
  required int minute,
  required Set<int> restWeekdays,
  required Set<DateTime> trainingDays,
  required Set<DateTime> loggedRestDays,
  int horizonDays = _reminderHorizonDays,
}) {
  final result = <DateTime>[];
  final today = dateOnly(now);
  for (var offset = 0; offset < horizonDays; offset++) {
    final day = DateTime(today.year, today.month, today.day + offset);
    final at = DateTime(day.year, day.month, day.day, hour, minute);
    if (!at.isAfter(now) ||
        !shouldRemindOnDay(
          day: day,
          restWeekdays: restWeekdays,
          trainingDays: trainingDays,
          loggedRestDays: loggedRestDays,
        )) {
      continue;
    }
    result.add(at);
  }
  return result;
}

class ReminderScheduler {
  const ReminderScheduler({
    required NotificationClient notifications,
    required SettingsRepository settings,
    required SessionRepository sessions,
    required RestDayRepository restDays,
  }) : _notifications = notifications,
       _settings = settings,
       _sessions = sessions,
       _restDays = restDays;

  final NotificationClient _notifications;
  final SettingsRepository _settings;
  final SessionRepository _sessions;
  final RestDayRepository _restDays;

  Future<void> sync({DateTime? now, bool clearWhenDisabled = true}) async {
    final current = now ?? DateTime.now();
    final preferences = await _settings.readReminderPreferences();
    if (!preferences.enabled && !clearWhenDisabled) return;
    // Clear the old rolling window before changing time or schedule.
    for (var offset = 0; offset < _reminderHorizonDays; offset++) {
      final day = DateTime(current.year, current.month, current.day + offset);
      await _notifications.cancel(_notificationId(day));
    }

    if (!preferences.enabled) return;
    final workoutSettings = await _settings.read();
    final trainingDays = (await _sessions.trainingDays()).toSet();
    final loggedRestDays = (await _restDays.all()).toSet();
    final dates = buildReminderSchedule(
      now: current,
      hour: preferences.hour,
      minute: preferences.minute,
      restWeekdays: workoutSettings.restWeekdays,
      trainingDays: trainingDays,
      loggedRestDays: loggedRestDays,
    );
    for (final date in dates) {
      await _notifications.schedule(
        id: _notificationId(date),
        at: date,
        title: 'Train today',
        body: 'A small session still counts. Ready when you are.',
        channelId: 'training_reminders',
        channelName: 'Training reminders',
      );
    }
  }
}

int _notificationId(DateTime day) =>
    _reminderIdBase + day.year * 10000 + day.month * 100 + day.day;

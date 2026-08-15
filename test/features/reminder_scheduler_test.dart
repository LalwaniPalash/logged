import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/services/notification_service.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/repositories/rest_day_repository.dart';
import 'package:logged/data/repositories/session_repository.dart';
import 'package:logged/data/repositories/settings_repository.dart';
import 'package:logged/features/settings/reminder_scheduler.dart';

void main() {
  final monday = DateTime(2026, 7, 20);

  test('reminds on an untrained scheduled training day', () {
    expect(
      shouldRemindOnDay(
        day: monday,
        restWeekdays: const {7},
        trainingDays: const {},
        loggedRestDays: const {},
      ),
      isTrue,
    );
  });

  test('does not remind on recurring or logged rest days', () {
    expect(
      shouldRemindOnDay(
        day: DateTime(2026, 7, 26),
        restWeekdays: const {7},
        trainingDays: const {},
        loggedRestDays: const {},
      ),
      isFalse,
    );
    expect(
      shouldRemindOnDay(
        day: monday,
        restWeekdays: const {},
        trainingDays: const {},
        loggedRestDays: {monday},
      ),
      isFalse,
    );
  });

  test('does not remind after training on that date', () {
    expect(
      shouldRemindOnDay(
        day: monday,
        restWeekdays: const {7},
        trainingDays: {DateTime(2026, 7, 20, 8, 30)},
        loggedRestDays: const {},
      ),
      isFalse,
    );
  });

  test('schedule skips past time today and includes future training days', () {
    final schedule = buildReminderSchedule(
      now: DateTime(2026, 7, 20, 19),
      hour: 18,
      minute: 30,
      restWeekdays: const {7},
      trainingDays: const {},
      loggedRestDays: {DateTime(2026, 7, 22)},
      horizonDays: 7,
    );

    expect(schedule.first, DateTime(2026, 7, 21, 18, 30));
    expect(schedule, isNot(contains(DateTime(2026, 7, 22, 18, 30))));
    expect(schedule, isNot(contains(DateTime(2026, 7, 26, 18, 30))));
    expect(schedule.length, 4);
  });

  test(
    'sync schedules a weekly backstop after an exhausted rolling window',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final settings = SettingsRepository(db);
      final sessions = SessionRepository(db);
      final restDays = RestDayRepository(db);
      final notifications = _FakeNotificationClient();
      final scheduler = ReminderScheduler(
        notifications: notifications,
        settings: settings,
        sessions: sessions,
        restDays: restDays,
      );
      final now = DateTime(2026, 7, 20, 9);

      await settings.setReminderEnabled(true);
      await settings.setReminderTime(hour: 18, minute: 0);
      for (var offset = 0; offset < 28; offset++) {
        await restDays.log(DateTime(2026, 7, 20 + offset));
      }

      await scheduler.sync(now: now);

      expect(notifications.scheduled, isEmpty);
      expect(notifications.weeklySchedules, hasLength(1));
      expect(
        notifications.weeklySchedules.single.at,
        DateTime(2026, 8, 17, 18),
      );
    },
  );

  test('disabling reminders cancels the weekly backstop too', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final settings = SettingsRepository(db);
    final sessions = SessionRepository(db);
    final restDays = RestDayRepository(db);
    final notifications = _FakeNotificationClient();
    final scheduler = ReminderScheduler(
      notifications: notifications,
      settings: settings,
      sessions: sessions,
      restDays: restDays,
    );
    final now = DateTime(2026, 7, 20, 9);

    await settings.setReminderEnabled(true);
    await settings.setReminderTime(hour: 18, minute: 0);
    for (var offset = 0; offset < 28; offset++) {
      await restDays.log(DateTime(2026, 7, 20 + offset));
    }
    await scheduler.sync(now: now);

    final backstopId = notifications.weeklySchedules.single.id;
    await settings.setReminderEnabled(false);
    await scheduler.sync(now: now);

    expect(notifications.cancelled, contains(backstopId));
  });
}

class _FakeNotificationClient implements NotificationClient {
  final cancelled = <int>[];
  final scheduled = <_ScheduledPost>[];
  final weeklySchedules = <_ScheduledPost>[];
  final _actions = StreamController<String>.broadcast();

  @override
  Stream<String> get actionSelections => _actions.stream;

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {
    scheduled.add(_ScheduledPost(id: id, at: at));
  }

  @override
  Future<void> scheduleWeekly({
    required int id,
    required DateTime firstAt,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {
    weeklySchedules.add(_ScheduledPost(id: id, at: firstAt));
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {}

  @override
  Future<void> showRestComplete({
    required int id,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> showRestCountdown({
    required int id,
    required DateTime endTime,
    required String title,
    required String body,
  }) async {}
}

class _ScheduledPost {
  const _ScheduledPost({required this.id, required this.at});

  final int id;
  final DateTime at;
}

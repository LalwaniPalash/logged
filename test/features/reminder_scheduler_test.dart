import 'package:flutter_test/flutter_test.dart';
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
}

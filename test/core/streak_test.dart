import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/streak.dart';

void main() {
  // 2026-07-20 is a Monday.
  final monday = DateTime(2026, 7, 20, 15, 30);
  DateTime d(int day) => DateTime(2026, 7, day);

  group('computeStreak (no rest days)', () {
    test('no training days is zero', () {
      expect(computeStreak(trainingDays: const [], today: monday), 0);
    });

    test('trained today only is one', () {
      expect(computeStreak(trainingDays: [d(20)], today: monday), 1);
    });

    test('counts consecutive trained days ending today', () {
      expect(
        computeStreak(trainingDays: [d(18), d(19), d(20)], today: monday),
        3,
      );
    });

    test('grace: trained yesterday but not yet today still counts', () {
      expect(computeStreak(trainingDays: [d(18), d(19)], today: monday), 2);
    });

    test('a gap breaks the streak', () {
      expect(computeStreak(trainingDays: [d(20), d(17)], today: monday), 1);
    });

    test('last training older than yesterday is broken', () {
      expect(computeStreak(trainingDays: [d(17), d(18)], today: monday), 0);
    });
  });

  group('computeStreak (rest days)', () {
    test('a scheduled Sunday rest bridges the streak', () {
      // Trained Mon–Sat (13–18) + today Mon 20; Sunday 19 is a scheduled rest.
      final trained = [d(13), d(14), d(15), d(16), d(17), d(18), d(20)];
      expect(
        computeStreak(
          trainingDays: trained,
          restWeekdays: {DateTime.sunday},
          today: monday,
        ),
        7, // 7 trained days; the Sunday bridges but doesn't add to the count
      );
    });

    test('a manually logged rest day bridges the streak', () {
      // Trained Mon, Tue, Thu; Wed logged as rest. Today = Thu 16.
      expect(
        computeStreak(
          trainingDays: [d(13), d(14), d(16)],
          loggedRestDays: [d(15)],
          today: DateTime(2026, 7, 16, 9),
        ),
        3,
      );
    });

    test('a scheduled rest before the first workout does not inflate', () {
      expect(
        computeStreak(
          trainingDays: [d(20)],
          restWeekdays: {DateTime.sunday},
          today: monday,
        ),
        1,
      );
    });

    test('all-weekdays-rest does not loop forever', () {
      expect(
        computeStreak(
          trainingDays: [d(20)],
          restWeekdays: {1, 2, 3, 4, 5, 6, 7},
          today: monday,
        ),
        1,
      );
    });

    test('a Mon/Wed/Fri split stays alive across Tue/Thu and the weekend', () {
      expect(
        computeStreak(
          trainingDays: [d(20), d(22), d(24)],
          restWeekdays: {2, 4, 6, 7},
          today: DateTime(2026, 7, 27, 9),
        ),
        3,
      );
    });
  });

  group('week helpers', () {
    test('startOfWeek is the Monday', () {
      expect(startOfWeek(d(20)), d(20)); // Monday
      expect(startOfWeek(d(19)), d(13)); // Sunday -> previous Monday
    });

    test('trainingDaysThisWeek counts only the current week', () {
      expect(trainingDaysThisWeek([d(18), d(20)], today: monday), 1);
      expect(trainingDaysThisWeek([d(20)], today: monday), 1);
    });
  });

  group('trainedToday / isRestDay', () {
    test('trainedToday reflects a stamp on today', () {
      expect(trainedToday([d(20)], today: monday), isTrue);
      expect(trainedToday([d(19)], today: monday), isFalse);
    });

    test('isRestDay honors scheduled weekday and logged dates', () {
      expect(
        isRestDay(
          d(19),
          restWeekdays: {DateTime.sunday},
          loggedRestDays: const {},
        ),
        isTrue,
      );
      expect(
        isRestDay(d(16), restWeekdays: const {}, loggedRestDays: {d(16)}),
        isTrue,
      );
      expect(
        isRestDay(
          d(16),
          restWeekdays: {DateTime.sunday},
          loggedRestDays: const {},
        ),
        isFalse,
      );
    });
  });
}

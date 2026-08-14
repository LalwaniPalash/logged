import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/providers.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test(
    'recentSessionsProvider families resolve distinct subscriptions with their own limits',
    () async {
      final exerciseId = await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Bench Press',
              category: ExerciseCategory.strength,
              muscleGroup: 'chest',
            ),
          );

      for (var index = 0; index < 6; index++) {
        final startedAt = DateTime(2026, 8, index + 1, 9);
        final sessionId = await database
            .into(database.sessions)
            .insert(
              SessionsCompanion.insert(
                startedAt: startedAt,
                endedAt: Value(startedAt.add(const Duration(hours: 1))),
              ),
            );
        await database
            .into(database.sessionExercises)
            .insert(
              SessionExercisesCompanion.insert(
                sessionId: sessionId,
                exerciseId: exerciseId,
                position: 0,
              ),
            );
      }

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      final recent3Completer = Completer<List<Session>>();
      final recent500Completer = Completer<List<Session>>();
      final sub3 = container.listen<AsyncValue<List<Session>>>(
        recentSessionsProvider(3),
        (previous, next) {
          next.whenData((sessions) {
            if (!recent3Completer.isCompleted) {
              recent3Completer.complete(sessions);
            }
          });
        },
        fireImmediately: true,
      );
      final sub500 = container.listen<AsyncValue<List<Session>>>(
        recentSessionsProvider(500),
        (previous, next) {
          next.whenData((sessions) {
            if (!recent500Completer.isCompleted) {
              recent500Completer.complete(sessions);
            }
          });
        },
        fireImmediately: true,
      );
      addTearDown(sub3.close);
      addTearDown(sub500.close);

      final recent3 = await recent3Completer.future;
      final recent500 = await recent500Completer.future;

      expect(recent3, hasLength(3));
      expect(recent500, hasLength(6));
      expect(recent3.first.startedAt, DateTime(2026, 8, 6, 9));
      expect(recent500.first.startedAt, DateTime(2026, 8, 6, 9));
      expect(recent500.last.startedAt, DateTime(2026, 8, 1, 9));
      expect(
        recent3.map((session) => session.id).toList(),
        isNot(recent500.map((session) => session.id).toList()),
      );
    },
  );

  test('nextLocalMidnight crosses a month boundary calendar-wise', () {
    expect(
      nextLocalMidnight(DateTime(2026, 1, 31, 23, 59)),
      DateTime(2026, 2, 1),
    );
  });

  test('nextLocalMidnight crosses a year boundary calendar-wise', () {
    expect(nextLocalMidnight(DateTime(2026, 12, 31, 12)), DateTime(2027, 1, 1));
  });

  test('nextLocalMidnight crosses leap day calendar-wise', () {
    expect(
      nextLocalMidnight(DateTime(2028, 2, 28, 7, 30)),
      DateTime(2028, 2, 29),
    );
  });
}

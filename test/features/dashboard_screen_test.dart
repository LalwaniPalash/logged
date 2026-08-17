import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/core/domain/muscle_progress.dart';
import 'package:logged/core/domain/training_goal.dart';
import 'package:logged/core/domain/workout_settings.dart';
import 'package:logged/core/theme/app_theme.dart';
import 'package:logged/core/widgets/app_widgets.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/providers.dart';
import 'package:logged/data/repositories/settings_repository.dart';
import 'package:logged/features/dashboard/dashboard_screen.dart';

void main() {
  const narrowPhone = Size(360, 800);
  const normalPhone = Size(393, 852);
  final today = DateTime(2026, 8, 15);

  List<DateTime> buildTrainingDays(int streakLength) => List.generate(
    streakLength,
    (index) => DateTime(
      today.year,
      today.month,
      today.day - (streakLength - index - 1),
    ),
  );

  Future<void> pumpDashboard(
    WidgetTester tester, {
    required AppDatabase database,
    required List<DateTime> trainingDays,
    Size size = narrowPhone,
    double textScale = 2,
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          trainingDaysProvider.overrideWith(
            (ref) => Stream.value(trainingDays),
          ),
          restDaysProvider.overrideWith(
            (ref) => Stream.value(const <DateTime>[]),
          ),
          workoutSettingsProvider.overrideWith(
            (ref) => Stream.value(
              const WorkoutSettings(restWeekdays: {}, weeklyGoal: 7),
            ),
          ),
          recentSessionsProvider(
            3,
          ).overrideWith((ref) => Stream.value(<Session>[])),
          bodyProgressSummaryProvider.overrideWith(
            (ref) => const AsyncLoading(),
          ),
          coachingPreferencesProvider.overrideWith(
            (ref) => Stream.value(
              const CoachingPreferences(trainingGoal: TrainingGoal.build),
            ),
          ),
          todayProvider.overrideWith((ref) => Stream.value(today)),
          muscleProgressProvider.overrideWith(
            (ref) => Stream.value(const <MuscleId, MuscleProgress>{}),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: const DashboardScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'large text keeps dashboard stats stable and labels the templates button',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final semantics = tester.ensureSemantics();
      try {
        await pumpDashboard(
          tester,
          database: database,
          trainingDays: buildTrainingDays(1234),
        );

        expect(
          tester.getSemantics(find.byTooltip('Templates')),
          matchesSemantics(label: 'Open workout templates', isButton: true),
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'normal text size renders the week strip and recent sessions below the '
    'streak row',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await pumpDashboard(
        tester,
        database: database,
        trainingDays: buildTrainingDays(10),
        size: normalPhone,
        textScale: 1,
      );

      // Regression: the streak/stat row uses CrossAxisAlignment.stretch,
      // which needs IntrinsicHeight when its parent (a ListView) gives it
      // unbounded height, or it renders this whole row and everything below
      // it (week strip, recent sessions) as blank space with no thrown
      // exception in release mode. See tasks/lessons.md 2026-08-09/08-17.
      expect(find.byType(IntrinsicHeight), findsOneWidget);
      expect(find.byType(WeeklyProgressStrip), findsOneWidget);
      expect(find.text('Next best focus'), findsOneWidget);

      await tester.drag(find.byType(Scrollable), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('RECENT SESSIONS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

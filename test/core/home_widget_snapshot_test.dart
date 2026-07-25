import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/home_widget_snapshot.dart';
import 'package:logged/core/domain/workout_session_summary.dart';

void main() {
  test('formats widget snapshot metrics for a completed workout', () {
    final snapshot = HomeWidgetSnapshot(
      streakDays: 4,
      setsThisWeek: 12,
      lastWorkout: WorkoutSessionSummary(
        id: 7,
        startedAt: DateTime(2026, 7, 25, 9),
        endedAt: DateTime(2026, 7, 25, 10),
        templateName: 'Upper A',
      ),
      generatedAt: DateTime(2026, 7, 25, 11),
    );

    expect(snapshot.streakText, '4 days');
    expect(snapshot.setsThisWeekText, '12 sets');
    expect(snapshot.lastWorkoutTitle, 'Upper A');
    expect(snapshot.lastWorkoutDateText, 'Jul 25');
    expect(snapshot.toWidgetData()['logged_widget_streak_text'], '4 days');
  });

  test('empty history stays readable and singular values stay singular', () {
    final snapshot = HomeWidgetSnapshot(
      streakDays: 1,
      setsThisWeek: 1,
      generatedAt: DateTime(2026, 7, 25),
    );

    expect(snapshot.streakText, '1 day');
    expect(snapshot.setsThisWeekText, '1 set');
    expect(snapshot.lastWorkoutTitle, 'No workouts yet');
    expect(snapshot.lastWorkoutDateText, 'Finish a workout to see it here');
  });
}

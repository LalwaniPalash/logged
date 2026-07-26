import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/home_widget_snapshot.dart';
import 'package:logged/core/domain/workout_session_summary.dart';
import 'package:logged/data/repositories/analytics_repository.dart';

WorkoutSetRecord _record({
  required DateTime date,
  double weightKg = 100,
  int reps = 10,
  WeightEntry weightEntry = WeightEntry.total,
  int sideCount = 1,
}) => WorkoutSetRecord(
  date: date,
  muscleGroup: 'chest',
  exerciseId: 1,
  exerciseName: 'Bench Press',
  weightKg: weightKg,
  reps: reps,
  weightEntry: weightEntry,
  sideCount: sideCount,
);

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

  group('summary widget metrics', () {
    test('compacts weekly volume the way the progress screen does', () {
      HomeWidgetSnapshot snapshotWith(double volumeKg) => HomeWidgetSnapshot(
        streakDays: 2,
        setsThisWeek: 8,
        weeklyVolumeKg: volumeKg,
        generatedAt: DateTime(2026, 7, 25),
      );

      expect(snapshotWith(0).weeklyVolumeText, '0 kg');
      expect(snapshotWith(840).weeklyVolumeText, '840 kg');
      expect(snapshotWith(999.4).weeklyVolumeText, '999 kg');
      expect(snapshotWith(12400).weeklyVolumeText, '12.4k kg');
    });

    test('describes the last workout as sets and exercises', () {
      final snapshot = HomeWidgetSnapshot(
        streakDays: 3,
        setsThisWeek: 18,
        weeklyVolumeKg: 12400,
        lastWorkout: WorkoutSessionSummary(
          id: 9,
          startedAt: DateTime(2026, 7, 25),
          endedAt: DateTime(2026, 7, 25, 1),
          templateName: 'Upper A',
        ),
        lastWorkoutSets: 18,
        lastWorkoutExercises: 6,
        generatedAt: DateTime(2026, 7, 25),
      );

      expect(snapshot.lastWorkoutDetailText, '18 sets · 6 exercises');
      final data = snapshot.toWidgetData();
      expect(data['logged_widget_weekly_volume_text'], '12.4k kg');
      expect(data['logged_widget_last_workout_detail'], '18 sets · 6 exercises');
    });

    test('keeps single sets and exercises singular', () {
      final snapshot = HomeWidgetSnapshot(
        streakDays: 1,
        setsThisWeek: 1,
        lastWorkout: WorkoutSessionSummary(
          id: 9,
          startedAt: DateTime(2026, 7, 25),
          endedAt: DateTime(2026, 7, 25, 1),
          templateName: 'Upper A',
        ),
        lastWorkoutSets: 1,
        lastWorkoutExercises: 1,
        generatedAt: DateTime(2026, 7, 25),
      );

      expect(snapshot.lastWorkoutDetailText, '1 set · 1 exercise');
    });

    test('falls back to a prompt when there is no last workout', () {
      final snapshot = HomeWidgetSnapshot(
        streakDays: 0,
        setsThisWeek: 0,
        generatedAt: DateTime(2026, 7, 25),
      );

      expect(snapshot.lastWorkoutDetailText, 'Log a set to get started');
      expect(snapshot.weeklyVolumeText, '0 kg');
    });
  });

  group('weeklyVolumeKg', () {
    test('sums only sets inside the current week', () {
      final today = DateTime(2026, 7, 25); // Saturday
      final records = [
        _record(date: DateTime(2026, 7, 20)), // Monday, in week
        _record(date: DateTime(2026, 7, 25)), // today, in week
        _record(date: DateTime(2026, 7, 19)), // previous Sunday, out
        _record(date: DateTime(2026, 7, 26)), // future, out
      ];

      expect(weeklyVolumeKg(records, today: today), 2000);
    });

    test('folds per-hand entry and side count into total load', () {
      final today = DateTime(2026, 7, 25);
      final records = [
        _record(
          date: today,
          weightKg: 20,
          reps: 10,
          weightEntry: WeightEntry.perSide,
        ),
        _record(date: today, weightKg: 30, reps: 8, sideCount: 2),
      ];

      expect(weeklyVolumeKg(records, today: today), 400 + 480);
    });

    test('is zero with no records', () {
      expect(weeklyVolumeKg(const [], today: DateTime(2026, 7, 25)), 0);
    });
  });
}

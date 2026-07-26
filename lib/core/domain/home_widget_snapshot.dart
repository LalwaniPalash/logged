import 'package:intl/intl.dart';

import '../../data/repositories/analytics_repository.dart';
import 'streak.dart';
import 'workout_session_summary.dart';

class HomeWidgetSnapshot {
  HomeWidgetSnapshot({
    required this.streakDays,
    required this.setsThisWeek,
    this.weeklyVolumeKg = 0,
    this.lastWorkout,
    this.lastWorkoutSets = 0,
    this.lastWorkoutExercises = 0,
    DateTime? generatedAt,
  }) : generatedAt = dateOnly(generatedAt ?? DateTime.now());

  final int streakDays;
  final int setsThisWeek;
  final double weeklyVolumeKg;
  final WorkoutSessionSummary? lastWorkout;
  final int lastWorkoutSets;
  final int lastWorkoutExercises;
  final DateTime generatedAt;

  String get streakText => '$streakDays ${streakDays == 1 ? 'day' : 'days'}';

  String get setsThisWeekText => _plural(setsThisWeek, 'set');

  /// Compacted the same way the Progress screen shows volume, so the widget and
  /// the app never disagree about the same number.
  String get weeklyVolumeText {
    final abs = weeklyVolumeKg.abs();
    final sign = weeklyVolumeKg < 0 ? '-' : '';
    if (abs >= 1000) return '$sign${(abs / 1000).toStringAsFixed(1)}k kg';
    return '$sign${abs.toStringAsFixed(0)} kg';
  }

  String get lastWorkoutDetailText {
    if (lastWorkout == null) return 'Log a set to get started';
    return '${_plural(lastWorkoutSets, 'set')} · '
        '${_plural(lastWorkoutExercises, 'exercise')}';
  }

  String get lastWorkoutTitle {
    final name = lastWorkout?.displayName.trim();
    return name == null || name.isEmpty ? 'No workouts yet' : name;
  }

  String get lastWorkoutDateText {
    final workoutDate = lastWorkout?.startedAt;
    if (workoutDate == null) return 'Finish a workout to see it here';
    final formatter = workoutDate.year == generatedAt.year
        ? DateFormat.MMMd()
        : DateFormat.yMMMd();
    return formatter.format(dateOnly(workoutDate));
  }

  Map<String, String> toWidgetData() => {
    'logged_widget_streak_text': streakText,
    'logged_widget_sets_text': setsThisWeekText,
    'logged_widget_weekly_volume_text': weeklyVolumeText,
    'logged_widget_last_workout_title': lastWorkoutTitle,
    'logged_widget_last_workout_date': lastWorkoutDateText,
    'logged_widget_last_workout_detail': lastWorkoutDetailText,
  };

  static String _plural(int count, String noun) =>
      '$count ${count == 1 ? noun : '${noun}s'}';
}

int completedSetsThisWeek(
  Iterable<WorkoutSetRecord> records, {
  DateTime? today,
}) => _thisWeek(records, today).length;

/// Total tonnage lifted this week, in kg — [WorkoutSetRecord.volumeKg] already
/// folds per-hand entry and side count into the load.
double weeklyVolumeKg(Iterable<WorkoutSetRecord> records, {DateTime? today}) =>
    _thisWeek(records, today).fold(0, (sum, record) => sum + record.volumeKg);

Iterable<WorkoutSetRecord> _thisWeek(
  Iterable<WorkoutSetRecord> records,
  DateTime? today,
) {
  final now = dateOnly(today ?? DateTime.now());
  final weekStart = startOfWeek(now);
  return records.where((record) {
    final day = dateOnly(record.date);
    return !day.isBefore(weekStart) && !day.isAfter(now);
  });
}

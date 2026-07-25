import 'package:intl/intl.dart';

import '../../data/repositories/analytics_repository.dart';
import 'streak.dart';
import 'workout_session_summary.dart';

class HomeWidgetSnapshot {
  HomeWidgetSnapshot({
    required this.streakDays,
    required this.setsThisWeek,
    this.lastWorkout,
    DateTime? generatedAt,
  }) : generatedAt = dateOnly(generatedAt ?? DateTime.now());

  final int streakDays;
  final int setsThisWeek;
  final WorkoutSessionSummary? lastWorkout;
  final DateTime generatedAt;

  String get streakText => '$streakDays ${streakDays == 1 ? 'day' : 'days'}';

  String get setsThisWeekText =>
      '$setsThisWeek ${setsThisWeek == 1 ? 'set' : 'sets'}';

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
    'logged_widget_last_workout_title': lastWorkoutTitle,
    'logged_widget_last_workout_date': lastWorkoutDateText,
  };
}

int completedSetsThisWeek(
  Iterable<WorkoutSetRecord> records, {
  DateTime? today,
}) {
  final now = dateOnly(today ?? DateTime.now());
  final weekStart = startOfWeek(now);
  return records.where((record) {
    final day = dateOnly(record.date);
    return !day.isBefore(weekStart) && !day.isAfter(now);
  }).length;
}

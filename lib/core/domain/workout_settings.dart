import 'package:flutter/foundation.dart';

/// User schedule preferences. Weekdays use DateTime.weekday (Mon=1 … Sun=7).
@immutable
class WorkoutSettings {
  const WorkoutSettings({required this.restWeekdays, required this.weeklyGoal});

  final Set<int> restWeekdays;
  final int weeklyGoal;

  /// Default: Sunday (7) is a rest day, targeting 6 training days a week.
  static const defaults = WorkoutSettings(restWeekdays: {7}, weeklyGoal: 6);

  WorkoutSettings copyWith({Set<int>? restWeekdays, int? weeklyGoal}) =>
      WorkoutSettings(
        restWeekdays: restWeekdays ?? this.restWeekdays,
        weeklyGoal: weeklyGoal ?? this.weeklyGoal,
      );
}

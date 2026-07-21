import '../../data/repositories/analytics_repository.dart';
import 'streak.dart';

class WeekStat {
  const WeekStat({
    required this.weekStart,
    required this.volumeKg,
    required this.sessions,
  });
  final DateTime weekStart;
  final double volumeKg;
  final int sessions;
}

class PrEvent {
  const PrEvent({
    required this.exerciseName,
    required this.oneRepMaxKg,
    required this.date,
    required this.weightKg,
    required this.reps,
  });
  final String exerciseName;
  final double oneRepMaxKg;
  final DateTime date;
  final double weightKg;
  final int reps;
}

/// Volume and session counts for the last [weeks] Monday-based weeks, oldest
/// first. Weeks with no training still appear (zeroed) so charts read evenly.
List<WeekStat> weeklyStats(
  List<WorkoutSetRecord> records, {
  int weeks = 8,
  DateTime? today,
}) {
  final thisWeekStart = startOfWeek(today ?? DateTime.now());
  final buckets = <DateTime, double>{};
  final sessionDays = <DateTime, Set<int>>{};
  for (final r in records) {
    final ws = startOfWeek(r.date);
    buckets[ws] = (buckets[ws] ?? 0) + r.volumeKg;
    (sessionDays[ws] ??= <int>{}).add(r.date.millisecondsSinceEpoch);
  }
  return [
    for (var i = weeks - 1; i >= 0; i--)
      () {
        final ws = DateTime(
          thisWeekStart.year,
          thisWeekStart.month,
          thisWeekStart.day - i * 7,
        );
        return WeekStat(
          weekStart: ws,
          volumeKg: buckets[ws] ?? 0,
          sessions: sessionDays[ws]?.length ?? 0,
        );
      }(),
  ];
}

/// Total volume (kg) per muscle group for the current Monday-based week.
Map<String, double> muscleVolumeThisWeek(
  List<WorkoutSetRecord> records, {
  DateTime? today,
}) {
  final weekStart = startOfWeek(today ?? DateTime.now());
  final result = <String, double>{};
  for (final r in records) {
    if (startOfWeek(r.date) != weekStart) continue;
    if (r.muscleGroup.isEmpty) continue;
    result[r.muscleGroup] = (result[r.muscleGroup] ?? 0) + r.volumeKg;
  }
  return result;
}

/// Recent personal records: each time an exercise's estimated 1RM reached a new
/// all-time high. Most recent first, capped at [limit].
List<PrEvent> recentPrs(List<WorkoutSetRecord> records, {int limit = 8}) {
  final best = <int, double>{}; // exerciseId -> best 1RM so far
  final events = <PrEvent>[];
  for (final r in records) {
    final current = best[r.exerciseId] ?? 0;
    if (r.estimatedOneRepMaxKg > current + 0.001) {
      best[r.exerciseId] = r.estimatedOneRepMaxKg;
      events.add(
        PrEvent(
          exerciseName: r.exerciseName,
          oneRepMaxKg: r.estimatedOneRepMaxKg,
          date: r.date,
          weightKg: r.weightKg,
          reps: r.reps,
        ),
      );
    }
  }
  events.sort((a, b) => b.date.compareTo(a.date));
  return events.take(limit).toList();
}

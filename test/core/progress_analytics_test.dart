import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/muscle_map.dart';
import 'package:logged/core/domain/progress_analytics.dart';
import 'package:logged/data/repositories/analytics_repository.dart';

WorkoutSetRecord rec(
  DateTime date,
  String mg,
  int eid,
  String name,
  double kg,
  int reps,
) => WorkoutSetRecord(
  date: date,
  muscleGroup: mg,
  exerciseId: eid,
  exerciseName: name,
  weightKg: kg,
  reps: reps,
);

void main() {
  final monday = DateTime(2026, 7, 20, 12);
  DateTime d(int day) => DateTime(2026, 7, day, 12);

  group('recentPrs', () {
    test('flags each new all-time 1RM, most recent first', () {
      final records = [
        rec(d(13), 'chest', 1, 'Bench', 100, 1), // baseline PR
        rec(d(14), 'chest', 1, 'Bench', 100, 5), // higher 1RM -> PR
        rec(d(15), 'chest', 1, 'Bench', 90, 1), // lower -> not a PR
      ];
      final prs = recentPrs(records);
      expect(prs, hasLength(2));
      expect(prs.first.date, d(14)); // most recent PR first
    });
  });

  group('muscleVolumeThisWeek', () {
    test('only counts the current Monday-week', () {
      final records = [
        rec(d(20), 'chest', 1, 'Bench', 100, 5), // this week
        rec(d(13), 'chest', 1, 'Bench', 100, 5), // last week
      ];
      final volume = muscleVolumeThisWeek(records, today: monday);
      expect(volume['chest'], 500); // only the 100*5 from this week
    });
  });

  group('weeklyStats', () {
    test('buckets volume and sessions into the right week', () {
      final records = [
        rec(d(20), 'chest', 1, 'Bench', 100, 5),
        rec(d(20), 'back', 2, 'Row', 50, 10), // same session timestamp
      ];
      final stats = weeklyStats(records, weeks: 2, today: monday);
      expect(stats, hasLength(2));
      final current = stats.last; // most recent week
      expect(current.volumeKg, 500 + 500);
      expect(current.sessions, 1); // both sets share one session timestamp
    });
  });

  group('regionIntensities', () {
    test('splits multi-region groups and normalizes to the busiest', () {
      final intensity = regionIntensities({
        'chest': 300,
        'quads/hamstrings/glutes': 300, // 100 to each of 3 regions
      });
      expect(intensity[BodyRegion.chest], closeTo(1.0, 0.0001));
      expect(intensity[BodyRegion.quads], closeTo(0.3333, 0.001));
    });

    test('unknown groups are ignored', () {
      expect(regionIntensities({'cardio': 100}), isEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/health_export.dart';
import 'package:logged/core/domain/workout_session_summary.dart';

void main() {
  test(
    'sessionsNeedingHealthExport skips exported and unfinished sessions in chronological order',
    () {
      final sessions = [
        WorkoutSessionSummary(
          id: 4,
          startedAt: DateTime(2026, 7, 22, 9),
          endedAt: DateTime(2026, 7, 22, 10),
        ),
        WorkoutSessionSummary(
          id: 2,
          startedAt: DateTime(2026, 7, 20, 9),
          endedAt: DateTime(2026, 7, 20, 10),
        ),
        WorkoutSessionSummary(id: 3, startedAt: DateTime(2026, 7, 21, 9)),
        WorkoutSessionSummary(
          id: 1,
          startedAt: DateTime(2026, 7, 18, 9),
          endedAt: DateTime(2026, 7, 18, 10),
        ),
      ];

      final selected = sessionsNeedingHealthExport(sessions, const [2]);
      expect(selected.map((session) => session.id).toList(), [1, 4]);
    },
  );

  test(
    'decodeExportedSessionIds falls back safely on malformed stored JSON',
    () {
      expect(decodeExportedSessionIds('{not valid json'), isEmpty);
      expect(decodeExportedSessionIds('{"wrong":"shape"}'), isEmpty);
    },
  );
}

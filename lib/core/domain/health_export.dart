import 'dart:convert';

import 'workout_session_summary.dart';

Set<int> decodeExportedSessionIds(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const {};
    final ids = <int>{};
    for (final value in decoded) {
      final parsed = _coercePositiveInt(value);
      if (parsed != null) ids.add(parsed);
    }
    return ids;
  } on Object {
    return const {};
  }
}

String encodeExportedSessionIds(Iterable<int> ids) {
  final unique = {...ids.where((id) => id > 0)}.toList()..sort();
  return jsonEncode(unique);
}

List<WorkoutSessionSummary> sessionsNeedingHealthExport(
  Iterable<WorkoutSessionSummary> sessions,
  Iterable<int> exportedSessionIds,
) {
  final exported = exportedSessionIds.toSet();
  final result =
      sessions
          .where(
            (session) => session.isCompleted && !exported.contains(session.id),
          )
          .toList()
        ..sort((a, b) {
          final byDate = a.startedAt.compareTo(b.startedAt);
          return byDate != 0 ? byDate : a.id.compareTo(b.id);
        });
  return result;
}

int? _coercePositiveInt(Object? value) {
  if (value is int && value > 0) return value;
  if (value is num && value.isFinite && value > 0) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0) return parsed;
  }
  return null;
}

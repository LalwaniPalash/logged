class WorkoutSessionSummary {
  const WorkoutSessionSummary({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.templateName,
  });

  final int id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? templateName;

  bool get isCompleted => endedAt != null;

  String get displayName {
    final trimmed = templateName?.trim();
    return trimmed == null || trimmed.isEmpty ? 'Workout' : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is WorkoutSessionSummary &&
      other.id == id &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt &&
      other.templateName == templateName;

  @override
  int get hashCode => Object.hash(id, startedAt, endedAt, templateName);
}

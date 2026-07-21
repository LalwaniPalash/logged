// Pure streak / weekly-schedule math, kept free of Flutter so it can be unit
// tested directly. Weekdays use DateTime.weekday semantics: Mon=1 … Sun=7.

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Monday-based start of the week containing [value].
DateTime startOfWeek(DateTime value) {
  final d = dateOnly(value);
  return DateTime(d.year, d.month, d.day - (d.weekday - 1));
}

/// A day is a rest day if its weekday is a scheduled rest weekday, or it was
/// manually logged as a rest day.
bool isRestDay(
  DateTime day, {
  required Set<int> restWeekdays,
  required Set<DateTime> loggedRestDays,
}) {
  final d = dateOnly(day);
  return restWeekdays.contains(d.weekday) || loggedRestDays.contains(d);
}

/// The current streak: the number of **trained** days in an unbroken run, where
/// rest days (scheduled or logged) bridge gaps instead of breaking the run. It
/// only breaks on a scheduled training day with no workout. Rest days keep the
/// chain alive but don't inflate the number — so a planned Sunday off never
/// resets the streak, and 6-days-a-week reads as a growing count.
int computeStreak({
  required Iterable<DateTime> trainingDays,
  Set<int> restWeekdays = const {},
  Iterable<DateTime> loggedRestDays = const [],
  DateTime? today,
}) {
  final trained = trainingDays.map(dateOnly).toSet();
  if (trained.isEmpty) return 0;
  final rests = loggedRestDays.map(dateOnly).toSet();
  // Never walk past the first-ever workout — trailing rest days there are just
  // scheduling, not a streak, and this also bounds the loop.
  final earliest = trained.reduce((a, b) => a.isBefore(b) ? a : b);

  bool satisfied(DateTime day) =>
      trained.contains(day) ||
      isRestDay(day, restWeekdays: restWeekdays, loggedRestDays: rests);

  var cursor = dateOnly(today ?? DateTime.now());
  // If today isn't satisfied yet, it's an as-yet-unfulfilled training day — don't
  // break the streak, just start counting from yesterday.
  if (!satisfied(cursor)) {
    cursor = _previousDay(cursor);
  }

  var count = 0;
  while (!cursor.isBefore(earliest) && satisfied(cursor)) {
    if (trained.contains(cursor)) count++;
    cursor = _previousDay(cursor);
  }
  return count;
}

/// Whether a workout has already been completed on [today].
bool trainedToday(Iterable<DateTime> trainingDays, {DateTime? today}) {
  final target = dateOnly(today ?? DateTime.now());
  return trainingDays.map(dateOnly).contains(target);
}

/// Distinct days trained in the current (Monday-based) week, up to and
/// including today.
int trainingDaysThisWeek(Iterable<DateTime> trainingDays, {DateTime? today}) {
  final now = dateOnly(today ?? DateTime.now());
  final weekStart = startOfWeek(now);
  return trainingDays
      .map(dateOnly)
      .where((d) => !d.isBefore(weekStart) && !d.isAfter(now))
      .toSet()
      .length;
}

// Building via (day - 1) lets Dart normalize month/year boundaries, and avoids
// the DST hour-drift you'd get from subtracting a Duration.
DateTime _previousDay(DateTime day) =>
    DateTime(day.year, day.month, day.day - 1);

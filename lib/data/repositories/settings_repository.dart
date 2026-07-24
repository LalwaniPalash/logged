import 'dart:convert';

import '../../core/domain/muscle.dart';
import '../../core/domain/muscle_progress.dart';
import '../../core/domain/training_goal.dart';
import '../../core/domain/strength_standards.dart';
import '../../core/domain/workout_settings.dart';
import '../database/app_database.dart';

class RestTimerPreferences {
  const RestTimerPreferences({
    this.defaultSeconds = 90,
    this.notificationsEnabled = true,
  });

  final int defaultSeconds;
  final bool notificationsEnabled;
}

class ReminderPreferences {
  const ReminderPreferences({
    this.enabled = false,
    this.hour = 18,
    this.minute = 0,
  });

  final bool enabled;
  final int hour;
  final int minute;

  String get encodedTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class CoachingPreferences {
  const CoachingPreferences({
    this.trainingGoal = TrainingGoal.build,
    this.volumeLandmarkOverrides,
    this.userSex = UserSex.unset,
  });

  final TrainingGoal trainingGoal;
  final String? volumeLandmarkOverrides;
  final UserSex userSex;

  // Value equality so watchCoachingPreferences().distinct() can drop re-emits
  // caused by writes to UNRELATED app_settings keys (the whole table is
  // watched). Without this, saving lastSeenRanks recomputed the entire muscle
  // progress + rank chain on every emission.
  @override
  bool operator ==(Object other) =>
      other is CoachingPreferences &&
      other.trainingGoal == trainingGoal &&
      other.volumeLandmarkOverrides == volumeLandmarkOverrides &&
      other.userSex == userSex;

  @override
  int get hashCode =>
      Object.hash(trainingGoal, volumeLandmarkOverrides, userSex);
}

class SettingsRepository {
  const SettingsRepository(this._database);

  final AppDatabase _database;

  static const _kRestWeekdays = 'restWeekdays';
  static const _kWeeklyGoal = 'weeklyGoal';
  static const _kDefaultRestSeconds = 'defaultRestSeconds';
  static const _kRestTimerNotificationsEnabled =
      'restTimerNotificationsEnabled';
  static const _kReminderEnabled = 'reminderEnabled';
  static const _kReminderTime = 'reminderTime';
  static const _kOnboardingComplete = 'onboardingComplete';
  static const _kTrainingGoal = 'trainingGoal';
  static const _kVolumeLandmarkOverrides = 'volumeLandmarkOverrides';
  static const _kDeloadDismissedWeek = 'deloadDismissedWeek';
  static const _kUserSex = 'userSex';
  static const _kLastSeenRanks = 'lastSeenRanks';

  Stream<WorkoutSettings> watch() =>
      _database.select(_database.appSettings).watch().map(_fromRows);

  Future<WorkoutSettings> read() async =>
      _fromRows(await _database.select(_database.appSettings).get());

  Future<void> setRestWeekdays(Set<int> weekdays) =>
      _put(_kRestWeekdays, (weekdays.toList()..sort()).join(','));

  Future<void> setWeeklyGoal(int goal) => _put(_kWeeklyGoal, '$goal');

  Stream<RestTimerPreferences> watchRestTimerPreferences() => _database
      .select(_database.appSettings)
      .watch()
      .map(_restTimerPreferencesFromRows);

  Future<RestTimerPreferences> readRestTimerPreferences() async =>
      _restTimerPreferencesFromRows(
        await _database.select(_database.appSettings).get(),
      );

  Future<void> setDefaultRestSeconds(int seconds) =>
      _put(_kDefaultRestSeconds, '${seconds.clamp(15, 3600)}');

  Future<void> setRestTimerNotificationsEnabled(bool enabled) =>
      _put(_kRestTimerNotificationsEnabled, '$enabled');

  Stream<ReminderPreferences> watchReminderPreferences() => _database
      .select(_database.appSettings)
      .watch()
      .map(_reminderPreferencesFromRows);

  Future<ReminderPreferences> readReminderPreferences() async =>
      _reminderPreferencesFromRows(
        await _database.select(_database.appSettings).get(),
      );

  Future<void> setReminderEnabled(bool enabled) =>
      _put(_kReminderEnabled, '$enabled');

  Future<void> setReminderTime({required int hour, required int minute}) =>
      _put(
        _kReminderTime,
        '${hour.clamp(0, 23).toString().padLeft(2, '0')}:'
        '${minute.clamp(0, 59).toString().padLeft(2, '0')}',
      );

  Stream<CoachingPreferences> watchCoachingPreferences() => _database
      .select(_database.appSettings)
      .watch()
      .map(_coachingPreferencesFromRows)
      .distinct();

  Future<CoachingPreferences> readCoachingPreferences() async =>
      _coachingPreferencesFromRows(
        await _database.select(_database.appSettings).get(),
      );

  Future<void> setTrainingGoal(TrainingGoal goal) =>
      _put(_kTrainingGoal, goal.name);

  Future<void> setUserSex(UserSex sex) => _put(_kUserSex, sex.name);

  Future<void> setVolumeLandmarkOverrides(String? overridesJson) =>
      _put(_kVolumeLandmarkOverrides, overridesJson?.trim() ?? '');

  Future<String?> readDeloadDismissedWeek() async {
    final row =
        await (_database.select(_database.appSettings)
              ..where((setting) => setting.key.equals(_kDeloadDismissedWeek)))
            .getSingleOrNull();
    final value = row?.value.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> dismissDeloadForWeek(String weekKey) =>
      _put(_kDeloadDismissedWeek, weekKey);

  Future<Map<MuscleId, MuscleRank>> readLastSeenRanks() async {
    final row =
        await (_database.select(_database.appSettings)
              ..where((setting) => setting.key.equals(_kLastSeenRanks)))
            .getSingleOrNull();
    if (row == null) return const {};
    try {
      final decoded = jsonDecode(row.value) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          MuscleId.fromId(entry.key): MuscleRank.values.byName(
            entry.value as String,
          ),
      };
    } on Object {
      return const {};
    }
  }

  Future<void> setLastSeenRanks(Map<MuscleId, MuscleRank> ranks) => _put(
    _kLastSeenRanks,
    jsonEncode({
      for (final entry in ranks.entries) entry.key.id: entry.value.name,
    }),
  );

  Future<bool> readOnboardingComplete() async {
    final row =
        await (_database.select(_database.appSettings)
              ..where((setting) => setting.key.equals(_kOnboardingComplete)))
            .getSingleOrNull();
    return bool.tryParse(row?.value ?? '') ?? false;
  }

  Future<void> setOnboardingComplete() => _put(_kOnboardingComplete, 'true');

  WorkoutSettings _fromRows(List<AppSetting> rows) {
    final map = {for (final row in rows) row.key: row.value};
    final restRaw = map[_kRestWeekdays];
    final restWeekdays = restRaw == null
        ? WorkoutSettings.defaults.restWeekdays
        : restRaw.split(',').where((s) => s.isNotEmpty).map(int.parse).toSet();
    final goal =
        int.tryParse(map[_kWeeklyGoal] ?? '') ??
        WorkoutSettings.defaults.weeklyGoal;
    return WorkoutSettings(restWeekdays: restWeekdays, weeklyGoal: goal);
  }

  RestTimerPreferences _restTimerPreferencesFromRows(List<AppSetting> rows) {
    final map = {for (final row in rows) row.key: row.value};
    final seconds =
        int.tryParse(map[_kDefaultRestSeconds] ?? '') ??
        const RestTimerPreferences().defaultSeconds;
    final notificationsEnabled =
        bool.tryParse(map[_kRestTimerNotificationsEnabled] ?? '') ??
        const RestTimerPreferences().notificationsEnabled;
    return RestTimerPreferences(
      defaultSeconds: seconds.clamp(15, 3600),
      notificationsEnabled: notificationsEnabled,
    );
  }

  ReminderPreferences _reminderPreferencesFromRows(List<AppSetting> rows) {
    final map = {for (final row in rows) row.key: row.value};
    final defaults = const ReminderPreferences();
    final time = (map[_kReminderTime] ?? '').split(':');
    final parsedHour = time.length == 2 ? int.tryParse(time[0]) : null;
    final parsedMinute = time.length == 2 ? int.tryParse(time[1]) : null;
    return ReminderPreferences(
      enabled: bool.tryParse(map[_kReminderEnabled] ?? '') ?? defaults.enabled,
      hour: (parsedHour ?? defaults.hour).clamp(0, 23),
      minute: (parsedMinute ?? defaults.minute).clamp(0, 59),
    );
  }

  CoachingPreferences _coachingPreferencesFromRows(List<AppSetting> rows) {
    final map = {for (final row in rows) row.key: row.value};
    var goal = TrainingGoal.build;
    for (final candidate in TrainingGoal.values) {
      if (candidate.name == map[_kTrainingGoal]) {
        goal = candidate;
        break;
      }
    }
    final overrides = map[_kVolumeLandmarkOverrides]?.trim();
    var userSex = UserSex.unset;
    for (final candidate in UserSex.values) {
      if (candidate.name == map[_kUserSex]) {
        userSex = candidate;
        break;
      }
    }
    return CoachingPreferences(
      trainingGoal: goal,
      volumeLandmarkOverrides: overrides == null || overrides.isEmpty
          ? null
          : overrides,
      userSex: userSex,
    );
  }

  Future<void> _put(String key, String value) => _database
      .into(_database.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: value),
      );
}

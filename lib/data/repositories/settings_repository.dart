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

class SettingsRepository {
  const SettingsRepository(this._database);

  final AppDatabase _database;

  static const _kRestWeekdays = 'restWeekdays';
  static const _kWeeklyGoal = 'weeklyGoal';
  static const _kDefaultRestSeconds = 'defaultRestSeconds';
  static const _kRestTimerNotificationsEnabled =
      'restTimerNotificationsEnabled';

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

  Future<void> _put(String key, String value) => _database
      .into(_database.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: value),
      );
}

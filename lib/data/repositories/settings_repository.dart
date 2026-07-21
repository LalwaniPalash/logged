import '../../core/domain/workout_settings.dart';
import '../database/app_database.dart';

class SettingsRepository {
  const SettingsRepository(this._database);

  final AppDatabase _database;

  static const _kRestWeekdays = 'restWeekdays';
  static const _kWeeklyGoal = 'weeklyGoal';

  Stream<WorkoutSettings> watch() =>
      _database.select(_database.appSettings).watch().map(_fromRows);

  Future<WorkoutSettings> read() async =>
      _fromRows(await _database.select(_database.appSettings).get());

  Future<void> setRestWeekdays(Set<int> weekdays) =>
      _put(_kRestWeekdays, (weekdays.toList()..sort()).join(','));

  Future<void> setWeeklyGoal(int goal) => _put(_kWeeklyGoal, '$goal');

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

  Future<void> _put(String key, String value) => _database
      .into(_database.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: value),
      );
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/repositories/settings_repository.dart';

void main() {
  test('health export defaults off and persists when toggled on', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = SettingsRepository(database);

    expect((await repository.readHealthExportPreferences()).enabled, isFalse);
    expect(
      (await repository.readHealthExportPreferences()).exportedSessionIds,
      isEmpty,
    );

    await repository.setHealthExportEnabled(true);
    await repository.setHealthExportedSessionIds(const [9, 3, 9]);

    final prefs = await repository.readHealthExportPreferences();
    expect(prefs.enabled, isTrue);
    expect(prefs.exportedSessionIds, [3, 9]);
  });

  test(
    'health export ids fall back to empty on malformed stored JSON',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = SettingsRepository(database);

      await database
          .into(database.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: 'healthExportedSessionIds',
              value: '{definitely not json',
            ),
          );

      final prefs = await repository.readHealthExportPreferences();
      expect(prefs.exportedSessionIds, isEmpty);
    },
  );

  test(
    'watchHealthExportPreferences ignores unrelated app_settings writes',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = SettingsRepository(database);

      final seen = <HealthExportPreferences>[];
      final sub = repository.watchHealthExportPreferences().listen(seen.add);
      addTearDown(sub.cancel);

      await pumpEventQueue();
      expect(seen, hasLength(1));
      expect(seen.single.enabled, isFalse);

      await repository.setWeeklyGoal(5);
      await pumpEventQueue();
      expect(
        seen,
        hasLength(1),
        reason:
            'an unrelated settings write must not re-emit health export prefs',
      );

      await repository.setHealthExportEnabled(true);
      await pumpEventQueue();
      expect(seen, hasLength(2));
      expect(seen.last.enabled, isTrue);
    },
  );
}

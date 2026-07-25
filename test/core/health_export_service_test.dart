import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:logged/core/services/health_export_service.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/repositories/session_repository.dart';
import 'package:logged/data/repositories/settings_repository.dart';

/// Fails the write on the [failOnCall]-th call (1-based); 0 never fails.
/// [throwOnCall] makes that call throw instead of returning false, which is the
/// path that actually loses progress if the exported-id marker is batched.
class _FakeHealth extends Health {
  _FakeHealth({this.failOnCall = 0, this.throwOnCall = 0});

  final int failOnCall;
  final int throwOnCall;
  int calls = 0;
  final written = <DateTime>[];

  @override
  Future<void> configure() async {}

  @override
  Future<bool> isHealthConnectAvailable() async => true;

  @override
  Future<bool?> hasPermissions(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async => true;

  @override
  Future<bool> requestAuthorization(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async => true;

  @override
  Future<bool> writeWorkoutData({
    required HealthWorkoutActivityType activityType,
    required DateTime start,
    required DateTime end,
    int? totalEnergyBurned,
    HealthDataUnit totalEnergyBurnedUnit = HealthDataUnit.KILOCALORIE,
    int? totalDistance,
    HealthDataUnit totalDistanceUnit = HealthDataUnit.METER,
    String? title,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async {
    calls++;
    if (calls == throwOnCall) throw StateError('health store exploded');
    if (calls == failOnCall) return false;
    written.add(start);
    return true;
  }
}

Future<AppDatabase> _databaseWithSessions(int count) async {
  final database = AppDatabase(NativeDatabase.memory());
  for (var i = 1; i <= count; i++) {
    await database
        .into(database.sessions)
        .insert(
          SessionsCompanion.insert(
            startedAt: DateTime(2026, 7, i, 9),
            endedAt: Value(DateTime(2026, 7, i, 10)),
          ),
        );
  }
  return database;
}

void main() {
  test('export is a no-op until the user opts in', () async {
    final database = await _databaseWithSessions(2);
    addTearDown(database.close);
    final health = _FakeHealth();
    final service = HealthExportService(
      sessions: SessionRepository(database),
      settings: SettingsRepository(database),
      health: health,
    );

    final result = await service.export();

    expect(result.failed, isTrue);
    expect(health.calls, 0, reason: 'nothing may be written before opt-in');
  });

  test('export writes each completed session once, then skips them', () async {
    final database = await _databaseWithSessions(3);
    addTearDown(database.close);
    final settings = SettingsRepository(database);
    await settings.setHealthExportEnabled(true);
    final health = _FakeHealth();
    final service = HealthExportService(
      sessions: SessionRepository(database),
      settings: settings,
      health: health,
    );

    final first = await service.export();
    expect(first.exportedCount, 3);
    expect(first.skippedCount, 0);

    // Re-running must not duplicate anything already in the health store.
    final second = await service.export();
    expect(second.exportedCount, 0);
    expect(second.skippedCount, 3);
    expect(health.calls, 3, reason: 'no session may be written twice');
  });

  // The marker is persisted per write, not once at the end. Batching it meant a
  // failure (or a kill) part-way through re-wrote every workout of that run on
  // the next attempt, duplicating them in the health store.
  test('a failure part-way through keeps earlier writes marked', () async {
    final database = await _databaseWithSessions(4);
    addTearDown(database.close);
    final settings = SettingsRepository(database);
    await settings.setHealthExportEnabled(true);
    final failing = _FakeHealth(failOnCall: 3);
    final service = HealthExportService(
      sessions: SessionRepository(database),
      settings: settings,
      health: failing,
    );

    final result = await service.export();
    expect(result.failed, isTrue);
    expect(result.exportedCount, 2);
    expect(
      (await settings.readHealthExportPreferences()).exportedSessionIds,
      hasLength(2),
      reason: 'the two successful writes must be recorded before the failure',
    );

    // A retry picks up only what never made it, so the first two are not
    // written a second time.
    final healthy = _FakeHealth();
    final retry = HealthExportService(
      sessions: SessionRepository(database),
      settings: settings,
      health: healthy,
    ).export();
    expect((await retry).exportedCount, 2);
    expect(healthy.calls, 2);
  });

  // This is the case the batched marker actually lost: the write THROWS, so the
  // service unwinds into its catch-all and never reaches an end-of-loop save.
  // Anything already written to the health store would be written again.
  test('a throwing write keeps earlier writes marked', () async {
    final database = await _databaseWithSessions(4);
    addTearDown(database.close);
    final settings = SettingsRepository(database);
    await settings.setHealthExportEnabled(true);
    final throwing = _FakeHealth(throwOnCall: 3);
    final service = HealthExportService(
      sessions: SessionRepository(database),
      settings: settings,
      health: throwing,
    );

    final result = await service.export();
    expect(result.failed, isTrue, reason: 'a throw must not escape into the UI');
    expect(
      (await settings.readHealthExportPreferences()).exportedSessionIds,
      hasLength(2),
      reason: 'the two writes that succeeded before the throw stay recorded',
    );

    final healthy = _FakeHealth();
    await HealthExportService(
      sessions: SessionRepository(database),
      settings: settings,
      health: healthy,
    ).export();
    expect(
      healthy.calls,
      2,
      reason: 'only the two never-written sessions may be retried',
    );
  });
}

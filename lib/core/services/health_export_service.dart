import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';

import '../../data/repositories/session_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../domain/health_export.dart';

abstract interface class HealthExportClient {
  Future<HealthExportResult> export();
}

class HealthExportResult {
  const HealthExportResult({
    this.exportedCount = 0,
    this.skippedCount = 0,
    this.failureReason,
  });

  final int exportedCount;
  final int skippedCount;
  final String? failureReason;

  bool get failed => failureReason != null;
}

class HealthExportService implements HealthExportClient {
  HealthExportService({
    required SessionRepository sessions,
    required SettingsRepository settings,
    Health? health,
  }) : _sessions = sessions,
       _settings = settings,
       _health = health ?? Health();

  static const _types = [HealthDataType.WORKOUT];
  static const _permissions = [HealthDataAccess.WRITE];

  final SessionRepository _sessions;
  final SettingsRepository _settings;
  final Health _health;

  @override
  Future<HealthExportResult> export() async {
    final preferences = await _settings.readHealthExportPreferences();
    if (!preferences.enabled) {
      return const HealthExportResult(
        failureReason: 'Turn on Health export first.',
      );
    }

    try {
      await _health.configure();
      if (Platform.isAndroid && !await _health.isHealthConnectAvailable()) {
        return const HealthExportResult(
          failureReason: 'Health Connect is not available on this device.',
        );
      }

      final hasPermissions = await _health.hasPermissions(
        _types,
        permissions: _permissions,
      );
      final authorized =
          hasPermissions == true ||
          await _health.requestAuthorization(_types, permissions: _permissions);
      if (!authorized) {
        return const HealthExportResult(
          failureReason: 'Health access was not granted.',
        );
      }

      final sessions = await _sessions.loadWorkoutSummaries();
      final pending = sessionsNeedingHealthExport(
        sessions,
        preferences.exportedSessionIds,
      );
      // Everything already in the health store before this run. Counting it as
      // "skipped" is the honest reading; deriving it from exportedCount instead
      // would fold already-exported history in with writes that failed.
      final alreadyExported =
          sessions.where((session) => session.isCompleted).length -
          pending.length;
      final exportedIds = {...preferences.exportedSessionIds};
      var exportedCount = 0;

      for (final session in pending) {
        final success = await _health.writeWorkoutData(
          activityType: HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
          start: session.startedAt,
          end: session.endedAt!,
        );
        if (!success) {
          return HealthExportResult(
            exportedCount: exportedCount,
            skippedCount: alreadyExported,
            failureReason:
                'Could not write workouts to the device health store.',
          );
        }
        exportedIds.add(session.id);
        exportedCount++;
        // Persist per write, not once at the end. Two stores cannot be written
        // atomically, so the order is chosen for the least-bad failure: write
        // first then mark, which risks a duplicate rather than a lost workout.
        // Marking after every write caps that risk at the single workout in
        // flight — batching the marker meant being killed mid-export re-wrote
        // every workout of the run on the next attempt.
        await _settings.setHealthExportedSessionIds(exportedIds);
      }

      return HealthExportResult(
        exportedCount: exportedCount,
        skippedCount: alreadyExported,
      );
    } on MissingPluginException catch (error) {
      debugPrint('Health plugin unavailable: $error');
      return const HealthExportResult(
        failureReason: 'Health export is unavailable on this device.',
      );
    } on PlatformException catch (error) {
      debugPrint('Health export platform error: $error');
      return const HealthExportResult(
        failureReason: 'Health export is unavailable on this device.',
      );
    } on UnsupportedError catch (error) {
      debugPrint('Health export unsupported: $error');
      return HealthExportResult(
        failureReason: Platform.isAndroid
            ? 'Health Connect is not available on this device.'
            : 'Health export is unavailable on this device.',
      );
    } on HealthException catch (error) {
      debugPrint('Health export failed: $error');
      return HealthExportResult(failureReason: error.cause);
    } on Object catch (error) {
      debugPrint('Health export failed: $error');
      return const HealthExportResult(
        failureReason: 'Health export is unavailable on this device.',
      );
    }
  }
}

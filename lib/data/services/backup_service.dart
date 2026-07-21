import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/app_database.dart';
import 'exercise_anatomy_service.dart';

class BackupService {
  BackupService(this._database, {ExerciseAnatomyService? anatomyService})
    : _anatomyService = anatomyService ?? ExerciseAnatomyService(_database);

  final AppDatabase _database;
  final ExerciseAnatomyService _anatomyService;

  Future<void> exportAndShare() async {
    final payload = await exportPayload();
    final directory = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final file = File('${directory.path}/logged-backup-$stamp.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Logged backup'),
    );
  }

  Future<bool> importFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return false;
    final raw = jsonDecode(await File(path).readAsString());
    if (raw is! Map<String, dynamic> ||
        raw['app'] != 'Logged' ||
        (raw['schemaVersion'] != 1 &&
            raw['schemaVersion'] != 2 &&
            raw['schemaVersion'] != 3 &&
            raw['schemaVersion'] != 4 &&
            raw['schemaVersion'] != 5 &&
            raw['schemaVersion'] != 6)) {
      throw const FormatException('This is not a valid Logged backup file.');
    }
    await replaceFromPayload(raw);
    return true;
  }

  Future<Map<String, dynamic>> exportPayload() async => {
    'app': 'Logged',
    'appVersion': '1.0.0',
    'schemaVersion': 6,
    'exportedAt': DateTime.now().toIso8601String(),
    'exercises': (await _database.select(_database.exercises).get())
        .map((row) => row.toJson())
        .toList(),
    'templates': (await _database.select(_database.templates).get())
        .map((row) => row.toJson())
        .toList(),
    'templateExercises':
        (await _database.select(_database.templateExercises).get())
            .map((row) => row.toJson())
            .toList(),
    'sessions': (await _database.select(_database.sessions).get())
        .map((row) => row.toJson())
        .toList(),
    'sessionExercises':
        (await _database.select(_database.sessionExercises).get())
            .map((row) => row.toJson())
            .toList(),
    'setEntries': (await _database.select(_database.setEntries).get())
        .map((row) => row.toJson())
        .toList(),
    'bodyweightEntries':
        (await _database.select(_database.bodyweightEntries).get())
            .map((row) => row.toJson())
            .toList(),
    'restDays': (await _database.select(_database.restDays).get())
        .map((row) => row.toJson())
        .toList(),
    'appSettings': (await _database.select(_database.appSettings).get())
        .map((row) => row.toJson())
        .toList(),
  };

  List<Map<String, dynamic>> _rows(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is! List || !value.every((row) => row is Map<String, dynamic>)) {
      throw FormatException('Missing or invalid $key.');
    }
    return value.cast<Map<String, dynamic>>();
  }

  // Tolerant read for tables added in later schema versions, so older backups
  // (which lack these keys) still import cleanly.
  List<Map<String, dynamic>> _optionalRows(
    Map<String, dynamic> source,
    String key,
  ) {
    final value = source[key];
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().toList();
  }

  Exercise _exerciseFromBackup(Map<String, dynamic> source) =>
      Exercise.fromJson({
        ...source,
        'primaryMuscles': source['primaryMuscles'] ?? '[]',
        'secondaryMuscles': source['secondaryMuscles'] ?? '[]',
        'weightEntry': source['weightEntry'] ?? 'total',
        'preferredLoadingMode': source['preferredLoadingMode'] ?? 'external',
        'bodyweightFactor': source['bodyweightFactor'] ?? 1.0,
      });

  SetEntry _setEntryFromBackup(Map<String, dynamic> source) =>
      SetEntry.fromJson({
        ...source,
        'weightEntry': source['weightEntry'] ?? 'total',
        'sideCount': source['sideCount'] ?? 1,
        'loadingMode': source['loadingMode'] ?? 'external',
      });

  TemplateExercise _templateExerciseFromBackup(Map<String, dynamic> source) =>
      TemplateExercise.fromJson({
        ...source,
        'targetSets': source['targetSets'],
        'sidesPerSet': source['sidesPerSet'],
        'minReps': source['minReps'],
        'maxReps': source['maxReps'],
        'targetDurationSec': source['targetDurationSec'],
        'targetDistanceMeters': source['targetDistanceMeters'],
        'restSeconds': source['restSeconds'],
        'eccentricSec': source['eccentricSec'],
        'bottomPauseSec': source['bottomPauseSec'],
        'concentricSec': source['concentricSec'],
        'topPauseSec': source['topPauseSec'],
        'prescriptionNotes': source['prescriptionNotes'],
        'formUrl': source['formUrl'],
      });

  SessionExercise _sessionExerciseFromBackup(Map<String, dynamic> source) =>
      SessionExercise.fromJson({
        ...source,
        'targetSets': source['targetSets'],
        'sidesPerSet': source['sidesPerSet'],
        'minReps': source['minReps'],
        'maxReps': source['maxReps'],
        'targetDurationSec': source['targetDurationSec'],
        'targetDistanceMeters': source['targetDistanceMeters'],
        'restSeconds': source['restSeconds'],
        'eccentricSec': source['eccentricSec'],
        'bottomPauseSec': source['bottomPauseSec'],
        'concentricSec': source['concentricSec'],
        'topPauseSec': source['topPauseSec'],
        'prescriptionNotes': source['prescriptionNotes'],
        'formUrl': source['formUrl'],
      });

  Future<void> replaceFromPayload(Map<String, dynamic> source) async {
    await _database.transaction(() async {
      await _database.delete(_database.setEntries).go();
      await _database.delete(_database.bodyweightEntries).go();
      await _database.delete(_database.sessionExercises).go();
      await _database.delete(_database.sessions).go();
      await _database.delete(_database.templateExercises).go();
      await _database.delete(_database.templates).go();
      await _database.delete(_database.exercises).go();
      await _database.delete(_database.restDays).go();
      await _database.delete(_database.appSettings).go();
      await _database.batch((batch) {
        batch.insertAll(
          _database.exercises,
          _rows(source, 'exercises').map(_exerciseFromBackup).toList(),
          mode: InsertMode.insertOrReplace,
        );
        batch.insertAll(
          _database.templates,
          _rows(source, 'templates').map(Template.fromJson).toList(),
          mode: InsertMode.insertOrReplace,
        );
        batch.insertAll(
          _database.templateExercises,
          _rows(
            source,
            'templateExercises',
          ).map(_templateExerciseFromBackup).toList(),
          mode: InsertMode.insertOrReplace,
        );
        batch.insertAll(
          _database.sessions,
          _rows(source, 'sessions').map(Session.fromJson).toList(),
          mode: InsertMode.insertOrReplace,
        );
        batch.insertAll(
          _database.sessionExercises,
          _rows(
            source,
            'sessionExercises',
          ).map(_sessionExerciseFromBackup).toList(),
          mode: InsertMode.insertOrReplace,
        );
        batch.insertAll(
          _database.setEntries,
          _rows(source, 'setEntries').map(_setEntryFromBackup).toList(),
          mode: InsertMode.insertOrReplace,
        );
        batch.insertAll(
          _database.bodyweightEntries,
          _optionalRows(
            source,
            'bodyweightEntries',
          ).map(BodyweightEntry.fromJson).toList(),
          mode: InsertMode.insertOrReplace,
        );
        batch.insertAll(
          _database.restDays,
          _optionalRows(source, 'restDays').map(RestDay.fromJson).toList(),
          mode: InsertMode.insertOrReplace,
        );
        batch.insertAll(
          _database.appSettings,
          _optionalRows(
            source,
            'appSettings',
          ).map(AppSetting.fromJson).toList(),
          mode: InsertMode.insertOrReplace,
        );
      });
    });
    final version = source['schemaVersion'] as int? ?? 1;
    if (version < 3) {
      await _anatomyService.enrichBundledExercises();
    }
  }
}

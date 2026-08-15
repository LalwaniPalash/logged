import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/app_database.dart';
import '../../core/domain/enums.dart';
import '../../core/domain/muscle.dart';
import '../../core/domain/muscle_bias.dart';
import '../../core/domain/workout_metrics.dart';
import 'exercise_anatomy_service.dart';

class BackupService {
  BackupService(this._database, {ExerciseAnatomyService? anatomyService})
    : _anatomyService = anatomyService ?? ExerciseAnatomyService(_database);

  final AppDatabase _database;
  final ExerciseAnatomyService _anatomyService;

  /// Schema versions this build can read. The current writer is [_schemaVersion].
  static const Set<int> _supportedSchemaVersions = {
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
  };
  static const int _schemaVersion = 13;

  /// Name of the JSON document stored inside the exported `.zip`.
  static const String _entryName = 'logged-backup.json';
  static const Set<String> _deviceLocalSettingKeys = {
    'healthExportedSessionIds',
    'muscleAnatomyBackfilled',
    'muscleAnatomyBackfillVersion',
    'weightEntryBackfilled',
    'pullUpExerciseBackfilled',
    'timedExerciseBackfilled',
    'onboardingComplete',
  };

  Future<void> exportAndShare() async {
    final payload = await exportPayload();
    final directory = await getTemporaryDirectory();
    await _pruneStaleExports(directory);
    final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

    // The backup is JSON (repeated keys, very compressible) so it is zipped —
    // typically 80-90% smaller. Still one file. `.json` backups remain readable
    // on import for anyone holding an older export.
    final json = utf8.encode(jsonEncode(payload));
    final archive = Archive()
      ..addFile(ArchiveFile(_entryName, json.length, json));
    final zipBytes = ZipEncoder().encode(archive);
    final file = File('${directory.path}/logged-backup-$stamp.zip');
    await file.writeAsBytes(zipBytes);

    // `text` must NOT be set alongside `files`: the iOS plugin appends the text
    // as a SECOND activity item, so saving to Files produced two files — the
    // backup plus a stray note. `subject` is metadata only (email subject), so
    // exactly one file is shared.
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'Logged backup'),
    );
  }

  /// Exports a flat, one-row-per-logged-set CSV for spreadsheets. Export only —
  /// it cannot be imported, because it does not carry the relational structure.
  Future<void> exportSetHistoryCsv() async {
    final csv = await setHistoryCsv();
    final directory = await getTemporaryDirectory();
    await _pruneStaleExports(directory);
    final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final file = File('${directory.path}/logged-sets-$stamp.csv');
    await file.writeAsString(csv);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'Logged set history'),
    );
  }

  Future<bool> importFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'json'],
    );
    final path = result?.files.firstOrNull?.path;
    if (path == null) return false;
    final raw = _decodeBackup(await File(path).readAsBytes(), path);
    if (raw is! Map<String, dynamic> ||
        raw['app'] != 'Logged' ||
        !_supportedSchemaVersions.contains(raw['schemaVersion'])) {
      throw const FormatException('This is not a valid Logged backup file.');
    }
    await replaceFromPayload(raw);
    return true;
  }

  /// Reads either a raw `.json` backup or a `.zip` produced by [exportAndShare].
  /// Sniffs the zip magic bytes rather than trusting the extension.
  ///
  /// Any decode/decompress/parse failure is normalised to a [FormatException] so
  /// the caller's single "invalid backup" path handles it — otherwise a corrupt
  /// or password-protected zip escapes as an uncaught async error.
  Object? _decodeBackup(List<int> bytes, String path) {
    final looksZip =
        path.toLowerCase().endsWith('.zip') ||
        (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B);
    try {
      if (looksZip) {
        final archive = ZipDecoder().decodeBytes(bytes);
        final entry = archive.files.firstWhere(
          (file) => file.isFile && file.name.endsWith('.json'),
          orElse: () =>
              throw const FormatException('No backup found inside the zip.'),
        );
        return jsonDecode(utf8.decode(entry.content));
      }
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('This file could not be read as a backup.');
    }
  }

  Future<String> setHistoryCsv() async {
    final db = _database;
    final rows =
        await (db.select(db.setEntries).join([
              innerJoin(
                db.sessionExercises,
                db.sessionExercises.id.equalsExp(
                  db.setEntries.sessionExerciseId,
                ),
              ),
              innerJoin(
                db.sessions,
                db.sessions.id.equalsExp(db.sessionExercises.sessionId),
              ),
              innerJoin(
                db.exercises,
                db.exercises.id.equalsExp(db.sessionExercises.exerciseId),
              ),
            ])..orderBy([
              OrderingTerm.asc(db.sessions.startedAt),
              OrderingTerm.asc(db.setEntries.setNumber),
            ]))
            .get();

    final buffer = StringBuffer()
      ..writeln(
        'date,exercise,set,warmup,weight,unit,per_hand,reps,each_side,'
        'duration_sec,distance_m,rpe,volume_kg',
      );
    final dateFormat = DateFormat('yyyy-MM-dd');
    for (final row in rows) {
      final set = row.readTable(db.setEntries);
      final session = row.readTable(db.sessions);
      final exercise = row.readTable(db.exercises);
      final volume = setVolumeKg(
        weightValue: set.weightValue,
        unit: set.unit,
        reps: set.reps,
        entry: set.weightEntry,
        sideCount: set.sideCount,
      );
      buffer.writeln(
        [
          dateFormat.format(session.startedAt),
          _csvField(exercise.name),
          set.setNumber,
          set.isWarmup ? 'yes' : 'no',
          set.weightValue ?? '',
          set.unit?.name ?? '',
          set.weightEntry == WeightEntry.perSide ? 'yes' : 'no',
          set.reps ?? '',
          set.sideCount > 1 ? 'yes' : 'no',
          set.durationSec ?? '',
          set.distanceMeters ?? '',
          set.rpe ?? '',
          volume == 0 ? '' : _trimCsvDouble(volume),
        ].join(','),
      );
    }
    return buffer.toString();
  }

  /// Renders a CSV field safely. Two concerns:
  ///  * RFC 4180 quoting when the value holds a comma, quote, CR, or LF.
  ///  * Formula-injection: a spreadsheet treats a cell starting with `= + - @`
  ///    (or a leading tab/CR) as a formula. Exercise names are user-entered, so
  ///    a leading `'` neutralises that before quoting.
  static String _csvField(String value) {
    var field = value;
    if (field.isNotEmpty && '=+-@\t\r'.contains(field[0])) {
      field = "'$field";
    }
    if (field.contains(RegExp('[",\r\n]'))) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  static String _trimCsvDouble(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  Future<Map<String, dynamic>> exportPayload() async => {
    'app': 'Logged',
    'appVersion': '1.0.0',
    'schemaVersion': _schemaVersion,
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
        .where((row) => !_deviceLocalSettingKeys.contains(row.key))
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

  Future<void> _pruneStaleExports(Directory directory) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 1));
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      final managedExport =
          (name.startsWith('logged-backup-') && name.endsWith('.zip')) ||
          (name.startsWith('logged-sets-') && name.endsWith('.csv'));
      if (!managedExport) continue;
      try {
        final modified = await entity.lastModified();
        if (modified.isBefore(cutoff)) {
          await entity.delete();
        }
      } on FileSystemException {
        // Cleanup failure should not block exporting the fresh file.
      }
    }
  }

  Exercise _exerciseFromBackup(Map<String, dynamic> source) =>
      Exercise.fromJson({
        ...source,
        'primaryMuscles': source['primaryMuscles'] ?? '[]',
        'secondaryMuscles': source['secondaryMuscles'] ?? '[]',
        'weightEntry': source['weightEntry'] ?? 'total',
        'preferredLoadingMode': source['preferredLoadingMode'] ?? 'external',
        'bodyweightFactor': source['bodyweightFactor'] ?? 1.0,
        'isTimed': source['isTimed'] ?? false,
        'tracksDistance': source['tracksDistance'] ?? false,
        'anatomyEditedByUser': source['anatomyEditedByUser'] ?? false,
      });

  SetEntry _setEntryFromBackup(
    Map<String, dynamic> source, {
    String? legacyMuscleBiasWeights,
  }) => SetEntry.fromJson({
    ...source,
    'weightEntry': source['weightEntry'] ?? 'total',
    'sideCount': source['sideCount'] ?? 1,
    'loadingMode': source['loadingMode'] ?? 'external',
    'muscleBiasWeights': source['muscleBiasWeights'] ?? legacyMuscleBiasWeights,
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
    final exerciseRows = _rows(source, 'exercises');
    final sessionExerciseRows = _rows(source, 'sessionExercises');
    final setRows = _rows(source, 'setEntries');
    final exercisesById = _rowsById(exerciseRows);
    final sessionExercisesById = _rowsById(sessionExerciseRows);
    final preservedDeviceLocalSettings =
        (await (_database.select(_database.appSettings)..where(
                  (row) => row.key.isIn(_deviceLocalSettingKeys.toList()),
                ))
                .get())
            .map((row) => row.toJson())
            .toList(growable: false);
    final version = source['schemaVersion'] as int? ?? 1;
    final portableAppSettings = _optionalRows(source, 'appSettings')
        .where(
          (row) =>
              row['key'] is! String ||
              !_deviceLocalSettingKeys.contains(row['key']),
        )
        .map(AppSetting.fromJson)
        .toList(growable: false);

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
          exerciseRows.map(_exerciseFromBackup).toList(),
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
          sessionExerciseRows.map(_sessionExerciseFromBackup).toList(),
          mode: InsertMode.insertOrReplace,
        );
        batch.insertAll(
          _database.setEntries,
          setRows.map((row) {
            final legacyWeights = _legacyMuscleBiasWeightsFromBackup(
              row,
              exercisesById: exercisesById,
              sessionExercisesById: sessionExercisesById,
            );
            return _setEntryFromBackup(
              row,
              legacyMuscleBiasWeights: legacyWeights,
            );
          }).toList(),
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
        batch.insertAll(_database.appSettings, [
          ...portableAppSettings,
          ...preservedDeviceLocalSettings.map(AppSetting.fromJson),
        ], mode: InsertMode.insertOrReplace);
      });
      // Inside the transaction on purpose. The imported rows are already at
      // v11 schema, so a crash between the commit and a later rescale would
      // strand share-scale weights that no migration would ever fix again.
      if (version < 11) {
        await rescaleStoredMuscleBiasWeights(_database);
      }
    });
    if (version < 8) {
      await _anatomyService.enrichBundledExercises();
    }
    if (version < 12) {
      await _anatomyService.backfillTimedExerciseOnce();
    }
  }

  Map<int, Map<String, dynamic>> _rowsById(List<Map<String, dynamic>> rows) => {
    for (final row in rows)
      if (row['id'] case final num id) id.toInt(): row,
  };

  String? _legacyMuscleBiasWeightsFromBackup(
    Map<String, dynamic> setRow, {
    required Map<int, Map<String, dynamic>> exercisesById,
    required Map<int, Map<String, dynamic>> sessionExercisesById,
  }) {
    if (setRow['muscleBiasWeights'] != null) {
      return setRow['muscleBiasWeights'] as String?;
    }
    final legacyBias = (setRow['muscleBias'] as num?)?.toDouble();
    if (legacyBias == null) return null;

    final sessionExerciseId = (setRow['sessionExerciseId'] as num?)?.toInt();
    final sessionExercise = sessionExerciseId == null
        ? null
        : sessionExercisesById[sessionExerciseId];
    final exerciseId = (sessionExercise?['exerciseId'] as num?)?.toInt();
    final exercise = exerciseId == null ? null : exercisesById[exerciseId];
    if (exercise == null) return null;

    final biasMuscleAId = exercise['biasMuscleA'] as String?;
    final biasMuscleBId = exercise['biasMuscleB'] as String?;
    if (biasMuscleAId == null || biasMuscleBId == null) return null;

    try {
      final biasMuscleA = _decodeLegacyMuscle(biasMuscleAId);
      final biasMuscleB = _decodeLegacyMuscle(biasMuscleBId);
      if (biasMuscleA == biasMuscleB) return null;
      final shares = resolveMuscleBiasShares(legacyBias);
      return encodeMuscleBiasWeights({
        biasMuscleA: shares.shareA,
        biasMuscleB: shares.shareB,
      });
    } on ArgumentError {
      return null;
    }
  }

  MuscleId _decodeLegacyMuscle(String value) {
    try {
      return MuscleId.fromId(value);
    } on ArgumentError {
      return MuscleId.values.byName(value);
    }
  }
}

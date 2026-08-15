import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/core/domain/muscle_bias.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/services/backup_service.dart';
import 'package:logged/data/services/exercise_anatomy_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('backup payload round-trips all linked workout data', () async {
    final source = AppDatabase(NativeDatabase.memory());
    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    addTearDown(target.close);
    final exerciseId = await source
        .into(source.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Barbell Bench Press',
            category: ExerciseCategory.strength,
            muscleGroup: 'chest',
            primaryMuscles: Value(jsonEncode(['mid_lower_chest'])),
            secondaryMuscles: Value(jsonEncode(['front_delts', 'triceps'])),
            defaultUnit: const Value(WeightUnit.kg),
            weightEntry: const Value(WeightEntry.perSide),
            isTimed: const Value(true),
            tracksDistance: const Value(true),
            videoUrl: const Value('https://youtu.be/demo'),
            isCustom: const Value(false),
            isArchived: const Value(false),
          ),
        );
    final sessionId = await source
        .into(source.sessions)
        .insert(
          SessionsCompanion.insert(
            startedAt: DateTime.utc(2026, 7, 20),
            endedAt: Value(DateTime.utc(2026, 7, 20, 12)),
          ),
        );
    final linkId = await source
        .into(source.sessionExercises)
        .insert(
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: 0,
          ),
        );
    await source
        .into(source.setEntries)
        .insert(
          SetEntriesCompanion.insert(
            sessionExerciseId: linkId,
            setNumber: 1,
            reps: const Value(5),
            weightValue: const Value(100),
            unit: const Value(WeightUnit.kg),
            weightEntry: const Value(WeightEntry.perSide),
            sideCount: const Value(2),
            muscleBiasWeights: Value(
              encodeMuscleBiasWeights(const {
                MuscleId.midLowerChest: 0.7,
                MuscleId.frontDelts: 0.3,
              }),
            ),
          ),
        );
    await source
        .into(source.bodyweightEntries)
        .insert(
          BodyweightEntriesCompanion.insert(
            date: DateTime.utc(2026, 7, 1),
            value: 80,
            unit: WeightUnit.kg,
          ),
        );
    final payload = await BackupService(source).exportPayload();
    expect(payload['schemaVersion'], 13);
    await BackupService(target).replaceFromPayload(payload);
    final exercises = await target.select(target.exercises).get();
    expect(exercises, hasLength(1));
    expect(exercises.single.videoUrl, 'https://youtu.be/demo');
    expect(jsonDecode(exercises.single.primaryMuscles), ['mid_lower_chest']);
    expect(jsonDecode(exercises.single.secondaryMuscles), [
      'front_delts',
      'triceps',
    ]);
    expect(exercises.single.weightEntry, WeightEntry.perSide);
    expect(exercises.single.isTimed, isTrue);
    expect(exercises.single.tracksDistance, isTrue);
    expect(await target.select(target.sessions).get(), hasLength(1));
    final sets = await target.select(target.setEntries).get();
    expect(sets, hasLength(1));
    expect(sets.single.weightValue, 100);
    expect(sets.single.weightEntry, WeightEntry.perSide);
    expect(sets.single.sideCount, 2);
    expect(sets.single.loadingMode, LoadingMode.external);
    expect(decodeMuscleBiasWeights(sets.single.muscleBiasWeights), const {
      MuscleId.midLowerChest: 0.7,
      MuscleId.frontDelts: 0.3,
    });
    final bodyweights = await target.select(target.bodyweightEntries).get();
    expect(bodyweights, hasLength(1));
    expect(bodyweights.single.value, 80);
  });

  test('export payload omits device-local app settings', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await _putAppSetting(db, 'weeklyGoal', '4');
    await _putAppSetting(db, 'onboardingComplete', 'true');
    await _putAppSetting(db, 'healthExportedSessionIds', '[1,2]');
    await _putAppSetting(db, 'muscleAnatomyBackfillVersion', '2');
    await _putAppSetting(db, 'weightEntryBackfilled', 'true');
    await _putAppSetting(db, 'pullUpExerciseBackfilled', 'true');
    await _putAppSetting(db, 'timedExerciseBackfilled', 'true');

    final payload = await BackupService(db).exportPayload();
    final keys = (payload['appSettings'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((row) => row['key'])
        .toSet();

    expect(keys, contains('weeklyGoal'));
    expect(keys, isNot(contains('onboardingComplete')));
    expect(keys, isNot(contains('healthExportedSessionIds')));
    expect(keys, isNot(contains('muscleAnatomyBackfillVersion')));
    expect(keys, isNot(contains('weightEntryBackfilled')));
    expect(keys, isNot(contains('pullUpExerciseBackfilled')));
    expect(keys, isNot(contains('timedExerciseBackfilled')));
  });

  test(
    'import skips device-local app settings and preserves local markers',
    () async {
      final source = AppDatabase(NativeDatabase.memory());
      final target = AppDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(target.close);

      await _putAppSetting(source, 'weeklyGoal', '4');
      await _putAppSetting(source, 'onboardingComplete', 'false');
      await _putAppSetting(source, 'healthExportedSessionIds', '[9]');
      await _putAppSetting(source, 'muscleAnatomyBackfillVersion', '99');
      await _putAppSetting(source, 'timedExerciseBackfilled', 'true');

      await _putAppSetting(target, 'weeklyGoal', '6');
      await _putAppSetting(target, 'onboardingComplete', 'true');
      await _putAppSetting(target, 'healthExportedSessionIds', '[1,2]');
      await _putAppSetting(target, 'muscleAnatomyBackfillVersion', '2');
      await _putAppSetting(target, 'timedExerciseBackfilled', 'false');

      final payload = await BackupService(source).exportPayload();
      await BackupService(target).replaceFromPayload(payload);

      final settings = await _appSettingsMap(target);
      expect(settings['weeklyGoal'], '4');
      expect(settings['onboardingComplete'], 'true');
      expect(settings['healthExportedSessionIds'], '[1,2]');
      expect(settings['muscleAnatomyBackfillVersion'], '2');
      expect(settings['timedExerciseBackfilled'], 'false');
    },
  );

  test(
    'pre-v2 backup without appSettings preserves onboarding and backfill markers',
    () async {
      final source = AppDatabase(NativeDatabase.memory());
      final target = AppDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(target.close);

      await _putAppSetting(target, 'onboardingComplete', 'true');
      await _putAppSetting(target, 'muscleAnatomyBackfillVersion', '2');

      final payload = await BackupService(source).exportPayload();
      payload['schemaVersion'] = 1;
      payload.remove('appSettings');

      await BackupService(target).replaceFromPayload(payload);

      final settings = await _appSettingsMap(target);
      expect(settings['onboardingComplete'], 'true');
      expect(settings['muscleAnatomyBackfillVersion'], '2');
    },
  );

  test(
    'v12 backup imports missing anatomyEditedByUser with a false default',
    () async {
      final source = AppDatabase(NativeDatabase.memory());
      final target = AppDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(target.close);

      await source
          .into(source.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'Legacy Pec Deck',
              category: ExerciseCategory.strength,
              muscleGroup: 'chest',
            ),
          );

      final payload = await BackupService(source).exportPayload();
      payload['schemaVersion'] = 12;
      for (final exercise
          in (payload['exercises'] as List<dynamic>)
              .cast<Map<String, dynamic>>()) {
        exercise.remove('anatomyEditedByUser');
      }

      await BackupService(target).replaceFromPayload(payload);

      final row = await target
          .customSelect(
            'SELECT anatomy_edited_by_user AS edited FROM exercises',
          )
          .getSingle();
      expect(row.read<int>('edited'), 0);
    },
  );

  test(
    'v11 backup imports missing timed/distance keys with false defaults',
    () async {
      final source = AppDatabase(NativeDatabase.memory());
      final target = AppDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(target.close);

      await source
          .into(source.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: 'My Imported Hold',
              category: ExerciseCategory.bodyweight,
              muscleGroup: 'custom',
              isCustom: const Value(true),
            ),
          );

      final payload = await BackupService(source).exportPayload();
      payload['schemaVersion'] = 11;
      for (final exercise
          in (payload['exercises'] as List<dynamic>)
              .cast<Map<String, dynamic>>()) {
        exercise.remove('isTimed');
        exercise.remove('tracksDistance');
      }

      await BackupService(target).replaceFromPayload(payload);

      final exercise = await target.select(target.exercises).getSingle();
      expect(exercise.name, 'My Imported Hold');
      expect(exercise.isTimed, isFalse);
      expect(exercise.tracksDistance, isFalse);
    },
  );

  test('v2 backup imports and enriches bundled exercise anatomy', () async {
    final source = AppDatabase(NativeDatabase.memory());
    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    addTearDown(target.close);

    await source
        .into(source.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Dumbbell Lateral Raise',
            category: ExerciseCategory.strength,
            muscleGroup: 'shoulders',
          ),
        );
    final payload = await BackupService(source).exportPayload();
    payload['schemaVersion'] = 2;
    for (final exercise
        in (payload['exercises'] as List<dynamic>)
            .cast<Map<String, dynamic>>()) {
      exercise.remove('primaryMuscles');
      exercise.remove('secondaryMuscles');
    }

    final anatomyService = ExerciseAnatomyService(
      target,
      loadAsset: () async => jsonEncode([
        {
          'name': 'Dumbbell Lateral Raise',
          'primaryMuscles': ['side_delts'],
          'secondaryMuscles': ['upper_traps'],
        },
      ]),
    );
    await BackupService(
      target,
      anatomyService: anatomyService,
    ).replaceFromPayload(payload);

    final exercise = await target.select(target.exercises).getSingle();
    expect(jsonDecode(exercise.primaryMuscles), ['side_delts']);
    expect(jsonDecode(exercise.secondaryMuscles), ['upper_traps']);
  });

  test('legacy bias backups import and convert set weights', () async {
    final source = AppDatabase(NativeDatabase.memory());
    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    addTearDown(target.close);

    final exerciseId = await source
        .into(source.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Leg Press',
            category: ExerciseCategory.strength,
            muscleGroup: 'legs',
            primaryMuscles: const Value('["quads","glute_max"]'),
            secondaryMuscles: const Value('["hamstrings","adductors"]'),
          ),
        );
    final sessionId = await source
        .into(source.sessions)
        .insert(
          SessionsCompanion.insert(
            startedAt: DateTime.utc(2026, 7, 20),
            endedAt: Value(DateTime.utc(2026, 7, 20, 12)),
          ),
        );
    final linkId = await source
        .into(source.sessionExercises)
        .insert(
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: 0,
          ),
        );
    await source
        .into(source.setEntries)
        .insert(
          SetEntriesCompanion.insert(
            sessionExerciseId: linkId,
            setNumber: 1,
            reps: const Value(10),
            weightValue: const Value(180),
            unit: const Value(WeightUnit.lb),
          ),
        );

    final payload = await BackupService(source).exportPayload();
    payload['schemaVersion'] = 9;
    for (final exercise
        in (payload['exercises'] as List<dynamic>)
            .cast<Map<String, dynamic>>()) {
      exercise['biasMuscleA'] = 'quads';
      exercise['biasMuscleB'] = 'glute_max';
    }
    for (final set
        in (payload['setEntries'] as List<dynamic>)
            .cast<Map<String, dynamic>>()) {
      set.remove('muscleBiasWeights');
      set['muscleBias'] = 0.25;
    }

    await BackupService(target).replaceFromPayload(payload);

    final exercise = await target.select(target.exercises).getSingle();
    final set = await target.select(target.setEntries).getSingle();
    expect(jsonDecode(exercise.primaryMuscles), ['quads', 'glute_max']);
    expect(decodeMuscleBiasWeights(set.muscleBiasWeights), const {
      MuscleId.quads: 0.75,
      MuscleId.gluteMax: 1.25,
    });
  });

  test('CSV set history flattens per-hand and each-side into volume', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final exerciseId = await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            // Comma in the name proves RFC-4180 quoting.
            name: 'Row, Single-Arm',
            category: ExerciseCategory.strength,
            muscleGroup: 'back',
            defaultUnit: const Value(WeightUnit.kg),
          ),
        );
    final sessionId = await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(startedAt: DateTime.utc(2026, 7, 22, 9)),
        );
    final linkId = await db
        .into(db.sessionExercises)
        .insert(
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: 0,
          ),
        );
    await db
        .into(db.setEntries)
        .insert(
          SetEntriesCompanion.insert(
            sessionExerciseId: linkId,
            setNumber: 1,
            reps: const Value(8),
            weightValue: const Value(20),
            unit: const Value(WeightUnit.kg),
            weightEntry: const Value(WeightEntry.perSide),
            sideCount: const Value(2),
          ),
        );

    final csv = await BackupService(db).setHistoryCsv();
    final lines = csv.trim().split('\n');
    expect(lines.first, startsWith('date,exercise,set,warmup,weight,unit'));
    // 20 kg/hand × 2 hands × 8 reps × 2 sides = 640 kg.
    expect(lines[1], contains('"Row, Single-Arm"'));
    expect(lines[1], contains('kg,yes,8,yes'));
    expect(lines[1], endsWith(',640'));
  });

  test('CSV neutralises a formula-injection exercise name', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final exerciseId = await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            // A custom name a user could type to attack their own spreadsheet.
            name: '=HYPERLINK("evil")',
            category: ExerciseCategory.strength,
            muscleGroup: 'chest',
            defaultUnit: const Value(WeightUnit.kg),
          ),
        );
    final sessionId = await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(startedAt: DateTime.utc(2026, 7, 22, 9)),
        );
    final linkId = await db
        .into(db.sessionExercises)
        .insert(
          SessionExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: 0,
          ),
        );
    await db
        .into(db.setEntries)
        .insert(
          SetEntriesCompanion.insert(
            sessionExerciseId: linkId,
            setNumber: 1,
            reps: const Value(5),
            weightValue: const Value(40),
            unit: const Value(WeightUnit.kg),
          ),
        );

    final csv = await BackupService(db).setHistoryCsv();
    // Leading `'` defuses the formula; the `=` never starts the cell.
    expect(csv, contains('"\'=HYPERLINK(""evil"")"'));
    expect(csv, isNot(contains(',=HYPERLINK')));
  });

  test('importFromPicker returns false for an empty selection', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    FilePicker.platform = _FakeFilePicker(const FilePickerResult([]));

    await expectLater(
      BackupService(db).importFromPicker(),
      completion(isFalse),
    );
  });

  test('exports prune stale temp backup files before sharing', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tempDir = await Directory.systemTemp.createTemp('logged-backup-test');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    _mockTemporaryDirectory(tempDir.path);
    _mockShareSheet();

    final staleBackup = File('${tempDir.path}/logged-backup-stale.zip')
      ..writeAsStringSync('old')
      ..setLastModifiedSync(DateTime.now().subtract(const Duration(days: 2)));
    final freshBackup = File('${tempDir.path}/logged-backup-fresh.zip')
      ..writeAsStringSync('fresh');
    final keep = File('${tempDir.path}/keep.txt')..writeAsStringSync('keep');

    await BackupService(db).exportAndShare();

    expect(staleBackup.existsSync(), isFalse);
    expect(freshBackup.existsSync(), isTrue);
    expect(keep.existsSync(), isTrue);
  });

  test('CSV export prunes stale temp history files before sharing', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tempDir = await Directory.systemTemp.createTemp('logged-csv-test');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    _mockTemporaryDirectory(tempDir.path);
    _mockShareSheet();

    final staleCsv = File('${tempDir.path}/logged-sets-stale.csv')
      ..writeAsStringSync('old')
      ..setLastModifiedSync(DateTime.now().subtract(const Duration(days: 2)));
    final freshCsv = File('${tempDir.path}/logged-sets-fresh.csv')
      ..writeAsStringSync('fresh');
    final keep = File('${tempDir.path}/keep.txt')..writeAsStringSync('keep');

    await BackupService(db).exportSetHistoryCsv();

    expect(staleCsv.existsSync(), isFalse);
    expect(freshCsv.existsSync(), isTrue);
    expect(keep.existsSync(), isTrue);
  });
}

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);
const MethodChannel _shareChannel = MethodChannel(
  'dev.fluttercommunity.plus/share',
);

Future<void> _putAppSetting(AppDatabase db, String key, String value) => db
    .into(db.appSettings)
    .insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );

Future<Map<String, String>> _appSettingsMap(AppDatabase db) async => {
  for (final row in await db.select(db.appSettings).get()) row.key: row.value,
};

void _mockTemporaryDirectory(String path) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_pathProviderChannel, (call) async {
    if (call.method == 'getTemporaryDirectory') return path;
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(_pathProviderChannel, null),
  );
}

void _mockShareSheet() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_shareChannel, (call) async {
    if (call.method == 'share') {
      return 'dev.fluttercommunity.plus/share/unavailable';
    }
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(_shareChannel, null));
}

class _FakeFilePicker extends FilePicker {
  _FakeFilePicker(this.result);

  final FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => result;
}

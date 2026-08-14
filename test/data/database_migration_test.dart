import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/workout_metrics.dart';
import 'package:logged/data/database/app_database.dart';

void main() {
  test(
    'v2 database gains empty anatomy columns without losing exercises',
    () async {
      final executor = NativeDatabase.memory(
        setup: (database) {
          database.execute('''
          CREATE TABLE exercises (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            category TEXT NOT NULL,
            muscle_group TEXT NOT NULL,
            default_unit TEXT NOT NULL DEFAULT 'kg',
            is_custom INTEGER NOT NULL DEFAULT 0,
            is_archived INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
          )
        ''');
          database.execute('''
          CREATE TABLE sessions (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            template_id INTEGER,
            notes TEXT
          )
        ''');
          database.execute('''
          CREATE TABLE session_exercises (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            exercise_id INTEGER NOT NULL,
            position INTEGER NOT NULL
          )
        ''');
          database.execute('''
          CREATE TABLE set_entries (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            session_exercise_id INTEGER NOT NULL,
            set_number INTEGER NOT NULL,
            reps INTEGER,
            weight_value REAL,
            unit TEXT,
            distance_meters REAL,
            duration_sec INTEGER,
            is_warmup INTEGER NOT NULL DEFAULT 0,
            rpe REAL,
            notes TEXT
          )
        ''');
          database.execute('''
          INSERT INTO exercises (name, category, muscle_group)
          VALUES ('Legacy Bench', 'strength', 'chest')
        ''');
          database.userVersion = 2;
        },
      );
      final database = AppDatabase(executor);
      addTearDown(database.close);

      final exercise = await database.select(database.exercises).getSingle();
      expect(exercise.name, 'Legacy Bench');
      expect(exercise.primaryMuscles, '[]');
      expect(exercise.secondaryMuscles, '[]');
      expect(exercise.preferredLoadingMode, LoadingMode.external);
      expect(exercise.bodyweightFactor, 1.0);
      expect(await database.select(database.bodyweightEntries).get(), isEmpty);
    },
  );

  test(
    'v5 sets migrate to total/sideCount 1 without changing old math',
    () async {
      const legacyWeight = 7.5;
      const legacyReps = 10;
      final legacyVolume = setVolumeKg(
        weightValue: legacyWeight,
        unit: WeightUnit.lb,
        reps: legacyReps,
      );
      final legacyOneRepMax = estimatedOneRepMax(
        weightValue: legacyWeight,
        unit: WeightUnit.lb,
        reps: legacyReps,
      );
      final executor = NativeDatabase.memory(
        setup: (database) {
          database.execute('''
          CREATE TABLE exercises (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            category TEXT NOT NULL,
            muscle_group TEXT NOT NULL,
            primary_muscles TEXT NOT NULL DEFAULT '[]',
            secondary_muscles TEXT NOT NULL DEFAULT '[]',
            default_unit TEXT NOT NULL DEFAULT 'kg',
            preferred_loading_mode TEXT NOT NULL DEFAULT 'external',
            bodyweight_factor REAL NOT NULL DEFAULT 1.0,
            is_custom INTEGER NOT NULL DEFAULT 0,
            is_archived INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
          )
        ''');
          database.execute('''
          CREATE TABLE templates (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            position INTEGER NOT NULL,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
          )
        ''');
          database.execute('''
          CREATE TABLE template_exercises (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            template_id INTEGER NOT NULL,
            exercise_id INTEGER NOT NULL,
            position INTEGER NOT NULL,
            target_sets INTEGER,
            min_reps INTEGER,
            max_reps INTEGER,
            target_duration_sec INTEGER,
            target_distance_meters REAL,
            rest_seconds INTEGER,
            eccentric_sec INTEGER,
            bottom_pause_sec INTEGER,
            concentric_sec INTEGER,
            top_pause_sec INTEGER,
            prescription_notes TEXT,
            form_url TEXT
          )
        ''');
          database.execute('''
          CREATE TABLE sessions (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            template_id INTEGER,
            notes TEXT
          )
        ''');
          database.execute('''
          CREATE TABLE session_exercises (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            exercise_id INTEGER NOT NULL,
            position INTEGER NOT NULL,
            target_sets INTEGER,
            min_reps INTEGER,
            max_reps INTEGER,
            target_duration_sec INTEGER,
            target_distance_meters REAL,
            rest_seconds INTEGER,
            eccentric_sec INTEGER,
            bottom_pause_sec INTEGER,
            concentric_sec INTEGER,
            top_pause_sec INTEGER,
            prescription_notes TEXT,
            form_url TEXT
          )
        ''');
          database.execute('''
          CREATE TABLE set_entries (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            session_exercise_id INTEGER NOT NULL,
            set_number INTEGER NOT NULL,
            reps INTEGER,
            weight_value REAL,
            unit TEXT,
            loading_mode TEXT NOT NULL DEFAULT 'external',
            distance_meters REAL,
            duration_sec INTEGER,
            is_warmup INTEGER NOT NULL DEFAULT 0,
            rpe REAL,
            notes TEXT
          )
        ''');
          database.execute('''
          CREATE TABLE bodyweight_entries (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            date INTEGER NOT NULL UNIQUE,
            value REAL NOT NULL,
            unit TEXT NOT NULL,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
          )
        ''');
          database.execute('''
          CREATE TABLE rest_days (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            date INTEGER NOT NULL UNIQUE,
            note TEXT
          )
        ''');
          database.execute('''
          CREATE TABLE app_settings (
            key TEXT NOT NULL PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
          database.execute('''
          INSERT INTO exercises (
            id,
            name,
            category,
            muscle_group,
            default_unit
          ) VALUES (1, 'Legacy Incline DB Press', 'strength', 'chest', 'lb')
        ''');
          database.execute('''
          INSERT INTO sessions (id, started_at, ended_at)
          VALUES (1, 1784505600, 1784509200)
        ''');
          database.execute('''
          INSERT INTO session_exercises (
            id,
            session_id,
            exercise_id,
            position
          ) VALUES (1, 1, 1, 0)
        ''');
          database.execute('''
          INSERT INTO set_entries (
            session_exercise_id,
            set_number,
            reps,
            weight_value,
            unit,
            loading_mode
          ) VALUES (1, 1, 10, 7.5, 'lb', 'external')
        ''');
          database.userVersion = 5;
        },
      );
      final database = AppDatabase(executor);
      addTearDown(database.close);

      final exercise = await database.select(database.exercises).getSingle();
      final set = await database.select(database.setEntries).getSingle();

      expect(exercise.weightEntry, WeightEntry.total);
      expect(set.weightEntry, WeightEntry.total);
      expect(set.sideCount, 1);
      expect(
        setVolumeKg(
          weightValue: set.weightValue,
          unit: set.unit,
          reps: set.reps,
          entry: set.weightEntry,
          sideCount: set.sideCount,
        ),
        legacyVolume,
      );
      expect(
        estimatedOneRepMax(
          weightValue: set.weightValue,
          unit: set.unit,
          reps: set.reps,
        ),
        legacyOneRepMax,
      );
    },
  );

  test('v6 gains a null video_url column without losing exercises', () async {
    final executor = NativeDatabase.memory(
      setup: (database) {
        database.execute('''
          CREATE TABLE exercises (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            category TEXT NOT NULL,
            muscle_group TEXT NOT NULL,
            primary_muscles TEXT NOT NULL DEFAULT '[]',
            secondary_muscles TEXT NOT NULL DEFAULT '[]',
            default_unit TEXT NOT NULL DEFAULT 'kg',
            weight_entry TEXT NOT NULL DEFAULT 'total',
            preferred_loading_mode TEXT NOT NULL DEFAULT 'external',
            bodyweight_factor REAL NOT NULL DEFAULT 1.0,
            is_custom INTEGER NOT NULL DEFAULT 0,
            is_archived INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
          )
        ''');
        // beforeOpen creates indexes on these, so they must exist to open.
        database.execute('''
          CREATE TABLE sessions (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            template_id INTEGER,
            notes TEXT
          )
        ''');
        database.execute('''
          CREATE TABLE session_exercises (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            exercise_id INTEGER NOT NULL,
            position INTEGER NOT NULL
          )
        ''');
        database.execute('''
          CREATE TABLE set_entries (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            session_exercise_id INTEGER NOT NULL,
            set_number INTEGER NOT NULL
          )
        ''');
        database.execute('''
          INSERT INTO exercises (name, category, muscle_group)
          VALUES ('Legacy Row', 'strength', 'back')
        ''');
        database.userVersion = 6;
      },
    );
    final database = AppDatabase(executor);
    addTearDown(database.close);

    final exercise = await database.select(database.exercises).getSingle();
    expect(exercise.name, 'Legacy Row');
    expect(exercise.videoUrl, isNull);
    expect(database.schemaVersion, 12);
  });

  test(
    'v7 gains muscleBiasWeights without losing existing exercise and set data',
    () async {
      final executor = NativeDatabase.memory(
        setup: (database) {
          database.execute('''
          CREATE TABLE exercises (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            category TEXT NOT NULL,
            muscle_group TEXT NOT NULL,
            primary_muscles TEXT NOT NULL DEFAULT '[]',
            secondary_muscles TEXT NOT NULL DEFAULT '[]',
            default_unit TEXT NOT NULL DEFAULT 'kg',
            weight_entry TEXT NOT NULL DEFAULT 'total',
            preferred_loading_mode TEXT NOT NULL DEFAULT 'external',
            bodyweight_factor REAL NOT NULL DEFAULT 1.0,
            video_url TEXT,
            is_custom INTEGER NOT NULL DEFAULT 0,
            is_archived INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
          )
        ''');
          database.execute('''
          CREATE TABLE sessions (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            template_id INTEGER,
            notes TEXT
          )
        ''');
          database.execute('''
          CREATE TABLE session_exercises (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            exercise_id INTEGER NOT NULL,
            position INTEGER NOT NULL
          )
        ''');
          database.execute('''
          CREATE TABLE set_entries (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            session_exercise_id INTEGER NOT NULL,
            set_number INTEGER NOT NULL,
            reps INTEGER,
            weight_value REAL,
            unit TEXT,
            weight_entry TEXT NOT NULL DEFAULT 'total',
            side_count INTEGER NOT NULL DEFAULT 1,
            loading_mode TEXT NOT NULL DEFAULT 'external',
            distance_meters REAL,
            duration_sec INTEGER,
            is_warmup INTEGER NOT NULL DEFAULT 0,
            rpe REAL,
            notes TEXT
          )
        ''');
          database.execute('''
          INSERT INTO exercises (
            id,
            name,
            category,
            muscle_group,
            primary_muscles,
            secondary_muscles,
            default_unit,
            video_url
          ) VALUES (
            1,
            'Legacy Leg Press',
            'strength',
            'legs',
            '["quads","glute_max"]',
            '["hamstrings","adductors"]',
            'lb',
            'https://youtu.be/legacy'
          )
        ''');
          database.execute('''
          INSERT INTO sessions (id, started_at, ended_at)
          VALUES (1, 1784505600, 1784509200)
        ''');
          database.execute('''
          INSERT INTO session_exercises (
            id,
            session_id,
            exercise_id,
            position
          ) VALUES (1, 1, 1, 0)
        ''');
          database.execute('''
          INSERT INTO set_entries (
            id,
            session_exercise_id,
            set_number,
            reps,
            weight_value,
            unit,
            weight_entry,
            side_count,
            loading_mode,
            rpe
          ) VALUES (1, 1, 1, 12, 180, 'lb', 'total', 1, 'external', 8.5)
        ''');
          database.userVersion = 7;
        },
      );
      final database = AppDatabase(executor);
      addTearDown(database.close);

      final exercise = await database.select(database.exercises).getSingle();
      final set = await database.select(database.setEntries).getSingle();

      expect(exercise.name, 'Legacy Leg Press');
      expect(exercise.videoUrl, 'https://youtu.be/legacy');
      expect(set.reps, 12);
      expect(set.weightValue, 180);
      expect(set.muscleBiasWeights, isNull);
      expect(database.schemaVersion, 12);
    },
  );

  test(
    'v9 converts legacy bias rows into weight maps and drops axis columns',
    () async {
      final executor = NativeDatabase.memory(
        setup: (database) {
          database.execute('''
          CREATE TABLE exercises (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            category TEXT NOT NULL,
            muscle_group TEXT NOT NULL,
            primary_muscles TEXT NOT NULL DEFAULT '[]',
            secondary_muscles TEXT NOT NULL DEFAULT '[]',
            default_unit TEXT NOT NULL DEFAULT 'kg',
            weight_entry TEXT NOT NULL DEFAULT 'total',
            preferred_loading_mode TEXT NOT NULL DEFAULT 'external',
            bodyweight_factor REAL NOT NULL DEFAULT 1.0,
            video_url TEXT,
            bias_muscle_a TEXT,
            bias_muscle_b TEXT,
            bias_axis_user_set INTEGER NOT NULL DEFAULT 0,
            is_custom INTEGER NOT NULL DEFAULT 0,
            is_archived INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
          )
        ''');
          database.execute('''
          CREATE TABLE sessions (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            template_id INTEGER,
            notes TEXT
          )
        ''');
          database.execute('''
          CREATE TABLE session_exercises (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            exercise_id INTEGER NOT NULL,
            position INTEGER NOT NULL
          )
        ''');
          database.execute('''
          CREATE TABLE set_entries (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            session_exercise_id INTEGER NOT NULL,
            set_number INTEGER NOT NULL,
            reps INTEGER,
            weight_value REAL,
            unit TEXT,
            weight_entry TEXT NOT NULL DEFAULT 'total',
            side_count INTEGER NOT NULL DEFAULT 1,
            loading_mode TEXT NOT NULL DEFAULT 'external',
            distance_meters REAL,
            duration_sec INTEGER,
            is_warmup INTEGER NOT NULL DEFAULT 0,
            rpe REAL,
            muscle_bias REAL,
            notes TEXT
          )
        ''');
          database.execute('''
          INSERT INTO exercises (
            id,
            name,
            category,
            muscle_group,
            primary_muscles,
            secondary_muscles,
            bias_muscle_a,
            bias_muscle_b,
            bias_axis_user_set
          ) VALUES (
            1,
            'Legacy Leg Press',
            'strength',
            'legs',
            '["quads","glute_max"]',
            '["hamstrings","adductors"]',
            'quads',
            'glute_max',
            1
          )
        ''');
          database.execute('''
          INSERT INTO sessions (id, started_at, ended_at)
          VALUES (1, 1784505600, 1784509200)
        ''');
          database.execute('''
          INSERT INTO session_exercises (
            id,
            session_id,
            exercise_id,
            position
          ) VALUES (1, 1, 1, 0)
        ''');
          database.execute('''
          INSERT INTO set_entries (
            id,
            session_exercise_id,
            set_number,
            reps,
            weight_value,
            unit,
            weight_entry,
            side_count,
            loading_mode,
            muscle_bias
          ) VALUES (1, 1, 1, 8, 180, 'lb', 'total', 1, 'external', 0.25)
        ''');
          database.userVersion = 9;
        },
      );
      final database = AppDatabase(executor);
      addTearDown(database.close);

      final exercise = await database.select(database.exercises).getSingle();
      final set = await database.select(database.setEntries).getSingle();
      final exerciseColumns = await database
          .customSelect("PRAGMA table_info('exercises')")
          .get();
      final setColumns = await database
          .customSelect("PRAGMA table_info('set_entries')")
          .get();

      expect(exercise.name, 'Legacy Leg Press');
      expect(
        exerciseColumns.map((row) => row.read<String>('name')),
        isNot(
          containsAll(['bias_muscle_a', 'bias_muscle_b', 'bias_axis_user_set']),
        ),
      );
      expect(
        setColumns.map((row) => row.read<String>('name')),
        contains('muscle_bias_weights'),
      );
      expect(
        setColumns.map((row) => row.read<String>('name')),
        isNot(contains('muscle_bias')),
      );
      expect(jsonDecode(set.muscleBiasWeights!), {
        'quads': 0.75,
        'glute_max': 1.25,
      });
      expect(database.schemaVersion, 12);
    },
  );

  test(
    'v10 rescales stored share weights to mean-1 multipliers in v11',
    () async {
      final executor = NativeDatabase.memory(
        setup: (database) {
          database.execute('''
          CREATE TABLE exercises (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            category TEXT NOT NULL,
            muscle_group TEXT NOT NULL,
            primary_muscles TEXT NOT NULL DEFAULT '[]',
            secondary_muscles TEXT NOT NULL DEFAULT '[]',
            default_unit TEXT NOT NULL DEFAULT 'kg',
            weight_entry TEXT NOT NULL DEFAULT 'total',
            preferred_loading_mode TEXT NOT NULL DEFAULT 'external',
            bodyweight_factor REAL NOT NULL DEFAULT 1.0,
            video_url TEXT,
            is_custom INTEGER NOT NULL DEFAULT 0,
            is_archived INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
          )
        ''');
          database.execute('''
          CREATE TABLE sessions (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            template_id INTEGER,
            notes TEXT
          )
        ''');
          database.execute('''
          CREATE TABLE session_exercises (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            exercise_id INTEGER NOT NULL,
            position INTEGER NOT NULL
          )
        ''');
          database.execute('''
          CREATE TABLE set_entries (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            session_exercise_id INTEGER NOT NULL,
            set_number INTEGER NOT NULL,
            reps INTEGER,
            weight_value REAL,
            unit TEXT,
            weight_entry TEXT NOT NULL DEFAULT 'total',
            side_count INTEGER NOT NULL DEFAULT 1,
            loading_mode TEXT NOT NULL DEFAULT 'external',
            distance_meters REAL,
            duration_sec INTEGER,
            is_warmup INTEGER NOT NULL DEFAULT 0,
            rpe REAL,
            muscle_bias_weights TEXT,
            notes TEXT
          )
        ''');
          database.execute('''
          INSERT INTO exercises (
            id,
            name,
            category,
            muscle_group,
            primary_muscles,
            secondary_muscles
          ) VALUES (
            1,
            'Legacy Leg Press',
            'strength',
            'legs',
            '["quads","glute_max","hamstrings"]',
            '["adductors"]'
          )
        ''');
          database.execute('''
          INSERT INTO sessions (id, started_at, ended_at)
          VALUES (1, 1784505600, 1784509200)
        ''');
          database.execute('''
          INSERT INTO session_exercises (
            id,
            session_id,
            exercise_id,
            position
          ) VALUES (1, 1, 1, 0)
        ''');
          database.execute('''
          INSERT INTO set_entries (
            id,
            session_exercise_id,
            set_number,
            reps,
            weight_value,
            unit,
            weight_entry,
            side_count,
            loading_mode,
            muscle_bias_weights
          ) VALUES (
            1,
            1,
            1,
            8,
            180,
            'lb',
            'total',
            1,
            'external',
            '{"quads":0.5,"glute_max":0.3,"hamstrings":0.2}'
          )
        ''');
          database.userVersion = 10;
        },
      );
      final database = AppDatabase(executor);
      addTearDown(database.close);

      final set = await database.select(database.setEntries).getSingle();
      final weights =
          (jsonDecode(set.muscleBiasWeights!) as Map<String, dynamic>)
              .cast<String, num>();
      expect(weights['quads']!.toDouble(), closeTo(1.5, 1e-9));
      expect(weights['glute_max']!.toDouble(), closeTo(0.9, 1e-9));
      expect(weights['hamstrings']!.toDouble(), closeTo(0.6, 1e-9));
      expect(database.schemaVersion, 12);
    },
  );

  test(
    'v11 gains timed and distance exercise flags without losing exercise or set data',
    () async {
      final executor = NativeDatabase.memory(
        setup: (database) {
          database.execute('''
          CREATE TABLE exercises (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            category TEXT NOT NULL,
            muscle_group TEXT NOT NULL,
            primary_muscles TEXT NOT NULL DEFAULT '[]',
            secondary_muscles TEXT NOT NULL DEFAULT '[]',
            default_unit TEXT NOT NULL DEFAULT 'kg',
            weight_entry TEXT NOT NULL DEFAULT 'total',
            preferred_loading_mode TEXT NOT NULL DEFAULT 'external',
            bodyweight_factor REAL NOT NULL DEFAULT 1.0,
            video_url TEXT,
            is_custom INTEGER NOT NULL DEFAULT 0,
            is_archived INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
          )
        ''');
          database.execute('''
          CREATE TABLE sessions (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            template_id INTEGER,
            notes TEXT
          )
        ''');
          database.execute('''
          CREATE TABLE session_exercises (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            exercise_id INTEGER NOT NULL,
            position INTEGER NOT NULL
          )
        ''');
          database.execute('''
          CREATE TABLE set_entries (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            session_exercise_id INTEGER NOT NULL,
            set_number INTEGER NOT NULL,
            reps INTEGER,
            weight_value REAL,
            unit TEXT,
            weight_entry TEXT NOT NULL DEFAULT 'total',
            side_count INTEGER NOT NULL DEFAULT 1,
            loading_mode TEXT NOT NULL DEFAULT 'external',
            distance_meters REAL,
            duration_sec INTEGER,
            is_warmup INTEGER NOT NULL DEFAULT 0,
            rpe REAL,
            muscle_bias_weights TEXT,
            notes TEXT
          )
        ''');
          database.execute('''
          INSERT INTO exercises (
            id,
            name,
            category,
            muscle_group,
            primary_muscles,
            secondary_muscles,
            default_unit,
            weight_entry,
            preferred_loading_mode,
            bodyweight_factor,
            video_url
          ) VALUES (
            1,
            'Legacy Carry',
            'strength',
            'full body',
            '["forearms","upper_traps"]',
            '["abs"]',
            'lb',
            'perSide',
            'external',
            1.0,
            'https://youtu.be/carry'
          )
        ''');
          database.execute('''
          INSERT INTO sessions (id, started_at, ended_at)
          VALUES (1, 1784505600, 1784509200)
        ''');
          database.execute('''
          INSERT INTO session_exercises (
            id,
            session_id,
            exercise_id,
            position
          ) VALUES (1, 1, 1, 0)
        ''');
          database.execute('''
          INSERT INTO set_entries (
            id,
            session_exercise_id,
            set_number,
            reps,
            weight_value,
            unit,
            weight_entry,
            side_count,
            loading_mode,
            distance_meters
          ) VALUES (1, 1, 1, 40, 30, 'lb', 'perSide', 1, 'external', 20)
        ''');
          database.userVersion = 11;
        },
      );
      final database = AppDatabase(executor);
      addTearDown(database.close);

      final exercise = await database.select(database.exercises).getSingle();
      final set = await database.select(database.setEntries).getSingle();
      final columns = await database
          .customSelect("PRAGMA table_info('exercises')")
          .get();

      expect(exercise.name, 'Legacy Carry');
      expect(exercise.videoUrl, 'https://youtu.be/carry');
      expect(exercise.isTimed, isFalse);
      expect(exercise.tracksDistance, isFalse);
      expect(set.reps, 40);
      expect(set.weightValue, 30);
      expect(set.distanceMeters, 20);
      expect(
        columns.map((row) => row.read<String>('name')),
        containsAll(['is_timed', 'tracks_distance']),
      );
      expect(database.schemaVersion, 12);
    },
  );
}

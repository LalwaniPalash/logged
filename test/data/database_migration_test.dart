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
}

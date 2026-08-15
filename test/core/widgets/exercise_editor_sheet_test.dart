import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/widgets/exercise_editor_sheet.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/providers.dart';
import 'package:logged/data/repositories/exercise_repository.dart';

void main() {
  late AppDatabase database;
  late _CountingExerciseRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = _CountingExerciseRepository(database);
  });

  tearDown(() => database.close());

  testWidgets('info sheet renders primary and secondary muscle names', (
    tester,
  ) async {
    final exercise = await _insertExercise(
      database,
      primary: const Value('["mid_lower_chest"]'),
      secondary: const Value('["front_delts","triceps"]'),
    );

    await tester.pumpWidget(_harness(repository, exercise));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Primary muscles'), findsOneWidget);
    expect(find.text('Mid / lower chest'), findsOneWidget);
    expect(find.text('Secondary muscles'), findsOneWidget);
    expect(find.text('Front delts'), findsOneWidget);
    expect(find.text('Triceps'), findsOneWidget);
  });

  testWidgets('saving from the session sheet calls updateMuscles once', (
    tester,
  ) async {
    final exercise = await _insertExercise(database);

    await tester.pumpWidget(_harness(repository, exercise));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.updateMusclesCalls, 1);
  });
}

Future<Exercise> _insertExercise(
  AppDatabase database, {
  Value<String> primary = const Value('["lats"]'),
  Value<String> secondary = const Value('["biceps"]'),
}) async {
  final id = await database
      .into(database.exercises)
      .insert(
        ExercisesCompanion.insert(
          name: 'Cable Row',
          category: ExerciseCategory.strength,
          muscleGroup: 'back',
          primaryMuscles: primary,
          secondaryMuscles: secondary,
          bodyweightFactor: const Value(0.2),
          videoUrl: const Value('https://youtu.be/demo'),
        ),
      );
  return (database.select(
    database.exercises,
  )..where((row) => row.id.equals(id))).getSingle();
}

Widget _harness(ExerciseRepository repository, Exercise exercise) =>
    ProviderScope(
      overrides: [exerciseRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => ExerciseInfoSheet(exercise: exercise),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

class _CountingExerciseRepository extends ExerciseRepository {
  _CountingExerciseRepository(this.database) : super(database);

  final AppDatabase database;
  int updateMusclesCalls = 0;

  @override
  Future<void> updateMuscles(
    int exerciseId, {
    required String primaryMuscles,
    required String secondaryMuscles,
  }) {
    updateMusclesCalls += 1;
    return super.updateMuscles(
      exerciseId,
      primaryMuscles: primaryMuscles,
      secondaryMuscles: secondaryMuscles,
    );
  }
}

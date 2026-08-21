import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/strength_standards.dart';
import 'package:logged/core/theme/app_theme.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/providers.dart';
import 'package:logged/data/repositories/analytics_repository.dart';
import 'package:logged/features/ranks/strength_standard_detail_screen.dart';
import 'package:logged/features/ranks/widgets/strength_standards_section.dart';

void main() {
  Exercise buildExercise({required int id, required String name}) => Exercise(
    id: id,
    name: name,
    category: ExerciseCategory.strength,
    muscleGroup: 'chest',
    primaryMuscles: '["chest"]',
    secondaryMuscles: '[]',
    defaultUnit: WeightUnit.kg,
    weightEntry: WeightEntry.total,
    preferredLoadingMode: LoadingMode.external,
    bodyweightFactor: 1,
    isTimed: false,
    tracksDistance: false,
    anatomyEditedByUser: false,
    isCustom: false,
    isArchived: false,
    createdAt: DateTime(2026, 8, 20),
  );

  BenchmarkSetRecord benchmarkSet({
    required String exerciseName,
    required double weight,
  }) => BenchmarkSetRecord(
    exerciseName: exerciseName,
    loadingMode: LoadingMode.external,
    reps: 5,
    bodyweightFactor: 1,
    enteredWeightKg: weight,
  );

  Future<void> pumpSection(
    WidgetTester tester, {
    required List<BenchmarkSetRecord> sets,
    required List<Exercise> exercises,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bodyweightEntriesProvider.overrideWith(
            (ref) => Stream.value([
              BodyweightEntry(
                id: 1,
                date: DateTime(2026, 8, 20),
                value: 80,
                unit: WeightUnit.kg,
                createdAt: DateTime(2026, 8, 20),
              ),
            ]),
          ),
          benchmarkSetsProvider.overrideWith((ref) => Stream.value(sets)),
          allExercisesProvider.overrideWith((ref) => Future.value(exercises)),
          oneRepMaxPointsForExerciseProvider(
            1,
          ).overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: StrengthStandardsSection(
                sex: UserSex.male,
                onEnable: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a lift with no logged sets is excluded', (tester) async {
    await pumpSection(
      tester,
      sets: const [],
      exercises: [buildExercise(id: 1, name: 'Barbell Bench Press')],
    );

    expect(find.text('Barbell Bench Press'), findsNothing);
    expect(
      find.text('Log one of the benchmark lifts to see a population standard.'),
      findsOneWidget,
    );
  });

  testWidgets('search filters the lift list', (tester) async {
    await pumpSection(
      tester,
      sets: [
        benchmarkSet(exerciseName: 'Barbell Bench Press', weight: 80),
        benchmarkSet(exerciseName: 'Barbell Back Squat', weight: 100),
      ],
      exercises: [
        buildExercise(id: 1, name: 'Barbell Bench Press'),
        buildExercise(id: 2, name: 'Barbell Back Squat'),
      ],
    );

    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('Barbell Back Squat'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'squat');
    await tester.pumpAndSettle();

    expect(find.text('Barbell Bench Press'), findsNothing);
    expect(find.text('Barbell Back Squat'), findsOneWidget);
  });

  testWidgets('tapping a card opens the lift detail screen', (tester) async {
    await pumpSection(
      tester,
      sets: [benchmarkSet(exerciseName: 'Barbell Bench Press', weight: 80)],
      exercises: [buildExercise(id: 1, name: 'Barbell Bench Press')],
    );

    await tester.tap(find.text('Barbell Bench Press'));
    await tester.pumpAndSettle();

    expect(find.byType(StrengthStandardDetailScreen), findsOneWidget);
    expect(
      find.text('Barbell Bench Press'),
      findsWidgets, // once in the AppBar title, once in the summary card
    );
  });
}

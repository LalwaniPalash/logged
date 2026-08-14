import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/theme/app_theme.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/features/session/widgets/set_row.dart';

/// The old layout wrapped every set onto two lines because two stepper fields
/// could not fit the width of a phone. A widget test is the only thing that
/// actually catches that: an overflowing RenderFlex throws, and the binding
/// records the exception, so these tests fail loudly if the row stops fitting.
void main() {
  // iPhone 17 logical size; the narrowest phone the app targets is 320pt wide.
  const iphoneSize = Size(402, 874);
  const narrowSize = Size(320, 640);

  SetEntry buildSet({
    required int setNumber,
    int? reps = 5,
    double? weightValue = 40,
    WeightUnit? unit = WeightUnit.kg,
    WeightEntry weightEntry = WeightEntry.total,
    int sideCount = 1,
    LoadingMode loadingMode = LoadingMode.external,
    double? distanceMeters,
    int? durationSec,
    bool isWarmup = false,
  }) => SetEntry(
    id: setNumber,
    sessionExerciseId: 1,
    setNumber: setNumber,
    reps: reps,
    weightValue: weightValue,
    unit: unit,
    weightEntry: weightEntry,
    sideCount: sideCount,
    loadingMode: loadingMode,
    distanceMeters: distanceMeters,
    durationSec: durationSec,
    isWarmup: isWarmup,
    muscleBiasWeights: null,
  );

  Widget harness({
    required List<SetEntry> sets,
    required ExerciseCategory category,
    WeightEntry headerWeightEntry = WeightEntry.total,
    int headerSideCount = 1,
    WeightUnit unit = WeightUnit.kg,
    bool timed = false,
  }) {
    final columns = setColumnsFor(
      category: category,
      loadingModes: sets.map((set) => set.loadingMode),
      timed: timed,
    );
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Card(
          child: Padding(
            // Mirrors _ExerciseCard's padding in active_session_screen.dart.
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SetTableHeader(
                  columns: columns,
                  unit: unit,
                  weightEntry: headerWeightEntry,
                  sideCount: headerSideCount,
                ),
                for (final set in sets)
                  SetRow(
                    key: ValueKey(set.id),
                    set: set,
                    category: category,
                    headerUnit: unit,
                    columns: columns,
                    headerWeightEntry: headerWeightEntry,
                    headerSideCount: headerSideCount,
                    timed: timed,
                    onCommit: (_) async {},
                    onOpenDetails: () {},
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpAt(WidgetTester tester, Widget widget, Size size) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    tester.view.devicePixelRatio = tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  testWidgets('a strength set fits on one line at phone width', (tester) async {
    await pumpAt(
      tester,
      harness(
        sets: [buildSet(setNumber: 1), buildSet(setNumber: 2)],
        category: ExerciseCategory.strength,
      ),
      iphoneSize,
    );

    // Both fields render, and every set row occupies a single line.
    expect(find.byType(TextField), findsNWidgets(4));
    final firstRow = tester.getRect(find.byType(SetRow).first);
    expect(
      firstRow.height,
      lessThan(60),
      reason: 'a set row must be one line, not the old two-line wrap',
    );
  });

  testWidgets('the four-set squat card stays compact', (tester) async {
    await pumpAt(
      tester,
      harness(
        sets: [for (var i = 1; i <= 4; i++) buildSet(setNumber: i)],
        category: ExerciseCategory.strength,
      ),
      iphoneSize,
    );

    final rows = tester.widgetList(find.byType(SetRow)).length;
    expect(rows, 4);
    final total =
        tester.getRect(find.byType(SetRow).last).bottom -
        tester.getRect(find.byType(SetRow).first).top;
    // The old layout needed ~215pt per set (860pt for four).
    expect(total, lessThan(260));
  });

  testWidgets('survives the narrowest supported phone width', (tester) async {
    await pumpAt(
      tester,
      harness(
        sets: [buildSet(setNumber: 1, weightValue: 102.5, reps: 12)],
        category: ExerciseCategory.strength,
      ),
      narrowSize,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('header column labels carry unit and per-hand/per-side', (
    tester,
  ) async {
    await pumpAt(
      tester,
      harness(
        sets: [buildSet(setNumber: 1, weightEntry: WeightEntry.perSide)],
        category: ExerciseCategory.strength,
        headerWeightEntry: WeightEntry.perSide,
        headerSideCount: 2,
      ),
      iphoneSize,
    );

    expect(find.text('KG / HAND'), findsOneWidget);
    expect(find.text('REPS / SIDE'), findsOneWidget);
  });

  testWidgets('last-time hint preserves each set entered semantics', (
    tester,
  ) async {
    await pumpAt(
      tester,
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: LastPerformanceHint(
            sets: [
              buildSet(
                setNumber: 1,
                reps: 8,
                weightValue: 40,
                unit: WeightUnit.lb,
                weightEntry: WeightEntry.perSide,
                sideCount: 2,
              ),
            ],
          ),
        ),
      ),
      iphoneSize,
    );

    expect(find.text('Last time: 8× 40 lb/hand each side'), findsOneWidget);
    expect(find.textContaining('kg'), findsNothing);
  });

  testWidgets('cardio shows time and distance columns, not weight', (
    tester,
  ) async {
    await pumpAt(
      tester,
      harness(
        sets: [
          buildSet(
            setNumber: 1,
            reps: null,
            weightValue: null,
            unit: null,
            durationSec: 600,
            distanceMeters: 2000,
          ),
        ],
        category: ExerciseCategory.cardio,
      ),
      iphoneSize,
    );

    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('METRES'), findsOneWidget);
    expect(find.text('KG'), findsNothing);
    expect(find.text('REPS'), findsNothing);
  });

  testWidgets('mixed loading modes keep every field editable inline', (
    tester,
  ) async {
    // A bodyweight set first: deriving columns from the first set alone would
    // have stranded the added-weight set's weight field.
    await pumpAt(
      tester,
      harness(
        sets: [
          buildSet(
            setNumber: 1,
            weightValue: null,
            unit: null,
            loadingMode: LoadingMode.bodyweight,
          ),
          buildSet(
            setNumber: 2,
            weightValue: 10,
            loadingMode: LoadingMode.bodyweightAdded,
          ),
        ],
        category: ExerciseCategory.bodyweight,
      ),
      iphoneSize,
    );

    expect(
      setColumnsFor(
        category: ExerciseCategory.bodyweight,
        loadingModes: const [
          LoadingMode.bodyweight,
          LoadingMode.bodyweightAdded,
        ],
      ),
      [SetField.weight, SetField.reps],
    );

    // The bodyweight row holds the weight column with a placeholder, so the
    // grid stays aligned instead of shifting the reps field left.
    expect(find.text('—'), findsOneWidget);
    // Deviating sets label themselves since the header cannot.
    expect(find.text('Bodyweight'), findsOneWidget);
    expect(find.text('Added weight'), findsOneWidget);
  });

  testWidgets('a timed bodyweight hold gets a duration column, not reps', (
    tester,
  ) async {
    // Plank is `bodyweight` category with a 90s, zero-rep prescription. A
    // reps-only column would make its hold time impossible to log.
    await pumpAt(
      tester,
      harness(
        sets: [
          buildSet(
            setNumber: 1,
            reps: null,
            weightValue: null,
            unit: null,
            loadingMode: LoadingMode.bodyweight,
          ),
        ],
        category: ExerciseCategory.bodyweight,
        timed: true,
      ),
      iphoneSize,
    );

    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('REPS'), findsNothing);
  });

  test('isTimedExercise reads the sets first, then the prescription', () {
    expect(
      isTimedExercise(
        exerciseIsTimed: true,
        sets: const [],
        targetDurationSec: null,
        minReps: null,
        maxReps: null,
      ),
      isTrue,
      reason:
          'a new custom exercise marked timed must resolve as timed before it has any history',
    );
    // Empty Plank: only the 90s/no-reps prescription can say it is timed.
    expect(
      isTimedExercise(
        exerciseIsTimed: false,
        sets: const [],
        targetDurationSec: 90,
        minReps: null,
        maxReps: null,
      ),
      isTrue,
    );
    // A rep target wins even when a duration is also prescribed.
    expect(
      isTimedExercise(
        exerciseIsTimed: false,
        sets: const [],
        targetDurationSec: 90,
        minReps: 8,
        maxReps: 12,
      ),
      isFalse,
    );
    // Logged sets outrank the prescription.
    expect(
      isTimedExercise(
        exerciseIsTimed: false,
        sets: [buildSet(setNumber: 1, reps: 8)],
        targetDurationSec: 90,
        minReps: null,
        maxReps: null,
      ),
      isFalse,
    );
  });

  testWidgets('a set logged in another unit says so on its own row', (
    tester,
  ) async {
    // Units are per-set and this gym mixes them; a lb row sitting silently
    // under a KG heading would misreport the load.
    await pumpAt(
      tester,
      harness(
        sets: [
          buildSet(setNumber: 1, unit: WeightUnit.kg, weightValue: 40),
          buildSet(setNumber: 2, unit: WeightUnit.lb, weightValue: 90),
        ],
        category: ExerciseCategory.strength,
      ),
      iphoneSize,
    );

    expect(find.text('KG'), findsOneWidget, reason: 'heading follows set 1');
    expect(find.text('in lb'), findsOneWidget, reason: 'set 2 flags itself');
  });

  test('setColumnsFor unions its sets in canonical order', () {
    expect(
      setColumnsFor(
        category: ExerciseCategory.strength,
        loadingModes: const [LoadingMode.external],
      ),
      [SetField.weight, SetField.reps],
    );
    expect(
      setColumnsFor(
        category: ExerciseCategory.cardio,
        loadingModes: const [LoadingMode.external],
      ),
      [SetField.duration, SetField.distance],
    );
    expect(
      setColumnsFor(
        category: ExerciseCategory.stretching,
        loadingModes: const [LoadingMode.external],
      ),
      [SetField.duration],
    );
  });
}

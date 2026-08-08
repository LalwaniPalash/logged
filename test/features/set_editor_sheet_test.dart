import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/core/theme/app_theme.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/features/session/widgets/set_editor_sheet.dart';

/// The sheet previously showed every control for every exercise, and its
/// four-way SegmentedButton truncated "Bodyweight" mid-word on a narrow phone.
/// These tests pin the category-aware sections and the plain-English echo that
/// distinguishes per-hand (weight x2) from each-side (reps x2).
void main() {
  const iphoneSize = Size(402, 874);
  const narrowSize = Size(320, 640);

  SetEntry buildSet({
    int? reps = 5,
    double? weightValue = 40,
    WeightEntry weightEntry = WeightEntry.total,
    int sideCount = 1,
    LoadingMode loadingMode = LoadingMode.external,
    double? muscleBias,
  }) => SetEntry(
    id: 1,
    sessionExerciseId: 1,
    setNumber: 3,
    reps: reps,
    weightValue: weightValue,
    unit: WeightUnit.kg,
    weightEntry: weightEntry,
    sideCount: sideCount,
    loadingMode: loadingMode,
    isWarmup: false,
    muscleBias: muscleBias,
  );

  Widget harness({
    required ExerciseCategory category,
    SetEntry? existing,
    String name = 'Barbell Back Squat',
    bool timed = false,
    MuscleId? biasMuscleA,
    MuscleId? biasMuscleB,
  }) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SetEditorSheet(
        exerciseName: name,
        category: category,
        timed: timed,
        defaultUnit: WeightUnit.kg,
        defaultWeightEntry: WeightEntry.total,
        defaultLoadingMode: LoadingMode.external,
        existing: existing,
        seed: null,
        effectiveBodyweightKg: null,
        biasMuscleA: biasMuscleA,
        biasMuscleB: biasMuscleB,
      ),
    ),
  );

  Future<void> pumpAt(WidgetTester tester, Widget widget, Size size) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  testWidgets('a barbell lift hides cardio-only fields', (tester) async {
    await pumpAt(
      tester,
      harness(category: ExerciseCategory.strength, existing: buildSet()),
      iphoneSize,
    );

    expect(find.text('WEIGHT'), findsOneWidget);
    expect(find.text('REPS'), findsOneWidget);
    // Distance is meaningless on a squat.
    expect(find.text('TIME & DISTANCE'), findsNothing);
    expect(find.text('DISTANCE'), findsNothing);
    expect(find.text('HOLD TIME'), findsNothing);
  });

  testWidgets('any lift can still be switched to assisted/added', (
    tester,
  ) async {
    // An assisted pull-up may be filed under `strength`; hiding the loading
    // modes for external-by-default exercises made that unreachable.
    await pumpAt(
      tester,
      harness(category: ExerciseCategory.strength, existing: buildSet()),
      iphoneSize,
    );

    expect(find.text('HOW IT IS LOADED'), findsOneWidget);
    expect(find.text('Assistance'), findsOneWidget);
  });

  testWidgets('a timed hold can edit its duration', (tester) async {
    // Plank: bodyweight category, prescribed in seconds. Without this the hold
    // time had no editor anywhere in the app.
    await pumpAt(
      tester,
      harness(
        category: ExerciseCategory.bodyweight,
        existing: buildSet(
          reps: null,
          weightValue: null,
          loadingMode: LoadingMode.bodyweight,
        ),
        name: 'Plank',
        timed: true,
      ),
      iphoneSize,
    );

    expect(find.text('HOLD TIME'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Duration'), findsOneWidget);
    // Distance stays hidden: a plank covers no ground.
    expect(find.widgetWithText(TextField, 'Distance'), findsNothing);
  });

  testWidgets('cardio shows time and distance, not weight or reps', (
    tester,
  ) async {
    await pumpAt(
      tester,
      harness(
        category: ExerciseCategory.cardio,
        existing: buildSet(reps: null, weightValue: null),
        name: 'Treadmill Run',
      ),
      iphoneSize,
    );

    expect(find.text('TIME & DISTANCE'), findsOneWidget);
    expect(find.text('WEIGHT'), findsNothing);
    expect(find.text('REPS'), findsNothing);
  });

  testWidgets('bodyweight exercises expose the loading modes', (tester) async {
    await pumpAt(
      tester,
      harness(
        category: ExerciseCategory.bodyweight,
        existing: buildSet(loadingMode: LoadingMode.bodyweightAdded),
        name: 'Pull-Up',
      ),
      iphoneSize,
    );

    expect(find.text('HOW IT IS LOADED'), findsOneWidget);
    // Chips size to their own text, so no label is truncated.
    expect(find.text('Bodyweight'), findsOneWidget);
    expect(find.text('Added weight'), findsWidgets);
  });

  testWidgets('per-hand echoes the doubled total load', (tester) async {
    await pumpAt(
      tester,
      harness(
        category: ExerciseCategory.strength,
        existing: buildSet(weightEntry: WeightEntry.perSide, weightValue: 40),
      ),
      iphoneSize,
    );

    // The whole point of the toggle, stated in words the user cannot misread.
    expect(find.text('40 kg in each hand = 80 kg total.'), findsOneWidget);
  });

  testWidgets('each-side echoes doubled reps, not doubled weight', (
    tester,
  ) async {
    await pumpAt(
      tester,
      harness(
        category: ExerciseCategory.strength,
        existing: buildSet(reps: 8, sideCount: 2),
      ),
      iphoneSize,
    );

    expect(find.text('8 each side = 16 reps total.'), findsOneWidget);
    // Weight is untouched by the reps-side toggle.
    expect(find.text('40 kg total.'), findsOneWidget);
  });

  testWidgets('renders without overflow on the narrowest phone', (
    tester,
  ) async {
    await pumpAt(
      tester,
      harness(
        category: ExerciseCategory.bodyweight,
        existing: buildSet(loadingMode: LoadingMode.bodyweightAssisted),
        name: 'Assisted Pull-Up',
      ),
      narrowSize,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('bias slider appears for axis exercises and saves the value', (
    tester,
  ) async {
    SetEditorResult? result;
    await pumpAt(
      tester,
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<SetEditorResult>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => SetEditorSheet(
                    exerciseName: 'Leg Press',
                    category: ExerciseCategory.strength,
                    defaultUnit: WeightUnit.kg,
                    defaultWeightEntry: WeightEntry.total,
                    defaultLoadingMode: LoadingMode.external,
                    existing: buildSet(muscleBias: 0),
                    seed: null,
                    effectiveBodyweightKg: null,
                    biasMuscleA: MuscleId.quads,
                    biasMuscleB: MuscleId.gluteMax,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
      iphoneSize,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('BIAS AXIS'), findsOneWidget);
    expect(find.text('50% Quads · 50% Glute max'), findsOneWidget);

    final slider = find.byType(Slider);
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    final rect = tester.getRect(slider);
    await tester.dragFrom(rect.center, Offset(-rect.width, 0));
    await tester.pumpAndSettle();

    expect(find.text('100% Quads · 0% Glute max'), findsOneWidget);

    await tester.tap(find.text('Save set'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.muscleBias, -1);
  });

  testWidgets('save returns the toggles as separate multipliers', (
    tester,
  ) async {
    SetEditorResult? result;
    await pumpAt(
      tester,
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<SetEditorResult>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => SetEditorSheet(
                    exerciseName: 'Dumbbell Row',
                    category: ExerciseCategory.strength,
                    defaultUnit: WeightUnit.kg,
                    defaultWeightEntry: WeightEntry.total,
                    defaultLoadingMode: LoadingMode.external,
                    existing: buildSet(
                      reps: 8,
                      weightValue: 20,
                      weightEntry: WeightEntry.perSide,
                      sideCount: 2,
                    ),
                    seed: null,
                    effectiveBodyweightKg: null,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
      iphoneSize,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save set'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.weightEntry, WeightEntry.perSide, reason: 'weight x2');
    expect(result!.sideCount, 2, reason: 'reps x2');
    expect(result!.weight, 20);
    expect(result!.reps, 8);
    expect(result!.delete, isFalse);
  });

  testWidgets('delete returns a delete-only result', (tester) async {
    SetEditorResult? result;
    await pumpAt(
      tester,
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<SetEditorResult>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => SetEditorSheet(
                    exerciseName: 'Barbell Back Squat',
                    category: ExerciseCategory.strength,
                    defaultUnit: WeightUnit.kg,
                    defaultWeightEntry: WeightEntry.total,
                    defaultLoadingMode: LoadingMode.external,
                    existing: buildSet(),
                    seed: null,
                    effectiveBodyweightKg: null,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
      iphoneSize,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete set'));
    await tester.pumpAndSettle();

    expect(result!.delete, isTrue);
  });
}

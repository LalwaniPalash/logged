import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/core/domain/muscle_bias.dart';
import 'package:logged/core/domain/muscle_progress.dart';
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
    String? muscleBiasWeights,
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
    muscleBiasWeights: muscleBiasWeights,
  );

  Widget harness({
    required ExerciseCategory category,
    SetEntry? existing,
    String name = 'Barbell Back Squat',
    bool timed = false,
    List<MuscleId> primaryMuscles = const [],
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
        primaryMuscles: primaryMuscles,
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

  testWidgets('muscle-bias sliders save a normalized two-muscle split', (
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
                    existing: buildSet(
                      muscleBiasWeights: encodeMuscleBiasWeights(const {
                        MuscleId.quads: 0.5,
                        MuscleId.gluteMax: 0.5,
                      }),
                    ),
                    seed: null,
                    effectiveBodyweightKg: null,
                    primaryMuscles: const [MuscleId.quads, MuscleId.gluteMax],
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

    expect(find.text('PRIMARY MUSCLE FOCUS'), findsOneWidget);
    expect(find.text('50% Quads · 50% Glute max'), findsOneWidget);

    final slider = find.byKey(const ValueKey('muscle-bias-quads'));
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    final rect = tester.getRect(slider);
    await tester.dragFrom(rect.center, Offset(rect.width, 0));
    await tester.pumpAndSettle();

    expect(find.text('100% Quads · 0% Glute max'), findsOneWidget);

    await tester.tap(find.text('Save set'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.muscleBiasWeights, const {
      MuscleId.quads: 2.0,
      MuscleId.gluteMax: 0.0,
    });
  });

  testWidgets(
    'saving an untouched two-primary sheet preserves the no-bias domain credit',
    (tester) async {
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
                      existing: buildSet(),
                      seed: null,
                      effectiveBodyweightKg: null,
                      primaryMuscles: const [MuscleId.quads, MuscleId.gluteMax],
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

      expect(result?.muscleBiasWeights, isNotNull);
      final savedProgress = buildMuscleProgress(
        records: [
          MusclePerformanceRecord(
            date: DateTime(2026, 8, 14),
            exerciseId: 1,
            exerciseName: 'Leg Press',
            primaryMuscles: const [MuscleId.quads, MuscleId.gluteMax],
            secondaryMuscles: const [],
            loadingMode: LoadingMode.external,
            reps: 5,
            weightValue: 100,
            unit: WeightUnit.kg,
            muscleBiasWeights: result!.muscleBiasWeights,
          ),
        ],
        today: DateTime(2026, 8, 14),
      );
      final unbiasedProgress = buildMuscleProgress(
        records: [
          MusclePerformanceRecord(
            date: DateTime(2026, 8, 14),
            exerciseId: 1,
            exerciseName: 'Leg Press',
            primaryMuscles: const [MuscleId.quads, MuscleId.gluteMax],
            secondaryMuscles: const [],
            loadingMode: LoadingMode.external,
            reps: 5,
            weightValue: 100,
            unit: WeightUnit.kg,
            muscleBiasWeights: null,
          ),
        ],
        today: DateTime(2026, 8, 14),
      );

      expect(
        savedProgress[MuscleId.quads]!.primarySets,
        unbiasedProgress[MuscleId.quads]!.primarySets,
      );
      expect(
        savedProgress[MuscleId.gluteMax]!.primarySets,
        unbiasedProgress[MuscleId.gluteMax]!.primarySets,
      );
    },
  );

  testWidgets('shows three linked sliders for multi-primary exercises', (
    tester,
  ) async {
    await pumpAt(
      tester,
      harness(
        category: ExerciseCategory.strength,
        existing: buildSet(),
        name: 'Zercher Squat',
        primaryMuscles: const [
          MuscleId.quads,
          MuscleId.gluteMax,
          MuscleId.hamstrings,
        ],
      ),
      iphoneSize,
    );

    expect(find.text('PRIMARY MUSCLE FOCUS'), findsOneWidget);
    expect(find.byKey(const ValueKey('muscle-bias-quads')), findsOneWidget);
    expect(find.byKey(const ValueKey('muscle-bias-glute_max')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('muscle-bias-hamstrings')),
      findsOneWidget,
    );
    expect(
      find.text('33% Quads · 33% Glute max · 34% Hamstrings'),
      findsOneWidget,
    );
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
                    primaryMuscles: const [],
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
                    primaryMuscles: const [],
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

  testWidgets('saving a stretching set preserves reps it already carries', (
    tester,
  ) async {
    // Save nulls every field the sheet hides. A stretching exercise is never
    // `_isLifting`, so the reps field does not render — but a set logged with
    // reps must survive an edit that only touched, say, the duration. Without
    // the existing-value guard this silently destroyed the user's rep count.
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
                    exerciseName: 'Hip Flexor Stretch',
                    category: ExerciseCategory.stretching,
                    defaultUnit: WeightUnit.kg,
                    defaultWeightEntry: WeightEntry.total,
                    defaultLoadingMode: LoadingMode.external,
                    existing: buildSet(reps: 12, weightValue: null),
                    seed: null,
                    effectiveBodyweightKg: null,
                    primaryMuscles: const [],
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
    expect(result!.reps, 12);
  });

  testWidgets('a timed exercise with no rep history saves duration, not reps', (
    tester,
  ) async {
    // The Copenhagen Plank case: marked timed at creation, no history at all.
    // Reps must not be invented, and the hold time must round-trip.
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
                    exerciseName: 'Copenhagen Plank',
                    category: ExerciseCategory.bodyweight,
                    timed: true,
                    defaultUnit: WeightUnit.kg,
                    defaultWeightEntry: WeightEntry.total,
                    defaultLoadingMode: LoadingMode.bodyweight,
                    existing: null,
                    seed: null,
                    effectiveBodyweightKg: null,
                    primaryMuscles: const [],
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

    expect(find.text('REPS'), findsNothing);
    expect(find.text('HOLD TIME'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Duration'),
      '30',
    );
    await tester.pumpAndSettle();
    // A brand-new set: the confirm button reads "Add set", and so does the
    // sheet title, so target the button itself.
    await tester.tap(find.widgetWithText(FilledButton, 'Add set'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.reps, isNull);
    expect(result!.durationSec, 30);
  });
}

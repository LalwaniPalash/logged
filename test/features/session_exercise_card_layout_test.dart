import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/domain/plate_math.dart';
import 'package:logged/core/theme/app_theme.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/repositories/session_repository.dart';
import 'package:logged/features/session/widgets/session_exercise_card.dart';

/// The redesigned card packs a badge, a name, four header icons and a
/// divided action row onto one line. `flutter analyze` cannot see an
/// overflow and the default text size is a DIFFERENT code path from the scaled
/// one, so every combination that ships gets pumped here — a widget test fails
/// loudly on a RenderFlex overflow, which is exactly the failure this guards.
void main() {
  SessionExerciseDetails buildDetail({required List<SetEntry> sets}) =>
      SessionExerciseDetails(
        sessionExercise: const SessionExercise(
          id: 1,
          sessionId: 1,
          exerciseId: 1,
          position: 0,
          targetSets: 3,
          minReps: 8,
          maxReps: 10,
          prescriptionNotes: 'Brace hard, RPE 8 on the last set.',
        ),
        exercise: Exercise(
          id: 1,
          name: '45° Hamstring Back Extension (Machine)',
          category: ExerciseCategory.strength,
          muscleGroup: 'hamstrings',
          primaryMuscles: '["hamstrings"]',
          secondaryMuscles: '["glute_max"]',
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
        ),
        sets: sets,
      );

  const set = SetEntry(
    id: 1,
    sessionExerciseId: 1,
    setNumber: 1,
    reps: 8,
    weightValue: 100,
    unit: WeightUnit.kg,
    weightEntry: WeightEntry.total,
    sideCount: 1,
    loadingMode: LoadingMode.external,
    isWarmup: false,
    isDone: false,
    muscleBiasWeights: null,
  );

  Widget harness({required Size size, required double textScale}) =>
      MaterialApp(
        theme: AppTheme.dark(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: SessionExerciseCard(
                index: 0,
                reorderable: true,
                detail: buildDetail(sets: const [set]),
                previousSets: const [set],
                onAddSet: () {},
                onRepeatSet: () {},
                onInlineCommit: (_, _, _) async {},
                onToggleSetDone: (_, _) async {},
                onEditSet: (_, _) {},
                onMoveSet: (_, _, _) async {},
                onInsertSetAbove: (_, _) async {},
                onOpenPlates:
                    ({
                      required exerciseName,
                      required targetWeight,
                      required unit,
                      required perImplement,
                    }) {},
                onOpenWarmup:
                    ({
                      required sessionExerciseId,
                      required exerciseName,
                      required warmups,
                      required unit,
                      required weightEntry,
                      required sideCount,
                      required loadingMode,
                    }) {},
                onRemove: () {},
                onSwap: () {},
                onEditVideoUrl: () {},
                onEditPrescription: () {},
                onOpenInfo: () {},
                onOverflowAction: (_) {},
                prescriptionEditable: true,
                progressionAggressiveness: 1,
                inventory: PlateInventory(),
              ),
            ),
          ),
        ),
      );

  for (final (label, size, scale) in const [
    ('narrow phone, default text', Size(360, 800), 1.0),
    ('wide phone, default text', Size(430, 900), 1.0),
    ('narrow phone, large text', Size(360, 800), 1.6),
    ('narrow phone, largest text', Size(320, 800), 2.0),
  ]) {
    testWidgets('lays out without overflow — $label', (tester) async {
      await tester.pumpWidget(harness(size: size, textScale: scale));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('45°'), findsOneWidget);
      // The action row and the tick control must survive every branch.
      expect(find.text('Swap'), findsOneWidget);
      expect(find.text('+ Add set'), findsOneWidget);
    });
  }
}

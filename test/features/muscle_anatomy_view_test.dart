import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interactive_3d/interactive_3d.dart';
import 'package:logged/core/domain/live_muscle_state.dart';
import 'package:logged/core/domain/muscle.dart';
import 'package:logged/core/theme/app_theme.dart';
import 'package:logged/features/exercise/widgets/muscle_anatomy_view.dart';

void main() {
  test('resetMuscleModelView uses resetCamera instead of zoom', () async {
    final controller = _RecordingInteractive3dController();

    await resetMuscleModelView(supports3d: true, controller: controller);

    expect(controller.resetCalls, 1);
    expect(controller.zoomCalls, 0);
  });

  testWidgets('2D fallback exposes detailed primary and secondary set data', (
    tester,
  ) async {
    final state = LiveMuscleState({
      MuscleId.sideDelts: const MuscleLoad(
        muscle: MuscleId.sideDelts,
        primarySets: 2,
        secondarySets: 0,
        exercises: [
          ExerciseMuscleContribution(
            exerciseName: 'Dumbbell Lateral Raise',
            primarySets: 2,
            secondarySets: 0,
          ),
        ],
      ),
      MuscleId.upperTraps: const MuscleLoad(
        muscle: MuscleId.upperTraps,
        primarySets: 1,
        secondarySets: 2,
        exercises: [
          ExerciseMuscleContribution(
            exerciseName: 'Dumbbell Shrug',
            primarySets: 1,
            secondarySets: 0,
          ),
          ExerciseMuscleContribution(
            exerciseName: 'Dumbbell Lateral Raise',
            primarySets: 0,
            secondarySets: 2,
          ),
        ],
      ),
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MuscleAnatomyView(state: state, enable3d: false),
          ),
        ),
      ),
    );

    expect(find.text('LIVE · MON–TODAY'), findsOneWidget);
    expect(find.text('FRONT'), findsOneWidget);
    expect(find.text('BACK'), findsOneWidget);

    await tester.ensureVisible(find.text('Upper traps'));
    await tester.tap(find.text('Upper traps'));
    await tester.pumpAndSettle();

    expect(
      find.text('1 primary · 2 secondary · 1.7 effective sets'),
      findsOneWidget,
    );
    expect(find.text('Dumbbell Shrug'), findsOneWidget);
    expect(find.text('Dumbbell Lateral Raise'), findsOneWidget);
    expect(find.text('2 secondary'), findsOneWidget);
  });

  testWidgets('empty state explains that working sets update the model', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MuscleAnatomyView(
              state: LiveMuscleState(const {}),
              enable3d: false,
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('Complete a working set to light up this week’s muscles.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Browse all muscles'));
    await tester.tap(find.text('Browse all muscles'));
    await tester.pumpAndSettle();
    expect(find.text('Neck'), findsOneWidget);

    await tester.ensureVisible(find.text('Neck'));
    await tester.tap(find.text('Neck'));
    await tester.pumpAndSettle();
    expect(find.text('No working sets for Neck this week.'), findsOneWidget);
  });

  testWidgets('muscle chips inspect locally before opening progress', (
    tester,
  ) async {
    final opened = <MuscleId>[];
    final state = LiveMuscleState({
      MuscleId.sideDelts: const MuscleLoad(
        muscle: MuscleId.sideDelts,
        primarySets: 2,
        secondarySets: 0,
        exercises: [
          ExerciseMuscleContribution(
            exerciseName: 'Dumbbell Lateral Raise',
            primarySets: 2,
            secondarySets: 0,
          ),
        ],
      ),
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MuscleAnatomyView(
              state: state,
              enable3d: false,
              onOpenMuscle: opened.add,
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Side delts'));
    await tester.tap(find.text('Side delts'));
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    expect(
      find.text('2 primary · 0 secondary · 2.0 effective sets'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Open progress'));
    await tester.tap(find.text('Open progress'));
    await tester.pumpAndSettle();
    expect(opened, [MuscleId.sideDelts]);
  });
}

class _RecordingInteractive3dController extends Interactive3dController {
  int resetCalls = 0;
  int zoomCalls = 0;

  @override
  Future<void> resetCamera() async {
    resetCalls += 1;
  }

  @override
  Future<void> setCameraZoomLevel(double zoomLevel) async {
    zoomCalls += 1;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logged/features/session/rest_timer_controller.dart';
import 'package:logged/features/session/rest_timer_screen.dart';

void main() {
  testWidgets('cancel with more than 30 seconds left asks for confirmation', (
    tester,
  ) async {
    final controller = _TestRestTimerController(
      RestTimerState(
        sessionId: 7,
        remainingSeconds: 45,
        running: true,
        endTime: DateTime.now().add(const Duration(seconds: 45)),
      ),
    );
    final container = ProviderContainer(
      overrides: [restTimerControllerProvider.overrideWith(() => controller)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: RestTimerScreen(
            sessionId: 7,
            exerciseName: 'Bench Press',
            nextSetNumber: 4,
            suggestion: null,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Cancel rest timer'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel rest timer?'), findsOneWidget);
    expect(controller.cancelCount, 0);
  });

  testWidgets('cancel with less than 30 seconds left stops immediately', (
    tester,
  ) async {
    final controller = _TestRestTimerController(
      RestTimerState(
        sessionId: 8,
        remainingSeconds: 25,
        running: true,
        endTime: DateTime.now().add(const Duration(seconds: 25)),
      ),
    );
    final container = ProviderContainer(
      overrides: [restTimerControllerProvider.overrideWith(() => controller)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: RestTimerScreen(
            sessionId: 8,
            exerciseName: 'Bench Press',
            nextSetNumber: 4,
            suggestion: null,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Cancel rest timer'));
    await tester.pumpAndSettle();

    expect(controller.cancelCount, 1);
    expect(find.text('Cancel rest timer?'), findsNothing);
  });
}

class _TestRestTimerController extends RestTimerController {
  _TestRestTimerController(this._initialState);

  final RestTimerState _initialState;
  int cancelCount = 0;

  @override
  RestTimerState build() => _initialState;

  @override
  Future<void> cancel({int? sessionId}) async {
    cancelCount++;
  }
}

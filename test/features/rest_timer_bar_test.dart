import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logged/features/session/rest_timer_controller.dart';
import 'package:logged/features/session/widgets/rest_timer_bar.dart';

void main() {
  testWidgets('completed state renders a Done row for its session only', (
    tester,
  ) async {
    final controller = _TestRestTimerController(
      const RestTimerState(sessionId: 7, remainingSeconds: 0, running: false),
    );
    final container = ProviderContainer(
      overrides: [restTimerControllerProvider.overrideWith(() => controller)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(bottomNavigationBar: RestTimerBar(sessionId: 7)),
        ),
      ),
    );

    expect(find.text('Rest complete'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(controller.acknowledgeCount, 1);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(bottomNavigationBar: RestTimerBar(sessionId: 99)),
        ),
      ),
    );

    expect(find.text('Rest complete'), findsNothing);
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('tapping the running bar reopens the full timer', (tester) async {
    var taps = 0;
    final controller = _TestRestTimerController(
      RestTimerState(
        sessionId: 3,
        remainingSeconds: 45,
        running: true,
        endTime: DateTime(2026, 8, 15, 12),
      ),
    );
    final container = ProviderContainer(
      overrides: [restTimerControllerProvider.overrideWith(() => controller)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: RestTimerBar(
              sessionId: 3,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Rest \u00b7 0:45'));
    await tester.pump();
    expect(taps, 1);

    // The controls must keep their own taps rather than maximising.
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(taps, 1);
  });
}

class _TestRestTimerController extends RestTimerController {
  _TestRestTimerController(this._initialState);

  final RestTimerState _initialState;
  int acknowledgeCount = 0;
  int cancelCount = 0;

  @override
  RestTimerState build() => _initialState;

  @override
  Future<void> acknowledge() async {
    acknowledgeCount++;
  }

  @override
  Future<void> cancel({int? sessionId}) async {
    cancelCount++;
  }
}

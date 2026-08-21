import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/domain/enums.dart';
import 'package:logged/core/theme/app_theme.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/repositories/session_repository.dart';
import 'package:logged/features/session/widgets/active_session_stats_card.dart';

void main() {
  SessionExerciseDetails buildDetail() => SessionExerciseDetails(
    sessionExercise: const SessionExercise(
      id: 1,
      sessionId: 1,
      exerciseId: 1,
      position: 0,
      targetSets: 3,
      minReps: 8,
      maxReps: 10,
    ),
    exercise: Exercise(
      id: 1,
      name: 'Front Squat',
      category: ExerciseCategory.strength,
      muscleGroup: 'quads',
      primaryMuscles: 'quads',
      secondaryMuscles: 'gluteMax',
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
    sets: const [
      SetEntry(
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
      ),
    ],
  );

  Widget harness({
    required Session session,
    required Size size,
    required double textScale,
    DateTime Function()? now,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: ActiveSessionStatsCard(
            session: session,
            details: [buildDetail()],
            bodyweightKg: 80,
            now: now ?? DateTime.now,
          ),
        ),
      ),
    );
  }

  testWidgets('wide unscaled layout uses one four-wide row', (tester) async {
    final session = Session(
      id: 1,
      startedAt: DateTime.now().subtract(
        const Duration(minutes: 1, seconds: 5),
      ),
    );

    await tester.pumpWidget(
      harness(session: session, size: const Size(420, 800), textScale: 1),
    );

    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Exercises'), findsOneWidget);
    expect(find.text('Total Volume'), findsOneWidget);
    expect(find.text('Calories'), findsOneWidget);
    expect(find.byType(VerticalDivider), findsNWidgets(3));
  });

  testWidgets('narrow unscaled layout falls back to 2x2 grid', (tester) async {
    final session = Session(
      id: 1,
      startedAt: DateTime.now().subtract(
        const Duration(minutes: 1, seconds: 5),
      ),
    );

    await tester.pumpWidget(
      harness(session: session, size: const Size(360, 800), textScale: 1),
    );

    expect(find.byType(VerticalDivider), findsNWidgets(2));
  });

  testWidgets('wide scaled layout falls back to 2x2 grid', (tester) async {
    final session = Session(
      id: 1,
      startedAt: DateTime.now().subtract(
        const Duration(minutes: 1, seconds: 5),
      ),
    );

    await tester.pumpWidget(
      harness(session: session, size: const Size(420, 800), textScale: 1.4),
    );

    expect(find.byType(VerticalDivider), findsNWidgets(2));
  });

  testWidgets('narrow scaled layout stays on the grid branch', (tester) async {
    final session = Session(
      id: 1,
      startedAt: DateTime.now().subtract(
        const Duration(minutes: 1, seconds: 5),
      ),
    );

    await tester.pumpWidget(
      harness(session: session, size: const Size(360, 800), textScale: 1.4),
    );

    expect(find.byType(VerticalDivider), findsNWidgets(2));
  });

  testWidgets('stat values never wrap at real phone width', (tester) async {
    // Regression: on the Vivo (1080px @ 2.75 = 393dp logical) the four-across
    // row gives each tile ~90px and "01:27:42" wrapped mid-value to
    // "01:27:4 / 2". A widget test does NOT fail on wrapping — only on
    // overflow — so this asserts the rendered line count directly, which is
    // the only thing that would have caught it.
    final start = DateTime(2026, 8, 20, 9);
    final session = Session(id: 1, startedAt: start);

    await tester.pumpWidget(
      harness(
        session: session,
        size: const Size(393, 851),
        textScale: 1,
        now: () =>
            start.add(const Duration(hours: 1, minutes: 27, seconds: 42)),
      ),
    );

    expect(_statValueText(tester, 0), '01:27:42');

    for (final paragraph in tester.widgetList<RichText>(
      find.byType(RichText),
    )) {
      // Height of the same span laid out with no width limit == exactly one
      // line. If what actually rendered is taller, the text wrapped.
      final reference = TextPainter(
        text: paragraph.text,
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
      )..layout();
      final rendered = tester.getSize(find.byWidget(paragraph)).height;
      expect(
        rendered,
        lessThan(reference.height * 1.5),
        reason:
            'stat tile text "${paragraph.text.toPlainText()}" wrapped onto a '
            'second line at 393dp',
      );
    }
  });

  testWidgets('duration is read off the clock, not accumulated per tick', (
    tester,
  ) async {
    // A backgrounded app stops firing periodic callbacks. A ticker that adds
    // one second per tick loses exactly the time the user was away; one that
    // recomputes from startedAt recovers it on the next tick. Here the clock
    // jumps ten minutes while a single tick fires.
    final start = DateTime(2026, 8, 20, 9);
    var now = start;
    final session = Session(id: 1, startedAt: start);

    await tester.pumpWidget(
      harness(
        session: session,
        size: const Size(420, 800),
        textScale: 1,
        now: () => now,
      ),
    );

    expect(_statValueText(tester, 0), '00:00:00');

    now = start.add(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 1));

    expect(
      _statValueText(tester, 0),
      '00:10:00',
      reason:
          'one tick after a ten-minute gap must show ten minutes, not one second',
    );
  });

  testWidgets('duration ticks live until the session is finished', (
    tester,
  ) async {
    final start = DateTime(2026, 8, 20, 9);
    var now = start.add(const Duration(seconds: 65));
    final session = Session(id: 1, startedAt: start);

    await tester.pumpWidget(
      harness(
        session: session,
        size: const Size(420, 800),
        textScale: 1,
        now: () => now,
      ),
    );

    expect(_statValueText(tester, 0), '00:01:05');

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(_statValueText(tester, 0), '00:01:06');
  });

  testWidgets('a finished session freezes its duration', (tester) async {
    final start = DateTime(2026, 8, 20, 9);
    final session = Session(
      id: 1,
      startedAt: start,
      endedAt: start.add(const Duration(minutes: 42, seconds: 7)),
    );

    await tester.pumpWidget(
      harness(
        session: session,
        size: const Size(420, 800),
        textScale: 1,
        now: () => start.add(const Duration(hours: 5)),
      ),
    );

    expect(_statValueText(tester, 0), '00:42:07');

    await tester.pump(const Duration(seconds: 2));

    expect(_statValueText(tester, 0), '00:42:07');
  });
}

String _statValueText(WidgetTester tester, int index) {
  final values = tester
      .widgetList<RichText>(find.byType(RichText))
      .map((widget) => widget.text.toPlainText())
      .where((text) => RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(text))
      .toList();
  return values[index];
}

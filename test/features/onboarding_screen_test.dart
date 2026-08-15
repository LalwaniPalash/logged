import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/providers.dart';
import 'package:logged/data/repositories/settings_repository.dart';
import 'package:logged/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets(
    'unset preference shows onboarding once and Skip completes it with a Mon/Wed/Fri split',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await tester.pumpWidget(_harness(database));
      await tester.pumpAndSettle();

      expect(find.text('Your training stays yours.'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      final settings = await SettingsRepository(database).read();
      expect(find.text('HOME'), findsOneWidget);
      expect(await SettingsRepository(database).readOnboardingComplete(), isTrue);
      expect(settings.restWeekdays, {2, 4, 6, 7});
    },
  );

  testWidgets('selected training days save the complementary rest days', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(_harness(database));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('M'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('W'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('F'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('T').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('T').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('S').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    final settings = await SettingsRepository(database).read();
    expect(find.text('HOME'), findsOneWidget);
    expect(settings.restWeekdays, {1, 3, 5, 7});
  });

  testWidgets('completed preference goes directly to home', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await SettingsRepository(database).setOnboardingComplete();

    await tester.pumpWidget(_harness(database));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });
}

Widget _harness(AppDatabase database) => ProviderScope(
  overrides: [databaseProvider.overrideWithValue(database)],
  child: const MaterialApp(
    home: OnboardingGate(home: Scaffold(body: Text('HOME'))),
  ),
);

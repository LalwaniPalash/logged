import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/providers.dart';
import 'package:logged/data/repositories/settings_repository.dart';
import 'package:logged/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('unset preference shows onboarding once and Skip completes it', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(_harness(database));
    await tester.pumpAndSettle();

    expect(find.text('Your training stays yours.'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(await SettingsRepository(database).readOnboardingComplete(), isTrue);
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

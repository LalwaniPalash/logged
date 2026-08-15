import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/services/home_widget_service.dart';
import 'package:logged/data/database/app_database.dart';
import 'package:logged/data/providers.dart';
import 'package:logged/main.dart';

void main() {
  testWidgets('LoggedApp honors a stored appearance mode across restart', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database
        .into(database.appSettings)
        .insert(AppSettingsCompanion.insert(key: 'themeMode', value: 'dark'));

    Widget buildApp() => ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        homeWidgetServiceProvider.overrideWithValue(_FakeHomeWidgetClient()),
      ],
      child: const LoggedApp(),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

class _FakeHomeWidgetClient implements HomeWidgetClient {
  @override
  Future<void> refresh() async {}
}

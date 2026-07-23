import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'data/database/app_database.dart';
import 'data/repositories/rest_day_repository.dart';
import 'data/repositories/session_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/exercise_anatomy_service.dart';
import 'data/services/exercise_seed_service.dart';
import 'data/services/workout_template_seed_service.dart';
import 'data/providers.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/reminder_scheduler.dart';

final appDatabase = AppDatabase();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ExerciseSeedService(appDatabase).seedIfEmpty();
    final anatomyService = ExerciseAnatomyService(appDatabase);
    await anatomyService.enrichBundledExercises();
    await anatomyService.backfillWeightEntryOnce();
    await anatomyService.backfillPullUpOnce();
    if (const bool.fromEnvironment(
      'LOGGED_SEED_DEFAULT_TEMPLATES',
      defaultValue: true,
    )) {
      await WorkoutTemplateSeedService(appDatabase).seedIfEmpty();
    }
  } catch (error, stackTrace) {
    // Never block app startup on seeding — the user can still log workouts and
    // add custom exercises even if the bundled library fails to load.
    debugPrint('Exercise seeding failed: $error\n$stackTrace');
  }
  final notificationService = NotificationService();
  await notificationService.init();
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(appDatabase),
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const LoggedApp(),
    ),
  );
  unawaited(_syncStartupReminders(notificationService));
}

Future<void> _syncStartupReminders(
  NotificationClient notificationService,
) async {
  try {
    await ReminderScheduler(
      notifications: notificationService,
      settings: SettingsRepository(appDatabase),
      sessions: SessionRepository(appDatabase),
      restDays: RestDayRepository(appDatabase),
    ).sync(clearWhenDisabled: false);
  } catch (error, stackTrace) {
    debugPrint('Reminder scheduling failed: $error\n$stackTrace');
  }
}

class LoggedApp extends StatelessWidget {
  const LoggedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logged',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const OnboardingGate(),
    );
  }
}

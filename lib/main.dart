import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/database/app_database.dart';
import 'data/services/exercise_anatomy_service.dart';
import 'data/services/exercise_seed_service.dart';
import 'data/services/workout_template_seed_service.dart';
import 'data/providers.dart';
import 'features/home/home_shell.dart';

final appDatabase = AppDatabase();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ExerciseSeedService(appDatabase).seedIfEmpty();
    await ExerciseAnatomyService(appDatabase).enrichBundledExercises();
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
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(appDatabase)],
      child: const LoggedApp(),
    ),
  );
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
      home: const HomeShell(),
    );
  }
}

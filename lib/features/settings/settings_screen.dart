import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/domain/enums.dart';
import '../../core/domain/muscle.dart';
import '../../core/domain/plate_math.dart';
import '../../core/domain/streak.dart';
import '../../core/domain/training_goal.dart';
import '../../core/domain/strength_standards.dart';
import '../../core/domain/workout_settings.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../../data/repositories/rest_day_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/backup_service.dart';
import 'reminder_scheduler.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace all data?'),
        content: const Text(
          'Importing replaces every workout, template, and exercise on this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace and import'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      final imported = await _withProgress<bool>(
        context,
        message: 'Importing backup…',
        // The file picker opens its own UI, so the spinner only covers the
        // wipe-and-reinsert that follows selection.
        task: () =>
            BackupService(ref.read(databaseProvider)).importFromPicker(),
      );
      if (context.mounted && imported) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Backup imported.')));
      }
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    await _withProgress<void>(
      context,
      message: 'Preparing backup…',
      task: () => BackupService(ref.read(databaseProvider)).exportAndShare(),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    await _withProgress<void>(
      context,
      message: 'Building spreadsheet…',
      task: () =>
          BackupService(ref.read(databaseProvider)).exportSetHistoryCsv(),
    );
  }

  /// Runs [task] behind a blocking spinner so the user knows work is happening
  /// during the DB read / zip / import, instead of a frozen-looking screen.
  Future<T> _withProgress<T>(
    BuildContext context, {
    required String message,
    required Future<T> Function() task,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    var dialogShown = false;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 20),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        ),
      ).then((_) => dialogShown = false),
    );
    dialogShown = true;
    try {
      return await task();
    } finally {
      if (dialogShown && navigator.canPop()) navigator.pop();
    }
  }

  Future<void> _addExercise(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final bodyweightFactor = TextEditingController(text: '1.0');
    final videoUrl = TextEditingController();
    var category = ExerciseCategory.strength;
    var primary = <MuscleId>{};
    var secondary = <MuscleId>{};
    var loadingMode = LoadingMode.external;
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer,
                child: const Icon(AppIcons.add, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Custom exercise'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Cable Crossover',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 20),
                  const _FieldLabel('Category'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in ExerciseCategory.values)
                        ChoiceChip(
                          label: Text(_titleCase(item.name)),
                          avatar: Icon(
                            AppIcons.forCategoryName(item.name),
                            size: 18,
                          ),
                          selected: category == item,
                          onSelected: (_) =>
                              setDialogState(() => category = item),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _FieldLabel('Default load'),
                  const SizedBox(height: 8),
                  SegmentedButton<LoadingMode>(
                    segments: const [
                      ButtonSegment(
                        value: LoadingMode.external,
                        label: Text('Weight'),
                      ),
                      ButtonSegment(
                        value: LoadingMode.bodyweight,
                        label: Text('Bodyweight'),
                      ),
                      ButtonSegment(
                        value: LoadingMode.bodyweightAdded,
                        label: Text('Added'),
                      ),
                      ButtonSegment(
                        value: LoadingMode.bodyweightAssisted,
                        label: Text('Assist'),
                      ),
                    ],
                    selected: {loadingMode},
                    onSelectionChanged: (value) =>
                        setDialogState(() => loadingMode = value.single),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyweightFactor,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Bodyweight factor',
                      helperText:
                          '1.0 = full bodyweight; use lower values for partial-body movements.',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 20),
                  const _FieldLabel('Muscles worked'),
                  const SizedBox(height: 8),
                  _MuscleSelectionField(
                    label: 'Primary muscles',
                    selected: primary,
                    onTap: () async {
                      final value = await _showMusclePicker(
                        context,
                        title: 'Primary muscles',
                        selected: primary,
                      );
                      if (value == null) return;
                      setDialogState(() {
                        primary = value;
                        secondary.removeAll(primary);
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _MuscleSelectionField(
                    label: 'Secondary muscles',
                    selected: secondary,
                    onTap: () async {
                      final value = await _showMusclePicker(
                        context,
                        title: 'Secondary muscles',
                        selected: secondary,
                        excluded: primary,
                      );
                      if (value == null) return;
                      setDialogState(() => secondary = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: videoUrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Video link (optional)',
                      hintText: 'YouTube or any demo link',
                    ),
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: name.text.trim().isEmpty || primary.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (shouldSave != true || name.text.trim().isEmpty) return;
    validateMuscleSelection(primary: primary, secondary: secondary);
    final factor = (double.tryParse(bodyweightFactor.text) ?? 1.0).clamp(
      0.0,
      1.0,
    );
    await ref
        .read(exerciseRepositoryProvider)
        .add(
          ExercisesCompanion.insert(
            name: name.text.trim(),
            category: category,
            muscleGroup: 'custom',
            primaryMuscles: Value(encodeMuscleIds(primary)),
            secondaryMuscles: Value(encodeMuscleIds(secondary)),
            defaultUnit: const Value(WeightUnit.kg),
            preferredLoadingMode: Value(loadingMode),
            bodyweightFactor: Value(factor),
            videoUrl: Value(
              videoUrl.text.trim().isEmpty ? null : videoUrl.text.trim(),
            ),
            isCustom: const Value(true),
            isArchived: const Value(false),
          ),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Exercise added.')));
    }
  }

  Future<void> _editExerciseMuscles(
    BuildContext context,
    WidgetRef ref,
    Exercise exercise,
  ) async {
    Set<MuscleId> primary;
    Set<MuscleId> secondary;
    try {
      primary = decodeMuscleIds(exercise.primaryMuscles).toSet();
      secondary = decodeMuscleIds(exercise.secondaryMuscles).toSet();
    } on FormatException {
      primary = {};
      secondary = {};
    } on ArgumentError {
      primary = {};
      secondary = {};
    }

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${exercise.name} muscles'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MuscleSelectionField(
                label: 'Primary muscles',
                selected: primary,
                onTap: () async {
                  final value = await _showMusclePicker(
                    context,
                    title: 'Primary muscles',
                    selected: primary,
                  );
                  if (value == null) return;
                  setDialogState(() {
                    primary = value;
                    secondary.removeAll(primary);
                  });
                },
              ),
              const SizedBox(height: 12),
              _MuscleSelectionField(
                label: 'Secondary muscles',
                selected: secondary,
                onTap: () async {
                  final value = await _showMusclePicker(
                    context,
                    title: 'Secondary muscles',
                    selected: secondary,
                    excluded: primary,
                  );
                  if (value == null) return;
                  setDialogState(() => secondary = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: primary.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (shouldSave != true) return;
    validateMuscleSelection(primary: primary, secondary: secondary);
    await ref
        .read(exerciseRepositoryProvider)
        .updateMuscles(
          exercise.id,
          primaryMuscles: encodeMuscleIds(primary),
          secondaryMuscles: encodeMuscleIds(secondary),
        );
  }

  Future<void> _manageExercises(BuildContext context, WidgetRef ref) async {
    final all = await ref.read(exerciseRepositoryProvider).all();
    if (!context.mounted) return;
    final custom = all.where((item) => item.isCustom).toList();
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                child: Text(
                  'Custom exercises',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (custom.isEmpty)
                const SizedBox(
                  height: 260,
                  child: EmptyState(
                    icon: AppIcons.inventory,
                    title: 'No custom exercises',
                    message:
                        'Exercises you add will appear here to archive or restore.',
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      for (final exercise in custom)
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHigh,
                            foregroundColor: theme.colorScheme.primary,
                            child: Icon(
                              AppIcons.forCategoryName(exercise.category.name),
                            ),
                          ),
                          title: Text(exercise.name),
                          subtitle: Text(
                            exercise.primaryMuscles == '[]'
                                ? 'Tap to assign muscles'
                                : exercise.isArchived
                                ? 'Archived'
                                : _titleCase(exercise.category.name),
                          ),
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            await _editExerciseMuscles(context, ref, exercise);
                          },
                          trailing: IconButton(
                            icon: Icon(
                              exercise.isArchived
                                  ? AppIcons.refresh
                                  : AppIcons.archive,
                            ),
                            tooltip: exercise.isArchived
                                ? 'Restore'
                                : 'Archive',
                            onPressed: () async {
                              await ref
                                  .read(exerciseRepositoryProvider)
                                  .archive(
                                    exercise.id,
                                    archived: !exercise.isArchived,
                                  );
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAnatomyAttribution(BuildContext context) => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('3D anatomy model'),
      content: const SingleChildScrollView(
        child: SelectableText(
          'The muscular geometry is derived from BodyParts3D, with Z-Anatomy '
          'used for anatomical naming and mesh identification. The compiled '
          'muscular.glb model is provided by Adamas Designs under CC BY-SA 4.0.\n\n'
          'Attribution\n'
          'BodyParts3D — The Database Center for Life Science — CC BY-SA 2.1 Japan\n'
          'Z-Anatomy — The libre 3D atlas of anatomy — CC BY-SA 4.0\n'
          'Adamas Designs muscular.glb — CC BY-SA 4.0\n\n'
          'License details are bundled with the app in assets/models/ATTRIBUTION.md.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Future<void> _addBodyweight(BuildContext context, WidgetRef ref) async {
    final value = TextEditingController();
    var unit = WeightUnit.kg;
    var date = DateTime.now();
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add bodyweight'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: value,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Bodyweight'),
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 12),
              SegmentedButton<WeightUnit>(
                segments: const [
                  ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                  ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
                ],
                selected: {unit},
                onSelectionChanged: (selection) =>
                    setDialogState(() => unit = selection.single),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Effective date'),
                subtitle: Text(DateFormat.yMMMd().format(date)),
                trailing: const Icon(AppIcons.calendarCheck),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setDialogState(() => date = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: (double.tryParse(value.text) ?? 0) <= 0
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (shouldSave != true) return;
    await ref
        .read(bodyweightRepositoryProvider)
        .upsert(date: date, value: double.parse(value.text), unit: unit);
  }

  Future<void> _pickCustomRest(
    BuildContext context,
    WidgetRef ref,
    int currentSeconds,
  ) async {
    final controller = TextEditingController(text: '$currentSeconds');
    final seconds = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom rest timer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: const InputDecoration(
            labelText: 'Seconds',
            helperText: 'Between 15 seconds and 60 minutes',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              Navigator.pop(context, value?.clamp(15, 3600));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (seconds != null) {
      await ref.read(settingsRepositoryProvider).setDefaultRestSeconds(seconds);
    }
  }

  Future<void> _setRestNotifications(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    var resolved = enabled;
    if (enabled) {
      resolved = await ref
          .read(notificationServiceProvider)
          .requestPermission();
    }
    await ref
        .read(settingsRepositoryProvider)
        .setRestTimerNotificationsEnabled(resolved);
    if (enabled && !resolved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notifications are off. The in-app rest timer still works.',
          ),
        ),
      );
    }
  }

  Future<void> _setReminderEnabled(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    var resolved = enabled;
    if (enabled) {
      resolved = await ref
          .read(notificationServiceProvider)
          .requestPermission();
    }
    await ref.read(settingsRepositoryProvider).setReminderEnabled(resolved);
    await ref.read(reminderSchedulerProvider).sync();
    if (enabled && !resolved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Training reminders need notification permission.'),
        ),
      );
    }
  }

  Future<void> _pickReminderTime(
    BuildContext context,
    WidgetRef ref,
    ReminderPreferences preferences,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: preferences.hour,
        minute: preferences.minute,
      ),
    );
    if (picked == null) return;
    await ref
        .read(settingsRepositoryProvider)
        .setReminderTime(hour: picked.hour, minute: picked.minute);
    await ref.read(reminderSchedulerProvider).sync();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(workoutSettingsProvider).asData?.value ??
        WorkoutSettings.defaults;
    final repo = ref.read(settingsRepositoryProvider);
    final restTimer =
        ref.watch(restTimerPreferencesProvider).asData?.value ??
        const RestTimerPreferences();
    final reminder =
        ref.watch(reminderPreferencesProvider).asData?.value ??
        const ReminderPreferences();
    final coaching =
        ref.watch(coachingPreferencesProvider).asData?.value ??
        const CoachingPreferences();
    final plateInventory =
        ref.watch(plateInventoryProvider).asData?.value ?? PlateInventory();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const SectionHeader('Schedule'),
          _ScheduleCard(
            settings: settings,
            onGoalChanged: repo.setWeeklyGoal,
            onRestDaysChanged: (weekdays) async {
              await repo.setRestWeekdays(weekdays);
              await ref.read(reminderSchedulerProvider).sync();
            },
          ),
          const SizedBox(height: 12),
          _TrainingGoalCard(
            selected: coaching.trainingGoal,
            onChanged: repo.setTrainingGoal,
          ),
          const SizedBox(height: 12),
          _ReminderSettingsCard(
            preferences: reminder,
            onEnabledChanged: (enabled) =>
                _setReminderEnabled(context, ref, enabled),
            onTimeTap: () => _pickReminderTime(context, ref, reminder),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Rest timer'),
          _RestTimerSettingsCard(
            preferences: restTimer,
            onAutoStartChanged: repo.setRestTimerAutoStartEnabled,
            onSecondsChanged: repo.setDefaultRestSeconds,
            onCustom: () =>
                _pickCustomRest(context, ref, restTimer.defaultSeconds),
            onNotificationsChanged: (enabled) =>
                _setRestNotifications(context, ref, enabled),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Rest day'),
          const _RestDaySection(),
          const SizedBox(height: 24),
          const SectionHeader('Units'),
          const _InfoCard(
            icon: AppIcons.swap,
            title: 'Per-exercise units',
            body:
                'Each exercise remembers whether you log it in kg or lb — switch it right on the set. All progress is normalized to kg.',
          ),
          const SizedBox(height: 24),
          const SectionHeader('Equipment'),
          _PlateSettingsCard(
            inventory: plateInventory,
            onChanged: repo.setPlateInventory,
          ),
          const SizedBox(height: 24),
          const SectionHeader('Bodyweight history'),
          _BodyweightSection(onAdd: () => _addBodyweight(context, ref)),
          const SizedBox(height: 12),
          _SexSettingsCard(
            selected: coaching.userSex,
            onChanged: repo.setUserSex,
          ),
          const SizedBox(height: 24),
          const SectionHeader('Exercises'),
          _ActionCard(
            children: [
              _ActionTile(
                icon: AppIcons.add,
                title: 'Add custom exercise',
                subtitle: 'Something not in the library',
                onTap: () => _addExercise(context, ref),
              ),
              const Divider(),
              _ActionTile(
                icon: AppIcons.inventory,
                title: 'Manage custom exercises',
                subtitle: 'Archive or restore your exercises',
                onTap: () => _manageExercises(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionHeader('Backup'),
          _ActionCard(
            children: [
              _ActionTile(
                icon: AppIcons.export,
                title: 'Export backup',
                subtitle: 'Share a compressed .zip to your other device',
                onTap: () => _export(context, ref),
              ),
              const Divider(),
              _ActionTile(
                icon: AppIcons.import,
                title: 'Import backup',
                subtitle: 'Replace this device from a .zip or .json backup',
                onTap: () => _import(context, ref),
              ),
              const Divider(),
              _ActionTile(
                icon: AppIcons.inventory,
                title: 'Export set history (CSV)',
                subtitle: 'A spreadsheet of every logged set · export only',
                onTap: () => _exportCsv(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionHeader('About'),
          _ActionCard(
            children: [
              _ActionTile(
                icon: AppIcons.cube,
                title: '3D anatomy model',
                subtitle: 'BodyParts3D + Z-Anatomy naming · CC BY-SA 4.0',
                onTap: () => _showAnatomyAttribution(context),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              'Logged · local-first workout tracker',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderSettingsCard extends StatelessWidget {
  const _ReminderSettingsCard({
    required this.preferences,
    required this.onEnabledChanged,
    required this.onTimeTap,
  });

  final ReminderPreferences preferences;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onTimeTap;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(
      hour: preferences.hour,
      minute: preferences.minute,
    ).format(context);
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(AppIcons.calendarCheck),
            title: const Text('Training reminders'),
            subtitle: const Text(
              'Only on training days, until that day is logged',
            ),
            value: preferences.enabled,
            onChanged: onEnabledChanged,
          ),
          if (preferences.enabled) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Reminder time'),
              subtitle: Text(time),
              trailing: const Icon(AppIcons.chevronRight),
              onTap: onTimeTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _RestTimerSettingsCard extends StatelessWidget {
  const _RestTimerSettingsCard({
    required this.preferences,
    required this.onAutoStartChanged,
    required this.onSecondsChanged,
    required this.onCustom,
    required this.onNotificationsChanged,
  });

  static const _presets = [60, 90, 120, 180];

  final RestTimerPreferences preferences;
  final ValueChanged<bool> onAutoStartChanged;
  final ValueChanged<int> onSecondsChanged;
  final VoidCallback onCustom;
  final ValueChanged<bool> onNotificationsChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final custom = !_presets.contains(preferences.defaultSeconds);
    final autoStart = preferences.autoStartEnabled;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-start rest timer'),
              subtitle: const Text(
                'Start a countdown when you complete a set. Turn off if you log '
                'sets after training.',
              ),
              value: autoStart,
              onChanged: onAutoStartChanged,
            ),
            // The rest of the card only matters when the timer can start.
            if (autoStart) ...[
              const Divider(height: 24),
              Text('Default rest', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'A completed set starts this automatically. Exercise prescriptions override it.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final seconds in _presets)
                    ChoiceChip(
                      label: Text(_formatRestPreset(seconds)),
                      selected: preferences.defaultSeconds == seconds,
                      onSelected: (_) => onSecondsChanged(seconds),
                    ),
                  ChoiceChip(
                    label: Text(
                      custom
                          ? _formatRestPreset(preferences.defaultSeconds)
                          : 'Custom',
                    ),
                    selected: custom,
                    onSelected: (_) => onCustom(),
                  ),
                ],
              ),
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Rest-finished notifications'),
                subtitle: const Text('Alerts while Logged is backgrounded'),
                value: preferences.notificationsEnabled,
                onChanged: onNotificationsChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatRestPreset(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return remainder == 0 ? '${minutes}m' : '${minutes}m ${remainder}s';
}

Future<Set<MuscleId>?> _showMusclePicker(
  BuildContext context, {
  required String title,
  required Set<MuscleId> selected,
  Set<MuscleId> excluded = const {},
}) {
  final working = selected.toSet();
  return showModalBottomSheet<Set<MuscleId>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) {
        return FractionallySizedBox(
          heightFactor: 0.72,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Choose every muscle this exercise targets in this role.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final muscle in MuscleId.values)
                            FilterChip(
                              label: Text(muscle.label),
                              selected: working.contains(muscle),
                              onSelected: excluded.contains(muscle)
                                  ? null
                                  : (on) => setSheetState(() {
                                      on
                                          ? working.add(muscle)
                                          : working.remove(muscle);
                                    }),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, working),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// A small uppercase field label for grouping inputs inside dialogs.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

String _titleCase(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

class _MuscleSelectionField extends StatelessWidget {
  const _MuscleSelectionField({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Set<MuscleId> selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = selected.length;
    final summary = selected.isEmpty
        ? 'None selected'
        : MuscleId.values
              .where(selected.contains)
              .map((muscle) => muscle.label)
              .join(', ');
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              Icon(
                AppIcons.chevronRight,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlateSettingsCard extends StatefulWidget {
  const _PlateSettingsCard({required this.inventory, required this.onChanged});

  final PlateInventory inventory;
  final Future<void> Function(PlateInventory inventory) onChanged;

  @override
  State<_PlateSettingsCard> createState() => _PlateSettingsCardState();
}

class _PlateSettingsCardState extends State<_PlateSettingsCard> {
  late final TextEditingController _kgBar = TextEditingController(
    text: _trimPlateValue(widget.inventory.kgBarWeight),
  );
  late final TextEditingController _lbBar = TextEditingController(
    text: _trimPlateValue(widget.inventory.lbBarWeight),
  );
  late final FocusNode _kgBarFocus = FocusNode()
    ..addListener(() {
      if (!_kgBarFocus.hasFocus) {
        unawaited(_saveBarWeight(WeightUnit.kg));
      }
    });
  late final FocusNode _lbBarFocus = FocusNode()
    ..addListener(() {
      if (!_lbBarFocus.hasFocus) {
        unawaited(_saveBarWeight(WeightUnit.lb));
      }
    });

  @override
  void didUpdateWidget(covariant _PlateSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_kgBarFocus.hasFocus &&
        oldWidget.inventory.kgBarWeight != widget.inventory.kgBarWeight) {
      _kgBar.text = _trimPlateValue(widget.inventory.kgBarWeight);
    }
    if (!_lbBarFocus.hasFocus &&
        oldWidget.inventory.lbBarWeight != widget.inventory.lbBarWeight) {
      _lbBar.text = _trimPlateValue(widget.inventory.lbBarWeight);
    }
  }

  @override
  void dispose() {
    _kgBar.dispose();
    _lbBar.dispose();
    _kgBarFocus.dispose();
    _lbBarFocus.dispose();
    super.dispose();
  }

  Future<void> _saveBarWeight(WeightUnit unit) async {
    final controller = unit == WeightUnit.kg ? _kgBar : _lbBar;
    final current = widget.inventory.barWeightFor(unit);
    final parsed = double.tryParse(controller.text.trim());
    if (parsed == null || parsed <= 0) {
      controller.text = _trimPlateValue(current);
      return;
    }
    final updated = widget.inventory.copyWithUnit(
      unit: unit,
      barWeight: parsed,
    );
    controller.text = _trimPlateValue(updated.barWeightFor(unit));
    await widget.onChanged(updated);
  }

  Future<void> _togglePlate(WeightUnit unit, double size, bool selected) async {
    final selectedSizes = widget.inventory.plateSizesFor(unit).toSet();
    if (selected) {
      selectedSizes.add(size);
    } else {
      selectedSizes.remove(size);
    }
    final ordered = [
      for (final plate in standardPlateSizesFor(unit))
        if (selectedSizes.contains(plate)) plate,
    ];
    await widget.onChanged(
      widget.inventory.copyWithUnit(unit: unit, plateSizes: ordered),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plate calculator', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Set the bars and plates you actually have.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            _PlateUnitSection(
              unit: WeightUnit.kg,
              barController: _kgBar,
              barFocusNode: _kgBarFocus,
              barWeight: widget.inventory.kgBarWeight,
              selectedPlates: widget.inventory.kgPlateSizes.toSet(),
              onBarSubmitted: () => _saveBarWeight(WeightUnit.kg),
              onPlateSelected: (size, selected) =>
                  _togglePlate(WeightUnit.kg, size, selected),
            ),
            const Divider(height: 24),
            _PlateUnitSection(
              unit: WeightUnit.lb,
              barController: _lbBar,
              barFocusNode: _lbBarFocus,
              barWeight: widget.inventory.lbBarWeight,
              selectedPlates: widget.inventory.lbPlateSizes.toSet(),
              onBarSubmitted: () => _saveBarWeight(WeightUnit.lb),
              onPlateSelected: (size, selected) =>
                  _togglePlate(WeightUnit.lb, size, selected),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlateUnitSection extends StatelessWidget {
  const _PlateUnitSection({
    required this.unit,
    required this.barController,
    required this.barFocusNode,
    required this.barWeight,
    required this.selectedPlates,
    required this.onBarSubmitted,
    required this.onPlateSelected,
  });

  final WeightUnit unit;
  final TextEditingController barController;
  final FocusNode barFocusNode;
  final double barWeight;
  final Set<double> selectedPlates;
  final VoidCallback onBarSubmitted;
  final Future<void> Function(double size, bool selected) onPlateSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(unit.label.toUpperCase(), style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        TextField(
          controller: barController,
          focusNode: barFocusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Bar weight',
            suffixText: unit.label,
          ),
          onSubmitted: (_) => onBarSubmitted(),
          onTapOutside: (_) => barFocusNode.unfocus(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final size in standardPlateSizesFor(unit))
              FilterChip(
                label: Text(_trimPlateValue(size)),
                selected: selectedPlates.contains(size),
                onSelected: (selected) => onPlateSelected(size, selected),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Bar: ${_trimPlateValue(barWeight)} ${unit.label}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

String _trimPlateValue(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

class _BodyweightSection extends ConsumerWidget {
  const _BodyweightSection({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entries =
        ref.watch(bodyweightEntriesProvider).asData?.value ??
        const <BodyweightEntry>[];
    final repo = ref.read(bodyweightRepositoryProvider);
    return _ActionCard(
      children: [
        _ActionTile(
          icon: AppIcons.body,
          title: entries.isEmpty
              ? 'Add bodyweight'
              : 'Current: ${_trim(entries.first.value)} ${entries.first.unit.name}',
          subtitle: entries.isEmpty
              ? 'Improves bodyweight, added-weight, and assisted calculations'
              : 'Effective ${DateFormat.yMMMd().format(entries.first.date)}',
          onTap: onAdd,
        ),
        if (entries.isNotEmpty) ...[
          const Divider(height: 1),
          for (var i = 0; i < entries.take(4).length; i++)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
                foregroundColor: theme.colorScheme.primary,
                child: Text('${i + 1}'),
              ),
              title: Text('${_trim(entries[i].value)} ${entries[i].unit.name}'),
              subtitle: Text(DateFormat.yMMMd().format(entries[i].date)),
              trailing: IconButton(
                tooltip: 'Delete bodyweight entry',
                icon: Icon(AppIcons.trash, color: theme.colorScheme.error),
                onPressed: () => repo.delete(entries[i].id),
              ),
            ),
          if (entries.length > 4)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                '${entries.length - 4} older entries kept for historical calculations.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ],
    );
  }

  static String _trim(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

/// One-off rest days: mark today or an upcoming day off so a planned absence
/// (e.g. legs too sore to train tomorrow) bridges the streak instead of breaking
/// it. Recurring weekly rest days live in [_ScheduleCard]; these are ad-hoc.
class _RestDaySection extends ConsumerWidget {
  const _RestDaySection();

  Future<void> _pickAnother(
    BuildContext context,
    RestDayRepository repo,
    WidgetRef ref,
  ) async {
    final now = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Mark a rest day',
    );
    if (picked == null) return;
    await repo.log(dateOnly(picked));
    await ref.read(reminderSchedulerProvider).sync();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(restDayRepositoryProvider);
    final restDays =
        ref.watch(restDaysProvider).asData?.value ?? const <DateTime>[];
    final settings =
        ref.watch(workoutSettingsProvider).asData?.value ??
        WorkoutSettings.defaults;

    final today = dateOnly(DateTime.now());
    final logged = restDays.map(dateOnly).toSet();
    final loggedToday = logged.contains(today);
    final scheduledToday = settings.restWeekdays.contains(today.weekday);
    final upcoming = logged.where((d) => !d.isBefore(today)).toList()..sort();

    return _ActionCard(
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
            foregroundColor: theme.colorScheme.primary,
            child: const Icon(AppIcons.rest),
          ),
          title: const Text('Rest day today'),
          subtitle: Text(
            scheduledToday
                ? 'Already a scheduled rest day'
                : loggedToday
                ? 'Marked as a rest day'
                : 'Keeps your streak alive on a day off',
          ),
          trailing: scheduledToday
              ? null
              : loggedToday
              ? OutlinedButton(
                  onPressed: () async {
                    await repo.remove(today);
                    await ref.read(reminderSchedulerProvider).sync();
                  },
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Undo'),
                )
              : FilledButton(
                  onPressed: () async {
                    await repo.log(today);
                    await ref.read(reminderSchedulerProvider).sync();
                  },
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Mark'),
                ),
        ),
        const Divider(height: 1),
        _ActionTile(
          icon: AppIcons.calendarCheck,
          title: 'Mark another day',
          subtitle: 'Plan an upcoming day off',
          onTap: () => _pickAnother(context, repo, ref),
        ),
        if (upcoming.isNotEmpty) ...[
          const Divider(height: 1),
          for (final day in upcoming)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                child: const Icon(AppIcons.rest),
              ),
              title: Text(
                day == today ? 'Today' : DateFormat.yMMMMEEEEd().format(day),
              ),
              subtitle: const Text('Rest day'),
              trailing: IconButton(
                icon: const Icon(AppIcons.trash),
                tooltip: 'Remove',
                onPressed: () async {
                  await repo.remove(day);
                  await ref.read(reminderSchedulerProvider).sync();
                },
              ),
            ),
        ],
      ],
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.settings,
    required this.onGoalChanged,
    required this.onRestDaysChanged,
  });

  final WorkoutSettings settings;
  final ValueChanged<int> onGoalChanged;
  final ValueChanged<Set<int>> onRestDaysChanged;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.target, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Weekly goal', style: theme.textTheme.titleMedium),
              ),
              IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                onPressed: settings.weeklyGoal > 1
                    ? () => onGoalChanged(settings.weeklyGoal - 1)
                    : null,
                icon: const Icon(Icons.remove, size: 18),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${settings.weeklyGoal}',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                onPressed: settings.weeklyGoal < 7
                    ? () => onGoalChanged(settings.weeklyGoal + 1)
                    : null,
                icon: const Icon(Icons.add, size: 18),
              ),
            ],
          ),
          Text(
            'days per week',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Divider(height: 28),
          Row(
            children: [
              Icon(AppIcons.rest, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text('Rest days', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Rest days keep your streak alive.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var weekday = 1; weekday <= 7; weekday++)
                _DayToggle(
                  label: _labels[weekday - 1],
                  selected: settings.restWeekdays.contains(weekday),
                  onTap: () {
                    final next = {...settings.restWeekdays};
                    next.contains(weekday)
                        ? next.remove(weekday)
                        : next.add(weekday);
                    onRestDaysChanged(next);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrainingGoalCard extends StatelessWidget {
  const _TrainingGoalCard({required this.selected, required this.onChanged});

  final TrainingGoal selected;
  final ValueChanged<TrainingGoal> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ActionCard(
      children: [
        ListTile(
          leading: const Icon(AppIcons.target),
          title: const Text('Training goal'),
          subtitle: const Text(
            'Tunes volume landmarks, progression, and recovery guidance',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: SegmentedButton<TrainingGoal>(
            segments: [
              for (final goal in TrainingGoal.values)
                ButtonSegment(value: goal, label: Text(goal.label)),
            ],
            selected: {selected},
            onSelectionChanged: (value) => onChanged(value.single),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Text(switch (selected) {
            TrainingGoal.maintain =>
              'Lower volume targets and conservative progression.',
            TrainingGoal.build =>
              'Balanced growth, progression, and recovery guidance.',
            TrainingGoal.push =>
              'Higher volume targets with more aggressive progression.',
          }),
        ),
      ],
    );
  }
}

class _SexSettingsCard extends StatelessWidget {
  const _SexSettingsCard({required this.selected, required this.onChanged});

  final UserSex selected;
  final ValueChanged<UserSex> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ActionCard(
      children: [
        ListTile(
          leading: const Icon(AppIcons.body),
          title: const Text('Sex for strength standards'),
          subtitle: const Text(
            'Optional. Used only for population lift comparisons, never muscle ranks.',
          ),
          trailing: DropdownButton<UserSex>(
            value: selected,
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
            items: const [
              DropdownMenuItem(value: UserSex.unset, child: Text('Not set')),
              DropdownMenuItem(value: UserSex.female, child: Text('Female')),
              DropdownMenuItem(value: UserSex.male, child: Text('Male')),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        width: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHigh,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        foregroundColor: theme.colorScheme.primary,
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        AppIcons.chevronRight,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

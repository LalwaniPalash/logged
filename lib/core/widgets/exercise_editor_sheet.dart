import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../app_icons.dart';
import '../domain/enums.dart';
import '../domain/exercise_name_matcher.dart';
import '../domain/muscle.dart';

Future<bool> showExerciseEditorSheet(
  BuildContext context,
  WidgetRef ref,
  Exercise exercise,
) async {
  final existingNames = (await ref.read(exerciseRepositoryProvider).all())
      .where((item) => item.id != exercise.id)
      .map((item) => item.name)
      .toList(growable: false);
  if (!context.mounted) return false;
  final navigator = Navigator.of(context);
  final navigatorContext = navigator.context;
  if (!navigatorContext.mounted) return false;
  final name = TextEditingController(text: exercise.name);
  final bodyweightFactor = TextEditingController(
    text: exercise.bodyweightFactor.toString(),
  );
  final videoUrl = TextEditingController(text: exercise.videoUrl ?? '');
  var category = exercise.category;
  var isTimed = exercise.isTimed;
  var tracksDistance = exercise.tracksDistance;
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
  final localizations = MaterialLocalizations.of(context);
  final route = ModalBottomSheetRoute<_ExerciseEditorAction>(
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) {
        final theme = Theme.of(context);
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor: theme.colorScheme.onPrimaryContainer,
                          child: const Icon(AppIcons.edit, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Edit exercise',
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: name,
                            // Deliberately NOT autofocused, unlike the
                            // create-exercise sheet where the name is the first
                            // thing you type. Here the name is already filled
                            // and the keyboard would cover the muscle pickers —
                            // the reason this sheet is usually opened at all,
                            // now that it is one tap from every card in a
                            // workout.
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Name',
                              errorText:
                                  isDuplicateExerciseName(
                                    name.text,
                                    existingNames,
                                  )
                                  ? '"${name.text.trim()}" already exists'
                                  : null,
                            ),
                            onChanged: (_) => setSheetState(() {}),
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
                                      setSheetState(() => category = item),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            categoryLoggingHelper(category),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Logged in seconds'),
                            subtitle: const Text(
                              'Show a duration field instead of reps for this exercise.',
                            ),
                            value: isTimed,
                            onChanged: (value) =>
                                setSheetState(() => isTimed = value),
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Tracks distance'),
                            subtitle: const Text(
                              'Keep distance available even when this exercise is not cardio.',
                            ),
                            value: tracksDistance,
                            onChanged: (value) =>
                                setSheetState(() => tracksDistance = value),
                          ),
                          const SizedBox(height: 20),
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
                              setSheetState(() {
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
                              setSheetState(() => secondary = value);
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(
                              context,
                              _ExerciseEditorAction.delete,
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                            ),
                            child: const Text('Delete'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed:
                                name.text.trim().isEmpty ||
                                    primary.isEmpty ||
                                    isDuplicateExerciseName(
                                      name.text,
                                      existingNames,
                                    )
                                ? null
                                : () => Navigator.pop(
                                    context,
                                    _ExerciseEditorAction.save,
                                  ),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
    capturedThemes: InheritedTheme.capture(from: context, to: navigatorContext),
    isScrollControlled: true,
    showDragHandle: true,
    barrierLabel: localizations.scrimLabel,
    barrierOnTapHint: localizations.scrimOnTapHint(
      localizations.bottomSheetLabel,
    ),
    modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
  );
  final action = await navigator.push(route);
  await route.completed;
  if (action == null) {
    name.dispose();
    bodyweightFactor.dispose();
    videoUrl.dispose();
    return false;
  }
  if (action == _ExerciseEditorAction.delete) {
    name.dispose();
    bodyweightFactor.dispose();
    videoUrl.dispose();
    if (!context.mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${exercise.name}?'),
        content: const Text(
          'This permanently removes the exercise if it is not used by any logged workouts or templates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    final repository = ref.read(exerciseRepositoryProvider);
    final deleted = await repository.delete(exercise.id);
    if (deleted) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Exercise deleted.')));
      }
      return true;
    }
    if (!context.mounted) return false;
    final archiveInstead = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive instead?'),
        content: const Text(
          'This exercise is already used by logged workouts or templates, so it cannot be deleted. Archive it instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (archiveInstead != true) return false;
    await repository.archive(exercise.id, archived: true);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Exercise archived.')));
    }
    return true;
  }
  validateMuscleSelection(primary: primary, secondary: secondary);
  final factor = (double.tryParse(bodyweightFactor.text) ?? 1.0).clamp(
    0.0,
    1.0,
  );
  final trimmedVideoUrl = videoUrl.text.trim();
  final repository = ref.read(exerciseRepositoryProvider);
  await repository.updateDetails(
    exercise.id,
    name: name.text.trim(),
    category: category,
    bodyweightFactor: factor,
    isTimed: isTimed,
    tracksDistance: tracksDistance,
  );
  await repository.updateMuscles(
    exercise.id,
    primaryMuscles: encodeMuscleIds(primary),
    secondaryMuscles: encodeMuscleIds(secondary),
  );
  await repository.updateVideoUrl(
    exercise.id,
    trimmedVideoUrl.isEmpty ? null : trimmedVideoUrl,
  );
  name.dispose();
  bodyweightFactor.dispose();
  videoUrl.dispose();
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Exercise updated.')));
  }
  return true;
}

class ExerciseInfoSheet extends ConsumerWidget {
  const ExerciseInfoSheet({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primary = _decodeMuscles(exercise.primaryMuscles);
    final secondary = _decodeMuscles(exercise.secondaryMuscles);
    final traits = [
      if (exercise.isTimed) 'Timed',
      if (exercise.tracksDistance) 'Tracks distance',
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Icon(
                    AppIcons.forCategoryName(exercise.category.name),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(exercise.name, style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoSection(
              label: 'Category',
              child: Text(_titleCase(exercise.category.name)),
            ),
            const SizedBox(height: 16),
            _InfoSection(
              label: 'Logging',
              child: Text(
                traits.isEmpty ? 'Standard reps and load' : traits.join(' · '),
              ),
            ),
            const SizedBox(height: 16),
            _InfoSection(
              label: 'Primary muscles',
              child: _MuscleNameWrap(muscles: primary),
            ),
            const SizedBox(height: 16),
            _InfoSection(
              label: 'Secondary muscles',
              child: _MuscleNameWrap(muscles: secondary),
            ),
            const SizedBox(height: 16),
            _InfoSection(
              label: 'Bodyweight factor',
              child: Text('${exercise.bodyweightFactor}'),
            ),
            if ((exercise.videoUrl ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _InfoSection(
                label: 'Video link',
                child: SelectableText(exercise.videoUrl!),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                final changed = await showExerciseEditorSheet(
                  context,
                  ref,
                  exercise,
                );
                if (changed && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
              icon: const Icon(AppIcons.edit),
              label: const Text('Edit'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ExerciseEditorAction { save, delete }

/// Explains what a category changes about logging. Shared by the exercise
/// editor and the create-exercise sheet in Settings — keep one copy.
String categoryLoggingHelper(ExerciseCategory category) => switch (category) {
  ExerciseCategory.cardio =>
    'Cardio sets need both a duration and a distance to count as complete.',
  ExerciseCategory.stretching =>
    'Stretching sets are logged in seconds, not reps.',
  ExerciseCategory.bodyweight =>
    'Bodyweight sets count when you log reps or seconds.',
  ExerciseCategory.strength =>
    'Strength sets count when you log reps and load.',
};

String _titleCase(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1)}';
    })
    .join(' ');

List<MuscleId> _decodeMuscles(String encoded) {
  try {
    return decodeMuscleIds(encoded);
  } on FormatException {
    return const [];
  } on ArgumentError {
    return const [];
  }
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.9,
      ),
    );
  }
}

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
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(14),
        alignment: Alignment.centerLeft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            selected.isEmpty
                ? 'Select muscles'
                : selected.map((muscle) => muscle.label).join(', '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: selected.isEmpty
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _MuscleNameWrap extends StatelessWidget {
  const _MuscleNameWrap({required this.muscles});

  final List<MuscleId> muscles;

  @override
  Widget build(BuildContext context) {
    if (muscles.isEmpty) {
      return Text(
        'None assigned',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final muscle in muscles) Chip(label: Text(muscle.label))],
    );
  }
}

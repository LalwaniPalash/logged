import 'package:flutter/material.dart';

import '../../data/database/app_database.dart';
import '../app_icons.dart';
import 'app_widgets.dart';

/// Shared searchable exercise chooser used by the session, progress and template
/// screens. Returns the chosen [Exercise], or null if dismissed.
Future<Exercise?> showExercisePicker(
  BuildContext context,
  List<Exercise> exercises, {
  String title = 'Choose an exercise',
}) {
  final available = exercises.where((e) => !e.isArchived).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return showModalBottomSheet<Exercise>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) =>
        _ExercisePickerSheet(exercises: available, title: title),
  );
}

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet({required this.exercises, required this.title});
  final List<Exercise> exercises;
  final String title;

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = widget.exercises
        .where(
          (e) =>
              e.name.toLowerCase().contains(_query.toLowerCase()) ||
              e.muscleGroup.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.title, style: theme.textTheme.titleLarge),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Search by name or muscle group',
                prefixIcon: Icon(AppIcons.search),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: AppIcons.search,
                    title: 'No matches',
                    message: 'Try a different search term.',
                  )
                : ListView.builder(
                    controller: controller,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final exercise = filtered[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHigh,
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                          child: Icon(
                            iconForCategoryName(exercise.category.name),
                            size: 20,
                          ),
                        ),
                        title: Text(exercise.name),
                        subtitle: Text(exercise.muscleGroup),
                        onTap: () => Navigator.pop(context, exercise),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/providers.dart';
import 'active_session_screen.dart';

/// Shared entry point used by Dashboard and empty-state CTAs.
Future<void> showStartWorkoutFlow(BuildContext context, WidgetRef ref) async {
  final session = ref.read(sessionRepositoryProvider);
  final templates = await ref.read(templateRepositoryProvider).watchAll().first;
  if (!context.mounted) return;
  final choice = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Start a workout', style: theme.textTheme.titleLarge),
            ),
            _StartTile(
              icon: AppIcons.bolt,
              title: 'Empty workout',
              subtitle: 'Add exercises as you go',
              onTap: () => Navigator.pop(context, 'empty'),
            ),
            if (templates.isNotEmpty) ...[
              const SizedBox(height: 16),
              const SectionHeader('From a template'),
              for (final item in templates)
                _StartTile(
                  icon: AppIcons.templates,
                  title: item.name,
                  subtitle: 'Pre-filled exercises',
                  onTap: () => Navigator.pop(context, item.id),
                ),
            ],
          ],
        ),
      );
    },
  );
  if (choice == null || !context.mounted) return;
  final templateId = choice is int ? choice : null;
  final id = await session.start(templateId: templateId);
  if (templateId != null) {
    await session.startFromTemplate(sessionId: id, templateId: templateId);
  }
  if (context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ActiveSessionScreen(sessionId: id)),
    );
  }
}

Future<void> startWorkoutWithExercise(
  BuildContext context,
  WidgetRef ref, {
  required int exerciseId,
}) async {
  final repository = ref.read(sessionRepositoryProvider);
  final sessionId = await repository.start();
  await repository.addExercise(sessionId: sessionId, exerciseId: exerciseId);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ActiveSessionScreen(sessionId: sessionId),
    ),
  );
}

class _StartTile extends StatelessWidget {
  const _StartTile({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Icon(icon),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  AppIcons.chevronRight,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import 'template_editor_screen.dart';
import 'import/import_screen.dart';

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New template'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'e.g. Push Day',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final id = await ref.read(templateRepositoryProvider).create(name);
    if (!context.mounted) return;
    final template =
        (await ref.read(templateRepositoryProvider).watchAll().first)
            .firstWhere((t) => t.id == id);
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateEditorScreen(template: template),
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Template template,
  ) async {
    final controller = TextEditingController(text: template.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename template'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    await ref.read(templateRepositoryProvider).rename(template.id, name);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Template template,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete “${template.name}”?'),
        content: const Text(
          'The template will be removed. Past workouts and their sets will stay in History.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(templateRepositoryProvider).delete(template.id);
  }

  Future<void> _duplicate(
    BuildContext context,
    WidgetRef ref,
    Template template,
  ) async {
    await ref.read(templateRepositoryProvider).duplicate(template.id);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Copied ${template.name}.')));
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    Template template,
    String action,
  ) async {
    switch (action) {
      case 'rename':
        await _rename(context, ref, template);
      case 'duplicate':
        await _duplicate(context, ref, template);
      case 'delete':
        await _delete(context, ref, template);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Templates'),
        actions: [
          IconButton(
            tooltip: 'Import program',
            icon: const Icon(AppIcons.import),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProgramImportScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(AppIcons.add),
        label: const Text('New template'),
      ),
      body: StreamBuilder<List<Template>>(
        stream: ref.watch(templateRepositoryProvider).watchAll(),
        builder: (context, snapshot) {
          final templates = snapshot.data ?? const <Template>[];
          if (templates.isEmpty) {
            return EmptyState(
              icon: AppIcons.templates,
              title: 'No templates yet',
              message:
                  'Build a reusable workout like "Push Day" so you can start it in one tap.',
              action: FilledButton.icon(
                onPressed: () => _create(context, ref),
                icon: const Icon(AppIcons.add),
                label: const Text('New template'),
              ),
            );
          }
          return ReorderableListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              final ordered = [for (final template in templates) template.id];
              final moved = ordered.removeAt(oldIndex);
              ordered.insert(newIndex, moved);
              unawaited(ref.read(templateRepositoryProvider).reorder(ordered));
            },
            children: [
              for (final template in templates)
                Padding(
                  key: ValueKey(template.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TemplateEditorScreen(template: template),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              foregroundColor:
                                  theme.colorScheme.onPrimaryContainer,
                              child: const Icon(AppIcons.templates),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                template.name,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Template actions',
                              onSelected: (action) =>
                                  _handleAction(context, ref, template, action),
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text('Rename'),
                                ),
                                PopupMenuItem(
                                  value: 'duplicate',
                                  child: Text('Duplicate'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                            ReorderableDragStartListener(
                              index: templates.indexOf(template),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  AppIcons.drag,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

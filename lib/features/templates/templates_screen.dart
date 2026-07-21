import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import 'template_editor_screen.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Templates')),
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
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            children: [
              for (final template in templates)
                Padding(
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
                            Icon(
                              AppIcons.chevronRight,
                              color: theme.colorScheme.onSurfaceVariant,
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

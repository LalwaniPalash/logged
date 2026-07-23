import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_icons.dart';
import '../rest_timer_controller.dart';

class RestTimerBar extends ConsumerWidget {
  const RestTimerBar({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(restTimerControllerProvider);
    if (!state.running || state.sessionId != sessionId) {
      return const SizedBox.shrink();
    }
    final controller = ref.read(restTimerControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Material(
        color: colors.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(AppIcons.rest, color: colors.onSecondaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Rest · ${state.display}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSecondaryContainer,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Subtract 15 seconds',
                onPressed: () => controller.adjust(-15),
                icon: const Icon(Icons.remove),
              ),
              IconButton(
                tooltip: 'Add 15 seconds',
                onPressed: () => controller.adjust(15),
                icon: const Icon(AppIcons.add),
              ),
              TextButton(onPressed: controller.skip, child: const Text('Skip')),
            ],
          ),
        ),
      ),
    );
  }
}

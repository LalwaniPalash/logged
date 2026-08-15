import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_icons.dart';
import '../rest_timer_controller.dart';

class RestTimerBar extends ConsumerWidget {
  const RestTimerBar({super.key, required this.sessionId, this.onTap});

  final int sessionId;

  /// Reopens the full-screen timer. Only the label and countdown are tappable —
  /// the −15s / +15s / Skip controls keep their own taps, so maximising never
  /// steals a press meant for them.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(restTimerControllerProvider);
    if (state.sessionId != sessionId) {
      return const SizedBox.shrink();
    }
    final controller = ref.read(restTimerControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    if (!state.running && !state.completed) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: Material(
        color: state.completed
            ? colors.primaryContainer
            : colors.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: state.completed
              ? Row(
                  children: [
                    Icon(AppIcons.rest, color: colors.onPrimaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Rest complete',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colors.onPrimaryContainer,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: controller.acknowledge,
                      child: const Text('Done'),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onTap,
                        child: Semantics(
                          button: onTap != null,
                          label: onTap == null
                              ? null
                              : 'Rest ${state.display}, open the full timer',
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.rest,
                                color: colors.onSecondaryContainer,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Rest · ${state.display}',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: colors.onSecondaryContainer,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Subtract 15 seconds',
                      onPressed: () => controller.adjust(-15),
                      icon: const Icon(AppIcons.minus),
                    ),
                    IconButton(
                      tooltip: 'Add 15 seconds',
                      onPressed: () => controller.adjust(15),
                      icon: const Icon(AppIcons.add),
                    ),
                    TextButton(
                      onPressed: controller.skip,
                      child: const Text('Skip'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

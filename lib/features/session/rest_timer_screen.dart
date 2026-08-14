import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/domain/progression.dart';
import 'rest_timer_controller.dart';

class RestTimerScreen extends ConsumerStatefulWidget {
  const RestTimerScreen({
    super.key,
    required this.sessionId,
    required this.exerciseName,
    required this.nextSetNumber,
    required this.suggestion,
  });

  final int sessionId;
  final String exerciseName;
  final int nextSetNumber;
  final ProgressionSuggestion? suggestion;

  @override
  ConsumerState<RestTimerScreen> createState() => _RestTimerScreenState();
}

class _RestTimerScreenState extends ConsumerState<RestTimerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  DateTime? _syncedEndTime;
  bool _syncedRunning = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, value: 1);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _cancelTimer(RestTimerState state) async {
    final remaining = _remainingSeconds(state);
    if (remaining > 30) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel rest timer?'),
          content: Text(
            'There are still ${_formatDisplay(remaining)} remaining in this rest.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep timer'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel timer'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }
    await ref
        .read(restTimerControllerProvider.notifier)
        .cancel(sessionId: widget.sessionId);
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _acknowledge() async {
    await ref.read(restTimerControllerProvider.notifier).acknowledge();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _syncAnimation(RestTimerState state) {
    if (!state.running || state.endTime == null) {
      _animationController.stop();
      _animationController.value = state.completed ? 0 : 1;
      _syncedRunning = state.running;
      _syncedEndTime = state.endTime;
      return;
    }
    final remaining = _remainingDuration(state.endTime!);
    final duration = remaining <= Duration.zero
        ? const Duration(milliseconds: 1)
        : remaining;
    _animationController
      ..stop()
      ..duration = duration
      ..value = 1
      ..reverse(from: 1);
    _syncedRunning = state.running;
    _syncedEndTime = state.endTime;
  }

  Duration _remainingDuration(DateTime endTime) {
    final remaining = endTime.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  int _remainingSeconds(RestTimerState state) {
    if (!state.running || state.endTime == null) {
      return state.remainingSeconds;
    }
    final milliseconds = state.endTime!
        .difference(DateTime.now())
        .inMilliseconds;
    if (milliseconds <= 0) return 0;
    return (milliseconds / Duration.millisecondsPerSecond).ceil();
  }

  String _formatDisplay(int remainingSeconds) {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(restTimerControllerProvider);
    if (_syncedRunning != state.running || _syncedEndTime != state.endTime) {
      _syncAnimation(state);
    }
    if (state.sessionId != widget.sessionId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }

    final controller = ref.read(restTimerControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, _) {
            final remainingSeconds = _remainingSeconds(state);
            final display = _formatDisplay(remainingSeconds);
            final progress = state.completed
                ? 0.0
                : _animationController.value.clamp(0.0, 1.0);

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Minimize rest timer',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(AppIcons.chevronDown),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Cancel rest timer',
                        onPressed: () => _cancelTimer(state),
                        icon: const Icon(AppIcons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.exerciseName,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set ${widget.nextSetNumber} is next',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (widget.suggestion != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.suggestion!.rationale,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 280,
                          width: 280,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 14,
                            backgroundColor: colors.surfaceContainerHighest,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.completed ? 'Rest complete' : 'Rest',
                              style: textTheme.titleLarge?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              state.completed ? 'Done' : display,
                              style: textTheme.displayLarge?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (state.completed)
                    FilledButton(
                      onPressed: _acknowledge,
                      child: const Text('Done'),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => controller.adjust(-15),
                            icon: const Icon(AppIcons.minus),
                            label: const Text('-15s'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => controller.adjust(15),
                            icon: const Icon(AppIcons.add),
                            label: const Text('+15s'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: controller.skip,
                            child: const Text('Skip'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

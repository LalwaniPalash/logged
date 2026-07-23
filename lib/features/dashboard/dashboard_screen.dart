import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/domain/muscle_progress.dart';
import '../../core/domain/muscle.dart';
import '../../core/domain/streak.dart';
import '../../core/domain/workout_settings.dart';
import '../../core/domain/training_goal.dart';
import '../../core/domain/rank_events.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/providers.dart';
import '../session/active_session_screen.dart';
import '../session/start_workout_flow.dart';
import '../templates/templates_screen.dart';
import '../ranks/ranks_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    await showStartWorkoutFlow(context, ref);
  }

  Future<void> _handleRankUpdates(
    BuildContext context,
    WidgetRef ref,
    Map<MuscleId, MuscleProgress> progress,
  ) async {
    final repository = ref.read(settingsRepositoryProvider);
    final previous = await repository.readLastSeenRanks();
    final current = {
      for (final entry in progress.entries) entry.key: entry.value.rank,
    };
    await repository.setLastSeenRanks(current);
    if (previous.isEmpty || !context.mounted) return;
    final events = detectRankUps(previous: previous, current: current);
    if (events.isEmpty) return;
    final event = events.first;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${event.muscle.label} ranked up to ${event.current.label}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(muscleProgressProvider, (previous, next) {
      next.whenData((progress) => _handleRankUpdates(context, ref, progress));
    });
    final theme = Theme.of(context);
    final recent = ref.watch(sessionRepositoryProvider).watchRecent(limit: 3);
    final bodySummary = ref.watch(bodyProgressSummaryProvider);
    final days =
        ref.watch(trainingDaysProvider).asData?.value ?? const <DateTime>[];
    final restDays =
        ref.watch(restDaysProvider).asData?.value ?? const <DateTime>[];
    final settings =
        ref.watch(workoutSettingsProvider).asData?.value ??
        WorkoutSettings.defaults;
    final now = DateTime.now();
    final goal =
        ref.watch(coachingPreferencesProvider).asData?.value.trainingGoal ??
        TrainingGoal.build;

    final daysThisWeek = trainingDaysThisWeek(days, today: now);
    final weekStates = _weekStates(
      now: now,
      trainingDays: days,
      restDays: restDays,
      restWeekdays: settings.restWeekdays,
    );

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width - 40,
        height: 58,
        child: FilledButton(
          onPressed: () => _start(context, ref),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 26,
                width: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.play,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Text('Start workout'),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(trainingDaysProvider);
            ref.invalidate(restDaysProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(now),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text('Logged', style: theme.textTheme.headlineMedium),
                    ],
                  ),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TemplatesScreen(),
                      ),
                    ),
                    icon: const Icon(AppIcons.templates),
                    tooltip: 'Templates',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _BodyRankHero(
                summary: bodySummary.asData?.value,
                goal: goal,
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const RanksScreen())),
              ),
              const SizedBox(height: 14),
              _NextFocusCard(summary: bodySummary.asData?.value),
              const SizedBox(height: 18),
              WeeklyProgressStrip(
                states: weekStates,
                done: daysThisWeek,
                goal: settings.weeklyGoal,
              ),
              const SizedBox(height: 24),
              const SectionHeader('Recent sessions'),
              StreamBuilder(
                stream: recent,
                builder: (context, snapshot) {
                  final sessions = snapshot.data ?? const [];
                  if (sessions.isEmpty) {
                    return _EmptyRecent(onStart: () => _start(context, ref));
                  }
                  return Column(
                    children: [
                      for (final session in sessions)
                        _SessionTile(
                          date: session.startedAt,
                          active: session.endedAt == null,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ActiveSessionScreen(sessionId: session.id),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Status for each day of the current (Monday-based) week, for the strip.
  List<WeekDayState> _weekStates({
    required DateTime now,
    required List<DateTime> trainingDays,
    required List<DateTime> restDays,
    required Set<int> restWeekdays,
  }) {
    final today = dateOnly(now);
    final weekStart = startOfWeek(now);
    final trained = trainingDays.map(dateOnly).toSet();
    final rests = restDays.map(dateOnly).toSet();
    return List.generate(7, (i) {
      final day = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      if (trained.contains(day)) return WeekDayState.trained;
      if (isRestDay(day, restWeekdays: restWeekdays, loggedRestDays: rests)) {
        return WeekDayState.rest;
      }
      if (day == today) return WeekDayState.today;
      return day.isBefore(today) ? WeekDayState.missed : WeekDayState.upcoming;
    });
  }
}

class _BodyRankHero extends StatelessWidget {
  const _BodyRankHero({
    required this.summary,
    required this.goal,
    required this.onTap,
  });
  final BodyProgressSummary? summary;
  final TrainingGoal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rank = summary?.rank.label ?? 'Foundation';
    final progress = ((summary?.rankProgress ?? 0) * 100).round();
    final momentum = summary?.momentum.label ?? 'Learning baseline';
    final trained = summary?.trainedMuscles ?? 0;
    return Material(
      color: theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BODY RANK',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer.withValues(
                    alpha: 0.72,
                  ),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$rank · ${goal.label}',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: summary?.rankProgress ?? 0,
                backgroundColor: theme.colorScheme.onPrimaryContainer
                    .withValues(alpha: 0.14),
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(height: 10),
              Text(
                '$progress% to next rank · $momentum · $trained muscles trained',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer.withValues(
                    alpha: 0.82,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(AppIcons.chevronRight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextFocusCard extends StatelessWidget {
  const _NextFocusCard({required this.summary});
  final BodyProgressSummary? summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = summary?.nextFocusLabel ?? 'Build your first baseline';
    final reason = summary == null
        ? 'This appears after you log enough comparable sets.'
        : 'Chosen from muscles with the least history, declining momentum, learning baseline, or lowest personal rank score.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
            child: const Icon(AppIcons.target),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next best focus', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.82,
                    ),
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

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.date, required this.active, this.onTap});

  final DateTime date;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: active
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    active ? AppIcons.play : AppIcons.dumbbell,
                    color: active
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.yMMMMEEEEd().format(date),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        active
                            ? 'In progress · tap to resume'
                            : DateFormat.jm().format(date),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: active
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
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

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            AppIcons.dumbbell,
            size: 30,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text('No workouts yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Your completed sessions will show up here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(AppIcons.play),
            label: const Text('Start your first workout'),
          ),
        ],
      ),
    );
  }
}

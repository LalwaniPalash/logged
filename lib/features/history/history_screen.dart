import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../session/active_session_screen.dart';
import '../session/start_workout_flow.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days =
        ref.watch(trainingDaysProvider).asData?.value ?? const <DateTime>[];
    final now = DateTime.now();
    final thisMonth = days
        .where((d) => d.year == now.year && d.month == now.month)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: StreamBuilder<List<Session>>(
        stream: ref.watch(sessionRepositoryProvider).watchRecent(limit: 500),
        builder: (context, snapshot) {
          final sessions = snapshot.data ?? const <Session>[];
          if (sessions.isEmpty) {
            return EmptyState(
              icon: AppIcons.history,
              title: 'No history yet',
              message:
                  'Finish a workout and it will appear here, grouped by month.',
              action: FilledButton.icon(
                onPressed: () => showStartWorkoutFlow(context, ref),
                icon: const Icon(AppIcons.play),
                label: const Text('Start a workout'),
              ),
            );
          }

          final grouped = _groupByMonth(sessions);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _ArchiveSummary(total: days.length, thisMonth: thisMonth),
              const SizedBox(height: 22),
              const SectionHeader('Workout archive'),
              for (final entry in grouped.entries) ...[
                SectionHeader(entry.key),
                for (final session in entry.value)
                  _HistoryTile(session: session),
                const SizedBox(height: 18),
              ],
            ],
          );
        },
      ),
    );
  }

  Map<String, List<Session>> _groupByMonth(List<Session> sessions) {
    final map = <String, List<Session>>{};
    for (final session in sessions) {
      final key = DateFormat.yMMMM().format(session.startedAt);
      map.putIfAbsent(key, () => []).add(session);
    }
    return map;
  }
}

class _ArchiveSummary extends StatelessWidget {
  const _ArchiveSummary({required this.total, required this.thisMonth});
  final int total;
  final int thisMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            child: const Icon(AppIcons.history),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '$total workouts logged · $thisMonth this month',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = session.endedAt == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ActiveSessionScreen(sessionId: session.id),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat.d().format(session.startedAt),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        DateFormat.E().format(session.startedAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active ? 'Active session' : 'Workout',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        DateFormat.jm().format(session.startedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  active ? AppIcons.play : AppIcons.chevronRight,
                  color: active
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

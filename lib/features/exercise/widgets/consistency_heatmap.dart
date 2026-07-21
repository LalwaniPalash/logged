import 'package:flutter/material.dart';

import '../../../core/domain/streak.dart';
import '../../../core/theme/app_theme.dart';

/// A GitHub-style calendar of the last [weeks] Monday-based weeks. Trained days
/// glow terracotta, rest days (scheduled or logged) show sage, missed training
/// days read faint, and future days stay empty.
class ConsistencyHeatmap extends StatelessWidget {
  const ConsistencyHeatmap({
    super.key,
    required this.trainingDays,
    required this.loggedRestDays,
    required this.restWeekdays,
    this.weeks = 16,
    this.today,
  });

  final List<DateTime> trainingDays;
  final List<DateTime> loggedRestDays;
  final Set<int> restWeekdays;
  final int weeks;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final now = dateOnly(today ?? DateTime.now());
    final trained = trainingDays.map(dateOnly).toSet();
    final rested = loggedRestDays.map(dateOnly).toSet();
    final thisWeekStart = startOfWeek(now);

    Color cellColor(DateTime day) {
      if (day.isAfter(now)) return theme.colorScheme.surfaceContainerHigh;
      if (trained.contains(day)) return theme.colorScheme.primary;
      if (restWeekdays.contains(day.weekday) || rested.contains(day)) {
        return colors.success.withValues(alpha: 0.55);
      }
      return theme.colorScheme.surfaceContainerHighest;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 4.0;
        final cell = ((constraints.maxWidth - (weeks - 1) * gap) / weeks).clamp(
          8.0,
          22.0,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: gap,
              children: [
                for (var w = weeks - 1; w >= 0; w--)
                  Column(
                    children: [
                      for (var d = 0; d < 7; d++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: gap),
                          child: Builder(
                            builder: (context) {
                              final day = DateTime(
                                thisWeekStart.year,
                                thisWeekStart.month,
                                thisWeekStart.day - w * 7 + d,
                              );
                              return Container(
                                width: cell,
                                height: cell,
                                decoration: BoxDecoration(
                                  color: cellColor(day),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _Key(color: theme.colorScheme.primary, label: 'Trained'),
                const SizedBox(width: 14),
                _Key(
                  color: colors.success.withValues(alpha: 0.55),
                  label: 'Rest',
                ),
                const SizedBox(width: 14),
                _Key(
                  color: theme.colorScheme.surfaceContainerHighest,
                  label: 'Missed',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

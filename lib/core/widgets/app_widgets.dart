import 'package:flutter/material.dart';

import '../app_icons.dart';
import '../theme/app_theme.dart';

/// A small uppercase overline label + optional trailing action, used to open
/// every section consistently.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.4,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// A compact card showing one metric: a large value over a quiet label, with an
/// optional accent color for the value.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.color,
    this.icon,
  });

  final String label;
  final String value;
  final String? unit;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: accent),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit!,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The streak stat as a warm gradient card (flame + count) that pairs with a
/// neutral [StatTile]. Keeps the streak's identity while balancing a row.
class StreakCard extends StatelessWidget {
  const StreakCard({
    super.key,
    required this.streak,
    required this.trainedToday,
    this.isRestToday = false,
  });

  final int streak;
  final bool trainedToday;
  final bool isRestToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final active = streak > 0;
    final caption = !active
        ? 'Start a streak'
        : isRestToday
        ? "Rest — you're safe"
        : trainedToday
        ? 'Locked in today'
        : 'Keep it alive';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        gradient: active
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.streak, theme.colorScheme.primary],
              )
            : null,
        color: active ? null : theme.colorScheme.surfaceContainerLow,
        border: active
            ? null
            : Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: active
            ? [
                BoxShadow(
                  color: colors.streak.withValues(alpha: 0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            active ? AppIcons.fire : AppIcons.bolt,
            size: 20,
            color: active
                ? colors.onStreak
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$streak',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: active ? colors.onStreak : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  streak == 1 ? 'day' : 'days',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: active
                        ? colors.onStreak.withValues(alpha: 0.9)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: active
                  ? colors.onStreak.withValues(alpha: 0.92)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-day status within the current week, driving the [WeeklyProgressStrip].
enum WeekDayState { trained, rest, today, missed, upcoming }

/// A horizontal week ribbon: the M–S weekday letters over status dots, with a
/// "done / goal workouts" tally. Reads the whole week at a glance and replaces
/// the old progress ring.
class WeeklyProgressStrip extends StatelessWidget {
  const WeeklyProgressStrip({
    super.key,
    required this.states,
    required this.done,
    required this.goal,
  });

  /// Exactly 7 entries, Monday → Sunday.
  final List<WeekDayState> states;
  final int done;
  final int goal;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final met = goal > 0 && done >= goal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'WEEKLY PROGRESS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$done',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: met
                            ? theme.extension<AppColors>()!.success
                            : theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: ' / $goal workouts',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                _DayDot(letter: _letters[i], state: states[i]),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.letter, required this.state});

  final String letter;
  final WeekDayState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isToday = state == WeekDayState.today;

    late final Widget dot;
    switch (state) {
      case WeekDayState.trained:
        dot = _circle(
          fill: scheme.primary,
          child: Icon(AppIcons.check, size: 18, color: scheme.onPrimary),
        );
      case WeekDayState.rest:
        dot = _circle(
          fill: scheme.surfaceContainerHighest,
          child: Icon(AppIcons.rest, size: 15, color: scheme.onSurfaceVariant),
        );
      case WeekDayState.today:
        dot = _circle(
          border: scheme.primary,
          borderWidth: 2,
          child: Container(
            height: 7,
            width: 7,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        );
      case WeekDayState.missed:
        dot = _circle(border: scheme.outline);
      case WeekDayState.upcoming:
        dot = _circle(border: scheme.outlineVariant);
    }

    return Column(
      children: [
        Text(
          letter,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isToday ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        dot,
      ],
    );
  }

  Widget _circle({
    Color? fill,
    Color? border,
    double borderWidth = 1.5,
    Widget? child,
  }) {
    return Container(
      height: 34,
      width: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: border == null
            ? null
            : Border.all(color: border, width: borderWidth),
      ),
      child: child,
    );
  }
}

/// Centered, friendly empty state with an icon, title, message and optional CTA.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 34,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// A full-width tappable row card: leading box, title/subtitle column,
/// optional trailing widget. The shape shared by list tiles across the app
/// (recent sessions, history, templates) — use this instead of hand-rolling
/// the Material/InkWell/Container skeleton again.
class AppListCard extends StatelessWidget {
  const AppListCard({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, ?subtitle],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// A category chip with a consistent icon, used across exercise lists.
IconData iconForCategoryName(String category) =>
    AppIcons.forCategoryName(category);

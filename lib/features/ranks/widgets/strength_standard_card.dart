import 'package:flutter/material.dart';

import '../../../core/app_icons.dart';
import '../../../core/domain/strength_standards.dart';
import '../../../core/theme/app_theme.dart';

/// One lift's current standard: icon, name, ratio, level pill, and — unless
/// already at Elite — a "next milestone" row. Shared by the standards list
/// (tappable, with a chevron) and the per-lift detail screen header
/// (untappable, no chevron).
class StrengthStandardCard extends StatelessWidget {
  const StrengthStandardCard({
    super.key,
    required this.lift,
    required this.result,
    required this.bodyweightKg,
    this.icon,
    this.accentColor,
    this.onTap,
  });

  final String lift;
  final StrengthStandardResult result;
  final double bodyweightKg;
  final IconData? icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.colorScheme.primary;
    final nextRatio = result.nextThreshold == null
        ? null
        : result.nextThreshold! / bodyweightKg;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: accent.withValues(alpha: 0.15),
                    foregroundColor: accent,
                    child: Icon(icon ?? AppIcons.strength, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lift,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${result.ratio.toStringAsFixed(2)}x',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'of your bodyweight',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          result.level.label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (onTap != null) ...[
                        const SizedBox(height: 10),
                        Icon(
                          AppIcons.chevronRight,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (nextRatio != null) ...[
                const SizedBox(height: 14),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      AppIcons.progress,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next milestone',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${nextRatio.toStringAsFixed(2)}x bodyweight',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Next at ${result.nextThreshold!.round()} kg',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';

/// Heaviest/estimated-max/volume stat tiles plus a load trend chart for one
/// exercise's logged history. Shared by the Progress screen's exercise
/// deep-dive and the strength-standards per-lift detail screen.
class ExerciseProgressDetail extends StatelessWidget {
  const ExerciseProgressDetail({super.key, required this.values});
  final List<({double kg, int reps})> values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final bestWeight = values.map((e) => e.kg).reduce((a, b) => a > b ? a : b);
    final best1rm = values
        .map((e) => e.kg * (1 + e.reps / 30))
        .reduce((a, b) => a > b ? a : b);
    final volume = values.fold(0.0, (sum, e) => sum + e.kg * e.reps);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Heaviest',
                value: bestWeight.toStringAsFixed(1),
                unit: 'kg',
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Estimated max',
                value: best1rm.toStringAsFixed(1),
                unit: 'kg',
                color: colors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StatTile(
          label: 'Total volume (all time)',
          value: volume.toStringAsFixed(0),
          unit: 'kg',
          color: theme.colorScheme.tertiary,
        ),
        const SizedBox(height: 8),
        Text(
          'Estimated max uses your logged weight and reps to estimate a one-rep strength marker. It is a trend signal, not a required test.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: theme.colorScheme.outlineVariant,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        curveSmoothness: 0.28,
                        color: theme.colorScheme.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                        ),
                        spots: [
                          for (var i = 0; i < values.length; i++)
                            FlSpot(i.toDouble(), values[i].kg),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

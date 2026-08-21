import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/app_icons.dart';
import '../../../core/domain/session_energy.dart';
import '../../../core/domain/workout_metrics.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/session_repository.dart';

class ActiveSessionStatsCard extends StatefulWidget {
  const ActiveSessionStatsCard({
    super.key,
    required this.session,
    required this.details,
    required this.bodyweightKg,
    this.now = DateTime.now,
  });

  final Session? session;
  final List<SessionExerciseDetails> details;
  final double bodyweightKg;

  /// The clock the live duration reads. Injectable because the duration is
  /// deliberately derived from wall-clock time rather than accumulated per
  /// tick — a test cannot advance the real clock, and the drift this guards
  /// against is only visible when the clock and the tick disagree.
  final DateTime Function() now;

  @override
  State<ActiveSessionStatsCard> createState() => _ActiveSessionStatsCardState();
}

class _ActiveSessionStatsCardState extends State<ActiveSessionStatsCard> {
  Timer? _ticker;
  Duration _liveElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _syncElapsed();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant ActiveSessionStatsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncElapsed();
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    _ticker?.cancel();
    if (widget.session?.endedAt != null || widget.session == null) {
      return;
    }
    // Recompute from the wall clock rather than accumulating +1s per tick.
    // Timers are throttled or suspended while the app is backgrounded, so an
    // accumulating counter loses exactly the time the user spent away and the
    // workout duration silently drifts low for the rest of the session.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(_syncElapsed);
    });
  }

  void _syncElapsed() {
    final session = widget.session;
    if (session == null) {
      _liveElapsed = Duration.zero;
      return;
    }
    _liveElapsed = (session.endedAt ?? widget.now()).difference(
      session.startedAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    if (session == null) return const SizedBox.shrink();

    final totals = computeSessionTotals([
      for (final detail in widget.details) (sets: detail.sets),
    ]);
    final elapsed = session.endedAt != null
        ? session.endedAt!.difference(session.startedAt)
        : _liveElapsed;
    final calories = estimateSessionKcal(
      sets: [
        for (final detail in widget.details)
          for (final set in detail.sets)
            SessionEnergySet(
              weightValue: set.weightValue,
              unit: set.unit,
              weightEntry: set.weightEntry,
              sideCount: set.sideCount,
              reps: set.reps,
              durationSec: set.durationSec,
              loadingMode: set.loadingMode,
              isWarmup: set.isWarmup,
              category: detail.exercise.category,
              muscleGroup: detail.exercise.muscleGroup,
              bodyweightFactor: detail.exercise.bodyweightFactor,
            ),
      ],
      elapsed: elapsed,
      bodyweightKg: widget.bodyweightKg,
    );
    final items = [
      _StatTileData(
        icon: AppIcons.clockBold,
        label: 'Duration',
        value: _formatDuration(elapsed),
      ),
      _StatTileData(
        icon: AppIcons.dumbbellBold,
        label: 'Exercises',
        value: '${totals.exerciseCount}',
      ),
      _StatTileData(
        icon: AppIcons.volumeBold,
        label: 'Total Volume',
        value: NumberFormat.decimalPattern().format(
          totals.totalVolumeKg.round(),
        ),
        unit: 'kg',
      ),
      _StatTileData(
        icon: AppIcons.fire,
        label: 'Calories',
        value: '~${(calories / 10).round() * 10}',
        unit: 'kcal',
      ),
    ];
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final useGrid = MediaQuery.sizeOf(context).width < 380 || textScale > 1.3;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: useGrid
            ? Column(
                children: [
                  _StatsRow(items: items.take(2).toList()),
                  const SizedBox(height: 12),
                  _StatsRow(items: items.skip(2).toList()),
                ],
              )
            : IntrinsicHeight(child: _StatsRow(items: items)),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.items});

  final List<_StatTileData> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < items.length; index++) ...[
            Expanded(child: _StatTile(item: items[index])),
            if (index != items.length - 1)
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.item});

  final _StatTileData item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(item.icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(height: 10),
          // Text.rich, never RichText: RichText defaults to
          // TextScaler.noScaling, so the numbers would stay fixed while the
          // labels around them grew with the system text size.
          //
          // FittedBox + maxLines 1: on a 393dp phone the 4-across row gives
          // each tile ~90px, and "01:27:42" wrapped mid-value to "01:27:4 / 2".
          // Shrinking to fit is right where wrapping a number never is.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              maxLines: 1,
              textAlign: TextAlign.center,
              TextSpan(
                style: valueStyle,
                children: [
                  TextSpan(text: item.value),
                  if (item.unit != null)
                    TextSpan(
                      text: ' ${item.unit}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTileData {
  const _StatTileData({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;
}

String _formatDuration(Duration elapsed) {
  final hours = elapsed.inHours.toString().padLeft(2, '0');
  final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

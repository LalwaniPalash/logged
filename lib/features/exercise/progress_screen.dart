import 'package:drift/drift.dart' show Variable;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/domain/enums.dart';
import '../../core/domain/deload.dart';
import '../../core/domain/live_muscle_state.dart';
import '../../core/domain/muscle.dart';
import '../../core/domain/muscle_progress.dart';
import '../../core/domain/progress_analytics.dart';
import '../../core/domain/workout_metrics.dart';
import '../../core/domain/volume_landmarks.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/exercise_picker.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../../data/repositories/analytics_repository.dart';
import '../session/start_workout_flow.dart';
import '../templates/template_editor_screen.dart';
import 'widgets/muscle_anatomy_view.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});
  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  Exercise? _exercise;

  Future<List<({double kg, int reps})>> _loadExercise(int id) async {
    final rows = await ref
        .read(databaseProvider)
        .customSelect(
          'SELECT se.weight_value, se.unit, se.reps '
          'FROM set_entries se '
          'JOIN session_exercises sx ON sx.id = se.session_exercise_id '
          'JOIN sessions s ON s.id = sx.session_id '
          'WHERE sx.exercise_id = ? AND s.ended_at IS NOT NULL '
          'ORDER BY s.started_at',
          variables: [Variable.withInt(id)],
        )
        .get();
    return [
      for (final row in rows)
        if (row.data['weight_value'] != null && row.data['unit'] != null)
          (
            kg: weightKg(
              (row.data['weight_value'] as num).toDouble(),
              WeightUnit.values.byName(row.data['unit'] as String),
            ),
            reps: (row.data['reps'] as int?) ?? 0,
          ),
    ].where((r) => r.kg > 0).toList();
  }

  Future<void> _pickExercise() async {
    final exercises = await ref.read(exerciseRepositoryProvider).all();
    if (!mounted) return;
    final chosen = await showExercisePicker(context, exercises);
    if (chosen != null) setState(() => _exercise = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final sets =
        ref.watch(completedSetsProvider).asData?.value ??
        const <WorkoutSetRecord>[];
    final liveMuscles = ref.watch(liveMuscleStateProvider);
    final landmarks =
        ref.watch(effectiveVolumeLandmarksProvider).asData?.value ??
        defaultLandmarks;
    final bodySummary = ref.watch(bodyProgressSummaryProvider).asData?.value;
    final deloadSignal = ref.watch(deloadSignalProvider).asData?.value;

    final weekly = weeklyStats(sets, weeks: 8);
    final prs = recentPrs(sets, limit: 6);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          if (deloadSignal != null) ...[
            _DeloadCard(
              signal: deloadSignal,
              onDismiss: _dismissDeload,
              onGenerate: _generateDeload,
            ),
            const SizedBox(height: 18),
          ],
          _BodyDevelopmentCard(summary: bodySummary),
          const SizedBox(height: 26),
          const SectionHeader('Muscle sculpture'),
          _Card(
            child: liveMuscles.when(
              data: (state) => MuscleAnatomyView(
                state: state,
                landmarks: landmarks,
                onOpenMuscle: (muscle) => _openMuscleProgress(muscle),
                onOpenAllMuscles: _openAllMuscleProgress,
                emptyAction: FilledButton.icon(
                  onPressed: () => showStartWorkoutFlow(context, ref),
                  icon: const Icon(AppIcons.play),
                  label: const Text('Log a set'),
                ),
              ),
              loading: () => const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        AppIcons.warning,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'The live muscle stream could not be loaded. Your workout data is unchanged.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  MuscleAnatomyView(
                    state: LiveMuscleState(const {}),
                    enable3d: false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (liveMuscles.asData case final state?)
            _Card(
              child: _WeeklyMuscleBalance(
                state: state.value,
                landmarks: landmarks,
              ),
            ),
          const SizedBox(height: 26),
          const SectionHeader('Rank breakdown'),
          _Card(child: _RankBreakdown(summary: bodySummary)),
          const SizedBox(height: 26),
          const SectionHeader('Weekly volume'),
          _Card(child: _WeeklyVolumeChart(stats: weekly)),
          const SizedBox(height: 26),
          const SectionHeader('Recent PRs'),
          if (prs.isEmpty)
            _Card(
              child: Row(
                children: [
                  Icon(
                    AppIcons.trophy,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Log weighted sets to start setting records.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            _Card(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < prs.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _PrRow(pr: prs[i]),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 26),
          const SectionHeader('Exercise deep-dive'),
          _ExercisePickerButton(exercise: _exercise, onTap: _pickExercise),
          const SizedBox(height: 16),
          if (_exercise != null)
            FutureBuilder<List<({double kg, int reps})>>(
              future: _loadExercise(_exercise!.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final values = snapshot.data ?? const [];
                if (values.isEmpty) {
                  return _Card(
                    child: Text(
                      'No weighted sets logged for ${_exercise!.name} yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return _ExerciseDetail(values: values);
              },
            ),
        ],
      ),
    );
  }

  void _openMuscleProgress(MuscleId muscle) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MuscleProgressScreen(initialMuscle: muscle),
      ),
    );
  }

  void _openAllMuscleProgress() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AllMuscleProgressScreen()));
  }

  Future<void> _dismissDeload() async {
    await ref
        .read(settingsRepositoryProvider)
        .dismissDeloadForWeek(currentWeekKey());
    ref.invalidate(deloadSignalProvider);
  }

  Future<void> _generateDeload() async {
    try {
      final template = await ref
          .read(templateRepositoryProvider)
          .createDeloadWeek();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TemplateEditorScreen(template: template),
        ),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _DeloadCard extends StatelessWidget {
  const _DeloadCard({
    required this.signal,
    required this.onDismiss,
    required this.onGenerate,
  });

  final DeloadSignal signal;
  final VoidCallback onDismiss;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.rest, color: theme.colorScheme.tertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Consider a deload',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  tooltip: 'Dismiss for this week',
                  icon: const Icon(AppIcons.close),
                ),
              ],
            ),
            for (final reason in signal.reasons)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 5),
                child: Text('• $reason'),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(AppIcons.add),
              label: const Text('Generate deload week'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ProgressRange {
  fourWeeks(4, '4 wk'),
  twelveWeeks(12, '12 wk'),
  twentyFourWeeks(24, '24 wk');

  const _ProgressRange(this.weeks, this.label);
  final int weeks;
  final String label;
}

class MuscleProgressScreen extends ConsumerStatefulWidget {
  const MuscleProgressScreen({super.key, required this.initialMuscle});
  final MuscleId initialMuscle;

  @override
  ConsumerState<MuscleProgressScreen> createState() =>
      _MuscleProgressScreenState();
}

class _MuscleProgressScreenState extends ConsumerState<MuscleProgressScreen> {
  _ProgressRange _range = _ProgressRange.twelveWeeks;

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(muscleProgressProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.initialMuscle.label)),
      body: progressAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ProgressError(error: error),
        data: (progressByMuscle) {
          final progress = progressByMuscle[widget.initialMuscle]!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              _MuscleRankCard(progress: progress),
              const SizedBox(height: 18),
              _RangeSelector(
                selected: _range,
                onChanged: (range) => setState(() => _range = range),
              ),
              const SizedBox(height: 12),
              _Card(
                child: _MuscleProgressChart(
                  progress: progress,
                  weeks: _range.weeks,
                ),
              ),
              const SizedBox(height: 18),
              _Card(
                child: _EffectiveSetSummary(
                  progress: progress,
                  weeks: _range.weeks,
                ),
              ),
              const SizedBox(height: 18),
              _Card(child: _MilestoneSummary(progress: progress)),
              const SizedBox(height: 18),
              const SectionHeader('Exercises'),
              if (progress.exercises.isEmpty)
                _Card(
                  child: Text(
                    progress.lastTrained == null
                        ? 'No qualifying history for this muscle yet.'
                        : 'Learning baseline. Log more comparable sets to show an exercise trend.',
                  ),
                )
              else
                _Card(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (var i = 0; i < progress.exercises.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _MuscleExerciseRow(exercise: progress.exercises[i]),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 18),
            ],
          );
        },
      ),
    );
  }
}

enum _MuscleSort { anatomical, rank, improvement, attention, lastTrained }

class AllMuscleProgressScreen extends ConsumerStatefulWidget {
  const AllMuscleProgressScreen({super.key});

  @override
  ConsumerState<AllMuscleProgressScreen> createState() =>
      _AllMuscleProgressScreenState();
}

class _AllMuscleProgressScreenState
    extends ConsumerState<AllMuscleProgressScreen> {
  _MuscleSort _sort = _MuscleSort.anatomical;

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(muscleProgressProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('All muscle progress')),
      body: progressAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ProgressError(error: error),
        data: (progressByMuscle) {
          final rows = progressByMuscle.values.toList();
          _sortRows(rows);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<_MuscleSort>(
                  segments: const [
                    ButtonSegment(
                      value: _MuscleSort.anatomical,
                      label: Text('Anatomy'),
                    ),
                    ButtonSegment(value: _MuscleSort.rank, label: Text('Rank')),
                    ButtonSegment(
                      value: _MuscleSort.improvement,
                      label: Text('Improve'),
                    ),
                    ButtonSegment(
                      value: _MuscleSort.attention,
                      label: Text('Attention'),
                    ),
                    ButtonSegment(
                      value: _MuscleSort.lastTrained,
                      label: Text('Recent'),
                    ),
                  ],
                  selected: {_sort},
                  onSelectionChanged: (value) =>
                      setState(() => _sort = value.single),
                ),
              ),
              const SizedBox(height: 12),
              for (final progress in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AllMuscleRow(progress: progress),
                ),
            ],
          );
        },
      ),
    );
  }

  void _sortRows(List<MuscleProgress> rows) {
    switch (_sort) {
      case _MuscleSort.anatomical:
        rows.sort(
          (a, b) => MuscleId.values
              .indexOf(a.muscle)
              .compareTo(MuscleId.values.indexOf(b.muscle)),
        );
      case _MuscleSort.rank:
        rows.sort((a, b) => b.rank.index.compareTo(a.rank.index));
      case _MuscleSort.improvement:
        rows.sort((a, b) => (b.latestIndex ?? 0).compareTo(a.latestIndex ?? 0));
      case _MuscleSort.attention:
        rows.sort((a, b) {
          final aDate = a.lastTrained ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.lastTrained ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aDate.compareTo(bDate);
        });
      case _MuscleSort.lastTrained:
        rows.sort((a, b) {
          final aDate = a.lastTrained ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.lastTrained ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
    }
  }
}

class _MuscleRankCard extends StatelessWidget {
  const _MuscleRankCard({required this.progress});
  final MuscleProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.trophy, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  progress.rank.label,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusPill(label: progress.momentum.label),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(value: progress.rankProgress),
          const SizedBox(height: 10),
          Text(
            '${(progress.rankProgress * 100).round()}% toward next rank · '
            '${progress.primarySets} primary / ${progress.secondarySets} secondary sets',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            progress.lastTrained == null
                ? 'Last trained: never'
                : 'Last trained: ${DateFormat.yMMMd().format(progress.lastTrained!)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onChanged});
  final _ProgressRange selected;
  final ValueChanged<_ProgressRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<_ProgressRange>(
        segments: [
          for (final range in _ProgressRange.values)
            ButtonSegment(value: range, label: Text(range.label)),
        ],
        selected: {selected},
        onSelectionChanged: (value) => onChanged(value.single),
      ),
    );
  }
}

class _MuscleProgressChart extends StatelessWidget {
  const _MuscleProgressChart({required this.progress, required this.weeks});
  final MuscleProgress progress;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cutoff = DateTime.now().subtract(Duration(days: weeks * 7));
    final points = progress.points
        .where((point) => !point.date.isBefore(cutoff))
        .toList();
    final displayedPoints = points.length >= 2 ? points : progress.points;
    if (displayedPoints.length < 2) {
      return Text(
        'Learning baseline. Two or more comparable observations are needed before a trend is shown.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final minY =
        displayedPoints
            .map((point) => point.index)
            .reduce((a, b) => a < b ? a : b) -
        8;
    final maxY =
        displayedPoints
            .map((point) => point.index)
            .reduce((a, b) => a > b ? a : b) +
        8;
    return Semantics(
      label:
          '${progress.muscle.label} normalized $weeks week progress chart. Latest index ${displayedPoints.last.index.toStringAsFixed(0)}.',
      child: SizedBox(
        height: 210,
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: theme.colorScheme.outlineVariant,
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                isCurved: true,
                color: theme.colorScheme.primary,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                ),
                spots: [
                  for (var i = 0; i < displayedPoints.length; i++)
                    FlSpot(i.toDouble(), displayedPoints[i].index),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EffectiveSetSummary extends StatelessWidget {
  const _EffectiveSetSummary({required this.progress, required this.weeks});
  final MuscleProgress progress;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cutoff = DateTime.now().subtract(Duration(days: weeks * 7));
    final effectiveSets = progress.effectiveSetHistory.values.fold(
      0.0,
      (sum, value) => sum + value,
    );
    final rangeEffectiveSets = progress.effectiveSetHistory.entries
        .where((entry) => !entry.key.isBefore(cutoff))
        .fold(0.0, (sum, entry) => sum + entry.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Effective-set history', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          '${rangeEffectiveSets.toStringAsFixed(1)} effective sets in this range · '
          '${effectiveSets.toStringAsFixed(1)} all time. '
          'This is workload, not the progressive-overload score.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MilestoneSummary extends StatelessWidget {
  const _MilestoneSummary({required this.progress});
  final MuscleProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bestExercise = progress.exercises.isEmpty
        ? null
        : progress.exercises.reduce(
            (a, b) => a.bestIndex >= b.bestIndex ? a : b,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Milestones', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (bestExercise == null)
          Text(
            'No personal milestones yet. Build a baseline with comparable sets.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          _MilestoneLine(
            label: 'Best exercise trend',
            value:
                '${bestExercise.exerciseName} · ${bestExercise.bestIndex.toStringAsFixed(0)} index',
          ),
          const SizedBox(height: 6),
          _MilestoneLine(
            label: 'Latest muscle index',
            value: progress.latestIndex == null
                ? 'Learning baseline'
                : progress.latestIndex!.toStringAsFixed(0),
          ),
          const SizedBox(height: 6),
          _MilestoneLine(
            label: 'Best muscle index',
            value: progress.bestIndex == null
                ? 'Learning baseline'
                : progress.bestIndex!.toStringAsFixed(0),
          ),
        ],
      ],
    );
  }
}

class _MilestoneLine extends StatelessWidget {
  const _MilestoneLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _MuscleExerciseRow extends StatelessWidget {
  const _MuscleExerciseRow({required this.exercise});
  final MuscleExerciseProgress exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.exerciseName, style: theme.textTheme.titleMedium),
                Text(
                  exercise.lowerPrecision
                      ? 'Lower precision: missing bodyweight for some sets'
                      : 'Best raw signal ${exercise.bestRawValue.toStringAsFixed(1)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                exercise.latestIndex.toStringAsFixed(0),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'index',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AllMuscleRow extends StatelessWidget {
  const _AllMuscleRow({required this.progress});
  final MuscleProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastTrained = progress.lastTrained == null
        ? 'Never trained'
        : DateFormat.yMMMd().format(progress.lastTrained!);
    return Semantics(
      button: true,
      label:
          '${progress.muscle.label}. Rank ${progress.rank.label}. Momentum ${progress.momentum.label}. '
          '${(progress.rankProgress * 100).round()} percent toward next rank. Last trained $lastTrained.',
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  MuscleProgressScreen(initialMuscle: progress.muscle),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        progress.muscle.label,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${progress.rank.label} · ${progress.momentum.label} · '
                        '${progress.lastTrained == null ? 'Never trained' : DateFormat.MMMd().format(progress.lastTrained!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: progress.rankProgress),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 56,
                  height: 32,
                  child: _Sparkline(points: progress.points),
                ),
                Icon(
                  AppIcons.chevronRight,
                  size: 16,
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

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.points});
  final List<MuscleTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return Center(
        child: Text('—', style: Theme.of(context).textTheme.titleMedium),
      );
    }
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].index),
            ],
            isCurved: true,
            dotData: const FlDotData(show: false),
            barWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _ProgressError extends StatelessWidget {
  const _ProgressError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: AppIcons.warning,
    title: 'Progress unavailable',
    message:
        'Muscle analytics could not be loaded. Your workout data is unchanged.',
  );
}

class _BodyDevelopmentCard extends StatelessWidget {
  const _BodyDevelopmentCard({required this.summary});
  final BodyProgressSummary? summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rank = summary?.rank.label ?? 'Foundation';
    final progress = ((summary?.rankProgress ?? 0) * 100).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.trophy, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text('Body rank', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            rank,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: summary?.rankProgress ?? 0),
          const SizedBox(height: 10),
          Text(
            '$progress% to next rank · ${summary?.momentum.label ?? 'Learning baseline'}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBreakdown extends StatelessWidget {
  const _RankBreakdown({required this.summary});
  final BodyProgressSummary? summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (summary == null) {
      return Text(
        'Build a baseline to see rank breakdowns.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BreakdownLine(
          label: 'Next focus',
          value: summary!.nextFocusLabel,
          icon: AppIcons.target,
        ),
        const Divider(height: 22),
        _BreakdownLine(
          label: 'Improving',
          value: summary!.improvingMuscles == 0
              ? 'Learning baseline'
              : '${summary!.improvingMuscles} muscles',
          icon: AppIcons.progress,
        ),
        const Divider(height: 22),
        _BreakdownLine(
          label: 'Strongest',
          value: summary!.strongest.isEmpty
              ? 'No ranked muscles yet'
              : summary!.strongest
                    .take(2)
                    .map((item) => item.muscle.label)
                    .join(', '),
          icon: AppIcons.trophy,
        ),
      ],
    );
  }
}

class _BreakdownLine extends StatelessWidget {
  const _BreakdownLine({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeeklyMuscleBalance extends StatelessWidget {
  const _WeeklyMuscleBalance({required this.state, required this.landmarks});

  final LiveMuscleState state;
  final Map<MuscleId, VolumeLandmarks> landmarks;

  @override
  Widget build(BuildContext context) {
    final below = MuscleId.values
        .where(
          (muscle) =>
              (state[muscle]?.effectiveSets ?? 0) < landmarks[muscle]!.mev,
        )
        .toList();
    final above = MuscleId.values
        .where(
          (muscle) =>
              (state[muscle]?.effectiveSets ?? 0) > landmarks[muscle]!.mrv,
        )
        .toList();
    final theme = Theme.of(context);

    Widget group(String title, List<MuscleId> muscles, Color color) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title · ${muscles.length}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          if (muscles.isEmpty)
            Text(
              'None',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final muscle in muscles)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(muscle.label),
                  ),
              ],
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Weekly muscle balance', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Compared with your current coaching landmarks.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        group('Below MEV', below, theme.colorScheme.primary),
        const SizedBox(height: 16),
        group('Above MRV', above, theme.colorScheme.error),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _WeeklyVolumeChart extends StatelessWidget {
  const _WeeklyVolumeChart({required this.stats});
  final List<WeekStat> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxVolume = stats.fold<double>(
      0,
      (m, s) => s.volumeKg > m ? s.volumeKg : m,
    );
    final totalSessions = stats.fold<int>(0, (m, s) => m + s.sessions);
    final totalVolume = stats.fold<double>(0, (m, s) => m + s.volumeKg);
    final current = stats.isEmpty ? null : stats.last;
    final previous = stats.length < 2 ? null : stats[stats.length - 2];
    final delta = current == null || previous == null
        ? 0.0
        : current.volumeKg - previous.volumeKg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (maxVolume <= 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No volume logged in the last 8 weeks.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: _VolumeMetric(
                  label: 'Current week',
                  value: _compactKg(current?.volumeKg ?? 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _VolumeMetric(
                  label: 'Vs last week',
                  value: delta == 0
                      ? '—'
                      : '${delta > 0 ? '+' : ''}${_compactKg(delta)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _VolumeWeekRow(
                  stat: stats[i],
                  maxVolume: maxVolume,
                  current: i == stats.length - 1,
                  label: _weekRangeLabel(stats[i].weekStart),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$totalSessions sessions · '
            '${_compactKg(totalVolume)} total across 8 weeks',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  String _compactKg(double value) {
    final abs = value.abs();
    final sign = value < 0 ? '-' : '';
    if (abs >= 1000) return '$sign${(abs / 1000).toStringAsFixed(1)}k kg';
    return '$sign${abs.toStringAsFixed(0)} kg';
  }

  String _weekRangeLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    final startLabel = DateFormat.Md().format(start);
    final endLabel = start.month == end.month
        ? DateFormat.d().format(end)
        : DateFormat.Md().format(end);
    return '$startLabel–$endLabel';
  }
}

class _VolumeMetric extends StatelessWidget {
  const _VolumeMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeWeekRow extends StatelessWidget {
  const _VolumeWeekRow({
    required this.stat,
    required this.maxVolume,
    required this.current,
    required this.label,
  });

  final WeekStat stat;
  final double maxVolume;
  final bool current;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = maxVolume <= 0
        ? 0.0
        : (stat.volumeKg / maxVolume).clamp(0.0, 1.0);
    final color = current
        ? theme.colorScheme.primary
        : Color.lerp(
            theme.colorScheme.tertiary.withValues(alpha: 0.48),
            theme.colorScheme.primary.withValues(alpha: 0.82),
            fraction,
          )!;
    return Semantics(
      label:
          '$label, ${stat.volumeKg.toStringAsFixed(0)} kilograms volume, ${stat.sessions} sessions',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: current
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.48)
              : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: current
                ? theme.colorScheme.primary.withValues(alpha: 0.42)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: current
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _compactKg(stat.volumeKg),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${stat.sessions} ${stat.sessions == 1 ? 'session' : 'sessions'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _compactKg(double value) {
    final abs = value.abs();
    final sign = value < 0 ? '-' : '';
    if (abs >= 1000) return '$sign${(abs / 1000).toStringAsFixed(1)}k kg';
    return '$sign${abs.toStringAsFixed(0)} kg';
  }
}

class _PrRow extends StatelessWidget {
  const _PrRow({required this.pr});
  final PrEvent pr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: colors.streakContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(AppIcons.trophy, size: 20, color: colors.streak),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pr.exerciseName,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_trim(pr.weightKg)} kg × ${pr.reps} · ${DateFormat.MMMd().format(pr.date)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                pr.oneRepMaxKg.toStringAsFixed(1),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.success,
                ),
              ),
              Text(
                'estimated max',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _trim(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

class _ExercisePickerButton extends StatelessWidget {
  const _ExercisePickerButton({required this.exercise, required this.onTap});
  final Exercise? exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(AppIcons.search, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  exercise?.name ?? 'Choose an exercise',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: exercise == null
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(
                AppIcons.chevronDown,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseDetail extends StatelessWidget {
  const _ExerciseDetail({required this.values});
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
        _Card(
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
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
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
      ],
    );
  }
}

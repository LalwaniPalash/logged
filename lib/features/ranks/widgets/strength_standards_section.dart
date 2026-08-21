import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_icons.dart';
import '../../../core/domain/muscle.dart';
import '../../../core/domain/muscle_map.dart';
import '../../../core/domain/region_visuals.dart';
import '../../../core/domain/strength_standards.dart';
import '../../../core/domain/workout_metrics.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/analytics_repository.dart';
import '../strength_standard_detail_screen.dart';
import 'strength_standard_card.dart';

/// Header + search + per-lift cards + methodology tip for the "Strength
/// standards" tab of the Ranks screen. Holds its own search-query state, kept
/// out of `RanksScreen` so switching tabs doesn't need to know about it.
class StrengthStandardsSection extends ConsumerStatefulWidget {
  const StrengthStandardsSection({
    super.key,
    required this.sex,
    required this.onEnable,
  });

  final UserSex sex;
  final VoidCallback onEnable;

  @override
  ConsumerState<StrengthStandardsSection> createState() =>
      _StrengthStandardsSectionState();
}

class _StrengthStandardsSectionState
    extends ConsumerState<StrengthStandardsSection> {
  final _searchController = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StandardsHeader(),
        const SizedBox(height: 18),
        _buildBody(context),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final bodyweights =
        ref.watch(bodyweightEntriesProvider).asData?.value ?? const [];
    if (widget.sex == UserSex.unset || bodyweights.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const Text(
                'Add optional sex and bodyweight data to compare benchmark lifts with population standards.',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: widget.onEnable,
                child: const Text('Enable strength standards'),
              ),
            ],
          ),
        ),
      );
    }
    final latestWeight = bodyweights.first;
    final bodyweightKg = weightKg(latestWeight.value, latestWeight.unit);
    final sets =
        ref.watch(benchmarkSetsProvider).asData?.value ??
        const <BenchmarkSetRecord>[];
    final best = <String, double>{};
    for (final set in sets) {
      if (!countsForStandard(
        lift: set.exerciseName,
        mode: set.loadingMode,
        hasEnteredWeight: set.enteredWeightKg != null,
      )) {
        continue;
      }
      final estimate = set.resistedOneRepMaxKg(bodyweightKg);
      if (estimate > (best[set.exerciseName] ?? 0)) {
        best[set.exerciseName] = estimate;
      }
    }
    if (best.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'Log one of the benchmark lifts to see a population standard.',
          ),
        ),
      );
    }
    final exercises =
        ref.watch(allExercisesProvider).asData?.value ?? const <Exercise>[];
    final exerciseByName = {for (final e in exercises) e.name: e};

    final entries =
        best.entries
            .where(
              (e) =>
                  _query.isEmpty ||
                  e.key.toLowerCase().contains(_query.toLowerCase()),
            )
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'Search exercises',
            prefixIcon: const Icon(AppIcons.search),
          ),
        ),
        const SizedBox(height: 16),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Builder(
              builder: (context) {
                final result = standardFor(
                  lift: entry.key,
                  sex: widget.sex,
                  bodyweightKg: bodyweightKg,
                  estOneRepMaxKg: entry.value,
                )!;
                final exercise = exerciseByName[entry.key];
                final region = exercise == null
                    ? null
                    : decodeMuscleIdsOrEmpty(exercise.primaryMuscles)
                          .map(regionForMuscle)
                          .whereType<BodyRegion>()
                          .firstOrNull;
                final icon = region == null
                    ? AppIcons.strength
                    : iconForRegion(region);
                final accent = region == null
                    ? theme.colorScheme.primary
                    : colorForRegion(region, theme.colorScheme);
                return StrengthStandardCard(
                  lift: entry.key,
                  result: result,
                  bodyweightKg: bodyweightKg,
                  icon: icon,
                  accentColor: accent,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StrengthStandardDetailScreen(
                        lift: entry.key,
                        result: result,
                        bodyweightKg: bodyweightKg,
                        icon: icon,
                        accentColor: accent,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        DashedBorder(
          color: theme.colorScheme.primary.withValues(alpha: 0.5),
          radius: AppRadius.card,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(AppIcons.lightbulb, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Standards are based on lifters at your bodyweight and experience level.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StandardsHeader extends StatelessWidget {
  const _StandardsHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: colors.streakContainer,
          foregroundColor: colors.streak,
          child: const Icon(AppIcons.trophy, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Strength standards',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Compare your lifts to see how you rank compared to others at your bodyweight.',
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

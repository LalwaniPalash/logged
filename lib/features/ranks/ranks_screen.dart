import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/domain/enums.dart';
import '../../core/domain/muscle_progress.dart';
import '../../core/domain/muscle.dart';
import '../../core/domain/strength_standards.dart';
import '../../core/domain/training_goal.dart';
import '../../core/domain/workout_metrics.dart';
import '../../data/providers.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/settings_repository.dart';

enum _RanksSection { muscles, standards }

class RanksScreen extends ConsumerStatefulWidget {
  const RanksScreen({super.key});

  @override
  ConsumerState<RanksScreen> createState() => _RanksScreenState();
}

class _RanksScreenState extends ConsumerState<RanksScreen> {
  var _section = _RanksSection.muscles;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(muscleProgressProvider);
    final coaching =
        ref.watch(coachingPreferencesProvider).asData?.value ??
        const CoachingPreferences();
    return Scaffold(
      appBar: AppBar(title: const Text('Ranks')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
        children: [
          SegmentedButton<_RanksSection>(
            segments: const [
              ButtonSegment(
                value: _RanksSection.muscles,
                label: Text('Your muscles'),
                icon: Icon(AppIcons.body),
              ),
              ButtonSegment(
                value: _RanksSection.standards,
                label: Text('Strength standards'),
                icon: Icon(AppIcons.strength),
              ),
            ],
            selected: {_section},
            onSelectionChanged: (value) =>
                setState(() => _section = value.single),
          ),
          const SizedBox(height: 16),
          if (_section == _RanksSection.muscles)
            progress.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => const Text(
                'Ranks could not be loaded. Your workout data is unchanged.',
              ),
              data: (values) =>
                  _MuscleRanks(values: values, goal: coaching.trainingGoal),
            )
          else
            _StrengthStandards(
              sex: coaching.userSex,
              onEnable: () => _enableStandards(coaching.userSex),
            ),
        ],
      ),
    );
  }

  Future<void> _enableStandards(UserSex current) async {
    var selected = current == UserSex.unset ? UserSex.female : current;
    final bodyweights =
        ref.read(bodyweightEntriesProvider).asData?.value ?? const [];
    final needsWeight = bodyweights.isEmpty;
    final weightController = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Enable strength standards'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<UserSex>(
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Sex'),
                items: const [
                  DropdownMenuItem(
                    value: UserSex.female,
                    child: Text('Female'),
                  ),
                  DropdownMenuItem(value: UserSex.male, child: Text('Male')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selected = value);
                  }
                },
              ),
              if (needsWeight) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Bodyweight (kg)',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enable'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) {
      weightController.dispose();
      return;
    }
    final weight = double.tryParse(weightController.text.trim());
    weightController.dispose();
    if (needsWeight && (weight == null || weight <= 0)) return;
    await ref.read(settingsRepositoryProvider).setUserSex(selected);
    if (weight != null) {
      await ref
          .read(bodyweightRepositoryProvider)
          .upsert(date: DateTime.now(), value: weight, unit: WeightUnit.kg);
    }
  }
}

class _MuscleRanks extends StatelessWidget {
  const _MuscleRanks({required this.values, required this.goal});

  final Map<MuscleId, MuscleProgress> values;
  final TrainingGoal goal;

  @override
  Widget build(BuildContext context) {
    final rows = values.values.toList()
      ..sort((a, b) => b.rankScore.compareTo(a.rankScore));
    return Column(
      children: [
        for (final progress in rows)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          progress.muscle.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        '${progress.rank.label} · ${goal.label}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress.rankProgress),
                  const SizedBox(height: 8),
                  Text(rankExplainer(progress, goal)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StrengthStandards extends ConsumerWidget {
  const _StrengthStandards({required this.sex, required this.onEnable});

  final UserSex sex;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bodyweights =
        ref.watch(bodyweightEntriesProvider).asData?.value ?? const [];
    if (sex == UserSex.unset || bodyweights.isEmpty) {
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
                onPressed: onEnable,
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
        ref.watch(completedSetsProvider).asData?.value ??
        const <WorkoutSetRecord>[];
    final best = <String, double>{};
    for (final set in sets) {
      if (!benchmarkLiftNames.contains(set.exerciseName)) continue;
      final estimate = set.exerciseName == 'Pull-Up'
          ? (bodyweightKg + set.weightKg) * (1 + set.reps / 30)
          : set.estimatedOneRepMaxKg;
      if (estimate > (best[set.exerciseName] ?? 0)) {
        best[set.exerciseName] = estimate;
      }
    }
    if (best.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'Log one of the six benchmark lifts to see a population standard.',
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final entry in best.entries)
          Builder(
            builder: (context) {
              final result = standardFor(
                lift: entry.key,
                sex: sex,
                bodyweightKg: bodyweightKg,
                estOneRepMaxKg: entry.value,
              )!;
              return Card(
                child: ListTile(
                  title: Text(entry.key),
                  subtitle: Text(
                    result.nextThreshold == null
                        ? '${result.ratio.toStringAsFixed(2)}× bodyweight'
                        : '${result.ratio.toStringAsFixed(2)}× bodyweight · '
                              'next at ${result.nextThreshold!.round()} kg',
                  ),
                  trailing: Text(
                    result.level.label,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

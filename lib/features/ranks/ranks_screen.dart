import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/domain/enums.dart';
import '../../core/domain/muscle_progress.dart';
import '../../core/domain/muscle.dart';
import '../../core/domain/strength_standards.dart';
import '../../core/domain/training_goal.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/providers.dart';
import '../../data/repositories/settings_repository.dart';
import 'widgets/strength_standards_section.dart';

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
      appBar: AppBar(
        title: const Text('Ranks'),
        actions: [
          IconButton(
            tooltip: 'How ranks work',
            icon: const Icon(AppIcons.info),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
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
          const SizedBox(height: 20),
          if (_section == _RanksSection.muscles) ...[
            const SectionHeader('Your muscles'),
            progress.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => const Text(
                'Ranks could not be loaded. Your workout data is unchanged.',
              ),
              data: (values) =>
                  _MuscleRanks(values: values, goal: coaching.trainingGoal),
            ),
          ] else
            StrengthStandardsSection(
              sex: coaching.userSex,
              onEnable: () => _enableStandards(coaching.userSex),
            ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How ranks work'),
        content: const Text(
          'Muscle ranks track your training volume against evidence-based '
          'landmarks for each muscle. Strength standards compare your '
          'benchmark lifts to population data at your bodyweight and sex — '
          'both are broad reference points, not a target you must hit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
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
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final rows = values.values.toList()
      ..sort((a, b) => b.rankScore.compareTo(a.rankScore));
    return Column(
      children: [
        for (final progress in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: colors.streakContainer,
                          foregroundColor: colors.streak,
                          child: const Icon(AppIcons.trophy, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            progress.muscle.label,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '${progress.rank.label} · ${goal.label}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: progress.rankProgress,
                        minHeight: 8,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      rankExplainer(progress, goal),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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

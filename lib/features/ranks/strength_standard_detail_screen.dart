import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/strength_standards.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../exercise/widgets/exercise_progress_detail.dart';
import 'widgets/strength_standard_card.dart';

class StrengthStandardDetailScreen extends ConsumerWidget {
  const StrengthStandardDetailScreen({
    super.key,
    required this.lift,
    required this.result,
    required this.bodyweightKg,
    this.icon,
    this.accentColor,
  });

  final String lift;
  final StrengthStandardResult result;
  final double bodyweightKg;
  final IconData? icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final exercises =
        ref.watch(allExercisesProvider).asData?.value ?? const <Exercise>[];
    Exercise? exercise;
    for (final candidate in exercises) {
      if (candidate.name == lift) {
        exercise = candidate;
        break;
      }
    }
    final points = exercise == null
        ? null
        : ref.watch(oneRepMaxPointsForExerciseProvider(exercise.id));

    return Scaffold(
      appBar: AppBar(title: Text(lift)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          StrengthStandardCard(
            lift: lift,
            result: result,
            bodyweightKg: bodyweightKg,
            icon: icon,
            accentColor: accentColor,
          ),
          const SizedBox(height: 24),
          const SectionHeader('History'),
          if (points == null)
            Text(
              'History could not be matched to an exercise.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            points.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => Text(
                'History could not be loaded.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              data: (values) => values.isEmpty
                  ? Text(
                      'No sets logged for $lift yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : ExerciseProgressDetail(values: values),
            ),
        ],
      ),
    );
  }
}

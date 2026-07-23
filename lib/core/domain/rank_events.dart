import 'muscle.dart';
import 'muscle_progress.dart';

class RankUpEvent {
  const RankUpEvent({
    required this.muscle,
    required this.previous,
    required this.current,
  });

  final MuscleId muscle;
  final MuscleRank previous;
  final MuscleRank current;
}

List<RankUpEvent> detectRankUps({
  required Map<MuscleId, MuscleRank> previous,
  required Map<MuscleId, MuscleRank> current,
}) => [
  for (final entry in current.entries)
    if (previous[entry.key] case final oldRank?
        when entry.value.index > oldRank.index)
      RankUpEvent(muscle: entry.key, previous: oldRank, current: entry.value),
];

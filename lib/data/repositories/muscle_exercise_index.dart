import '../../core/domain/muscle.dart';
import '../database/app_database.dart';

class MuscleExerciseMatch {
  const MuscleExerciseMatch({
    required this.exercise,
    required this.isPrimary,
    required this.trainingCount,
  });

  final Exercise exercise;
  final bool isPrimary;
  final int trainingCount;
}

class MuscleExerciseIndex {
  const MuscleExerciseIndex(this._database);

  final AppDatabase _database;

  Future<Map<MuscleId, List<MuscleExerciseMatch>>> build() async {
    final exercises = await (_database.select(
      _database.exercises,
    )..where((exercise) => exercise.isArchived.equals(false))).get();
    final frequencyRows = await _database
        .customSelect(
          'SELECT sx.exercise_id AS exercise_id, COUNT(DISTINCT s.id) AS uses '
          'FROM session_exercises sx '
          'JOIN sessions s ON s.id = sx.session_id '
          'WHERE s.ended_at IS NOT NULL GROUP BY sx.exercise_id',
        )
        .get();
    final frequency = {
      for (final row in frequencyRows)
        row.read<int>('exercise_id'): row.read<int>('uses'),
    };
    final result = {
      for (final muscle in MuscleId.values) muscle: <MuscleExerciseMatch>[],
    };
    for (final exercise in exercises) {
      List<MuscleId> primary;
      List<MuscleId> secondary;
      try {
        primary = decodeMuscleIds(exercise.primaryMuscles);
        secondary = decodeMuscleIds(exercise.secondaryMuscles);
      } on FormatException {
        continue;
      } on ArgumentError {
        continue;
      }
      final primarySet = primary.toSet();
      for (final muscle in primarySet) {
        result[muscle]!.add(
          MuscleExerciseMatch(
            exercise: exercise,
            isPrimary: true,
            trainingCount: frequency[exercise.id] ?? 0,
          ),
        );
      }
      for (final muscle in secondary.toSet().difference(primarySet)) {
        result[muscle]!.add(
          MuscleExerciseMatch(
            exercise: exercise,
            isPrimary: false,
            trainingCount: frequency[exercise.id] ?? 0,
          ),
        );
      }
    }
    for (final matches in result.values) {
      matches.sort((a, b) {
        final byRole = (b.isPrimary ? 1 : 0).compareTo(a.isPrimary ? 1 : 0);
        if (byRole != 0) return byRole;
        final byFrequency = b.trainingCount.compareTo(a.trainingCount);
        if (byFrequency != 0) return byFrequency;
        return a.exercise.name.compareTo(b.exercise.name);
      });
    }
    return result;
  }
}

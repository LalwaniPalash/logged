enum TrainingGoal {
  maintain(
    landmarkScale: 0.70,
    rankThresholdScale: 0.85,
    progressionAggressiveness: 0.75,
    deloadSensitivity: 1.20,
  ),
  build(
    landmarkScale: 1.0,
    rankThresholdScale: 1.0,
    progressionAggressiveness: 1.0,
    deloadSensitivity: 1.0,
  ),
  push(
    landmarkScale: 1.25,
    rankThresholdScale: 1.15,
    progressionAggressiveness: 1.20,
    deloadSensitivity: 0.85,
  );

  const TrainingGoal({
    required this.landmarkScale,
    required this.rankThresholdScale,
    required this.progressionAggressiveness,
    required this.deloadSensitivity,
  });

  final double landmarkScale;
  final double rankThresholdScale;
  final double progressionAggressiveness;

  /// Lower values trigger recovery guidance sooner.
  final double deloadSensitivity;

  String get label => switch (this) {
    TrainingGoal.maintain => 'Maintain',
    TrainingGoal.build => 'Build',
    TrainingGoal.push => 'Push',
  };
}

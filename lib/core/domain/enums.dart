enum ExerciseCategory { strength, cardio, bodyweight, stretching }

enum WeightUnit { kg, lb }

extension WeightUnitLabel on WeightUnit {
  String get label => name;
}

/// How the number typed into the weight field relates to total load.
/// [perSide] means the user held one implement per hand, so total load is 2x.
enum WeightEntry { total, perSide }

extension WeightEntryLabel on WeightEntry {
  String get label => switch (this) {
    WeightEntry.total => 'total',
    WeightEntry.perSide => 'per hand',
  };

  int get implements => this == WeightEntry.perSide ? 2 : 1;
}

enum LoadingMode { external, bodyweight, bodyweightAdded, bodyweightAssisted }

extension LoadingModeLabel on LoadingMode {
  String get label => switch (this) {
    LoadingMode.external => 'Weight',
    LoadingMode.bodyweight => 'Bodyweight',
    LoadingMode.bodyweightAdded => 'Added weight',
    LoadingMode.bodyweightAssisted => 'Assistance',
  };
}

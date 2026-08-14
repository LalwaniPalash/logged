import 'dart:convert';

import 'muscle.dart';

typedef MuscleBiasShares = ({double shareA, double shareB});

/// Preserved for v9->v10 migration of legacy two-muscle axis data.
MuscleBiasShares resolveMuscleBiasShares(double? bias) {
  final clamped = (bias ?? 0.0).clamp(-1.0, 1.0).toDouble();
  final t = (clamped + 1) / 2;
  return (shareA: 1 - t, shareB: t);
}

double? primaryMuscleBiasWeight({
  required MuscleId muscle,
  required Map<MuscleId, double>? weights,
}) => weights?[muscle];

Map<MuscleId, double>? rescaleMuscleBiasWeightsToMeanOne(
  Map<MuscleId, double>? weights,
) {
  if (weights == null) return null;
  if (weights.isEmpty) return const {};
  final scale = weights.length.toDouble();
  return Map.unmodifiable({
    for (final entry in weights.entries) entry.key: entry.value * scale,
  });
}

String? encodeMuscleBiasWeights(Map<MuscleId, double>? weights) {
  if (weights == null) return null;
  final entries = weights.entries.toList()
    ..sort((a, b) => a.key.id.compareTo(b.key.id));
  return jsonEncode({for (final entry in entries) entry.key.id: entry.value});
}

String? rescaleEncodedMuscleBiasWeightsToMeanOne(String? encoded) =>
    encodeMuscleBiasWeights(
      rescaleMuscleBiasWeightsToMeanOne(decodeMuscleBiasWeights(encoded)),
    );

Map<MuscleId, double>? decodeMuscleBiasWeights(String? encoded) {
  if (encoded == null) return null;
  final raw = jsonDecode(encoded);
  if (raw is! Map<String, dynamic>) {
    throw const FormatException('Muscle bias weights must be a JSON object.');
  }
  return Map.unmodifiable({
    for (final entry in raw.entries)
      _decodeMuscleBiasKey(entry.key): switch (entry.value) {
        final num weight => weight.toDouble(),
        _ => throw const FormatException(
          'Muscle bias weights must map string ids to numeric values.',
        ),
      },
  });
}

MuscleId _decodeMuscleBiasKey(String key) {
  try {
    return MuscleId.fromId(key);
  } on ArgumentError {
    try {
      return MuscleId.values.byName(key);
    } on ArgumentError {
      throw ArgumentError.value(key, 'key', 'Unknown muscle id');
    }
  }
}

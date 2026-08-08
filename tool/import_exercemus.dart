import 'dart:convert';
import 'dart:io';

import 'package:logged/core/domain/exercise_muscle_name_rules.dart';
import 'package:logged/core/domain/exercise_name_matcher.dart';
import 'package:logged/core/domain/muscle.dart';

void main(List<String> args) {
  if (args.isEmpty || args.length > 2) {
    stderr.writeln(
      'Usage: dart run tool/import_exercemus.dart <source.json> [asset.json]',
    );
    exitCode = 64;
    return;
  }

  final sourceFile = File(args.first);
  final assetFile = File(
    args.length == 2 ? args[1] : 'assets/data/exercise_library.json',
  );
  if (!sourceFile.existsSync()) {
    stderr.writeln('Source dataset not found: ${sourceFile.path}');
    exitCode = 66;
    return;
  }
  if (!assetFile.existsSync()) {
    stderr.writeln('Asset file not found: ${assetFile.path}');
    exitCode = 66;
    return;
  }

  final existingRows =
      (jsonDecode(assetFile.readAsStringSync()) as List<dynamic>)
          .cast<Map<String, dynamic>>();
  final source =
      jsonDecode(sourceFile.readAsStringSync()) as Map<String, dynamic>;
  final sourceExercises = (source['exercises'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final stats = _ImportStats();
  final existingNames = {
    for (final row in existingRows) (row['name']! as String).toLowerCase(),
  };
  final imported = <Map<String, Object?>>[];

  for (final raw in sourceExercises) {
    final name = raw['name']! as String;
    final normalizedName = name.toLowerCase();
    if (existingNames.contains(normalizedName)) {
      stats.overlapCount++;
      continue;
    }
    imported.add(_buildImportedRow(raw, stats));
    existingNames.add(normalizedName);
  }

  final merged = <Object?>[...existingRows, ...imported];
  assetFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(merged)}\n',
  );

  stdout.writeln(
    'Imported ${imported.length} exercises '
    '(existing: ${existingRows.length}, overlaps skipped: ${stats.overlapCount}, '
    'total: ${merged.length}).',
  );
  stdout.writeln(
    'Ambiguous label resolutions '
    '(rows with ambiguous labels: ${stats.rowsWithAmbiguousLabels}, '
    'keyword-specific: ${stats.rowsUsingAmbiguousKeywords}, '
    'default-only: ${stats.rowsUsingAmbiguousDefaults}).',
  );
  stdout.writeln(
    'Label counts '
    '[chest keyword/default: ${stats.chestKeyword}/${stats.chestDefault}, '
    'shoulders keyword/default: ${stats.shoulderKeyword}/${stats.shoulderDefault}, '
    'glutes keyword/default: ${stats.gluteKeyword}/${stats.gluteDefault}]',
  );
}

Map<String, Object?> _buildImportedRow(
  Map<String, dynamic> raw,
  _ImportStats stats,
) {
  final name = raw['name']! as String;
  final primaryLabels = (raw['primary_muscles'] as List<dynamic>)
      .cast<String>();
  final secondaryLabels = (raw['secondary_muscles'] as List<dynamic>)
      .cast<String>();
  final anatomy = _mapAnatomy(
    name,
    primaryLabels: primaryLabels,
    secondaryLabels: secondaryLabels,
    stats: stats,
  );
  final row = <String, Object?>{}
    ..['name'] = name
    ..['category'] = _mapCategory(raw['category']! as String)
    ..['muscleGroup'] = _mapMuscleGroup(primaryLabels.first)
    ..['primaryMuscles'] = [for (final muscle in anatomy.primary) muscle.id]
    ..['secondaryMuscles'] = [for (final muscle in anatomy.secondary) muscle.id]
    ..['defaultUnit'] = 'kg';

  if (_isPerSideExercise(name)) {
    row['weightEntry'] = 'perSide';
  }
  final videoUrl = (raw['video'] as String?)?.trim();
  if (videoUrl != null && videoUrl.isNotEmpty) {
    row['videoUrl'] = videoUrl;
  }
  _validateImportedRow(row);
  return row;
}

({List<MuscleId> primary, List<MuscleId> secondary}) _mapAnatomy(
  String name, {
  required List<String> primaryLabels,
  required List<String> secondaryLabels,
  required _ImportStats stats,
}) {
  final primary = <MuscleId>{};
  final secondary = <MuscleId>{};
  var rowHasAmbiguousLabel = false;
  var rowUsedKeywordSpecificRule = false;
  var rowUsedDefaultAmbiguousRule = false;

  void applyLabel(
    String label,
    Set<MuscleId> target, {
    required bool isPrimary,
  }) {
    final resolved = _resolveSourceMuscle(label, name, stats);
    target.add(resolved.muscle);
    if (resolved.extraSecondary != null) {
      secondary.add(resolved.extraSecondary!);
    }
    if (!resolved.wasAmbiguous) return;
    rowHasAmbiguousLabel = true;
    if (resolved.usedKeywordSpecificRule) {
      rowUsedKeywordSpecificRule = true;
    } else {
      rowUsedDefaultAmbiguousRule = true;
    }
  }

  for (final label in primaryLabels) {
    applyLabel(label, primary, isPrimary: true);
  }
  for (final label in secondaryLabels) {
    applyLabel(label, secondary, isPrimary: false);
  }
  secondary.removeWhere(primary.contains);

  if (rowHasAmbiguousLabel) {
    stats.rowsWithAmbiguousLabels++;
    if (rowUsedKeywordSpecificRule) {
      stats.rowsUsingAmbiguousKeywords++;
    }
    if (!rowUsedKeywordSpecificRule && rowUsedDefaultAmbiguousRule) {
      stats.rowsUsingAmbiguousDefaults++;
    }
  }

  return (primary: primary.toList(), secondary: secondary.toList());
}

_ResolvedSourceMuscle _resolveSourceMuscle(
  String rawLabel,
  String exerciseName,
  _ImportStats stats,
) {
  final label = rawLabel.toLowerCase();
  switch (label) {
    case 'quads':
      return const _ResolvedSourceMuscle(muscle: MuscleId.quads);
    case 'hamstrings':
      return const _ResolvedSourceMuscle(muscle: MuscleId.hamstrings);
    case 'calves':
    case 'soleus':
      return const _ResolvedSourceMuscle(muscle: MuscleId.calves);
    case 'forearms':
      return const _ResolvedSourceMuscle(muscle: MuscleId.forearms);
    case 'biceps':
      return const _ResolvedSourceMuscle(muscle: MuscleId.biceps);
    case 'brachialis':
      return const _ResolvedSourceMuscle(muscle: MuscleId.brachialis);
    case 'triceps':
      return const _ResolvedSourceMuscle(muscle: MuscleId.triceps);
    case 'abs':
      return const _ResolvedSourceMuscle(muscle: MuscleId.abs);
    case 'adductors':
      return const _ResolvedSourceMuscle(muscle: MuscleId.adductors);
    case 'lats':
      return const _ResolvedSourceMuscle(muscle: MuscleId.lats);
    case 'neck':
      return const _ResolvedSourceMuscle(muscle: MuscleId.neck);
    case 'abductors':
      return const _ResolvedSourceMuscle(muscle: MuscleId.gluteMedMin);
    case 'middle back':
      return const _ResolvedSourceMuscle(muscle: MuscleId.rhomboids);
    case 'lower back':
      return const _ResolvedSourceMuscle(muscle: MuscleId.spinalErectors);
    case 'traps':
      return _ResolvedSourceMuscle(
        muscle: MuscleId.upperTraps,
        extraSecondary: exerciseNameSuggestsRowOrFacePull(exerciseName)
            ? MuscleId.midLowerTraps
            : null,
      );
    case 'chest':
      final muscle = chestMuscleFromExerciseName(exerciseName);
      final usedKeyword = muscle == MuscleId.upperChest;
      if (usedKeyword) {
        stats.chestKeyword++;
      } else {
        stats.chestDefault++;
      }
      return _ResolvedSourceMuscle(
        muscle: muscle,
        wasAmbiguous: true,
        usedKeywordSpecificRule: usedKeyword,
      );
    case 'shoulders':
      final muscle = shoulderMuscleFromExerciseName(exerciseName);
      final usedKeyword = muscle != MuscleId.frontDelts;
      if (usedKeyword) {
        stats.shoulderKeyword++;
      } else {
        stats.shoulderDefault++;
      }
      return _ResolvedSourceMuscle(
        muscle: muscle,
        wasAmbiguous: true,
        usedKeywordSpecificRule: usedKeyword,
      );
    case 'glutes':
      final muscle = gluteMuscleFromExerciseName(exerciseName);
      final usedKeyword = muscle == MuscleId.gluteMedMin;
      if (usedKeyword) {
        stats.gluteKeyword++;
      } else {
        stats.gluteDefault++;
      }
      return _ResolvedSourceMuscle(
        muscle: muscle,
        wasAmbiguous: true,
        usedKeywordSpecificRule: usedKeyword,
      );
  }
  throw UnsupportedError('Unmapped source muscle label: $rawLabel');
}

String _mapCategory(String category) {
  switch (category.toLowerCase()) {
    case 'strength':
    case 'olympic weightlifting':
    case 'strongman':
      return 'strength';
    case 'stretching':
      return 'stretching';
    case 'cardio':
      return 'cardio';
    case 'calisthenics':
    case 'plyometrics':
      return 'bodyweight';
  }
  throw UnsupportedError('Unmapped category: $category');
}

String _mapMuscleGroup(String rawLabel) {
  switch (rawLabel.toLowerCase()) {
    case 'chest':
      return 'chest';
    case 'shoulders':
      return 'shoulders';
    case 'lats':
    case 'middle back':
    case 'lower back':
    case 'traps':
    case 'neck':
      return 'back';
    case 'biceps':
    case 'brachialis':
    case 'triceps':
    case 'forearms':
      return 'arms';
    case 'abs':
      return 'core';
    case 'quads':
      return 'quads';
    case 'hamstrings':
      return 'hamstrings';
    case 'glutes':
    case 'abductors':
      return 'glutes';
    case 'adductors':
      return 'quads';
    case 'calves':
    case 'soleus':
      return 'calves';
  }
  throw UnsupportedError('Unmapped muscleGroup label: $rawLabel');
}

bool _isPerSideExercise(String exerciseName) {
  final tokens = tokenizeExerciseName(exerciseName);
  return mostSpecificExercisePhraseMatch(tokens, const [
        'dumbbell',
        'single arm',
        'one arm',
        'kettlebell',
      ]) !=
      null;
}

void _validateImportedRow(Map<String, Object?> row) {
  final primary = (row['primaryMuscles'] as List<Object?>).cast<String>();
  final secondary = (row['secondaryMuscles'] as List<Object?>).cast<String>();
  if (primary.isEmpty) {
    throw StateError('${row['name']} has no primary muscles.');
  }
  final primarySet = primary.toSet();
  final secondarySet = secondary.toSet();
  if (primarySet.length != primary.length) {
    throw StateError('${row['name']} has duplicate primary muscles.');
  }
  if (secondarySet.length != secondary.length) {
    throw StateError('${row['name']} has duplicate secondary muscles.');
  }
  if (primarySet.intersection(secondarySet).isNotEmpty) {
    throw StateError('${row['name']} overlaps primary and secondary muscles.');
  }
  for (final id in [...primary, ...secondary]) {
    MuscleId.fromId(id);
  }
}

class _ResolvedSourceMuscle {
  const _ResolvedSourceMuscle({
    required this.muscle,
    this.extraSecondary,
    this.wasAmbiguous = false,
    this.usedKeywordSpecificRule = false,
  });

  final MuscleId muscle;
  final MuscleId? extraSecondary;
  final bool wasAmbiguous;
  final bool usedKeywordSpecificRule;
}

class _ImportStats {
  int overlapCount = 0;
  int rowsWithAmbiguousLabels = 0;
  int rowsUsingAmbiguousKeywords = 0;
  int rowsUsingAmbiguousDefaults = 0;
  int chestKeyword = 0;
  int chestDefault = 0;
  int shoulderKeyword = 0;
  int shoulderDefault = 0;
  int gluteKeyword = 0;
  int gluteDefault = 0;
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_icons.dart';
import '../../../core/domain/enums.dart';
import '../../../core/domain/plate_math.dart';
import '../../../core/domain/progression.dart';
import '../../../core/domain/warmup.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/prescription_editor_sheet.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/session_repository.dart';
import 'set_row.dart';

enum SessionExerciseOverflowAction {
  info,
  video,
  editVideo,
  warmup,
  addAbove,
  addBelow,
  remove,
}

class SessionExerciseCard extends StatelessWidget {
  const SessionExerciseCard({
    super.key,
    required this.index,
    required this.reorderable,
    required this.detail,
    required this.previousSets,
    required this.onAddSet,
    required this.onRepeatSet,
    required this.onInlineCommit,
    required this.onToggleSetDone,
    required this.onEditSet,
    required this.onMoveSet,
    required this.onInsertSetAbove,
    required this.onOpenPlates,
    required this.onOpenWarmup,
    required this.onRemove,
    required this.onSwap,
    required this.onEditVideoUrl,
    required this.onEditPrescription,
    required this.onOpenInfo,
    required this.onOverflowAction,
    required this.prescriptionEditable,
    required this.progressionAggressiveness,
    required this.inventory,
  });

  final int index;
  final bool reorderable;
  final SessionExerciseDetails detail;
  final List<SetEntry> previousSets;
  final VoidCallback onAddSet;
  final VoidCallback onRepeatSet;
  final Future<void> Function(
    SetEntry set,
    SetRowDraft draft,
    ProgressionSuggestion? suggestion,
  )
  onInlineCommit;
  final Future<void> Function(SetEntry set, ProgressionSuggestion? suggestion)
  onToggleSetDone;
  final void Function(SetEntry set, ProgressionSuggestion? suggestion)
  onEditSet;
  final Future<void> Function(
    SessionExerciseDetails detail,
    int oldIndex,
    int newIndex,
  )
  onMoveSet;
  final Future<void> Function(SessionExerciseDetails detail, SetEntry set)
  onInsertSetAbove;
  final void Function({
    required String exerciseName,
    required double targetWeight,
    required WeightUnit unit,
    required bool perImplement,
  })
  onOpenPlates;
  final void Function({
    required int sessionExerciseId,
    required String exerciseName,
    required List<WarmupSet> warmups,
    required WeightUnit unit,
    required WeightEntry weightEntry,
    required int sideCount,
    required LoadingMode loadingMode,
  })
  onOpenWarmup;
  final VoidCallback onRemove;
  final VoidCallback onSwap;
  final VoidCallback onOpenInfo;
  final VoidCallback onEditVideoUrl;
  final VoidCallback onEditPrescription;
  final ValueChanged<SessionExerciseOverflowAction> onOverflowAction;
  final bool prescriptionEditable;
  final double progressionAggressiveness;
  final PlateInventory inventory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetText = formatPrescription(
      targetSets: detail.sessionExercise.targetSets,
      sidesPerSet: detail.sessionExercise.sidesPerSet,
      minReps: detail.sessionExercise.minReps,
      maxReps: detail.sessionExercise.maxReps,
      targetDurationSec: detail.sessionExercise.targetDurationSec,
      targetDistanceMeters: detail.sessionExercise.targetDistanceMeters,
      restSeconds: detail.sessionExercise.restSeconds,
      eccentricSec: detail.sessionExercise.eccentricSec,
      bottomPauseSec: detail.sessionExercise.bottomPauseSec,
      concentricSec: detail.sessionExercise.concentricSec,
      topPauseSec: detail.sessionExercise.topPauseSec,
    );
    final firstSet = detail.sets.isEmpty ? null : detail.sets.first;
    final headerUnit = firstSet?.unit ?? detail.exercise.defaultUnit;
    final headerWeightEntry =
        firstSet?.weightEntry ?? detail.exercise.weightEntry;
    final headerSideCount =
        firstSet?.sideCount ?? detail.sessionExercise.sidesPerSet ?? 1;
    final timed = isTimedExercise(
      exerciseIsTimed: detail.exercise.isTimed,
      sets: detail.sets,
      targetDurationSec: detail.sessionExercise.targetDurationSec,
      minReps: detail.sessionExercise.minReps,
      maxReps: detail.sessionExercise.maxReps,
    );
    final columns = setColumnsFor(
      category: detail.exercise.category,
      loadingModes: detail.sets.isEmpty
          ? [detail.exercise.preferredLoadingMode]
          : detail.sets.map((set) => set.loadingMode),
      timed: timed,
      tracksDistance: detail.exercise.tracksDistance,
    );
    final suggestion = timed
        ? null
        : suggestNextSet(
            lastExerciseSets: previousSets,
            minReps: detail.sessionExercise.minReps,
            maxReps: detail.sessionExercise.maxReps,
            targetRpe: _targetRpe(detail.sessionExercise.prescriptionNotes),
            weightEntry: headerWeightEntry,
            unit: headerUnit,
            loadingMode:
                firstSet?.loadingMode ?? detail.exercise.preferredLoadingMode,
            progressionAggressiveness: progressionAggressiveness,
          );
    final loadingMode =
        firstSet?.loadingMode ?? detail.exercise.preferredLoadingMode;
    final plateSupported =
        loadingMode == LoadingMode.external ||
        loadingMode == LoadingMode.bodyweightAdded;
    final perImplement = headerWeightEntry == WeightEntry.perSide;
    final workingWeight =
        _latestWorkingWeight(detail.sets, loadingMode: loadingMode) ??
        suggestion?.weightValue;
    final plateTarget = workingWeight ?? inventory.barWeightFor(headerUnit);
    final alreadyWarmedUp = detail.sets.any((set) => set.isWarmup);
    final warmups = workingWeight == null || alreadyWarmedUp
        ? const <WarmupSet>[]
        : generateWarmup(
            workingWeight: workingWeight,
            unit: headerUnit,
            inventory: inventory,
            workingReps:
                detail.sessionExercise.maxReps ??
                detail.sessionExercise.minReps,
            loadingMode: loadingMode,
            perImplement: perImplement,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.exercise.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // A finished workout with no prescription must not
                        // show a grey, untappable "Add prescription" — it is a
                        // dead affordance. Guard carried over from the
                        // pre-redesign card.
                        if (prescriptionEditable || targetText.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: prescriptionEditable
                                  ? onEditPrescription
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        targetText.isEmpty
                                            ? 'Add prescription'
                                            : targetText,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  targetText.isEmpty &&
                                                      prescriptionEditable
                                                  ? theme.colorScheme.primary
                                                  : theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                              height: 1.4,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (previousSets.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          LastPerformanceHint(sets: previousSets),
                        ],
                        if ((detail.sessionExercise.prescriptionNotes ?? '')
                            .isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            detail.sessionExercise.prescriptionNotes!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<SessionExerciseOverflowAction>(
                    tooltip: 'Exercise actions',
                    padding: const EdgeInsets.all(8),
                    icon: Icon(
                      AppIcons.more,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onSelected: onOverflowAction,
                    itemBuilder: (context) {
                      final link =
                          (detail.sessionExercise.formUrl?.isNotEmpty ?? false)
                          ? detail.sessionExercise.formUrl!
                          : (detail.exercise.videoUrl ?? '');
                      return [
                        const PopupMenuItem(
                          value: SessionExerciseOverflowAction.info,
                          child: Text('Exercise info'),
                        ),
                        if (link.isEmpty)
                          const PopupMenuItem(
                            value: SessionExerciseOverflowAction.editVideo,
                            child: Text('Add a video link'),
                          )
                        else ...[
                          const PopupMenuItem(
                            value: SessionExerciseOverflowAction.video,
                            child: Text('Play video'),
                          ),
                          if ((detail.exercise.videoUrl ?? '').isNotEmpty)
                            const PopupMenuItem(
                              value: SessionExerciseOverflowAction.editVideo,
                              child: Text('Change video link'),
                            ),
                        ],
                        PopupMenuItem(
                          value: SessionExerciseOverflowAction.warmup,
                          enabled: warmups.isNotEmpty,
                          child: const Text('Warm-up'),
                        ),
                        const PopupMenuItem(
                          value: SessionExerciseOverflowAction.addAbove,
                          child: Text('Add exercise above'),
                        ),
                        const PopupMenuItem(
                          value: SessionExerciseOverflowAction.addBelow,
                          child: Text('Add exercise below'),
                        ),
                        const PopupMenuItem(
                          value: SessionExerciseOverflowAction.remove,
                          child: Text('Remove exercise'),
                        ),
                      ];
                    },
                  ),
                  if (reorderable)
                    ReorderableDragStartListener(
                      index: index,
                      // Height-matched to the ⋮ button above: PopupMenuButton
                      // wraps an IconButton, which forces a 48-tall hit box
                      // even with 8px padding around an 18px icon, so its
                      // glyph centers at 24px from the row top. A bare
                      // Padding.all(8) here centers at 17px instead — same
                      // padding, different result, because only one of the
                      // two boxes gets stretched to the 48 minimum.
                      child: SizedBox(
                        height: 48,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              AppIcons.drag,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (detail.sets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  child: Text(
                    'No sets yet',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else ...[
                SetTableHeader(
                  columns: columns,
                  unit: headerUnit,
                  weightEntry: headerWeightEntry,
                  sideCount: headerSideCount,
                ),
                const SizedBox(height: 4),
                for (final set in detail.sets)
                  SetRow(
                    key: ValueKey(set.id),
                    set: set,
                    category: detail.exercise.category,
                    headerUnit: headerUnit,
                    columns: columns,
                    headerWeightEntry: headerWeightEntry,
                    headerSideCount: headerSideCount,
                    timed: timed,
                    tracksDistance: detail.exercise.tracksDistance,
                    suggestion: set == detail.sets.last ? suggestion : null,
                    onCommit: (draft) => onInlineCommit(
                      set,
                      draft,
                      set == detail.sets.last ? suggestion : null,
                    ),
                    onToggleDone: () => onToggleSetDone(
                      set,
                      set == detail.sets.last ? suggestion : null,
                    ),
                    onOpenDetails: () => onEditSet(
                      set,
                      set == detail.sets.last ? suggestion : null,
                    ),
                    onMoveUp: reorderable && set != detail.sets.first
                        ? () => unawaited(
                            onMoveSet(
                              detail,
                              detail.sets.indexOf(set),
                              detail.sets.indexOf(set) - 1,
                            ),
                          )
                        : null,
                    onMoveDown: reorderable && set != detail.sets.last
                        ? () => unawaited(
                            onMoveSet(
                              detail,
                              detail.sets.indexOf(set),
                              detail.sets.indexOf(set) + 1,
                            ),
                          )
                        : null,
                    onInsertAbove: reorderable
                        ? () => unawaited(onInsertSetAbove(detail, set))
                        : null,
                  ),
              ],
              const SizedBox(height: 10),
              _ExerciseActionRow(
                plateSupported: plateSupported,
                onOpenPlates: plateSupported
                    ? () => onOpenPlates(
                        exerciseName: detail.exercise.name,
                        targetWeight: plateTarget,
                        unit: headerUnit,
                        perImplement: perImplement,
                      )
                    : null,
                onRepeat: detail.sets.isEmpty ? null : onRepeatSet,
                onSwap: onSwap,
              ),
              const SizedBox(height: 10),
              _DashedAddSetButton(onPressed: onAddSet),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseActionRow extends StatelessWidget {
  const _ExerciseActionRow({
    required this.plateSupported,
    required this.onOpenPlates,
    required this.onRepeat,
    required this.onSwap,
  });

  final bool plateSupported;
  final VoidCallback? onOpenPlates;
  final VoidCallback? onRepeat;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    if (textScale > 1.3) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (plateSupported)
            _SegmentActionButton(
              onPressed: onOpenPlates,
              icon: AppIcons.plates,
              label: 'Plates',
            ),
          _SegmentActionButton(
            onPressed: onRepeat,
            icon: AppIcons.refresh,
            label: 'Repeat',
          ),
          _SegmentActionButton(
            onPressed: onSwap,
            icon: AppIcons.swap,
            label: 'Swap',
          ),
        ],
      );
    }
    return IntrinsicHeight(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            if (plateSupported)
              Expanded(
                child: _SegmentActionButton(
                  onPressed: onOpenPlates,
                  icon: AppIcons.plates,
                  label: 'Plates',
                  compact: true,
                ),
              ),
            if (plateSupported)
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            Expanded(
              child: _SegmentActionButton(
                onPressed: onRepeat,
                icon: AppIcons.refresh,
                label: 'Repeat',
                compact: true,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(
              child: _SegmentActionButton(
                onPressed: onSwap,
                icon: AppIcons.swap,
                label: 'Swap',
                compact: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentActionButton extends StatelessWidget {
  const _SegmentActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.compact = false,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: compact
          ? TextButton.styleFrom(
              shape: const RoundedRectangleBorder(),
              minimumSize: const Size(0, 48),
            )
          : null,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _DashedAddSetButton extends StatelessWidget {
  const _DashedAddSetButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DashedBorder(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: onPressed,
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: Center(
              child: Text(
                '+ Add set',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double? _latestWorkingWeight(
  List<SetEntry> sets, {
  required LoadingMode loadingMode,
}) {
  for (final set in sets.reversed) {
    if (!set.isWarmup &&
        set.loadingMode == loadingMode &&
        set.weightValue != null) {
      return set.weightValue;
    }
  }
  for (final set in sets.reversed) {
    if (set.loadingMode == loadingMode && set.weightValue != null) {
      return set.weightValue;
    }
  }
  return null;
}

/// Pulls a target RPE out of free-text prescription notes, e.g. "RPE 8" or
/// "RPE: 7.5" — the schema has no dedicated RPE column (see tasks/lessons.md
/// 2026-08-14), so this is the only place it can come from. Null on no
/// match or a number outside the 1-10 RPE scale.
double? _targetRpe(String? prescriptionNotes) {
  if (prescriptionNotes == null) return null;
  final match = RegExp(
    r'rpe\s*[:@]?\s*(\d+(\.\d+)?)',
    caseSensitive: false,
  ).firstMatch(prescriptionNotes);
  if (match == null) return null;
  final value = double.tryParse(match.group(1)!);
  if (value == null || value < 1 || value > 10) return null;
  return value;
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_icons.dart';
import '../../core/domain/enums.dart';
import '../../core/domain/workout_metrics.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/exercise_picker.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/providers.dart';
import 'widgets/set_editor_sheet.dart';
import 'rest_timer_controller.dart';
import 'widgets/rest_timer_bar.dart';
import 'widgets/set_row.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  const ActiveSessionScreen({super.key, required this.sessionId});
  final int sessionId;

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  late Future<_SessionView> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => _future = _loadView();

  @override
  void dispose() {
    unawaited(
      ref
          .read(restTimerControllerProvider.notifier)
          .cancel(sessionId: widget.sessionId),
    );
    super.dispose();
  }

  Future<_SessionView> _loadView() async {
    final repo = ref.read(sessionRepositoryProvider);
    final session = await repo.getSession(widget.sessionId);
    final details = await repo.details(widget.sessionId);
    return _SessionView(session: session, details: details);
  }

  Future<void> _addExercise() async {
    final exercises = await ref.read(exerciseRepositoryProvider).all();
    if (!mounted) return;
    final exercise = await showExercisePicker(
      context,
      exercises,
      title: 'Add an exercise',
    );
    if (exercise == null) return;
    await ref
        .read(sessionRepositoryProvider)
        .addExercise(sessionId: widget.sessionId, exerciseId: exercise.id);
    setState(_refresh);
  }

  Future<void> _removeExercise(int sessionExerciseId) async {
    await ref
        .read(sessionRepositoryProvider)
        .removeSessionExercise(sessionExerciseId);
    setState(_refresh);
  }

  Future<void> _openSet(
    SessionExerciseDetails detail, {
    SetEntry? existing,
    SetSeed? seed,
  }) async {
    final sessionRepository = ref.read(sessionRepositoryProvider);
    final resolvedSeed = existing == null
        ? seed ??
              await sessionRepository.seedForNextSet(
                sessionExerciseId: detail.sessionExercise.id,
              )
        : SetSeed.fromSetEntry(existing);
    final session = await ref
        .read(sessionRepositoryProvider)
        .getSession(widget.sessionId);
    final bodyweight = session == null
        ? null
        : await ref
              .read(bodyweightRepositoryProvider)
              .latestOnOrBefore(session.startedAt);
    final effectiveBodyweightKg = bodyweight == null
        ? null
        : weightKg(bodyweight.value, bodyweight.unit) *
              detail.exercise.bodyweightFactor.clamp(0.0, 1.0);
    if (!mounted) return;

    final result = await showModalBottomSheet<SetEditorResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SetEditorSheet(
        exerciseName: detail.exercise.name,
        category: detail.exercise.category,
        timed: isTimedExercise(
          sets: detail.sets,
          targetDurationSec: detail.sessionExercise.targetDurationSec,
          minReps: detail.sessionExercise.minReps,
          maxReps: detail.sessionExercise.maxReps,
        ),
        defaultUnit: detail.exercise.defaultUnit,
        defaultWeightEntry: detail.exercise.weightEntry,
        existing: existing,
        seed: resolvedSeed,
        defaultLoadingMode: detail.exercise.preferredLoadingMode,
        effectiveBodyweightKg: effectiveBodyweightKg,
      ),
    );
    if (result == null) return;

    final wasComplete =
        existing != null &&
        isSetComplete(
          category: detail.exercise.category,
          loadingMode: existing.loadingMode,
          reps: existing.reps,
          weightValue: existing.weightValue,
          durationSec: existing.durationSec,
          distanceMeters: existing.distanceMeters,
        );
    final becomesComplete =
        !result.delete &&
        isSetComplete(
          category: detail.exercise.category,
          loadingMode: result.loadingMode,
          reps: result.reps,
          weightValue: result.weight,
          durationSec: result.durationSec,
          distanceMeters: result.distanceMeters,
        );

    if (result.delete && existing != null) {
      await ref.read(setRepositoryProvider).delete(existing.id);
    } else if (existing != null) {
      await ref
          .read(setRepositoryProvider)
          .edit(
            existing.id,
            reps: result.reps,
            weightValue: result.weight,
            unit: result.weight == null ? null : result.unit,
            weightEntry: result.weightEntry,
            sideCount: result.sideCount,
            loadingMode: result.loadingMode,
            distanceMeters: result.distanceMeters,
            durationSec: result.durationSec,
            rpe: result.rpe,
            isWarmup: result.isWarmup,
            notes: result.notes,
          );
    } else {
      await ref
          .read(setRepositoryProvider)
          .add(
            sessionExerciseId: detail.sessionExercise.id,
            setNumber: _nextSetNumber(detail),
            reps: result.reps,
            weightValue: result.weight,
            unit: result.weight == null ? null : result.unit,
            weightEntry: result.weightEntry,
            sideCount: result.sideCount,
            loadingMode: result.loadingMode,
            distanceMeters: result.distanceMeters,
            durationSec: result.durationSec,
            rpe: result.rpe,
            isWarmup: result.isWarmup,
            notes: result.notes,
          );
    }
    // The delete result carries placeholder values, not user choices — writing
    // them back would reset the exercise's remembered unit / per-hand / loading
    // defaults every time a set is deleted.
    if (!result.delete) {
      await ref
          .read(exerciseRepositoryProvider)
          .updateLoggingDefaults(
            detail.exercise.id,
            unit: result.unit,
            weightEntry: result.weightEntry,
            loadingMode: result.loadingMode,
          );
    }
    if (!wasComplete && becomesComplete) {
      await _startRestTimer(detail);
    }
    if (!mounted) return;
    setState(_refresh);
  }

  Future<void> _addSet(SessionExerciseDetails detail) async {
    final seed = await ref
        .read(sessionRepositoryProvider)
        .seedForNextSet(sessionExerciseId: detail.sessionExercise.id);
    await ref
        .read(setRepositoryProvider)
        .add(
          sessionExerciseId: detail.sessionExercise.id,
          setNumber: _nextSetNumber(detail),
          reps: seed.reps,
          weightValue: seed.weightValue,
          unit: seed.weightValue == null
              ? null
              : (seed.unit ?? detail.exercise.defaultUnit),
          weightEntry: seed.weightEntry,
          sideCount: seed.sideCount,
          loadingMode: seed.loadingMode,
          distanceMeters: seed.distanceMeters,
          durationSec: seed.durationSec,
        );
    setState(_refresh);
  }

  Future<void> _repeatSet(SessionExerciseDetails detail) async {
    if (detail.sets.isEmpty) return;
    final last = detail.sets.last;
    await ref
        .read(setRepositoryProvider)
        .add(
          sessionExerciseId: detail.sessionExercise.id,
          setNumber: _nextSetNumber(detail),
          reps: last.reps,
          weightValue: last.weightValue,
          unit: last.unit,
          weightEntry: last.weightEntry,
          sideCount: last.sideCount,
          loadingMode: last.loadingMode,
          distanceMeters: last.distanceMeters,
          durationSec: last.durationSec,
          isWarmup: last.isWarmup,
          rpe: last.rpe,
          notes: last.notes,
        );
    setState(_refresh);
  }

  Future<void> _updateInlineSet(
    SessionExerciseDetails detail,
    SetEntry set,
    SetRowDraft draft,
  ) async {
    final wasComplete = isSetComplete(
      category: detail.exercise.category,
      loadingMode: set.loadingMode,
      reps: set.reps,
      weightValue: set.weightValue,
      durationSec: set.durationSec,
      distanceMeters: set.distanceMeters,
    );
    final becomesComplete = isSetComplete(
      category: detail.exercise.category,
      loadingMode: set.loadingMode,
      reps: draft.reps,
      weightValue: draft.weightValue,
      durationSec: draft.durationSec,
      distanceMeters: draft.distanceMeters,
    );
    await ref
        .read(setRepositoryProvider)
        .edit(
          set.id,
          reps: draft.reps,
          weightValue: set.loadingMode == LoadingMode.bodyweight
              ? null
              : draft.weightValue,
          unit:
              set.loadingMode == LoadingMode.bodyweight ||
                  draft.weightValue == null
              ? null
              : draft.unit,
          weightEntry: set.weightEntry,
          sideCount: set.sideCount,
          loadingMode: set.loadingMode,
          distanceMeters: draft.distanceMeters,
          durationSec: draft.durationSec,
          rpe: set.rpe,
          isWarmup: set.isWarmup,
          notes: set.notes,
        );
    if (!wasComplete && becomesComplete) {
      await _startRestTimer(detail);
    }
    if (!mounted) return;
    setState(_refresh);
  }

  Future<void> _startRestTimer(SessionExerciseDetails detail) async {
    final preferences = await ref
        .read(settingsRepositoryProvider)
        .readRestTimerPreferences();
    final notificationsAllowed = await ref
        .read(restTimerControllerProvider.notifier)
        .start(
          sessionId: widget.sessionId,
          seconds:
              detail.sessionExercise.restSeconds ?? preferences.defaultSeconds,
          notificationsEnabled: preferences.notificationsEnabled,
        );
    if (preferences.notificationsEnabled && !notificationsAllowed) {
      await ref
          .read(settingsRepositoryProvider)
          .setRestTimerNotificationsEnabled(false);
    }
  }

  Future<void> _finish() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish workout?'),
        content: const Text('This marks the session complete.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(sessionRepositoryProvider).finish(widget.sessionId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteWorkout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete workout?'),
        content: const Text(
          'This permanently removes the session and its sets.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(sessionRepositoryProvider).deleteSession(widget.sessionId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<_SessionView>(
      future: _future,
      builder: (context, snapshot) {
        final view = snapshot.data;
        final details = view?.details ?? const <SessionExerciseDetails>[];
        final completed = view?.session?.endedAt != null;

        return Scaffold(
          appBar: AppBar(
            title: Text(completed ? 'Workout' : 'Active workout'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') _deleteWorkout();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete workout'),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addExercise,
            icon: const Icon(AppIcons.add),
            label: const Text('Add exercise'),
          ),
          body: Column(
            children: [
              Expanded(
                child: details.isEmpty
                    ? EmptyState(
                        icon: AppIcons.strength,
                        title: 'No exercises yet',
                        message:
                            'Add your first exercise to start logging sets.',
                        action: FilledButton.icon(
                          onPressed: _addExercise,
                          icon: const Icon(AppIcons.add),
                          label: const Text('Add exercise'),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                        children: [
                          for (final detail in details)
                            _ExerciseCard(
                              detail: detail,
                              onAddSet: () => _addSet(detail),
                              onRepeatSet: () => _repeatSet(detail),
                              onInlineCommit: (set, draft) =>
                                  _updateInlineSet(detail, set, draft),
                              onEditSet: (set) =>
                                  _openSet(detail, existing: set),
                              onRemove: () =>
                                  _removeExercise(detail.sessionExercise.id),
                            ),
                          const SizedBox(height: 8),
                          if (!completed)
                            FilledButton.icon(
                              onPressed: _finish,
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.secondary,
                                foregroundColor: theme.colorScheme.onSecondary,
                              ),
                              icon: const Icon(AppIcons.check),
                              label: const Text('Finish workout'),
                            ),
                        ],
                      ),
              ),
              RestTimerBar(sessionId: widget.sessionId),
            ],
          ),
        );
      },
    );
  }
}

/// Next set number for an exercise. Derived from the highest existing number
/// rather than the row count, so deleting a middle set can't make the next add
/// collide with a number that is still in use.
int _nextSetNumber(SessionExerciseDetails detail) =>
    detail.sets.fold<int>(
      0,
      (max, set) => set.setNumber > max ? set.setNumber : max,
    ) +
    1;

class _SessionView {
  const _SessionView({required this.session, required this.details});
  final Session? session;
  final List<SessionExerciseDetails> details;
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.detail,
    required this.onAddSet,
    required this.onRepeatSet,
    required this.onInlineCommit,
    required this.onEditSet,
    required this.onRemove,
  });

  final SessionExerciseDetails detail;
  final VoidCallback onAddSet;
  final VoidCallback onRepeatSet;
  final Future<void> Function(SetEntry set, SetRowDraft draft) onInlineCommit;
  final ValueChanged<SetEntry> onEditSet;
  final VoidCallback onRemove;

  Future<void> _openForm(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetText = _formatPrescription(
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

    // Column headings describe the exercise's prevailing shape, taken from the
    // first set (the sets of one exercise almost always agree). Any set that
    // differs still renders in the same columns and labels its own deviation.
    final firstSet = detail.sets.isEmpty ? null : detail.sets.first;
    final headerUnit = firstSet?.unit ?? detail.exercise.defaultUnit;
    final headerWeightEntry =
        firstSet?.weightEntry ?? detail.exercise.weightEntry;
    final headerSideCount =
        firstSet?.sideCount ?? detail.sessionExercise.sidesPerSet ?? 1;
    // A Plank is `bodyweight` category but prescribed in seconds; without this
    // it would render a reps column and its hold time would be unloggable.
    final timed = isTimedExercise(
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
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    AppIcons.forCategoryName(detail.exercise.category.name),
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.exercise.name,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (targetText.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            targetText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if ((detail.sessionExercise.prescriptionNotes ?? '')
                            .isNotEmpty) ...[
                          const SizedBox(height: 3),
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
                  if ((detail.sessionExercise.formUrl ?? '').isNotEmpty)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          _openForm(detail.sessionExercise.formUrl!),
                      icon: const Icon(AppIcons.play, size: 18),
                      tooltip: 'Open form video',
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onRemove,
                    icon: Icon(
                      AppIcons.close,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Remove exercise',
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                    onCommit: (draft) => onInlineCommit(set, draft),
                    onOpenDetails: () => onEditSet(set),
                  ),
              ],
              const SizedBox(height: 6),
              // Wrap, not Row: these must fall onto a second line at large text
              // scales rather than overflow.
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: detail.sets.isEmpty ? null : onRepeatSet,
                    icon: const Icon(AppIcons.refresh, size: 18),
                    label: const Text('Repeat'),
                  ),
                  TextButton.icon(
                    onPressed: onAddSet,
                    icon: const Icon(AppIcons.add, size: 18),
                    label: const Text('Add set'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatPrescription({
  int? targetSets,
  int? sidesPerSet,
  int? minReps,
  int? maxReps,
  int? targetDurationSec,
  double? targetDistanceMeters,
  int? restSeconds,
  int? eccentricSec,
  int? bottomPauseSec,
  int? concentricSec,
  int? topPauseSec,
}) {
  final parts = <String>[];
  final eachSide = sidesPerSet != null && sidesPerSet > 1;
  if (targetSets != null) {
    parts.add('$targetSets ${targetSets == 1 ? 'set' : 'sets'}');
  }
  if (minReps != null || maxReps != null) {
    if (minReps != null && maxReps != null && minReps != maxReps) {
      parts.add('$minReps–$maxReps reps${eachSide ? ' each side' : ''}');
    } else {
      parts.add('${minReps ?? maxReps} reps${eachSide ? ' each side' : ''}');
    }
  }
  if (targetDurationSec != null) {
    parts.add(
      '${_formatPrescriptionDuration(targetDurationSec)}${eachSide ? ' each side' : ''}',
    );
  }
  if (targetDistanceMeters != null) {
    parts.add(
      '${_formatPrescriptionDistance(targetDistanceMeters)}${eachSide ? ' each side' : ''}',
    );
  }
  if (eccentricSec != null ||
      bottomPauseSec != null ||
      concentricSec != null ||
      topPauseSec != null) {
    parts.add(
      'Tempo ${eccentricSec ?? 0}-${bottomPauseSec ?? 0}-${concentricSec ?? 0}-${topPauseSec ?? 0}',
    );
  }
  if (restSeconds != null) {
    parts.add('${_formatPrescriptionDuration(restSeconds)} rest');
  }
  return parts.join(' · ');
}

String _formatPrescriptionDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  if (minutes <= 0) return '${seconds}s';
  return remaining == 0 ? '${minutes}m' : '${minutes}m ${remaining}s';
}

String _formatPrescriptionDistance(double meters) {
  if (meters >= 1000) return '${_trimPrescription(meters / 1000)} km';
  return '${_trimPrescription(meters)} m';
}

String _trimPrescription(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

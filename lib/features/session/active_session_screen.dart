import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_icons.dart';
import '../../core/domain/enums.dart';
import '../../core/domain/muscle_bias.dart';
import '../../core/domain/plate_math.dart';
import '../../core/domain/progression.dart';
import '../../core/domain/muscle.dart';
import '../../core/domain/progress_analytics.dart';
import '../../core/domain/streak.dart';
import '../../core/domain/training_goal.dart';
import '../../core/domain/warmup.dart';
import '../../core/domain/workout_metrics.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/exercise_editor_sheet.dart';
import '../../core/widgets/prescription_editor_sheet.dart';
import '../../core/widgets/exercise_picker.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/providers.dart';
import '../settings/reminder_scheduler.dart';
import 'rest_timer_screen.dart';
import 'widgets/plate_calculator_sheet.dart';
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

/// Timed-ness and distance-tracking decide which columns a set shows AND what
/// makes it complete, so every consumer must agree. Resolving it in one place
/// stops a set from rendering a hold-time column while completion still demands
/// reps the editor already nulled.
bool _timedForDetail(SessionExerciseDetails detail) => isTimedExercise(
  exerciseIsTimed: detail.exercise.isTimed,
  sets: detail.sets,
  targetDurationSec: detail.sessionExercise.targetDurationSec,
  minReps: detail.sessionExercise.minReps,
  maxReps: detail.sessionExercise.maxReps,
);

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
    final previousSets = <int, List<SetEntry>>{};
    await Future.wait([
      for (final detail in details)
        repo
            .lastSetsForExercise(
              detail.exercise.id,
              excludingSessionId: widget.sessionId,
            )
            .then((sets) => previousSets[detail.sessionExercise.id] = sets),
    ]);
    return _SessionView(
      session: session,
      details: details,
      previousSets: previousSets,
    );
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

  Future<MuscleId?> _pickMuscle() => showDialog<MuscleId>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Build from a muscle'),
      children: [
        SizedBox(
          width: 360,
          height: 440,
          child: ListView(
            children: [
              for (final muscle in MuscleId.values)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, muscle),
                  child: Text(muscle.label),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _addForMuscle() async {
    final muscle = await _pickMuscle();
    if (muscle == null) return;
    final index = await ref.read(muscleExerciseIndexProvider).build();
    if (!mounted) return;
    final exercise = await showExercisePicker(
      context,
      (index[muscle] ?? const []).map((match) => match.exercise).toList(),
      title: 'Exercises for ${muscle.label}',
      preserveOrder: true,
    );
    if (exercise == null) return;
    await ref
        .read(sessionRepositoryProvider)
        .addExercise(sessionId: widget.sessionId, exerciseId: exercise.id);
    setState(_refresh);
  }

  Future<void> _swapExercise(SessionExerciseDetails detail) async {
    final primary = decodeMuscleIds(detail.exercise.primaryMuscles);
    final index = await ref.read(muscleExerciseIndexProvider).build();
    final matches = primary.isEmpty
        ? const <Exercise>[]
        : (index[primary.first] ?? const [])
              .map((match) => match.exercise)
              .where((exercise) => exercise.id != detail.exercise.id)
              .toList();
    if (!mounted) return;
    final exercise = await showExercisePicker(
      context,
      matches,
      title: primary.isEmpty
          ? 'Swap ${detail.exercise.name}'
          : 'Swap for ${primary.first.label}',
      preserveOrder: true,
    );
    if (exercise == null) return;
    if (!mounted) return;
    if (detail.sets.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace exercise?'),
          content: const Text(
            'The prescription slot will stay, but sets already logged for this exercise will be removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await ref
        .read(sessionRepositoryProvider)
        .swapExercise(
          sessionExerciseId: detail.sessionExercise.id,
          exerciseId: exercise.id,
        );
    setState(_refresh);
  }

  Future<void> _removeExercise(SessionExerciseDetails detail) async {
    final setCount = detail.sets.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove exercise?'),
        content: Text(
          'Remove ${detail.exercise.name} and delete its $setCount ${setCount == 1 ? 'set' : 'sets'} from this workout?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(sessionRepositoryProvider)
        .removeSessionExercise(detail.sessionExercise.id);
    setState(_refresh);
  }

  Future<void> _editPrescription(SessionExerciseDetails detail) async {
    final updated = await showModalBottomSheet<ExercisePrescriptionValues>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => PrescriptionEditorSheet(
        exerciseName: detail.exercise.name,
        initialValues: ExercisePrescriptionValues(
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
          prescriptionNotes: detail.sessionExercise.prescriptionNotes,
          formUrl: detail.sessionExercise.formUrl,
        ),
      ),
    );
    if (updated == null) return;
    await ref
        .read(sessionRepositoryProvider)
        .updatePrescription(
          detail.sessionExercise.id,
          targetSets: Value(updated.targetSets),
          sidesPerSet: Value(updated.sidesPerSet),
          minReps: Value(updated.minReps),
          maxReps: Value(updated.maxReps),
          targetDurationSec: Value(updated.targetDurationSec),
          targetDistanceMeters: Value(updated.targetDistanceMeters),
          restSeconds: Value(updated.restSeconds),
          eccentricSec: Value(updated.eccentricSec),
          bottomPauseSec: Value(updated.bottomPauseSec),
          concentricSec: Value(updated.concentricSec),
          topPauseSec: Value(updated.topPauseSec),
          prescriptionNotes: Value(updated.prescriptionNotes),
          formUrl: Value(updated.formUrl),
        );
    if (!mounted) return;
    setState(_refresh);
  }

  void _showDeletedSetSnackBar(SessionExerciseDetails detail, SetEntry set) {
    final messenger = ScaffoldMessenger.of(context);
    // Read the repository up front: the SnackBar outlives this route, so
    // touching `ref` from the Undo callback throws once the screen unmounts.
    final repository = ref.read(setRepositoryProvider);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${detail.exercise.name} set ${set.setNumber} deleted.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            unawaited(
              repository
                  .restoreDeletedSet(
                    sessionExerciseId: detail.sessionExercise.id,
                    setNumber: set.setNumber,
                    reps: set.reps,
                    weightValue: set.weightValue,
                    unit: set.unit,
                    weightEntry: set.weightEntry,
                    sideCount: set.sideCount,
                    loadingMode: set.loadingMode,
                    distanceMeters: set.distanceMeters,
                    durationSec: set.durationSec,
                    isWarmup: set.isWarmup,
                    rpe: set.rpe,
                    muscleBiasWeights: set.muscleBiasWeights == null
                        ? null
                        : decodeMuscleBiasWeights(set.muscleBiasWeights),
                    notes: set.notes,
                  )
                  .then((_) {
                    if (!mounted) return;
                    setState(_refresh);
                  }),
            );
          },
        ),
      ),
    );
  }

  Future<void> _reorderExercises(
    List<SessionExerciseDetails> details,
    int oldIndex,
    int newIndex,
  ) async {
    // Flutter's reorder callback targets the index BEFORE the dragged item is
    // removed, so an item moving downward needs its target shifted back one.
    if (oldIndex < newIndex) newIndex -= 1;
    final ids = [for (final detail in details) detail.sessionExercise.id];
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);
    await ref
        .read(sessionRepositoryProvider)
        .reorderExercises(widget.sessionId, ids);
    setState(_refresh);
  }

  /// Add / edit / clear the exercise's own demo video link. Stored on the
  /// exercise so it shows in every workout it appears in, not just this one.
  Future<void> _editVideoUrl(SessionExerciseDetails detail) async {
    final controller = TextEditingController(
      text: detail.exercise.videoUrl ?? '',
    );
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Video for ${detail.exercise.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Video link',
            hintText: 'Paste a YouTube (or any) link',
          ),
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        ),
        actions: [
          if ((detail.exercise.videoUrl ?? '').isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return; // cancelled
    await ref
        .read(exerciseRepositoryProvider)
        .updateVideoUrl(detail.exercise.id, result.isEmpty ? null : result);
    setState(_refresh);
  }

  Future<void> _openSet(
    SessionExerciseDetails detail, {
    SetEntry? existing,
    SetSeed? seed,
    ProgressionSuggestion? suggestion,
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
    final primaryMuscles = decodeMuscleIds(detail.exercise.primaryMuscles);

    final result = await showModalBottomSheet<SetEditorResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SetEditorSheet(
        exerciseName: detail.exercise.name,
        category: detail.exercise.category,
        timed: isTimedExercise(
          exerciseIsTimed: detail.exercise.isTimed,
          sets: detail.sets,
          targetDurationSec: detail.sessionExercise.targetDurationSec,
          minReps: detail.sessionExercise.minReps,
          maxReps: detail.sessionExercise.maxReps,
        ),
        tracksDistance: detail.exercise.tracksDistance,
        defaultUnit: detail.exercise.defaultUnit,
        defaultWeightEntry: detail.exercise.weightEntry,
        existing: existing,
        seed: resolvedSeed,
        defaultLoadingMode: detail.exercise.preferredLoadingMode,
        effectiveBodyweightKg: effectiveBodyweightKg,
        primaryMuscles: primaryMuscles,
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
          timed: _timedForDetail(detail),
          tracksDistance: detail.exercise.tracksDistance,
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
          timed: _timedForDetail(detail),
          tracksDistance: detail.exercise.tracksDistance,
        );

    if (result.delete && existing != null) {
      await ref.read(setRepositoryProvider).delete(existing.id);
    } else if (existing != null) {
      await ref
          .read(setRepositoryProvider)
          .edit(
            existing.id,
            reps: Value(result.reps),
            weightValue: Value(result.weight),
            unit: Value(result.weight == null ? null : result.unit),
            weightEntry: result.weightEntry,
            sideCount: result.sideCount,
            loadingMode: result.loadingMode,
            distanceMeters: Value(result.distanceMeters),
            durationSec: Value(result.durationSec),
            rpe: Value(result.rpe),
            muscleBiasWeights: Value(result.muscleBiasWeights),
            isWarmup: result.isWarmup,
            notes: Value(result.notes),
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
            muscleBiasWeights: result.muscleBiasWeights,
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
      await _startRestTimer(detail, suggestion: suggestion);
    }
    if (!mounted) return;
    setState(_refresh);
    if (result.delete && existing != null) {
      _showDeletedSetSnackBar(detail, existing);
    }
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
          muscleBiasWeights: seed.muscleBiasWeights,
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
          muscleBiasWeights: decodeMuscleBiasWeights(last.muscleBiasWeights),
          notes: last.notes,
        );
    setState(_refresh);
  }

  Future<void> _reorderSets(
    SessionExerciseDetails detail,
    int oldIndex,
    int newIndex,
  ) async {
    final orderedIds = [for (final set in detail.sets) set.id];
    final moved = orderedIds.removeAt(oldIndex);
    orderedIds.insert(newIndex, moved);
    await ref
        .read(setRepositoryProvider)
        .reorderSets(detail.sessionExercise.id, orderedIds);
    if (!mounted) return;
    setState(_refresh);
  }

  Future<void> _insertSetAbove(
    SessionExerciseDetails detail,
    SetEntry target,
  ) async {
    final seed = await ref
        .read(sessionRepositoryProvider)
        .seedForNextSet(sessionExerciseId: detail.sessionExercise.id);
    await ref
        .read(setRepositoryProvider)
        .insertSetAt(
          sessionExerciseId: detail.sessionExercise.id,
          setNumber: target.setNumber,
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
          muscleBiasWeights: seed.muscleBiasWeights,
        );
    if (!mounted) return;
    setState(_refresh);
  }

  Future<void> _updateInlineSet(
    SessionExerciseDetails detail,
    SetEntry set,
    SetRowDraft draft,
    ProgressionSuggestion? suggestion,
  ) async {
    final timed = _timedForDetail(detail);
    final tracksDistance = detail.exercise.tracksDistance;
    final wasComplete = isSetComplete(
      category: detail.exercise.category,
      loadingMode: set.loadingMode,
      reps: set.reps,
      weightValue: set.weightValue,
      durationSec: set.durationSec,
      distanceMeters: set.distanceMeters,
      timed: timed,
      tracksDistance: tracksDistance,
    );
    final becomesComplete = isSetComplete(
      category: detail.exercise.category,
      loadingMode: set.loadingMode,
      reps: draft.reps,
      weightValue: draft.weightValue,
      durationSec: draft.durationSec,
      distanceMeters: draft.distanceMeters,
      timed: timed,
      tracksDistance: tracksDistance,
    );
    await ref
        .read(setRepositoryProvider)
        .edit(
          set.id,
          reps: Value(draft.reps),
          weightValue: Value(
            set.loadingMode == LoadingMode.bodyweight
                ? null
                : draft.weightValue,
          ),
          unit: Value(
            set.loadingMode == LoadingMode.bodyweight ||
                    draft.weightValue == null
                ? null
                : draft.unit,
          ),
          weightEntry: set.weightEntry,
          sideCount: set.sideCount,
          loadingMode: set.loadingMode,
          distanceMeters: Value(draft.distanceMeters),
          durationSec: Value(draft.durationSec),
          rpe: Value(set.rpe),
          muscleBiasWeights: Value(
            set.muscleBiasWeights == null
                ? null
                : decodeMuscleBiasWeights(set.muscleBiasWeights),
          ),
          isWarmup: set.isWarmup,
          notes: Value(set.notes),
        );
    if (!wasComplete && becomesComplete) {
      await _startRestTimer(detail, suggestion: suggestion);
    }
    if (!mounted) return;
    setState(_refresh);
  }

  Future<void> _startRestTimer(
    SessionExerciseDetails detail, {
    ProgressionSuggestion? suggestion,
  }) async {
    final preferences = await ref
        .read(settingsRepositoryProvider)
        .readRestTimerPreferences();
    // Opt-out for people who log sets after training instead of resting in-app:
    // with auto-start off the countdown bar never appears.
    if (!preferences.autoStartEnabled) return;
    final controller = ref.read(restTimerControllerProvider.notifier);
    final notificationsAllowed = await controller.start(
      sessionId: widget.sessionId,
      seconds: detail.sessionExercise.restSeconds ?? preferences.defaultSeconds,
      notificationsEnabled: preferences.notificationsEnabled,
    );
    if (preferences.notificationsEnabled && !notificationsAllowed) {
      await ref
          .read(settingsRepositoryProvider)
          .setRestTimerNotificationsEnabled(false);
    }
    if (!mounted) return;
    final timerState = ref.read(restTimerControllerProvider);
    if (!timerState.running || timerState.sessionId != widget.sessionId) return;
    // Not awaited: the caller refreshes the set list right after this returns,
    // and awaiting the route would hold that refresh back for the whole rest.
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => RestTimerScreen(
            sessionId: widget.sessionId,
            exerciseName: detail.exercise.name,
            nextSetNumber: _nextSetNumber(detail),
            suggestion: suggestion,
          ),
        ),
      ),
    );
  }

  Future<void> _finish() async {
    final repository = ref.read(sessionRepositoryProvider);
    final session = await repository.getSession(widget.sessionId);
    if (!mounted) return;
    final controller = TextEditingController(text: session?.notes ?? '');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Finish workout?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This marks the session complete.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              minLines: 3,
              decoration: const InputDecoration(
                labelText: 'Workout notes',
                hintText: 'Optional',
              ),
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
            ),
          ],
        ),
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
    final notes = controller.text.trim();
    controller.dispose();
    if (confirm != true) return;
    await repository.finish(
      widget.sessionId,
      notes: notes.isEmpty ? null : notes,
    );
    await ref.read(reminderSchedulerProvider).sync();
    await ref.read(homeWidgetServiceProvider).refresh();
    final prs = recentPrs(
      await ref.read(analyticsRepositoryProvider).loadCompletedSets(),
      limit: 20,
    );
    final currentPr = session == null
        ? null
        : prs.cast<PrEvent?>().firstWhere(
            (event) =>
                event != null &&
                dateOnly(event.date) == dateOnly(session.startedAt),
            orElse: () => null,
          );
    if (mounted && currentPr != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(AppIcons.trophy),
          title: const Text('New personal record'),
          content: Text(
            '${currentPr.exerciseName} · estimated 1RM '
            '${currentPr.oneRepMaxKg.toStringAsFixed(1)} kg',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Nice'),
            ),
          ],
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _openPlateCalculator(_PlateCalculatorRequest request) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => PlateCalculatorSheet(
        exerciseName: request.exerciseName,
        initialTarget: request.targetWeight,
        unit: request.unit,
        inventory: request.inventory,
        perImplement: request.perImplement,
      ),
    );
  }

  Future<void> _previewWarmup(_WarmupRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add warm-up sets?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(request.exerciseName),
              const SizedBox(height: 12),
              for (final warmup in request.warmups) ...[
                Text(
                  '${warmup.label} · '
                  '${_formatWarmupWeight(warmup.weight, request.unit, request.weightEntry)}',
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add sets'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(setRepositoryProvider)
        .insertWarmupSets(
          sessionExerciseId: request.sessionExerciseId,
          warmups: request.warmups,
          unit: request.unit,
          weightEntry: request.weightEntry,
          sideCount: request.sideCount,
          loadingMode: request.loadingMode,
        );
    if (!mounted) return;
    setState(_refresh);
  }

  Future<void> _openExerciseInfo(Exercise exercise) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ExerciseInfoSheet(exercise: exercise),
    );
    if (changed == true && mounted) {
      setState(_refresh);
    }
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
    final trainingGoal =
        ref.watch(coachingPreferencesProvider).asData?.value.trainingGoal ??
        TrainingGoal.build;
    final plateInventory =
        ref.watch(plateInventoryProvider).asData?.value ?? PlateInventory();
    return FutureBuilder<_SessionView>(
      future: _future,
      builder: (context, snapshot) {
        final view = snapshot.data;
        final details = view?.details ?? const <SessionExerciseDetails>[];
        final completed = view?.session?.endedAt != null;
        final sessionNote = view?.session?.notes?.trim();

        return Scaffold(
          appBar: AppBar(
            title: Text(completed ? 'Workout' : 'Active workout'),
            actions: [
              IconButton(
                onPressed: completed ? null : _addForMuscle,
                tooltip: 'Build from a muscle',
                icon: const Icon(AppIcons.progress),
              ),
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
                    : CustomScrollView(
                        slivers: [
                          if (completed &&
                              sessionNote != null &&
                              sessionNote.isNotEmpty)
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              sliver: SliverToBoxAdapter(
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      14,
                                      16,
                                      14,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Workout notes',
                                          style: theme.textTheme.titleSmall,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(sessionNote),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            sliver: SliverReorderableList(
                              itemCount: details.length,
                              onReorder: completed
                                  ? (_, _) {}
                                  : (oldIndex, newIndex) => _reorderExercises(
                                      details,
                                      oldIndex,
                                      newIndex,
                                    ),
                              itemBuilder: (context, index) {
                                final detail = details[index];
                                return _ExerciseCard(
                                  key: ValueKey(detail.sessionExercise.id),
                                  index: index,
                                  reorderable: !completed,
                                  detail: detail,
                                  previousSets:
                                      view?.previousSets[detail
                                          .sessionExercise
                                          .id] ??
                                      const [],
                                  progressionAggressiveness:
                                      trainingGoal.progressionAggressiveness,
                                  inventory: plateInventory,
                                  onAddSet: () => _addSet(detail),
                                  onRepeatSet: () => _repeatSet(detail),
                                  onInlineCommit: (set, draft, suggestion) =>
                                      _updateInlineSet(
                                        detail,
                                        set,
                                        draft,
                                        suggestion,
                                      ),
                                  onEditSet: (set, suggestion) => _openSet(
                                    detail,
                                    existing: set,
                                    suggestion: suggestion,
                                  ),
                                  onMoveSet: _reorderSets,
                                  onInsertSetAbove: _insertSetAbove,
                                  onOpenPlates: _openPlateCalculator,
                                  onOpenWarmup: _previewWarmup,
                                  onSwap: () => _swapExercise(detail),
                                  onRemove: () => _removeExercise(detail),
                                  onOpenInfo: () =>
                                      _openExerciseInfo(detail.exercise),
                                  onEditVideoUrl: () => _editVideoUrl(detail),
                                  onEditPrescription: () =>
                                      _editPrescription(detail),
                                  prescriptionEditable: !completed,
                                );
                              },
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            sliver: SliverToBoxAdapter(
                              child: !completed
                                  ? FilledButton.icon(
                                      onPressed: _finish,
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            theme.colorScheme.secondary,
                                        foregroundColor:
                                            theme.colorScheme.onSecondary,
                                      ),
                                      icon: const Icon(AppIcons.check),
                                      label: const Text('Finish workout'),
                                    )
                                  : const SizedBox.shrink(),
                            ),
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
  const _SessionView({
    required this.session,
    required this.details,
    required this.previousSets,
  });
  final Session? session;
  final List<SessionExerciseDetails> details;
  final Map<int, List<SetEntry>> previousSets;
}

class _PlateCalculatorRequest {
  const _PlateCalculatorRequest({
    required this.exerciseName,
    required this.targetWeight,
    required this.unit,
    required this.inventory,
    required this.perImplement,
  });

  final String exerciseName;
  final double targetWeight;
  final WeightUnit unit;
  final PlateInventory inventory;
  final bool perImplement;
}

class _WarmupRequest {
  const _WarmupRequest({
    required this.sessionExerciseId,
    required this.exerciseName,
    required this.warmups,
    required this.unit,
    required this.weightEntry,
    required this.sideCount,
    required this.loadingMode,
  });

  final int sessionExerciseId;
  final String exerciseName;
  final List<WarmupSet> warmups;
  final WeightUnit unit;
  final WeightEntry weightEntry;
  final int sideCount;
  final LoadingMode loadingMode;
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    super.key,
    required this.index,
    required this.reorderable,
    required this.detail,
    required this.previousSets,
    required this.onAddSet,
    required this.onRepeatSet,
    required this.onInlineCommit,
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
  final ValueChanged<_PlateCalculatorRequest> onOpenPlates;
  final ValueChanged<_WarmupRequest> onOpenWarmup;
  final VoidCallback onRemove;
  final VoidCallback onSwap;
  final VoidCallback onOpenInfo;
  final VoidCallback onEditVideoUrl;
  final VoidCallback onEditPrescription;
  final bool prescriptionEditable;
  final double progressionAggressiveness;
  final PlateInventory inventory;

  Future<void> _openForm(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

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
    // Once this exercise has warm-ups the offer is done: the generator works off
    // the working set, so it would happily produce the same rungs a second time
    // and a stray tap would double-log the whole ramp.
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
                        if (prescriptionEditable || targetText.isNotEmpty) ...[
                          const SizedBox(height: 3),
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
                                    if (prescriptionEditable) ...[
                                      const SizedBox(width: 6),
                                      Icon(
                                        AppIcons.edit,
                                        size: 14,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (previousSets.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          LastPerformanceHint(sets: previousSets),
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
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onOpenInfo,
                    icon: Icon(
                      AppIcons.info,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Exercise info',
                  ),
                  // A per-template link (formUrl) overrides the exercise's own
                  // saved video; either one shows a one-tap play button that
                  // opens in the YouTube app / browser. With no link, an add
                  // button lets you attach one to the exercise on the spot.
                  Builder(
                    builder: (context) {
                      final link =
                          (detail.sessionExercise.formUrl?.isNotEmpty ?? false)
                          ? detail.sessionExercise.formUrl!
                          : (detail.exercise.videoUrl ?? '');
                      if (link.isEmpty) {
                        return IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: onEditVideoUrl,
                          icon: Icon(
                            AppIcons.videoAdd,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          tooltip: 'Add a video link',
                        );
                      }
                      // Long-press edits the exercise's own saved link; a
                      // template override can only be changed in the template.
                      return GestureDetector(
                        onLongPress: (detail.exercise.videoUrl ?? '').isNotEmpty
                            ? onEditVideoUrl
                            : null,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _openForm(link),
                          icon: Icon(
                            AppIcons.play,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          tooltip: 'Play video',
                        ),
                      );
                    },
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
                  if (reorderable)
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          AppIcons.drag,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
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
                    tracksDistance: detail.exercise.tracksDistance,
                    suggestion: set == detail.sets.last ? suggestion : null,
                    onCommit: (draft) => onInlineCommit(
                      set,
                      draft,
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
              const SizedBox(height: 6),
              // Wrap, not Row: these must fall onto a second line at large text
              // scales rather than overflow.
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (plateSupported)
                    TextButton.icon(
                      onPressed: () => onOpenPlates(
                        _PlateCalculatorRequest(
                          exerciseName: detail.exercise.name,
                          targetWeight: plateTarget,
                          unit: headerUnit,
                          inventory: inventory,
                          perImplement: perImplement,
                        ),
                      ),
                      icon: const Icon(AppIcons.plates, size: 18),
                      label: const Text('Plates'),
                    ),
                  if (warmups.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => onOpenWarmup(
                        _WarmupRequest(
                          sessionExerciseId: detail.sessionExercise.id,
                          exerciseName: detail.exercise.name,
                          warmups: warmups,
                          unit: headerUnit,
                          weightEntry: headerWeightEntry,
                          sideCount: headerSideCount,
                          loadingMode: loadingMode,
                        ),
                      ),
                      icon: const Icon(AppIcons.warmup, size: 18),
                      label: const Text('Warm-up'),
                    ),
                  TextButton.icon(
                    onPressed: detail.sets.isEmpty ? null : onRepeatSet,
                    icon: const Icon(AppIcons.refresh, size: 18),
                    label: const Text('Repeat'),
                  ),
                  TextButton.icon(
                    onPressed: onSwap,
                    icon: const Icon(AppIcons.swap, size: 18),
                    label: const Text('Swap'),
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

double? _targetRpe(String? notes) {
  if (notes == null) return null;
  final match = RegExp(
    r'\bRPE\s*([1-9](?:\.\d+)?|10(?:\.0+)?)\b',
    caseSensitive: false,
  ).firstMatch(notes);
  return double.tryParse(match?.group(1) ?? '');
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

String _formatWarmupWeight(
  double value,
  WeightUnit unit,
  WeightEntry weightEntry,
) {
  final label = weightEntry == WeightEntry.perSide ? '/hand' : '';
  return '${_trimPrescription(value)} ${unit.label}$label';
}

String _trimPrescription(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

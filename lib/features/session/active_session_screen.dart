import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../core/widgets/exercise_picker.dart';
import '../../core/widgets/prescription_editor_sheet.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/providers.dart';
import '../settings/reminder_scheduler.dart';
import 'rest_timer_screen.dart';
import 'widgets/active_session_stats_card.dart';
import 'widgets/plate_calculator_sheet.dart';
import 'rest_timer_controller.dart';
import 'widgets/rest_timer_bar.dart';
import 'widgets/session_exercise_card.dart';
import 'widgets/set_editor_sheet.dart';
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
  _RestTimerContext? _restContext;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // Block body, not `=> _future = _loadView()`: an arrow body returns the
  // assignment's value, so a `void`-declared arrow still hands setState a
  // Future and trips its "callback returned a Future" assert. Release builds
  // strip that assert, which is why this only ever bit in debug.
  void _refresh() {
    _future = _loadView();
  }

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
    // No bodyweight history is common on a fresh install; use the spec's
    // fallback baseline rather than hiding calories outright.
    final bodyweightKg = session == null
        ? 75.0
        : await ref
              .read(bodyweightRepositoryProvider)
              .latestOnOrBefore(session.startedAt)
              .then(
                (entry) =>
                    entry == null ? 75.0 : weightKg(entry.value, entry.unit),
              );
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
      bodyweightKg: bodyweightKg,
      previousSets: previousSets,
    );
  }

  Future<Exercise?> _pickExercise({
    required String title,
    List<Exercise>? exercises,
    bool preserveOrder = false,
  }) async {
    final available =
        exercises ?? await ref.read(exerciseRepositoryProvider).all();
    if (!mounted) return null;
    return showExercisePicker(
      context,
      available,
      title: title,
      preserveOrder: preserveOrder,
    );
  }

  Future<void> _addExercise() async {
    await _addExerciseAt();
  }

  Future<void> _addExerciseAt([int? position]) async {
    final exercise = await _pickExercise(
      title: position == null ? 'Add an exercise' : 'Insert an exercise',
    );
    if (exercise == null) return;
    if (position == null) {
      await ref
          .read(sessionRepositoryProvider)
          .addExercise(sessionId: widget.sessionId, exerciseId: exercise.id);
    } else {
      await ref
          .read(sessionRepositoryProvider)
          .addExerciseAt(
            sessionId: widget.sessionId,
            exerciseId: exercise.id,
            position: position,
          );
    }
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
    final exercise = await _pickExercise(
      title: 'Exercises for ${muscle.label}',
      exercises: (index[muscle] ?? const [])
          .map((match) => match.exercise)
          .toList(),
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
    // SnackBar.duration alone isn't reliable here: Android stretches it to the
    // system's accessibility timeout setting, which left "Undo" on screen
    // indefinitely on-device. A long nominal duration plus our own timer
    // guarantees the ~6s we actually want regardless of that OS setting.
    final controller = messenger.showSnackBar(
      SnackBar(
        duration: const Duration(minutes: 10),
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
                    isDone: set.isDone,
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
    Timer(const Duration(seconds: 6), controller.close);
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
    if (!mounted) return;
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
    if (!mounted) return;
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
    if (!mounted) return;
    setState(_refresh);
  }

  /// Ticks a set off, or un-ticks it. Marking one done is the ONLY thing that
  /// starts a rest timer: inferring it from which fields were filled in fired
  /// the countdown the instant a set was added (before the load was even
  /// corrected) and never fired at all for a bodyweight set on an exercise the
  /// app expects to be loaded.
  Future<void> _toggleSetDone(
    SessionExerciseDetails detail,
    SetEntry set,
    ProgressionSuggestion? suggestion,
  ) async {
    final nowDone = !set.isDone;
    await ref.read(setRepositoryProvider).edit(set.id, isDone: nowDone);
    if (!mounted) return;
    if (!nowDone) {
      // Undoing the tick must take back the rest it started, but ONLY that one:
      // un-ticking set 1 while resting after set 3 has to leave set 3's
      // countdown alone, so match on the set that actually started it.
      if (_restContext?.fromSetId == set.id) {
        await ref
            .read(restTimerControllerProvider.notifier)
            .cancel(sessionId: widget.sessionId);
        _restContext = null;
      }
      return;
    }
    // Reread after the write: what comes next depends on this very tick, and
    // the `detail` captured by the row is one edit stale.
    final view = await _future;
    if (!mounted) return;
    final target = nextUpAfter(
      details: view.details,
      sessionExerciseId: detail.sessionExercise.id,
      completedSetNumber: set.setNumber,
    );
    await _startRestTimer(
      detail,
      fromSetId: set.id,
      target: target,
      // The suggestion describes the exercise just finished, so it only still
      // applies while the lifter is staying on it.
      suggestion: target?.sessionExerciseId == detail.sessionExercise.id
          ? suggestion
          : null,
    );
  }

  Future<void> _startRestTimer(
    SessionExerciseDetails detail, {
    required int fromSetId,
    required RestTimerTarget? target,
    ProgressionSuggestion? suggestion,
  }) async {
    // This screen also opens finished sessions — logging a set you missed
    // last Friday must stay editable without popping a rest timer meant for
    // the workout you're doing right now.
    final session = await ref
        .read(sessionRepositoryProvider)
        .getSession(widget.sessionId);
    if (session?.endedAt != null) return;
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
    // Remembered so tapping the minimised bar can reopen the same screen: the
    // timer state carries only a sessionId, not which exercise it was started
    // for, and recomputing that after a minimise would guess.
    _restContext = _RestTimerContext(
      fromSetId: fromSetId,
      exerciseName: target?.exerciseName,
      nextSetNumber: target?.setNumber,
      suggestion: suggestion,
    );
    // Not awaited: the caller refreshes the set list right after this returns,
    // and awaiting the route would hold that refresh back for the whole rest.
    unawaited(_openRestTimerScreen());
  }

  Future<void> _openRestTimerScreen() {
    final context_ = _restContext;
    if (context_ == null) return Future<void>.value();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => RestTimerScreen(
          sessionId: widget.sessionId,
          exerciseName: context_.exerciseName,
          nextSetNumber: context_.nextSetNumber,
          suggestion: context_.suggestion,
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

  /// Opens the per-template `formUrl` when the template overrides it, else the
  /// exercise's own saved video. Moved off the card when the inline play button
  /// went into the overflow menu.
  Future<void> _playExerciseVideo(SessionExerciseDetails detail) async {
    final link = (detail.sessionExercise.formUrl?.isNotEmpty ?? false)
        ? detail.sessionExercise.formUrl!
        : (detail.exercise.videoUrl ?? '');
    final uri = Uri.tryParse(link);
    if (uri == null || link.isEmpty) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  Future<void> _renameWorkout(String? currentTitle) async {
    final controller = TextEditingController(text: currentTitle ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename workout'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(hintText: 'e.g. Push day'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    await ref
        .read(sessionRepositoryProvider)
        .updateTitle(widget.sessionId, result);
    if (!mounted) return;
    setState(_refresh);
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
        final sessionTitle = view?.session?.title?.trim();
        final displayTitle = sessionTitle != null && sessionTitle.isNotEmpty
            ? sessionTitle
            : (completed ? 'Workout' : 'Active workout');

        return Scaffold(
          appBar: AppBar(
            title: Text(displayTitle),
            actions: [
              IconButton(
                onPressed: completed ? null : _addForMuscle,
                tooltip: 'Build from a muscle',
                icon: const Icon(AppIcons.progress),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'rename') _renameWorkout(sessionTitle);
                  if (value == 'delete') _deleteWorkout();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('Rename workout'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete workout'),
                  ),
                ],
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RestTimerBar(
                  sessionId: widget.sessionId,
                  onTap: _restContext == null
                      ? null
                      : () => unawaited(_openRestTimerScreen()),
                ),
                if (!completed) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _finish,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: theme.colorScheme.onSecondary,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(AppIcons.check),
                    label: const Text('Finish workout'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _addExercise,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(AppIcons.add),
                    label: const Text('Add exercise'),
                  ),
                ],
              ],
            ),
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
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            sliver: SliverToBoxAdapter(
                              child: ActiveSessionStatsCard(
                                session: view?.session,
                                details: details,
                                bodyweightKg: view?.bodyweightKg ?? 75,
                              ),
                            ),
                          ),
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
                                return SessionExerciseCard(
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
                                  onToggleSetDone: (set, suggestion) =>
                                      _toggleSetDone(detail, set, suggestion),
                                  onEditSet: (set, suggestion) => _openSet(
                                    detail,
                                    existing: set,
                                    suggestion: suggestion,
                                  ),
                                  onMoveSet: _reorderSets,
                                  onInsertSetAbove: _insertSetAbove,
                                  onOpenPlates:
                                      ({
                                        required exerciseName,
                                        required targetWeight,
                                        required unit,
                                        required perImplement,
                                      }) => _openPlateCalculator(
                                        _PlateCalculatorRequest(
                                          exerciseName: exerciseName,
                                          targetWeight: targetWeight,
                                          unit: unit,
                                          inventory: plateInventory,
                                          perImplement: perImplement,
                                        ),
                                      ),
                                  onOpenWarmup:
                                      ({
                                        required sessionExerciseId,
                                        required exerciseName,
                                        required warmups,
                                        required unit,
                                        required weightEntry,
                                        required sideCount,
                                        required loadingMode,
                                      }) => _previewWarmup(
                                        _WarmupRequest(
                                          sessionExerciseId: sessionExerciseId,
                                          exerciseName: exerciseName,
                                          warmups: warmups,
                                          unit: unit,
                                          weightEntry: weightEntry,
                                          sideCount: sideCount,
                                          loadingMode: loadingMode,
                                        ),
                                      ),
                                  onSwap: () => _swapExercise(detail),
                                  onRemove: () => _removeExercise(detail),
                                  onOpenInfo: () =>
                                      _openExerciseInfo(detail.exercise),
                                  onEditVideoUrl: () => _editVideoUrl(detail),
                                  onEditPrescription: () =>
                                      _editPrescription(detail),
                                  onOverflowAction: (action) {
                                    switch (action) {
                                      case SessionExerciseOverflowAction.info:
                                        _openExerciseInfo(detail.exercise);
                                        return;
                                      case SessionExerciseOverflowAction.video:
                                        unawaited(_playExerciseVideo(detail));
                                        return;
                                      case SessionExerciseOverflowAction
                                          .editVideo:
                                        _editVideoUrl(detail);
                                        return;
                                      case SessionExerciseOverflowAction
                                          .addAbove:
                                        unawaited(_addExerciseAt(index));
                                        return;
                                      case SessionExerciseOverflowAction
                                          .addBelow:
                                        unawaited(_addExerciseAt(index + 1));
                                        return;
                                      case SessionExerciseOverflowAction.warmup:
                                        final firstSet = detail.sets.isEmpty
                                            ? null
                                            : detail.sets.first;
                                        final headerUnit =
                                            firstSet?.unit ??
                                            detail.exercise.defaultUnit;
                                        final headerWeightEntry =
                                            firstSet?.weightEntry ??
                                            detail.exercise.weightEntry;
                                        final headerSideCount =
                                            firstSet?.sideCount ??
                                            detail
                                                .sessionExercise
                                                .sidesPerSet ??
                                            1;
                                        final loadingMode =
                                            firstSet?.loadingMode ??
                                            detail
                                                .exercise
                                                .preferredLoadingMode;
                                        final workingWeight =
                                            _latestWorkingWeight(
                                              detail.sets,
                                              loadingMode: loadingMode,
                                            );
                                        if (workingWeight == null) return;
                                        final warmups = generateWarmup(
                                          workingWeight: workingWeight,
                                          unit: headerUnit,
                                          inventory: plateInventory,
                                          workingReps:
                                              detail.sessionExercise.maxReps ??
                                              detail.sessionExercise.minReps,
                                          loadingMode: loadingMode,
                                          perImplement:
                                              headerWeightEntry ==
                                              WeightEntry.perSide,
                                        );
                                        if (warmups.isEmpty) return;
                                        unawaited(
                                          _previewWarmup(
                                            _WarmupRequest(
                                              sessionExerciseId:
                                                  detail.sessionExercise.id,
                                              exerciseName:
                                                  detail.exercise.name,
                                              warmups: warmups,
                                              unit: headerUnit,
                                              weightEntry: headerWeightEntry,
                                              sideCount: headerSideCount,
                                              loadingMode: loadingMode,
                                            ),
                                          ),
                                        );
                                        return;
                                      case SessionExerciseOverflowAction.remove:
                                        unawaited(_removeExercise(detail));
                                        return;
                                    }
                                  },
                                  prescriptionEditable: !completed,
                                );
                              },
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 180),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// What the full-screen rest timer needs beyond the timer state itself, kept so
/// a minimised timer can be reopened showing the same next-set context.
class _RestTimerContext {
  const _RestTimerContext({
    required this.fromSetId,
    required this.exerciseName,
    required this.nextSetNumber,
    required this.suggestion,
  });

  /// The set whose tick started this rest, so undoing that tick can take the
  /// countdown back without touching a rest some other set started.
  final int fromSetId;

  /// Null once there is nothing left to log — the timer then says so instead
  /// of naming the exercise that was just finished.
  final String? exerciseName;
  final int? nextSetNumber;
  final ProgressionSuggestion? suggestion;
}

/// Where the lifter goes once a set is ticked off, used to label the rest
/// timer. Null means the session has nothing left to log.
typedef RestTimerTarget = ({
  int sessionExerciseId,
  String exerciseName,
  int setNumber,
});

/// Resolves the exercise and set the lifter faces after finishing
/// [completedSetNumber] of [sessionExerciseId].
///
/// Stays on the same exercise while it still owes work — an unticked set, or a
/// prescribed set that has not been created yet — and otherwise moves on to the
/// next exercise in the session. Naming the exercise just finished (which is
/// what a fresh `_nextSetNumber` did) is wrong precisely when it matters most:
/// on the last set, when what the lifter needs to know is what comes next.
RestTimerTarget? nextUpAfter({
  required List<SessionExerciseDetails> details,
  required int sessionExerciseId,
  required int completedSetNumber,
}) {
  final index = details.indexWhere(
    (detail) => detail.sessionExercise.id == sessionExerciseId,
  );
  if (index < 0) return null;
  final detail = details[index];

  // Only sets *after* the one just finished: an earlier row left unticked
  // (a warm-up the lifter never ticked off) is behind them, not next.
  final pending = _lowestPendingSetNumber(detail, after: completedSetNumber);
  if (pending != null) {
    return (
      sessionExerciseId: sessionExerciseId,
      exerciseName: detail.exercise.name,
      setNumber: pending,
    );
  }
  // Every logged set is ticked, but the prescription may still owe rows that
  // have not been created yet. Warm-ups do not count against the target.
  final workingSets = detail.sets.where((set) => !set.isWarmup).length;
  if (workingSets < (detail.sessionExercise.targetSets ?? 0)) {
    return (
      sessionExerciseId: sessionExerciseId,
      exerciseName: detail.exercise.name,
      setNumber: completedSetNumber + 1,
    );
  }
  for (final next in details.skip(index + 1)) {
    return (
      sessionExerciseId: next.sessionExercise.id,
      exerciseName: next.exercise.name,
      setNumber: _lowestPendingSetNumber(next) ?? 1,
    );
  }
  return null;
}

int? _lowestPendingSetNumber(SessionExerciseDetails detail, {int after = 0}) =>
    detail.sets
        .where((set) => !set.isDone && set.setNumber > after)
        .fold<int?>(
          null,
          (lowest, set) =>
              lowest == null || set.setNumber < lowest ? set.setNumber : lowest,
        );

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
    required this.bodyweightKg,
    required this.previousSets,
  });
  final Session? session;
  final List<SessionExerciseDetails> details;
  final double bodyweightKg;
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

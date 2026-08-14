import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_icons.dart';
import '../../core/domain/muscle.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/prescription_editor_sheet.dart';
import '../../core/widgets/exercise_picker.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';

class TemplateEditorScreen extends ConsumerStatefulWidget {
  const TemplateEditorScreen({super.key, required this.template});
  final Template template;

  @override
  ConsumerState<TemplateEditorScreen> createState() =>
      _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  late Future<void> _loadFuture;
  late String _name = widget.template.name;
  List<_TemplateExerciseDraft> _selected = [];
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<void> _load() async {
    final details = await ref
        .read(templateRepositoryProvider)
        .exerciseDetails(widget.template.id);
    _selected = [
      for (final detail in details)
        _TemplateExerciseDraft.fromTemplateExercise(
          detail.exercise,
          detail.templateExercise,
        ),
    ];
  }

  Future<void> _save() async {
    await ref
        .read(templateRepositoryProvider)
        .replaceExerciseDetails(widget.template.id, [
          for (var index = 0; index < _selected.length; index++)
            _selected[index].toCompanion(
              templateId: widget.template.id,
              position: index,
            ),
        ]);
    if (mounted) {
      _dirty = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Template saved.')));
      Navigator.pop(context);
    }
  }

  Future<void> _add() async {
    final all = await ref.read(exerciseRepositoryProvider).all();
    if (!mounted) return;
    final exercise = await showExercisePicker(
      context,
      all,
      title: 'Add to template',
    );
    if (exercise != null) {
      setState(() {
        _selected.add(_TemplateExerciseDraft(exercise: exercise));
        _dirty = true;
      });
    }
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
    setState(() {
      _selected.add(_TemplateExerciseDraft(exercise: exercise));
      _dirty = true;
    });
  }

  Future<void> _swap(_TemplateExerciseDraft draft) async {
    final primary = decodeMuscleIds(draft.exercise.primaryMuscles);
    if (primary.isEmpty) return;
    final index = await ref.read(muscleExerciseIndexProvider).build();
    if (!mounted) return;
    final exercise = await showExercisePicker(
      context,
      (index[primary.first] ?? const [])
          .map((match) => match.exercise)
          .where((exercise) => exercise.id != draft.exercise.id)
          .toList(),
      title: 'Swap for ${primary.first.label}',
      preserveOrder: true,
    );
    if (exercise == null) return;
    setState(() {
      final index = _selected.indexOf(draft);
      if (index != -1) {
        _selected[index] = draft.copyWith(exercise: exercise);
        _dirty = true;
      }
    });
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename template'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == _name) return;
    await ref.read(templateRepositoryProvider).rename(widget.template.id, name);
    if (mounted) setState(() => _name = name);
  }

  Future<void> _edit(_TemplateExerciseDraft draft) async {
    final updated = await showModalBottomSheet<ExercisePrescriptionValues>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => PrescriptionEditorSheet(
        exerciseName: draft.exercise.name,
        initialValues: draft.prescriptionValues,
      ),
    );
    if (updated == null) return;
    setState(() {
      final index = _selected.indexOf(draft);
      if (index != -1) _selected[index] = draft.copyWithPrescription(updated);
      _dirty = true;
    });
  }

  Future<void> _openForm(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _rename,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(AppIcons.edit, size: 17),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _addForMuscle,
            tooltip: 'Build from a muscle',
            icon: const Icon(AppIcons.progress),
          ),
          if (_dirty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(onPressed: _save, child: const Text('Save')),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(AppIcons.add),
        label: const Text('Add exercise'),
      ),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_selected.isEmpty) {
            return EmptyState(
              icon: AppIcons.add,
              title: 'Empty template',
              message: 'Add exercises, then drag to reorder them.',
              action: FilledButton.icon(
                onPressed: _add,
                icon: const Icon(AppIcons.add),
                label: const Text('Add exercise'),
              ),
            );
          }
          return ReorderableListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            onReorder: (oldIndex, newIndex) => setState(() {
              if (newIndex > oldIndex) newIndex--;
              final item = _selected.removeAt(oldIndex);
              _selected.insert(newIndex, item);
              _dirty = true;
            }),
            children: [
              for (final item in _selected)
                Padding(
                  key: ValueKey(item.localKey),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Icon(
                            iconForCategoryName(item.exercise.category.name),
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.exercise.name,
                                style: theme.textTheme.titleMedium,
                              ),
                              if (item.targetText.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  item.targetText,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if ((item.prescriptionNotes ?? '')
                                  .isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  item.prescriptionNotes!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if ((item.formUrl ?? '').isNotEmpty)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(AppIcons.play),
                            tooltip: 'Open form video',
                            onPressed: () => _openForm(item.formUrl!),
                          ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(AppIcons.swap),
                          tooltip: 'Swap exercise',
                          onPressed: () => _swap(item),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(AppIcons.edit),
                          tooltip: 'Edit prescription',
                          onPressed: () => _edit(item),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            AppIcons.close,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => setState(() {
                            _selected.remove(item);
                            _dirty = true;
                          }),
                        ),
                        ReorderableDragStartListener(
                          index: _selected.indexOf(item),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              AppIcons.drag,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TemplateExerciseDraft {
  _TemplateExerciseDraft({
    required this.exercise,
    this.targetSets,
    this.sidesPerSet,
    this.minReps,
    this.maxReps,
    this.targetDurationSec,
    this.targetDistanceMeters,
    this.restSeconds,
    this.eccentricSec,
    this.bottomPauseSec,
    this.concentricSec,
    this.topPauseSec,
    this.prescriptionNotes,
    this.formUrl,
    Object? localKey,
  }) : localKey = localKey ?? Object();

  factory _TemplateExerciseDraft.fromTemplateExercise(
    Exercise exercise,
    TemplateExercise templateExercise,
  ) => _TemplateExerciseDraft(
    exercise: exercise,
    targetSets: templateExercise.targetSets,
    sidesPerSet: templateExercise.sidesPerSet,
    minReps: templateExercise.minReps,
    maxReps: templateExercise.maxReps,
    targetDurationSec: templateExercise.targetDurationSec,
    targetDistanceMeters: templateExercise.targetDistanceMeters,
    restSeconds: templateExercise.restSeconds,
    eccentricSec: templateExercise.eccentricSec,
    bottomPauseSec: templateExercise.bottomPauseSec,
    concentricSec: templateExercise.concentricSec,
    topPauseSec: templateExercise.topPauseSec,
    prescriptionNotes: templateExercise.prescriptionNotes,
    formUrl: templateExercise.formUrl,
    localKey: templateExercise.id,
  );

  final Exercise exercise;
  final int? targetSets;
  final int? sidesPerSet;
  final int? minReps;
  final int? maxReps;
  final int? targetDurationSec;
  final double? targetDistanceMeters;
  final int? restSeconds;
  final int? eccentricSec;
  final int? bottomPauseSec;
  final int? concentricSec;
  final int? topPauseSec;
  final String? prescriptionNotes;
  final String? formUrl;
  final Object localKey;

  ExercisePrescriptionValues get prescriptionValues =>
      ExercisePrescriptionValues(
        targetSets: targetSets,
        sidesPerSet: sidesPerSet,
        minReps: minReps,
        maxReps: maxReps,
        targetDurationSec: targetDurationSec,
        targetDistanceMeters: targetDistanceMeters,
        restSeconds: restSeconds,
        eccentricSec: eccentricSec,
        bottomPauseSec: bottomPauseSec,
        concentricSec: concentricSec,
        topPauseSec: topPauseSec,
        prescriptionNotes: prescriptionNotes,
        formUrl: formUrl,
      );

  String get targetText => formatPrescription(
    targetSets: targetSets,
    sidesPerSet: sidesPerSet,
    minReps: minReps,
    maxReps: maxReps,
    targetDurationSec: targetDurationSec,
    targetDistanceMeters: targetDistanceMeters,
    restSeconds: restSeconds,
    eccentricSec: eccentricSec,
    bottomPauseSec: bottomPauseSec,
    concentricSec: concentricSec,
    topPauseSec: topPauseSec,
  );

  _TemplateExerciseDraft copyWith({
    Exercise? exercise,
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
    String? prescriptionNotes,
    String? formUrl,
  }) => _TemplateExerciseDraft(
    exercise: exercise ?? this.exercise,
    targetSets: targetSets,
    sidesPerSet: sidesPerSet,
    minReps: minReps,
    maxReps: maxReps,
    targetDurationSec: targetDurationSec,
    targetDistanceMeters: targetDistanceMeters,
    restSeconds: restSeconds,
    eccentricSec: eccentricSec,
    bottomPauseSec: bottomPauseSec,
    concentricSec: concentricSec,
    topPauseSec: topPauseSec,
    prescriptionNotes: prescriptionNotes,
    formUrl: formUrl,
    localKey: localKey,
  );

  _TemplateExerciseDraft copyWithPrescription(
    ExercisePrescriptionValues values,
  ) => copyWith(
    targetSets: values.targetSets,
    sidesPerSet: values.sidesPerSet,
    minReps: values.minReps,
    maxReps: values.maxReps,
    targetDurationSec: values.targetDurationSec,
    targetDistanceMeters: values.targetDistanceMeters,
    restSeconds: values.restSeconds,
    eccentricSec: values.eccentricSec,
    bottomPauseSec: values.bottomPauseSec,
    concentricSec: values.concentricSec,
    topPauseSec: values.topPauseSec,
    prescriptionNotes: values.prescriptionNotes,
    formUrl: values.formUrl,
  );

  TemplateExercisesCompanion toCompanion({
    required int templateId,
    required int position,
  }) => TemplateExercisesCompanion.insert(
    templateId: templateId,
    exerciseId: exercise.id,
    position: position,
    targetSets: Value(targetSets),
    sidesPerSet: Value(sidesPerSet),
    minReps: Value(minReps),
    maxReps: Value(maxReps),
    targetDurationSec: Value(targetDurationSec),
    targetDistanceMeters: Value(targetDistanceMeters),
    restSeconds: Value(restSeconds),
    eccentricSec: Value(eccentricSec),
    bottomPauseSec: Value(bottomPauseSec),
    concentricSec: Value(concentricSec),
    topPauseSec: Value(topPauseSec),
    prescriptionNotes: Value(prescriptionNotes),
    formUrl: Value(formUrl),
  );
}

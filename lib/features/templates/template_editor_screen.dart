import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_icons.dart';
import '../../core/domain/muscle.dart';
import '../../core/widgets/app_widgets.dart';
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
    final updated = await showModalBottomSheet<_TemplateExerciseDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _PrescriptionEditor(draft: draft),
    );
    if (updated == null) return;
    setState(() {
      final index = _selected.indexOf(draft);
      if (index != -1) _selected[index] = updated;
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
                      borderRadius: BorderRadius.circular(16),
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

class _PrescriptionEditor extends StatefulWidget {
  const _PrescriptionEditor({required this.draft});
  final _TemplateExerciseDraft draft;

  @override
  State<_PrescriptionEditor> createState() => _PrescriptionEditorState();
}

class _PrescriptionEditorState extends State<_PrescriptionEditor> {
  late final TextEditingController _sets = TextEditingController(
    text: widget.draft.targetSets?.toString() ?? '',
  );
  late bool _eachSide = widget.draft.sidesPerSet == 2;
  late final TextEditingController _minReps = TextEditingController(
    text: widget.draft.minReps?.toString() ?? '',
  );
  late final TextEditingController _maxReps = TextEditingController(
    text: widget.draft.maxReps?.toString() ?? '',
  );
  late final TextEditingController _duration = TextEditingController(
    text: widget.draft.targetDurationSec?.toString() ?? '',
  );
  late final TextEditingController _distance = TextEditingController(
    text: widget.draft.targetDistanceMeters?.toString() ?? '',
  );
  late final TextEditingController _rest = TextEditingController(
    text: widget.draft.restSeconds?.toString() ?? '',
  );
  late final TextEditingController _eccentric = TextEditingController(
    text: widget.draft.eccentricSec?.toString() ?? '',
  );
  late final TextEditingController _bottomPause = TextEditingController(
    text: widget.draft.bottomPauseSec?.toString() ?? '',
  );
  late final TextEditingController _concentric = TextEditingController(
    text: widget.draft.concentricSec?.toString() ?? '',
  );
  late final TextEditingController _topPause = TextEditingController(
    text: widget.draft.topPauseSec?.toString() ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.draft.prescriptionNotes ?? '',
  );
  late final TextEditingController _formUrl = TextEditingController(
    text: widget.draft.formUrl ?? '',
  );

  @override
  void dispose() {
    _sets.dispose();
    _minReps.dispose();
    _maxReps.dispose();
    _duration.dispose();
    _distance.dispose();
    _rest.dispose();
    _eccentric.dispose();
    _bottomPause.dispose();
    _concentric.dispose();
    _topPause.dispose();
    _notes.dispose();
    _formUrl.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      widget.draft.copyWith(
        targetSets: _intOrNull(_sets.text),
        sidesPerSet: _eachSide ? 2 : null,
        minReps: _intOrNull(_minReps.text),
        maxReps: _intOrNull(_maxReps.text),
        targetDurationSec: _intOrNull(_duration.text),
        targetDistanceMeters: _doubleOrNull(_distance.text),
        restSeconds: _intOrNull(_rest.text),
        eccentricSec: _intOrNull(_eccentric.text),
        bottomPauseSec: _intOrNull(_bottomPause.text),
        concentricSec: _intOrNull(_concentric.text),
        topPauseSec: _intOrNull(_topPause.text),
        prescriptionNotes: _blankToNull(_notes.text),
        formUrl: _blankToNull(_formUrl.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 20),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            widget.draft.exercise.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _field(_sets, 'Sets')),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text('Each side'),
                selected: _eachSide,
                onSelected: (value) => setState(() => _eachSide = value),
              ),
              const SizedBox(width: 10),
              Expanded(child: _field(_minReps, 'Min reps')),
              const SizedBox(width: 10),
              Expanded(child: _field(_maxReps, 'Max reps')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _field(_duration, 'Duration sec')),
              const SizedBox(width: 10),
              Expanded(child: _field(_rest, 'Rest sec')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _field(_eccentric, 'Eccentric')),
              const SizedBox(width: 10),
              Expanded(child: _field(_bottomPause, 'Bottom pause')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _field(_concentric, 'Concentric')),
              const SizedBox(width: 10),
              Expanded(child: _field(_topPause, 'Top pause')),
            ],
          ),
          const SizedBox(height: 10),
          _field(_distance, 'Distance meters'),
          const SizedBox(height: 10),
          _field(
            _formUrl,
            'YouTube / form URL',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notes / cues'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.number,
  }) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: label),
  );

  int? _intOrNull(String value) => int.tryParse(value.trim());
  double? _doubleOrNull(String value) => double.tryParse(value.trim());
  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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

String formatPrescription({
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
      '${_formatDuration(targetDurationSec)}${eachSide ? ' each side' : ''}',
    );
  }
  if (targetDistanceMeters != null) {
    parts.add(
      '${_formatDistance(targetDistanceMeters)}${eachSide ? ' each side' : ''}',
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
  if (restSeconds != null) parts.add('${_formatDuration(restSeconds)} rest');
  return parts.join(' · ');
}

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  if (minutes <= 0) return '${seconds}s';
  return remaining == 0 ? '${minutes}m' : '${minutes}m ${remaining}s';
}

String _formatDistance(double meters) {
  if (meters >= 1000) return '${_trim(meters / 1000)} km';
  return '${_trim(meters)} m';
}

String _trim(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

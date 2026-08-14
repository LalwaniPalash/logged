import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_icons.dart';
import '../../../core/widgets/exercise_picker.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/template_repository.dart';
import '../template_editor_screen.dart';
import 'program_parser.dart';

class ProgramImportScreen extends ConsumerStatefulWidget {
  const ProgramImportScreen({super.key});

  @override
  ConsumerState<ProgramImportScreen> createState() =>
      _ProgramImportScreenState();
}

class _ProgramImportScreenState extends ConsumerState<ProgramImportScreen> {
  final _source = TextEditingController();
  ProgramParseResult? _result;
  List<Exercise> _library = const [];
  final _mappedIds = <String, int?>{};
  final _createCustom = <String>{};
  bool _importing = false;

  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
      withData: true,
    );
    final file = picked?.files.singleOrNull;
    if (file == null) return;
    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null || !mounted) return;
    _source.text = utf8.decode(bytes, allowMalformed: true);
    await _parse();
  }

  Future<void> _parse() async {
    final result = parseProgram(_source.text);
    final library = await ref.read(exerciseRepositoryProvider).all();
    final available = library
        .where((exercise) => !exercise.isArchived)
        .toList();
    final byName = {for (final exercise in available) exercise.name: exercise};
    final mappings = <String, int?>{};
    for (final name in result.rows.map((row) => row.exercise).toSet()) {
      final match = fuzzyMatchExercise(name, byName.keys);
      mappings[name] = match == null ? null : byName[match.name]?.id;
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      _library = available;
      _mappedIds
        ..clear()
        ..addAll(mappings);
      _createCustom.clear();
    });
  }

  Future<void> _chooseMapping(String sourceName) async {
    final chosen = await showExercisePicker(
      context,
      _library,
      title: 'Map “$sourceName”',
    );
    if (chosen == null) return;
    setState(() {
      _mappedIds[sourceName] = chosen.id;
      _createCustom.remove(sourceName);
    });
  }

  bool get _canImport {
    final result = _result;
    if (result == null || result.rows.isEmpty || _importing) return false;
    return result.rows.every(
      (row) =>
          _mappedIds[row.exercise] != null ||
          _createCustom.contains(row.exercise),
    );
  }

  Future<void> _import() async {
    if (!_canImport) return;
    setState(() => _importing = true);
    try {
      final templates = await ref
          .read(templateRepositoryProvider)
          .importProgram([
            for (final row in _result!.rows)
              ProgramImportExercise(
                day: row.day,
                exerciseName: row.exercise,
                exerciseId: _mappedIds[row.exercise],
                createCustom: _createCustom.contains(row.exercise),
                targetSets: row.sets,
                minReps: row.minReps,
                maxReps: row.maxReps,
                targetDurationSec: row.targetDurationSec,
                targetDistanceMeters: row.targetDistanceMeters,
                sidesPerSet: row.sidesPerSet,
                restSeconds: row.restSeconds,
                rpe: row.rpe,
                notes: row.notes,
              ),
          ]);
      if (!mounted) return;
      if (templates.isNotEmpty) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TemplateEditorScreen(template: templates.first),
          ),
        );
      } else {
        Navigator.pop(context);
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Import program')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        children: [
          Text('CSV columns', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          const SelectableText(
            'day,exercise,sets,min_reps,max_reps,duration_sec,distance_m,'
            'sides,rest_sec,rpe,notes',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _source,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(
              hintText: 'Paste CSV here…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(AppIcons.import),
                label: const Text('Choose file'),
              ),
              FilledButton.icon(
                onPressed: _parse,
                icon: const Icon(AppIcons.check),
                label: const Text('Parse and map'),
              ),
            ],
          ),
          if (result != null) ...[
            const SizedBox(height: 20),
            if (result.errors.isNotEmpty)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${result.errors.length} row ${result.errors.length == 1 ? 'issue' : 'issues'}',
                        style: theme.textTheme.titleSmall,
                      ),
                      for (final error in result.errors)
                        Text('Row ${error.rowNumber}: ${error.message}'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text('Exercise mapping', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            for (final sourceName
                in result.rows.map((row) => row.exercise).toSet())
              _MappingTile(
                sourceName: sourceName,
                mapped: _library
                    .where((exercise) => exercise.id == _mappedIds[sourceName])
                    .firstOrNull,
                createCustom: _createCustom.contains(sourceName),
                onChoose: () => _chooseMapping(sourceName),
                onCreateChanged: (value) => setState(() {
                  if (value) {
                    _createCustom.add(sourceName);
                    _mappedIds[sourceName] = null;
                  } else {
                    _createCustom.remove(sourceName);
                  }
                }),
              ),
            const SizedBox(height: 18),
            Text('Preview', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            for (final day in result.rows.map((row) => row.day).toSet())
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(day, style: theme.textTheme.titleMedium),
                      for (final row in result.rows.where(
                        (row) => row.day == day,
                      ))
                        Text(
                          '${row.exercise} · ${row.sets} sets'
                          '${row.minReps == null ? '' : ' · ${row.minReps}–${row.maxReps ?? row.minReps} reps'}',
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _canImport ? _import : null,
          icon: _importing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(AppIcons.import),
          label: const Text('Import templates'),
        ),
      ),
    );
  }
}

class _MappingTile extends StatelessWidget {
  const _MappingTile({
    required this.sourceName,
    required this.mapped,
    required this.createCustom,
    required this.onChoose,
    required this.onCreateChanged,
  });

  final String sourceName;
  final Exercise? mapped;
  final bool createCustom;
  final VoidCallback onChoose;
  final ValueChanged<bool> onCreateChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(sourceName),
            subtitle: Text(
              createCustom
                  ? 'Create custom exercise'
                  : mapped?.name ?? 'Mapping required',
            ),
            trailing: TextButton(
              onPressed: onChoose,
              child: Text(mapped == null ? 'Choose' : 'Change'),
            ),
          ),
          CheckboxListTile(
            value: createCustom,
            onChanged: (value) => onCreateChanged(value ?? false),
            title: const Text('Create as a custom exercise'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }
}

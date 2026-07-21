import 'package:flutter/material.dart';

import '../../../core/app_icons.dart';
import '../../../core/domain/enums.dart';
import '../../../core/domain/workout_metrics.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/session_repository.dart';

class SetEditorResult {
  const SetEditorResult({
    required this.reps,
    required this.weight,
    required this.unit,
    required this.weightEntry,
    required this.loadingMode,
    required this.distanceMeters,
    required this.durationSec,
    required this.sideCount,
    required this.rpe,
    required this.isWarmup,
    required this.notes,
    this.delete = false,
  });

  final int? reps;
  final double? weight;
  final WeightUnit unit;
  final WeightEntry weightEntry;
  final LoadingMode loadingMode;
  final double? distanceMeters;
  final int? durationSec;
  final int sideCount;
  final double? rpe;
  final bool isWarmup;
  final String? notes;
  final bool delete;
}

class SetEditorSheet extends StatefulWidget {
  const SetEditorSheet({
    super.key,
    required this.exerciseName,
    required this.defaultUnit,
    required this.defaultWeightEntry,
    required this.defaultLoadingMode,
    required this.existing,
    required this.seed,
    required this.effectiveBodyweightKg,
  });

  final String exerciseName;
  final WeightUnit defaultUnit;
  final WeightEntry defaultWeightEntry;
  final LoadingMode defaultLoadingMode;
  final SetEntry? existing;
  final SetSeed? seed;
  final double? effectiveBodyweightKg;

  @override
  State<SetEditorSheet> createState() => _SetEditorSheetState();
}

class _SetEditorSheetState extends State<SetEditorSheet> {
  late final TextEditingController _reps = TextEditingController(
    text: (widget.existing?.reps ?? widget.seed?.reps)?.toString() ?? '',
  );
  late final TextEditingController _weight = TextEditingController(
    text:
        (widget.existing?.weightValue ?? widget.seed?.weightValue)
            ?.toString() ??
        '',
  );
  late final TextEditingController _rpe = TextEditingController(
    text: widget.existing?.rpe?.toString() ?? '',
  );
  late final TextEditingController _duration = TextEditingController(
    text:
        (widget.existing?.durationSec ?? widget.seed?.durationSec)
            ?.toString() ??
        '',
  );
  late final TextEditingController _distance = TextEditingController(
    text:
        (widget.existing?.distanceMeters ?? widget.seed?.distanceMeters)
            ?.toString() ??
        '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.existing?.notes ?? '',
  );
  late WeightUnit _unit =
      widget.existing?.unit ?? widget.seed?.unit ?? widget.defaultUnit;
  late WeightEntry _weightEntry =
      widget.existing?.weightEntry ??
      widget.seed?.weightEntry ??
      widget.defaultWeightEntry;
  late LoadingMode _loadingMode =
      widget.existing?.loadingMode ??
      widget.seed?.loadingMode ??
      widget.defaultLoadingMode;
  late bool _warmup = widget.existing?.isWarmup ?? false;
  late bool _eachSide =
      (widget.existing?.sideCount ?? widget.seed?.sideCount ?? 1) > 1;
  String? _errorText;

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    _rpe.dispose();
    _duration.dispose();
    _distance.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final parsedWeight = double.tryParse(_weight.text);
    if (_loadingMode == LoadingMode.bodyweightAssisted &&
        parsedWeight != null &&
        widget.effectiveBodyweightKg != null &&
        totalLoadKg(parsedWeight, _unit, _weightEntry) >=
            widget.effectiveBodyweightKg!) {
      setState(() {
        _errorText =
            'Assistance must be less than effective bodyweight resistance.';
      });
      return;
    }
    Navigator.pop(
      context,
      SetEditorResult(
        reps: int.tryParse(_reps.text),
        weight: _loadingMode == LoadingMode.bodyweight ? null : parsedWeight,
        unit: _unit,
        weightEntry: _weightEntry,
        loadingMode: _loadingMode,
        distanceMeters: double.tryParse(_distance.text),
        durationSec: int.tryParse(_duration.text),
        sideCount: _eachSide ? 2 : 1,
        rpe: double.tryParse(_rpe.text),
        isWarmup: _warmup,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            editing ? 'Edit set' : 'Add set',
            style: theme.textTheme.titleLarge,
          ),
          Text(
            widget.exerciseName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _reps,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reps'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: _loadingMode.label),
                  enabled: _loadingMode != LoadingMode.bodyweight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<LoadingMode>(
            segments: const [
              ButtonSegment(value: LoadingMode.external, label: Text('Weight')),
              ButtonSegment(
                value: LoadingMode.bodyweight,
                label: Text('Bodyweight'),
              ),
              ButtonSegment(
                value: LoadingMode.bodyweightAdded,
                label: Text('Added'),
              ),
              ButtonSegment(
                value: LoadingMode.bodyweightAssisted,
                label: Text('Assist'),
              ),
            ],
            selected: {_loadingMode},
            onSelectionChanged: (value) => setState(() {
              _loadingMode = value.single;
              if (_loadingMode == LoadingMode.bodyweight) _weight.clear();
            }),
          ),
          const SizedBox(height: 12),
          if (_loadingMode != LoadingMode.bodyweight) ...[
            SegmentedButton<WeightEntry>(
              segments: const [
                ButtonSegment(value: WeightEntry.total, label: Text('Total')),
                ButtonSegment(
                  value: WeightEntry.perSide,
                  label: Text('Per hand'),
                ),
              ],
              selected: {_weightEntry},
              onSelectionChanged: (value) =>
                  setState(() => _weightEntry = value.single),
            ),
            const SizedBox(height: 12),
          ],
          if (_errorText != null) ...[
            Text(
              _errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_loadingMode == LoadingMode.bodyweightAssisted &&
              widget.effectiveBodyweightKg == null) ...[
            Text(
              'Add bodyweight in Settings to validate assistance precisely.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration',
                    suffixText: 'sec',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _distance,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Distance',
                    suffixText: 'm',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<WeightUnit>(
                  segments: const [
                    ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                    ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
                  ],
                  selected: {_unit},
                  onSelectionChanged: (value) =>
                      setState(() => _unit = value.single),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 96,
                child: TextField(
                  controller: _rpe,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'RPE'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Each side'),
            value: _eachSide,
            onChanged: (value) => setState(() => _eachSide = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Warm-up set'),
            value: _warmup,
            onChanged: (value) => setState(() => _warmup = value),
          ),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
            maxLines: 2,
            minLines: 1,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (editing)
                TextButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    const SetEditorResult(
                      reps: null,
                      weight: null,
                      unit: WeightUnit.kg,
                      weightEntry: WeightEntry.total,
                      loadingMode: LoadingMode.external,
                      distanceMeters: null,
                      durationSec: null,
                      sideCount: 1,
                      rpe: null,
                      isWarmup: false,
                      notes: null,
                      delete: true,
                    ),
                  ),
                  icon: Icon(
                    AppIcons.trash,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  label: Text(
                    'Delete',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _save,
                child: Text(editing ? 'Save' : 'Add set'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

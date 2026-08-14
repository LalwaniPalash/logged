import 'package:flutter/material.dart';

import '../../../core/app_icons.dart';
import '../../../core/domain/enums.dart';
import '../../../core/domain/muscle.dart';
import '../../../core/domain/muscle_bias.dart';
import '../../../core/domain/workout_metrics.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/session_repository.dart';

/// Drops the trailing `.0` so a 20 kg dumbbell reads "20", not "20.0".
String _formatNumber(double? value) {
  if (value == null) return '';
  return value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
}

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
    required this.muscleBiasWeights,
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
  final Map<MuscleId, double>? muscleBiasWeights;
  final bool delete;
}

class SetEditorSheet extends StatefulWidget {
  const SetEditorSheet({
    super.key,
    required this.exerciseName,
    required this.category,
    required this.defaultUnit,
    required this.defaultWeightEntry,
    required this.defaultLoadingMode,
    required this.existing,
    required this.seed,
    required this.effectiveBodyweightKg,
    required this.primaryMuscles,
    this.timed = false,
  });

  final String exerciseName;
  final ExerciseCategory category;

  /// Exercise is logged by hold time rather than reps (e.g. Plank).
  final bool timed;
  final WeightUnit defaultUnit;
  final WeightEntry defaultWeightEntry;
  final LoadingMode defaultLoadingMode;
  final SetEntry? existing;
  final SetSeed? seed;
  final double? effectiveBodyweightKg;
  final List<MuscleId> primaryMuscles;

  @override
  State<SetEditorSheet> createState() => _SetEditorSheetState();
}

class _SetEditorSheetState extends State<SetEditorSheet> {
  late final TextEditingController _reps = TextEditingController(
    text: (widget.existing?.reps ?? widget.seed?.reps)?.toString() ?? '',
  );
  late final TextEditingController _weight = TextEditingController(
    text: _formatNumber(
      widget.existing?.weightValue ?? widget.seed?.weightValue,
    ),
  );
  late final TextEditingController _rpe = TextEditingController(
    text: _formatNumber(widget.existing?.rpe),
  );
  late final TextEditingController _duration = TextEditingController(
    text:
        (widget.existing?.durationSec ?? widget.seed?.durationSec)
            ?.toString() ??
        '',
  );
  late final TextEditingController _distance = TextEditingController(
    text: _formatNumber(
      widget.existing?.distanceMeters ?? widget.seed?.distanceMeters,
    ),
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
  late Map<MuscleId, double>? _biasWeights = _initialBiasWeights();
  String? _errorText;

  // Which sections apply. Distance on a barbell squat is noise, but anything a
  // set can actually store must stay reachable here — this sheet is the only
  // editor for values the inline row has no column for.
  bool get _isLifting =>
      widget.category == ExerciseCategory.strength ||
      widget.category == ExerciseCategory.bodyweight;

  /// Any lift can be logged as bodyweight / added / assisted, regardless of how
  /// the exercise is categorised — an assisted pull-up may sit under `strength`.
  bool get _showsLoadingMode => _isLifting;
  bool get _showsWeight => _isLifting && _loadingMode != LoadingMode.bodyweight;
  bool get _showsReps => _isLifting;

  /// Timed holds (Plank is `bodyweight` but prescribed in seconds) and any set
  /// that already carries a duration must be able to edit it.
  bool get _showsDuration =>
      widget.category == ExerciseCategory.cardio ||
      widget.category == ExerciseCategory.stretching ||
      widget.timed ||
      widget.existing?.durationSec != null ||
      widget.seed?.durationSec != null;
  bool get _showsDistance =>
      widget.category == ExerciseCategory.cardio ||
      widget.existing?.distanceMeters != null;
  bool get _showsMuscleBias => widget.primaryMuscles.length >= 2;

  Map<MuscleId, double>? _initialBiasWeights() {
    if (!_showsMuscleBias) return null;

    Map<MuscleId, double>? stored;
    final encoded = widget.existing?.muscleBiasWeights;
    if (encoded != null) {
      try {
        stored = decodeMuscleBiasWeights(encoded);
      } on FormatException {
        stored = null;
      } on ArgumentError {
        stored = null;
      }
    }
    stored ??= widget.seed?.muscleBiasWeights;
    return _normalizeBiasWeights(stored);
  }

  Map<MuscleId, double> _normalizeBiasWeights(Map<MuscleId, double>? weights) {
    final targetTotal = widget.primaryMuscles.length.toDouble();
    final filtered = <MuscleId, double>{
      for (final muscle in widget.primaryMuscles)
        if (weights != null)
          muscle: switch (weights[muscle]) {
            final double value when value.isFinite && value >= 0 => value,
            _ => 0,
          },
    };
    final total = filtered.values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) {
      return {for (final muscle in widget.primaryMuscles) muscle: 1.0};
    }

    final normalized = <MuscleId, double>{};
    var allocated = 0.0;
    for (var index = 0; index < widget.primaryMuscles.length; index++) {
      final muscle = widget.primaryMuscles[index];
      if (index == widget.primaryMuscles.length - 1) {
        normalized[muscle] = (targetTotal - allocated)
            .clamp(0.0, targetTotal)
            .toDouble();
        break;
      }
      final value = ((filtered[muscle] ?? 0) / total) * targetTotal;
      normalized[muscle] = value;
      allocated += value;
    }
    return normalized;
  }

  Map<MuscleId, double> get _effectiveBiasWeights =>
      _biasWeights ?? _normalizeBiasWeights(null);

  Map<MuscleId, double> get _biasShares {
    final weights = _effectiveBiasWeights;
    final total = weights.values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) {
      final evenShare = 1 / widget.primaryMuscles.length;
      return {for (final muscle in widget.primaryMuscles) muscle: evenShare};
    }

    final shares = <MuscleId, double>{};
    var allocated = 0.0;
    for (var index = 0; index < widget.primaryMuscles.length; index++) {
      final muscle = widget.primaryMuscles[index];
      if (index == widget.primaryMuscles.length - 1) {
        shares[muscle] = (1 - allocated).clamp(0.0, 1.0).toDouble();
        break;
      }
      final value = (weights[muscle]! / total).clamp(0.0, 1.0).toDouble();
      shares[muscle] = value;
      allocated += value;
    }
    return shares;
  }

  Map<MuscleId, int> get _biasPercentages {
    final shares = _biasShares;
    final percentages = <MuscleId, int>{};
    var remaining = 100;
    for (var index = 0; index < widget.primaryMuscles.length; index++) {
      final muscle = widget.primaryMuscles[index];
      if (index == widget.primaryMuscles.length - 1) {
        percentages[muscle] = remaining;
      } else {
        final value = (shares[muscle]! * 100).round().clamp(0, remaining);
        percentages[muscle] = value;
        remaining -= value;
      }
    }
    return percentages;
  }

  void _setBiasShare(MuscleId muscle, double share) {
    if (!_showsMuscleBias) return;
    final current = _effectiveBiasWeights;
    final targetTotal = widget.primaryMuscles.length.toDouble();
    final otherMuscles = [
      for (final item in widget.primaryMuscles)
        if (item != muscle) item,
    ];
    final clampedShare = share.clamp(0.0, 1.0).toDouble();
    final targetWeight = clampedShare * targetTotal;
    final remainingWeight = (1 - clampedShare) * targetTotal;
    final otherTotal = otherMuscles.fold<double>(
      0,
      (sum, other) => sum + (current[other] ?? 0),
    );
    final updated = <MuscleId, double>{muscle: targetWeight};
    if (otherTotal <= 0) {
      final evenShare = remainingWeight / otherMuscles.length;
      for (final other in otherMuscles) {
        updated[other] = evenShare;
      }
    } else {
      for (final other in otherMuscles) {
        updated[other] = remainingWeight * (current[other] ?? 0) / otherTotal;
      }
    }
    setState(() {
      _biasWeights = _normalizeBiasWeights(updated);
    });
  }

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
        muscleBiasWeights: _showsMuscleBias ? _effectiveBiasWeights : null,
      ),
    );
  }

  void _delete() => Navigator.pop(
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
      muscleBiasWeights: null,
      delete: true,
    ),
  );

  /// Plain-English restatement of what the weight field means. This is the
  /// whole point of the total/per-hand switch, so it should never be a guess.
  String get _weightEcho {
    final value = double.tryParse(_weight.text);
    final unit = _unit.label;
    if (value == null || value <= 0) {
      return _weightEntry == WeightEntry.perSide
          ? 'The number is the load in ONE hand — counted twice.'
          : 'The number is the whole load being moved.';
    }
    final shown = _formatNumber(value);
    if (_weightEntry == WeightEntry.perSide) {
      return '$shown $unit in each hand = ${_formatNumber(value * 2)} $unit total.';
    }
    return '$shown $unit total.';
  }

  /// Same idea for reps: this one multiplies the REPS, not the weight.
  String get _repsEcho {
    final value = int.tryParse(_reps.text);
    if (!_eachSide) return 'Counted once for the set.';
    if (value == null || value <= 0) {
      return 'The number is per limb — counted twice.';
    }
    return '$value each side = ${value * 2} reps total.';
  }

  String get _biasEcho {
    if (!_showsMuscleBias) return '';
    final percentages = _biasPercentages;
    return widget.primaryMuscles
        .map((muscle) => '${percentages[muscle]}% ${muscle.label}')
        .join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.existing != null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(theme, editing),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  // Dragging the content down dismisses the keyboard — the
                  // gesture users reach for when the numeric keypad is stuck.
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildSections(theme),
                  ),
                ),
              ),
              _buildFooter(theme, editing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool editing) {
    final setLabel = widget.existing == null
        ? null
        : 'Set ${widget.existing!.setNumber}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editing ? 'Edit set' : 'Add set',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  [widget.exerciseName, ?setLabel].join(' · '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Destructive action lives away from Save, not beside it.
          if (editing)
            IconButton(
              onPressed: _delete,
              tooltip: 'Delete set',
              icon: Icon(
                AppIcons.trash,
                size: 20,
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildSections(ThemeData theme) {
    return [
      if (_showsLoadingMode) ...[
        const _SectionLabel('How it is loaded'),
        _ChoiceRow<LoadingMode>(
          values: LoadingMode.values,
          selected: _loadingMode,
          labelOf: (mode) => mode.label,
          onChanged: (mode) => setState(() {
            _loadingMode = mode;
            if (_loadingMode == LoadingMode.bodyweight) _weight.clear();
          }),
        ),
        const SizedBox(height: 18),
      ],

      if (_showsWeight) ...[
        _SectionLabel(_loadingMode.label),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NumberField(
                controller: _weight,
                hint: '0',
                decimal: true,
                onChanged: () => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 56,
              child: SegmentedButton<WeightUnit>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                  ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
                ],
                selected: {_unit},
                onSelectionChanged: (value) =>
                    setState(() => _unit = value.single),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Attached to the weight field, because it multiplies the WEIGHT.
        _ChoiceRow<WeightEntry>(
          values: WeightEntry.values,
          selected: _weightEntry,
          labelOf: (entry) =>
              entry == WeightEntry.total ? 'Total load' : 'Per hand (×2)',
          onChanged: (entry) => setState(() => _weightEntry = entry),
        ),
        _EchoLine(_weightEcho),
        if (_errorText case final error?) _EchoLine(error, isError: true),
        if (_loadingMode == LoadingMode.bodyweightAssisted &&
            widget.effectiveBodyweightKg == null)
          const _EchoLine(
            'Add your bodyweight in Settings to validate assistance precisely.',
          ),
        const SizedBox(height: 18),
      ],

      if (_showsReps) ...[
        const _SectionLabel('Reps'),
        _NumberField(
          controller: _reps,
          hint: '0',
          decimal: false,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 10),
        // Attached to the reps field, because it multiplies the REPS.
        _ChoiceRow<bool>(
          values: const [false, true],
          selected: _eachSide,
          labelOf: (value) => value ? 'Each side (×2)' : 'Both sides together',
          onChanged: (value) => setState(() => _eachSide = value),
        ),
        _EchoLine(_repsEcho),
        const SizedBox(height: 18),
      ],

      if (_showsMuscleBias) ...[
        const _SectionLabel('Primary muscle focus'),
        for (final muscle in widget.primaryMuscles) ...[
          Row(
            children: [
              Expanded(
                child: Text(muscle.label, style: theme.textTheme.bodyMedium),
              ),
              Text(
                '${_biasPercentages[muscle]}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Slider(
            key: ValueKey('muscle-bias-${muscle.id}'),
            value: _biasShares[muscle]!,
            min: 0,
            max: 1,
            divisions: 20,
            label: '${_biasPercentages[muscle]}%',
            onChanged: (value) => _setBiasShare(muscle, value),
          ),
        ],
        _EchoLine(_biasEcho),
        const SizedBox(height: 18),
      ],

      if (_showsDuration || _showsDistance) ...[
        _SectionLabel(
          _showsDuration && _showsDistance
              ? 'Time & distance'
              : (_showsDuration ? 'Hold time' : 'Distance'),
        ),
        Row(
          children: [
            if (_showsDuration)
              Expanded(
                child: _NumberField(
                  controller: _duration,
                  hint: 'Duration',
                  suffix: 'sec',
                  decimal: false,
                  onChanged: () => setState(() {}),
                ),
              ),
            if (_showsDuration && _showsDistance) const SizedBox(width: 10),
            if (_showsDistance)
              Expanded(
                child: _NumberField(
                  controller: _distance,
                  hint: 'Distance',
                  suffix: 'm',
                  decimal: true,
                  onChanged: () => setState(() {}),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
      ],

      const _SectionLabel('Effort'),
      Row(
        children: [
          SizedBox(
            width: 116,
            child: _NumberField(
              controller: _rpe,
              hint: 'RPE',
              decimal: true,
              onChanged: () {},
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilterChip(
              label: const Text('Warm-up set'),
              selected: _warmup,
              onSelected: (value) => setState(() => _warmup = value),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),

      const _SectionLabel('Notes'),
      TextField(
        controller: _notes,
        decoration: const InputDecoration(hintText: 'Optional'),
        maxLines: 3,
        minLines: 1,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      ),
    ];
  }

  Widget _buildFooter(ThemeData theme, bool editing) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 54),
                shape: const StadiumBorder(),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _save,
              child: Text(editing ? 'Save set' : 'Add set'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

/// Wrapping choice chips. Chips size to their own text and flow onto a second
/// line when needed, so labels can never be truncated mid-word the way a
/// fixed four-way [SegmentedButton] truncated "Bodyweight" on a narrow phone.
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(labelOf(value)),
            selected: value == selected,
            onSelected: (isSelected) {
              if (isSelected) onChanged(value);
            },
          ),
      ],
    );
  }
}

/// One line of plain English restating what the inputs above actually mean.
class _EchoLine extends StatelessWidget {
  const _EchoLine(this.text, {this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 2),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isError
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.hint,
    required this.decimal,
    required this.onChanged,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final bool decimal;
  final VoidCallback onChanged;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      decoration: InputDecoration(hintText: hint, suffixText: suffix),
      // The iOS numeric keypad has no return key, so tapping elsewhere is the
      // only way to dismiss it — wire that up or the keyboard traps Save.
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      onChanged: (_) => onChanged(),
    );
  }
}

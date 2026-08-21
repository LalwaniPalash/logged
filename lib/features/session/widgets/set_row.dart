import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_icons.dart';
import '../../../core/domain/enums.dart';
import '../../../core/domain/progression.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';

/// One editable column in the set table.
enum SetField { weight, reps, duration, distance }

/// Single source of truth for which columns a set shows. The header and every
/// row derive their layout from this, so labels can never drift out of sync
/// with the fields sitting underneath them.
///
/// [timed] marks a hold rather than a rep count — a Plank is `bodyweight`
/// category but is prescribed in seconds, so it needs a duration column where
/// a Push-Up needs reps. Deliberately capped at two columns: three steppers do
/// not fit a 320pt phone.
/// [tracksDistance] marks a loaded carry — a Farmer's Walk is `strength`
/// category but is measured in metres, so distance replaces reps as its volume
/// unit exactly as [timed] replaces them with a hold time.
List<SetField> setFieldsFor({
  required ExerciseCategory category,
  required LoadingMode loadingMode,
  bool timed = false,
  bool tracksDistance = false,
}) => switch (category) {
  ExerciseCategory.cardio => const [SetField.duration, SetField.distance],
  ExerciseCategory.stretching => const [SetField.duration],
  // Pure bodyweight is loggable by reps/hold alone, regardless of the category
  // it is filed under. A `strength` exercise the user marks bodyweight (e.g. an
  // Inverted Row) must NOT keep demanding a weight — drive this off the loading
  // mode, not the category enum.
  ExerciseCategory.bodyweight || ExerciseCategory.strength
      when loadingMode == LoadingMode.bodyweight =>
    timed
        ? const [SetField.duration]
        : (tracksDistance ? const [SetField.distance] : const [SetField.reps]),
  ExerciseCategory.bodyweight || ExerciseCategory.strength =>
    timed
        ? const [SetField.weight, SetField.duration]
        : (tracksDistance
              ? const [SetField.weight, SetField.distance]
              : const [SetField.weight, SetField.reps]),
};

/// Whether an exercise is logged by hold time instead of reps. Prefers what the
/// sets actually contain; falls back to the prescription for an empty exercise.
bool isTimedExercise({
  required bool exerciseIsTimed,
  required Iterable<SetEntry> sets,
  required int? targetDurationSec,
  required int? minReps,
  required int? maxReps,
}) {
  if (exerciseIsTimed) return true;
  if (sets.isNotEmpty) {
    return sets.any((set) => set.durationSec != null) &&
        sets.every((set) => set.reps == null);
  }
  return targetDurationSec != null && minReps == null && maxReps == null;
}

/// Columns for a whole exercise: the union of what each of its sets needs, so
/// every logged value stays editable inline even when sets mix loading modes
/// (deriving columns from the first set alone would strand the others' fields).
List<SetField> setColumnsFor({
  required ExerciseCategory category,
  required Iterable<LoadingMode> loadingModes,
  bool timed = false,
  bool tracksDistance = false,
}) {
  final used = <SetField>{};
  for (final mode in loadingModes) {
    used.addAll(
      setFieldsFor(
        category: category,
        loadingMode: mode,
        timed: timed,
        tracksDistance: tracksDistance,
      ),
    );
  }
  return [
    for (final field in SetField.values)
      if (used.contains(field)) field,
  ];
}

/// Relative width of each column. Weight and distance hold more digits.
int _flexFor(SetField field) => switch (field) {
  SetField.weight => 5,
  SetField.distance => 5,
  SetField.reps => 4,
  SetField.duration => 4,
};

// Fixed metrics shared by the header and every row so columns line up exactly.
const double _indexWidth = 32;
const double _indexGap = 8;
const double _columnGap = 8;
const double _doneWidth = 40;
const double _menuWidth = 32;
// The tick is a control like the steppers, so it takes the same gap they take
// from each other. Without it the tick sits flush against the last column.
const double _trailingWidth = _columnGap + _doneWidth + _menuWidth;

class SetRowDraft {
  const SetRowDraft({
    required this.reps,
    required this.weightValue,
    required this.unit,
    required this.durationSec,
    required this.distanceMeters,
  });

  final int? reps;
  final double? weightValue;
  final WeightUnit unit;
  final int? durationSec;
  final double? distanceMeters;
}

/// Read-only, per-set history. Each item carries its own entered unit and
/// loading qualifiers, so a mixed-unit workout is never relabelled by a shared
/// header or a kg round-trip.
class LastPerformanceHint extends StatelessWidget {
  const LastPerformanceHint({super.key, required this.sets});

  final List<SetEntry> sets;

  @override
  Widget build(BuildContext context) {
    if (sets.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1.5),
          child: Icon(
            AppIcons.history,
            size: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            summariseLastPerformance(sets),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Collapses last session's sets into something readable at a glance.
///
/// Repeating "8x 100 kg" once per set filled three lines and still made you
/// count entries to answer the only question being asked — "what did I do, and
/// for how many sets?". Consecutive sets with the same load and reps fold into
/// one "3 x 8 @ 100 kg" group; a set that differs starts a new group, so a
/// drop-off still shows rather than being averaged away.
String summariseLastPerformance(List<SetEntry> sets) {
  final working = sets.where((set) => !set.isWarmup).toList();
  final counted = working.isEmpty ? sets : working;
  if (counted.isEmpty) return '';

  final groups = <({String label, int count})>[];
  for (final set in counted) {
    final label = _formatLastSet(set);
    if (groups.isNotEmpty && groups.last.label == label) {
      final last = groups.removeLast();
      groups.add((label: last.label, count: last.count + 1));
    } else {
      groups.add((label: label, count: 1));
    }
  }

  final parts = [
    for (final group in groups)
      group.count > 1 ? '${group.count} x ${group.label}' : group.label,
  ];
  return 'Last time  ${parts.join('  .  ')}';
}

String _formatLastSet(SetEntry set) {
  final reps = set.reps;
  final weight = set.weightValue;
  final hasWeight = weight != null && weight > 0 && set.unit != null;
  final perHand = set.weightEntry == WeightEntry.perSide ? '/hand' : '';

  final String core;
  if (reps != null && reps > 0 && hasWeight) {
    core = '$reps @ ${_formatEnteredNumber(weight)} ${set.unit!.label}$perHand';
  } else if (reps != null && reps > 0) {
    core = '$reps reps';
  } else if (set.durationSec != null && set.durationSec! > 0) {
    core = _formatLastDuration(set.durationSec!);
  } else if (hasWeight) {
    core = '${_formatEnteredNumber(weight)} ${set.unit!.label}$perHand';
  } else {
    core = 'set ${set.setNumber}';
  }

  final distance = set.distanceMeters;
  final withDistance = distance != null && distance > 0
      ? '$core, ${_formatEnteredNumber(distance)} m'
      : core;
  return set.sideCount > 1 ? '$withDistance each side' : withDistance;
}

String _formatLastDuration(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return remainder == 0 ? '${minutes}m' : '${minutes}m ${remainder}s';
}

String _formatEnteredNumber(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

/// Column headings for a set table. Carries the unit and the per-hand /
/// per-side qualifiers once, instead of repeating them on every row.
class SetTableHeader extends StatelessWidget {
  const SetTableHeader({
    super.key,
    required this.columns,
    required this.unit,
    required this.weightEntry,
    required this.sideCount,
  });

  final List<SetField> columns;
  final WeightUnit unit;
  final WeightEntry weightEntry;
  final int sideCount;

  String _label(SetField field) {
    final perSide = sideCount > 1 ? ' / side' : '';
    return switch (field) {
      SetField.weight =>
        weightEntry == WeightEntry.perSide
            ? '${unit.label} / hand'
            : unit.label,
      SetField.reps => 'reps$perSide',
      SetField.duration => 'time$perSide',
      SetField.distance => 'metres',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.6,
    );
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: _indexWidth,
            child: Text('SET', textAlign: TextAlign.center, style: style),
          ),
          const SizedBox(width: _indexGap),
          for (final field in columns) ...[
            if (field != columns.first) const SizedBox(width: _columnGap),
            Expanded(
              flex: _flexFor(field),
              child: Text(
                _label(field).toUpperCase(),
                textAlign: TextAlign.center,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(width: _trailingWidth),
        ],
      ),
    );
  }
}

class SetRow extends StatefulWidget {
  const SetRow({
    super.key,
    required this.set,
    required this.category,
    required this.headerUnit,
    required this.columns,
    required this.headerWeightEntry,
    required this.headerSideCount,
    required this.timed,
    this.tracksDistance = false,
    required this.onCommit,
    required this.onToggleDone,
    required this.onOpenDetails,
    this.onMoveUp,
    this.onMoveDown,
    this.onInsertAbove,
    this.suggestion,
  });

  final SetEntry set;
  final ExerciseCategory category;

  /// Unit shown in the column heading. A set logged in another unit says so on
  /// its own row — units are per-set and mixing them is normal in this gym.
  final WeightUnit headerUnit;

  /// Columns rendered by the table. A row always occupies every column so the
  /// grid stays aligned, even when this particular set does not use one.
  final List<SetField> columns;
  final WeightEntry headerWeightEntry;
  final int headerSideCount;
  final bool timed;

  /// A loaded carry logs metres instead of reps — see [setFieldsFor].
  final bool tracksDistance;

  final Future<void> Function(SetRowDraft draft) onCommit;

  /// Ticks the set off (or un-ticks it). The only thing that starts a rest
  /// timer — resting is a decision the lifter makes, not something the app can
  /// read off which fields happen to be filled in.
  final Future<void> Function() onToggleDone;
  final VoidCallback onOpenDetails;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onInsertAbove;
  final ProgressionSuggestion? suggestion;

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late final TextEditingController _weight = TextEditingController(
    text: _formatDouble(widget.set.weightValue),
  );
  late final TextEditingController _reps = TextEditingController(
    text: widget.set.reps?.toString() ?? '',
  );
  late final TextEditingController _duration = TextEditingController(
    text: widget.set.durationSec?.toString() ?? '',
  );
  late final TextEditingController _distance = TextEditingController(
    text: _formatDouble(widget.set.distanceMeters),
  );
  late final FocusNode _weightFocus = FocusNode()..addListener(_handleBlur);
  late final FocusNode _repsFocus = FocusNode()..addListener(_handleBlur);
  late final FocusNode _durationFocus = FocusNode()..addListener(_handleBlur);
  late final FocusNode _distanceFocus = FocusNode()..addListener(_handleBlur);

  Timer? _debounce;
  bool _saving = false;
  bool _queued = false;

  WeightUnit get _unit => widget.set.unit ?? widget.headerUnit;

  /// Fields this specific set uses, which can be narrower than the table's
  /// columns (e.g. a bodyweight set inside a weighted exercise).
  List<SetField> get _ownFields => setFieldsFor(
    category: widget.category,
    loadingMode: widget.set.loadingMode,
    timed: widget.timed,
    tracksDistance: widget.tracksDistance,
  );

  @override
  void didUpdateWidget(covariant SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController(
      _weight,
      _weightFocus,
      _formatDouble(widget.set.weightValue),
    );
    _syncController(_reps, _repsFocus, widget.set.reps?.toString() ?? '');
    _syncController(
      _duration,
      _durationFocus,
      widget.set.durationSec?.toString() ?? '',
    );
    _syncController(
      _distance,
      _distanceFocus,
      _formatDouble(widget.set.distanceMeters),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _weight.dispose();
    _reps.dispose();
    _duration.dispose();
    _distance.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    _durationFocus.dispose();
    _distanceFocus.dispose();
    super.dispose();
  }

  void _syncController(
    TextEditingController controller,
    FocusNode focusNode,
    String value,
  ) {
    if (focusNode.hasFocus || controller.text == value) return;
    controller.text = value;
  }

  void _handleBlur() {
    if (_weightFocus.hasFocus ||
        _repsFocus.hasFocus ||
        _durationFocus.hasFocus ||
        _distanceFocus.hasFocus) {
      return;
    }
    unawaited(_commitNow());
  }

  void _scheduleCommit() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_commitNow());
    });
  }

  Future<void> _commitNow() async {
    _debounce?.cancel();
    if (_saving) {
      _queued = true;
      return;
    }
    _saving = true;
    await widget.onCommit(
      SetRowDraft(
        reps: int.tryParse(_reps.text.trim()),
        weightValue: _doubleOrNull(_weight.text),
        unit: _unit,
        durationSec: int.tryParse(_duration.text.trim()),
        distanceMeters: _doubleOrNull(_distance.text),
      ),
    );
    _saving = false;
    // The row can be disposed mid-save (e.g. the exercise is removed while a
    // blur commit is in flight); its controllers would then throw on read.
    if (!mounted) return;
    if (_queued) {
      _queued = false;
      unawaited(_commitNow());
    }
  }

  void _bumpInt(TextEditingController controller, int step) {
    final current = int.tryParse(controller.text.trim()) ?? 0;
    final next = current + step;
    controller.text = next <= 0 ? '' : '$next';
    _scheduleCommit();
  }

  void _bumpDouble(TextEditingController controller, double step) {
    final current = _doubleOrNull(controller.text) ?? 0;
    final next = current + step;
    controller.text = next <= 0 ? '' : _formatDouble(next);
    _scheduleCommit();
  }

  /// A set with nothing in it has nothing to tick off. Deliberately looser
  /// than "has every field the exercise usually wants": a 0 kg Dead Bug logged
  /// by reps alone is a real set and must still be tickable.
  bool get _hasAnyValue =>
      _reps.text.trim().isNotEmpty ||
      _weight.text.trim().isNotEmpty ||
      _duration.text.trim().isNotEmpty ||
      _distance.text.trim().isNotEmpty;

  /// Flushes whatever is in the fields before flipping the flag, so ticking
  /// straight after typing can never rest on a stale weight or rep count.
  Future<void> _toggleDone() async {
    await _commitNow();
    if (!mounted) return;
    await widget.onToggleDone();
  }

  void _applySuggestion() {
    final suggestion = widget.suggestion;
    if (suggestion == null) return;
    if (suggestion.weightValue != null) {
      _weight.text = _formatDouble(suggestion.weightValue);
    }
    if (suggestion.reps != null) {
      _reps.text = '${suggestion.reps}';
    }
    setState(() {});
  }

  /// Anything about this set the column headings do not already say. Silence
  /// here must mean "the heading is accurate for this row" — a lb set sitting
  /// under a KG heading with no marker would misreport the load.
  List<String> get _deviations => [
    if (widget.set.loadingMode != LoadingMode.external)
      widget.set.loadingMode.label,
    if (widget.set.unit != null &&
        widget.set.unit != widget.headerUnit &&
        _ownFields.contains(SetField.weight))
      'in ${widget.set.unit!.label}',
    if (widget.set.weightEntry != widget.headerWeightEntry &&
        _ownFields.contains(SetField.weight))
      widget.set.weightEntry == WeightEntry.perSide ? 'per hand' : 'total load',
    if (widget.set.sideCount != widget.headerSideCount)
      widget.set.sideCount > 1 ? 'each side' : 'both sides together',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviations = _deviations;
    final hasOverflowActions =
        widget.onMoveUp != null ||
        widget.onMoveDown != null ||
        widget.onInsertAbove != null;
    return InkWell(
      onLongPress: widget.onOpenDetails,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SetIndexChip(
                  label: widget.set.isWarmup ? 'W' : '${widget.set.setNumber}',
                  isWarmup: widget.set.isWarmup,
                  isComplete: widget.set.isDone,
                ),
                const SizedBox(width: _indexGap),
                for (final field in widget.columns) ...[
                  if (field != widget.columns.first)
                    const SizedBox(width: _columnGap),
                  Expanded(flex: _flexFor(field), child: _buildColumn(field)),
                ],
                const SizedBox(width: _columnGap),
                SizedBox(
                  width: _doneWidth,
                  child: _SetDoneButton(
                    isDone: widget.set.isDone,
                    onPressed: _hasAnyValue ? _toggleDone : null,
                  ),
                ),
                SizedBox(
                  width: _menuWidth,
                  child: hasOverflowActions
                      ? PopupMenuButton<_SetRowAction>(
                          tooltip: 'Set actions',
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            AppIcons.more,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onSelected: (action) {
                            switch (action) {
                              case _SetRowAction.details:
                                widget.onOpenDetails();
                              case _SetRowAction.moveUp:
                                widget.onMoveUp?.call();
                              case _SetRowAction.moveDown:
                                widget.onMoveDown?.call();
                              case _SetRowAction.insertAbove:
                                widget.onInsertAbove?.call();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: _SetRowAction.details,
                              child: Text('Set details'),
                            ),
                            PopupMenuItem(
                              value: _SetRowAction.moveUp,
                              enabled: widget.onMoveUp != null,
                              child: const Text('Move up'),
                            ),
                            PopupMenuItem(
                              value: _SetRowAction.moveDown,
                              enabled: widget.onMoveDown != null,
                              child: const Text('Move down'),
                            ),
                            PopupMenuItem(
                              value: _SetRowAction.insertAbove,
                              enabled: widget.onInsertAbove != null,
                              child: const Text('Insert set above'),
                            ),
                          ],
                        )
                      : IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: _menuWidth,
                            height: 36,
                          ),
                          onPressed: widget.onOpenDetails,
                          icon: Icon(
                            AppIcons.more,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          tooltip: 'Set details',
                        ),
                ),
              ],
            ),
            if (deviations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(
                  left: _indexWidth + _indexGap,
                  top: 2,
                  bottom: 2,
                ),
                child: Text(
                  deviations.join(' · '),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            if (widget.suggestion case final suggestion?)
              Padding(
                padding: const EdgeInsets.only(
                  left: _indexWidth + _indexGap,
                  top: 3,
                  bottom: 2,
                ),
                child: ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(AppIcons.bolt, size: 15),
                  onPressed: _applySuggestion,
                  tooltip: suggestion.rationale,
                  label: Text(_suggestionLabel(suggestion)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Renders the table column [field]. A set that does not use the column still
  /// occupies it with a placeholder, so every row stays on the same grid.
  Widget _buildColumn(SetField field) {
    if (!_ownFields.contains(field)) return const _EmptyCell();
    return switch (field) {
      SetField.weight => _MicroStepper(
        controller: _weight,
        focusNode: _weightFocus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => _scheduleCommit(),
        onSubmitted: (_) => unawaited(_commitNow()),
        onDecrement: () => _bumpDouble(_weight, -_weightStepFor(_unit)),
        onIncrement: () => _bumpDouble(_weight, _weightStepFor(_unit)),
      ),
      SetField.reps => _MicroStepper(
        controller: _reps,
        focusNode: _repsFocus,
        keyboardType: TextInputType.number,
        onChanged: (_) => _scheduleCommit(),
        onSubmitted: (_) => unawaited(_commitNow()),
        onDecrement: () => _bumpInt(_reps, -1),
        onIncrement: () => _bumpInt(_reps, 1),
      ),
      SetField.duration => _MicroStepper(
        controller: _duration,
        focusNode: _durationFocus,
        keyboardType: TextInputType.number,
        onChanged: (_) => _scheduleCommit(),
        onSubmitted: (_) => unawaited(_commitNow()),
        onDecrement: () => _bumpInt(_duration, -5),
        onIncrement: () => _bumpInt(_duration, 5),
      ),
      SetField.distance => _MicroStepper(
        controller: _distance,
        focusNode: _distanceFocus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => _scheduleCommit(),
        onSubmitted: (_) => unawaited(_commitNow()),
        onDecrement: () => _bumpDouble(_distance, -100),
        onIncrement: () => _bumpDouble(_distance, 100),
      ),
    };
  }

  static double? _doubleOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : double.tryParse(trimmed);
  }

  static String _formatDouble(double? value) {
    return formatSetRowDouble(value);
  }

  static double _weightStepFor(WeightUnit unit) =>
      unit == WeightUnit.kg ? 2.5 : 5;

  static String _suggestionLabel(ProgressionSuggestion suggestion) {
    final load = suggestion.weightValue;
    final reps = suggestion.reps;
    final loadText = load == null
        ? null
        : '${_formatDouble(load)} ${suggestion.unit?.label ?? ''}'.trim();
    final prescription = [
      ?loadText,
      if (reps != null) '$reps reps',
    ].join(' × ');
    return prescription.isEmpty
        ? 'Suggested: match last time'
        : 'Suggested: $prescription · Apply';
  }
}

@visibleForTesting
String formatSetRowDouble(double? value) {
  if (value == null) return '';
  final rounded = (value * 100).roundToDouble() / 100;
  if (rounded == rounded.roundToDouble()) {
    return rounded.toStringAsFixed(0);
  }
  var text = rounded.toStringAsFixed(2);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  text = text.replaceFirst(RegExp(r'\.$'), '');
  return text;
}

enum _SetRowAction { details, moveUp, moveDown, insertAbove }

/// Tick-off control. This is the single gesture that ends a set and starts the
/// rest timer, which is why it sits on the row itself rather than behind the
/// overflow menu — everything else about a set is an edit, this is a decision.
class _SetDoneButton extends StatelessWidget {
  const _SetDoneButton({required this.isDone, required this.onPressed});

  final bool isDone;

  /// Null while the row is still empty — there is no set to finish yet.
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    final Color background;
    final Color foreground;
    final Color border;
    if (isDone) {
      // Green, like the mock and like Finish workout — done is done.
      background = theme.colorScheme.secondary.withValues(alpha: 0.20);
      foreground = theme.colorScheme.secondary;
      border = theme.colorScheme.secondary;
    } else {
      background = Colors.transparent;
      foreground = enabled
          ? theme.colorScheme.onSurfaceVariant
          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.30);
      border = enabled
          ? theme.colorScheme.outlineVariant
          : theme.colorScheme.outlineVariant.withValues(alpha: 0.45);
    }
    return Tooltip(
      message: isDone ? 'Set done — tap to undo' : 'Finish set and start rest',
      child: Semantics(
        button: true,
        checked: isDone,
        label: isDone ? 'Set done' : 'Finish set and start rest',
        child: InkWell(
          onTap: enabled ? () => unawaited(onPressed!()) : null,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: SizedBox(
            // Still occupies the same 40pt slot the steppers align to, but the
            // control itself is a ring rather than a rounded box — a circular
            // check reads as "tick this off" where a square reads as another
            // input field beside the two real ones.
            height: 40,
            width: _doneWidth,
            child: Center(
              child: Container(
                height: 30,
                width: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                  border: Border.all(color: border, width: 1.8),
                ),
                child: Icon(AppIcons.checkBold, size: 16, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Set number badge. Fills with the accent once the set holds real data — it is
/// a status indicator derived from the row, never a tappable "done" control.
class _SetIndexChip extends StatelessWidget {
  const _SetIndexChip({
    required this.label,
    required this.isWarmup,
    required this.isComplete,
  });

  final String label;
  final bool isWarmup;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final Color foreground;
    if (isWarmup) {
      foreground = colors.streak;
    } else if (isComplete) {
      foreground = theme.colorScheme.primary;
    } else {
      foreground = theme.colorScheme.onSurfaceVariant;
    }
    return SizedBox(
      height: 34,
      width: _indexWidth,
      child: Center(
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: Center(
        child: Text(
          '—',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

/// A −/value/+ control sized to fit two-per-row on a phone. Uses tight custom
/// hit areas rather than [IconButton]'s 48px minimum, which is what forced the
/// old layout to wrap onto a second line.
class _MicroStepper extends StatelessWidget {
  const _MicroStepper({
    required this.controller,
    required this.focusNode,
    required this.keyboardType,
    required this.onChanged,
    required this.onSubmitted,
    required this.onDecrement,
    required this.onIncrement,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          _RepeatIconButton(icon: AppIcons.minus, onPressed: onDecrement),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: keyboardType,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              onTapOutside: (_) => focusNode.unfocus(),
            ),
          ),
          _RepeatIconButton(icon: AppIcons.add, onPressed: onIncrement),
        ],
      ),
    );
  }
}

class _RepeatIconButton extends StatefulWidget {
  const _RepeatIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<_RepeatIconButton> createState() => _RepeatIconButtonState();
}

class _RepeatIconButtonState extends State<_RepeatIconButton> {
  Timer? _repeat;

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  void _startRepeat() {
    widget.onPressed();
    _repeat = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => widget.onPressed(),
    );
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onLongPressStart: (_) => _startRepeat(),
      onLongPressEnd: (_) => _stopRepeat(),
      onLongPressCancel: _stopRepeat,
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(
          height: 38,
          width: 30,
          child: Icon(
            widget.icon,
            size: 17,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

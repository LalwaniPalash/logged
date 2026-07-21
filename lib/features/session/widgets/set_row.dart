import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_icons.dart';
import '../../../core/domain/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';

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

class SetRow extends StatefulWidget {
  const SetRow({
    super.key,
    required this.set,
    required this.category,
    required this.fallbackUnit,
    required this.onCommit,
    required this.onOpenDetails,
  });

  final SetEntry set;
  final ExerciseCategory category;
  final WeightUnit fallbackUnit;
  final Future<void> Function(SetRowDraft draft) onCommit;
  final VoidCallback onOpenDetails;

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

  WeightUnit get _unit => widget.set.unit ?? widget.fallbackUnit;

  bool get _showsWeightField =>
      widget.category == ExerciseCategory.strength ||
      (widget.category == ExerciseCategory.bodyweight &&
          widget.set.loadingMode != LoadingMode.bodyweight);

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

  bool get _isComplete => switch (widget.category) {
    ExerciseCategory.cardio =>
      (int.tryParse(_duration.text.trim()) ?? 0) > 0 &&
          (_doubleOrNull(_distance.text) ?? 0) > 0,
    ExerciseCategory.stretching =>
      (int.tryParse(_duration.text.trim()) ?? 0) > 0,
    ExerciseCategory.bodyweight
        when widget.set.loadingMode == LoadingMode.bodyweight =>
      (int.tryParse(_reps.text.trim()) ?? 0) > 0,
    ExerciseCategory.bodyweight || ExerciseCategory.strength =>
      (int.tryParse(_reps.text.trim()) ?? 0) > 0 &&
          (_doubleOrNull(_weight.text) ?? 0) > 0,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    return GestureDetector(
      onLongPress: widget.onOpenDetails,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 32,
              width: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.set.isWarmup
                    ? colors.streakContainer
                    : theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.set.isWarmup ? 'W' : '${widget.set.setNumber}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.set.loadingMode != LoadingMode.external)
                    _Tag(label: widget.set.loadingMode.label),
                  if (_showsWeightField)
                    _StepperField(
                      controller: _weight,
                      focusNode: _weightFocus,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => _scheduleCommit(),
                      onSubmitted: (_) => unawaited(_commitNow()),
                      onDecrement: () =>
                          _bumpDouble(_weight, -_weightStepFor(_unit)),
                      onIncrement: () =>
                          _bumpDouble(_weight, _weightStepFor(_unit)),
                      suffix: _weightSuffix(),
                      width: 52,
                    ),
                  if (widget.set.loadingMode == LoadingMode.bodyweight)
                    const _Tag(label: 'Bodyweight'),
                  if (widget.category == ExerciseCategory.strength ||
                      widget.category == ExerciseCategory.bodyweight)
                    _StepperField(
                      controller: _reps,
                      focusNode: _repsFocus,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _scheduleCommit(),
                      onSubmitted: (_) => unawaited(_commitNow()),
                      onDecrement: () => _bumpInt(_reps, -1),
                      onIncrement: () => _bumpInt(_reps, 1),
                      suffix:
                          'reps${widget.set.sideCount > 1 ? ' each side' : ''}',
                      width: 46,
                    ),
                  if (widget.category == ExerciseCategory.stretching ||
                      widget.category == ExerciseCategory.cardio)
                    _StepperField(
                      controller: _duration,
                      focusNode: _durationFocus,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _scheduleCommit(),
                      onSubmitted: (_) => unawaited(_commitNow()),
                      onDecrement: () => _bumpInt(_duration, -5),
                      onIncrement: () => _bumpInt(_duration, 5),
                      suffix:
                          's${widget.set.sideCount > 1 ? ' each side' : ''}',
                      width: 44,
                    ),
                  if (widget.category == ExerciseCategory.cardio)
                    _StepperField(
                      controller: _distance,
                      focusNode: _distanceFocus,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => _scheduleCommit(),
                      onSubmitted: (_) => unawaited(_commitNow()),
                      onDecrement: () => _bumpDouble(_distance, -100),
                      onIncrement: () => _bumpDouble(_distance, 100),
                      suffix: 'm',
                      width: 56,
                    ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: widget.onOpenDetails,
              icon: Icon(
                _isComplete ? AppIcons.check : AppIcons.circle,
                size: 18,
                color: _isComplete
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: 'Edit details',
            ),
          ],
        ),
      ),
    );
  }

  String _weightSuffix() {
    final unit = _unit.label;
    return widget.set.weightEntry == WeightEntry.perSide ? '$unit × 2' : unit;
  }

  static double? _doubleOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : double.tryParse(trimmed);
  }

  static String _formatDouble(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
  }

  static double _weightStepFor(WeightUnit unit) =>
      unit == WeightUnit.kg ? 2.5 : 5;
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _StepperField extends StatelessWidget {
  const _StepperField({
    required this.controller,
    required this.focusNode,
    required this.keyboardType,
    required this.onChanged,
    required this.onSubmitted,
    required this.onDecrement,
    required this.onIncrement,
    required this.suffix,
    required this.width,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final String suffix;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RepeatIconButton(icon: Icons.remove_rounded, onPressed: onDecrement),
          SizedBox(
            width: width,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: keyboardType,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              onTapOutside: (_) => focusNode.unfocus(),
            ),
          ),
          Text(
            suffix,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          _RepeatIconButton(icon: Icons.add_rounded, onPressed: onIncrement),
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
    return GestureDetector(
      onLongPressStart: (_) => _startRepeat(),
      onLongPressEnd: (_) => _stopRepeat(),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: widget.onPressed,
        icon: Icon(widget.icon, size: 16),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/domain/enums.dart';
import '../../../core/domain/plate_math.dart';

class PlateCalculatorSheet extends StatefulWidget {
  const PlateCalculatorSheet({
    super.key,
    required this.exerciseName,
    required this.initialTarget,
    required this.unit,
    required this.inventory,
    this.perImplement = false,
  });

  final String exerciseName;
  final double initialTarget;
  final WeightUnit unit;
  final PlateInventory inventory;
  final bool perImplement;

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  late final TextEditingController _target = TextEditingController(
    text: _formatWeight(widget.initialTarget),
  );

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  double? get _targetValue => double.tryParse(_target.text.trim());

  PlateSolution? get _solution {
    final target = _targetValue;
    if (target == null) return null;
    return solvePlates(
      targetTotal: target,
      unit: widget.unit,
      inventory: widget.inventory,
      perImplement: widget.perImplement,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final solution = _solution;
    final barWeight = widget.inventory.barWeightFor(widget.unit);
    final stackLabel = widget.perImplement ? 'each hand' : 'per side';
    final barLabel = widget.perImplement ? 'Handle weight' : 'Bar weight';

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Plates', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  widget.exerciseName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _target,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Target load',
                    suffixText: widget.unit.label,
                  ),
                  onChanged: (_) => setState(() {}),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                ),
                const SizedBox(height: 20),
                if (solution == null)
                  Text(
                    'Enter a target load to see the stack.',
                    style: theme.textTheme.bodyMedium,
                  )
                else ...[
                  Text('Stack', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (solution.perSidePlates.isEmpty)
                    Text('No plates needed.', style: theme.textTheme.bodyMedium)
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (
                          var index = 0;
                          index < solution.perSidePlates.length;
                          index++
                        ) ...[
                          Chip(
                            label: Text(
                              _formatWeight(solution.perSidePlates[index]),
                            ),
                          ),
                          if (index < solution.perSidePlates.length - 1)
                            Text('+', style: theme.textTheme.titleMedium),
                        ],
                        Text(stackLabel),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Resolved total: '
                    '${_formatWeight(solution.achievedTotal)} ${widget.unit.label}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$barLabel used: ${_formatWeight(barWeight)} ${widget.unit.label}',
                  ),
                  if (!solution.isExact) ...[
                    const SizedBox(height: 10),
                    Text(
                      _shortfallText(
                        solution.shortfall,
                        unit: widget.unit,
                        perImplement: widget.perImplement,
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _shortfallText(
  double shortfall, {
  required WeightUnit unit,
  required bool perImplement,
}) {
  if (shortfall > 0) {
    return 'Closest load is ${_formatWeight(shortfall)} ${unit.label} under target.';
  }
  final gap = _formatWeight(shortfall.abs());
  if (perImplement) {
    return 'The handle is already $gap ${unit.label} over target.';
  }
  return 'The bar is already $gap ${unit.label} over target.';
}

String _formatWeight(double value) {
  return value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
}

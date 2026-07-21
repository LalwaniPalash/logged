import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:interactive_3d/interactive_3d.dart';

import '../../../core/app_icons.dart';
import '../../../core/domain/live_muscle_state.dart';
import '../../../core/domain/muscle.dart';
import '../../../core/domain/muscle_map.dart';
import '../../../core/domain/muscle_model.dart';
import 'muscle_heatmap.dart';

class MuscleAnatomyView extends StatefulWidget {
  const MuscleAnatomyView({
    super.key,
    required this.state,
    this.enable3d = true,
    this.onOpenMuscle,
    this.onOpenAllMuscles,
  });

  final LiveMuscleState state;

  /// Lets tests and future unsupported platforms disable the native renderer.
  final bool enable3d;
  final ValueChanged<MuscleId>? onOpenMuscle;
  final VoidCallback? onOpenAllMuscles;

  @override
  State<MuscleAnatomyView> createState() => _MuscleAnatomyViewState();
}

class _MuscleAnatomyViewState extends State<MuscleAnatomyView> {
  final Interactive3dController _controller = Interactive3dController();
  MuscleId? _selectedMuscle;
  bool _showAllMuscles = false;

  static const double _defaultModelZoom = 3.0;

  bool get _supports3d =>
      widget.enable3d && (Platform.isAndroid || Platform.isIOS);

  @override
  void didUpdateWidget(MuscleAnatomyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMaterialSync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleMaterialSync();
  }

  void _scheduleMaterialSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_supports3d) return;
      unawaited(_syncMaterials());
    });
  }

  Future<void> _syncMaterials() async {
    try {
      await _controller.setEntityMaterials(
        _materialOverrides(Theme.of(context), widget.state),
      );
    } on StateError {
      // The widget's initial overrides cover first load. A live update can race
      // controller attachment while the user switches back from the fallback.
    }
  }

  void _onEntitiesSelected(List<EntityData> entities) {
    if (entities.isEmpty) {
      setState(() => _selectedMuscle = null);
      return;
    }

    final latest = entities.last;
    final selected = muscleForModelEntity(latest.name);
    if (selected != null) {
      setState(() => _selectedMuscle = selected);
    }

    if (entities.length > 1) {
      unawaited(
        _controller.unselectEntities(
          entityIds: entities
              .take(entities.length - 1)
              .map((entity) => entity.id)
              .toList(),
        ),
      );
    }
  }

  Future<void> _resetModelView() async {
    if (!_supports3d) return;
    try {
      await _controller.setCameraZoomLevel(_defaultModelZoom);
    } on StateError {
      // The native view can still be attaching during first load. The
      // Interactive3d widget also receives this same value as defaultZoom.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topLoads = widget.state.loads.values.toList()
      ..sort((a, b) => b.effectiveSets.compareTo(a.effectiveSets));
    final activeMuscles = topLoads.map((load) => load.muscle).toSet();
    final inactiveMuscles =
        MuscleId.values
            .where((muscle) => !activeMuscles.contains(muscle))
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));
    final displayedMuscles = _showAllMuscles
        ? [...topLoads.map((load) => load.muscle), ...inactiveMuscles]
        : topLoads.map((load) => load.muscle).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'LIVE · MON–TODAY',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _resetModelView,
              icon: const Icon(AppIcons.refresh, size: 16),
              label: const Text('Reset view'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _supports3d
            ? _ThreeDimensionalMuscleModel(
                state: widget.state,
                controller: _controller,
                defaultZoom: _defaultModelZoom,
                onSelectionChanged: _onEntitiesSelected,
              )
            : MuscleHeatmap(
                intensities: regionIntensitiesFromLiveState(widget.state),
              ),
        const SizedBox(height: 14),
        _IntensityLegend(),
        const SizedBox(height: 16),
        if (displayedMuscles.isNotEmpty) ...[
          Text(
            _showAllMuscles
                ? 'All muscles'
                : _selectedMuscle == null
                ? 'Choose a muscle'
                : 'Other muscles',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final muscle in displayedMuscles)
                _MuscleChip(
                  muscle: muscle,
                  load: widget.state[muscle],
                  selected: _selectedMuscle == muscle,
                  onTap: () => setState(() => _selectedMuscle = muscle),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () =>
                    setState(() => _showAllMuscles = !_showAllMuscles),
                icon: AnimatedRotation(
                  turns: _showAllMuscles ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(AppIcons.chevronDown, size: 16),
                ),
                label: Text(
                  _showAllMuscles ? 'Show trained only' : 'Browse all muscles',
                ),
              ),
              if (widget.onOpenAllMuscles != null)
                TextButton.icon(
                  onPressed: widget.onOpenAllMuscles,
                  icon: const Icon(AppIcons.progress, size: 16),
                  label: const Text('All muscle progress'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _MuscleDetails(
            key: ValueKey(_selectedMuscle),
            muscle: _selectedMuscle,
            load: _selectedMuscle == null
                ? null
                : widget.state[_selectedMuscle!],
            isEmpty: widget.state.isEmpty,
            onOpenMuscle: widget.onOpenMuscle,
          ),
        ),
      ],
    );
  }
}

class _ThreeDimensionalMuscleModel extends StatelessWidget {
  const _ThreeDimensionalMuscleModel({
    required this.state,
    required this.controller,
    required this.defaultZoom,
    required this.onSelectionChanged,
  });

  final LiveMuscleState state;
  final Interactive3dController controller;
  final double defaultZoom;
  final ValueChanged<List<EntityData>> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.brightness == Brightness.dark
        ? const Color(0xFF171513)
        : const Color(0xFF2A2622);
    final topMuscles = state.loads.values.toList()
      ..sort((a, b) => b.effectiveSets.compareTo(a.effectiveSets));
    final summary = topMuscles.isEmpty
        ? 'No working sets recorded this week.'
        : 'Most trained: ${topMuscles.take(3).map((load) => load.muscle.label).join(', ')}.';

    return Semantics(
      label: 'Interactive 3D muscular anatomy. $summary',
      child: Container(
        height: 430,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Interactive3d(
          controller: controller,
          modelPath: muscleModelAssetPath,
          defaultZoom: defaultZoom,
          solidBackgroundColor: _rgba(background),
          backgroundColor: background,
          selectionColor: const [1.0, 0.72, 0.16, 1.0],
          initialMaterialOverrides: _materialOverrides(theme, state),
          onSelectionChanged: onSelectionChanged,
          loadingWidget: _ModelLoadingIndicator(background: background),
        ),
      ),
    );
  }
}

class _ModelLoadingIndicator extends StatelessWidget {
  const _ModelLoadingIndicator({required this.background});
  final Color background;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: background,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Preparing anatomy',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    ),
  );
}

class _IntensityLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Color scale from untrained to twelve or more effective sets',
      child: Row(
        children: [
          Text(
            '0 sets',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                for (final intensity in const [0.0, 0.2, 0.45, 0.7, 1.0])
                  Expanded(
                    child: Container(
                      height: 9,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: _muscleColor(theme, intensity),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '12+ effective',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MuscleChip extends StatelessWidget {
  const _MuscleChip({
    required this.muscle,
    required this.load,
    required this.selected,
    required this.onTap,
  });

  final MuscleId muscle;
  final MuscleLoad? load;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      onPressed: onTap,
      avatar: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: _muscleColor(theme, load?.intensity ?? 0),
          shape: BoxShape.circle,
        ),
      ),
      label: Text(muscle.label),
      backgroundColor: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainer,
      side: BorderSide(
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.outlineVariant,
      ),
    );
  }
}

class _MuscleDetails extends StatelessWidget {
  const _MuscleDetails({
    super.key,
    required this.muscle,
    required this.load,
    required this.isEmpty,
    required this.onOpenMuscle,
  });

  final MuscleId? muscle;
  final MuscleLoad? load;
  final bool isEmpty;
  final ValueChanged<MuscleId>? onOpenMuscle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (muscle == null) {
      if (isEmpty) {
        return _DetailShell(
          child: Row(
            children: [
              Icon(AppIcons.bolt, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Complete a working set to light up this week’s muscles.',
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    if (load == null) {
      return _DetailShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'No working sets for ${muscle!.label} this week.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onOpenMuscle != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => onOpenMuscle!(muscle!),
                  icon: const Icon(AppIcons.progress, size: 16),
                  label: const Text('Open progress'),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return _DetailShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: _muscleColor(theme, load!.intensity),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  muscle!.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${load!.primarySets} primary · ${load!.secondarySets} secondary · '
            '${load!.effectiveSets.toStringAsFixed(1)} effective sets',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < load!.exercises.length; index++) ...[
            if (index > 0) const Divider(height: 17),
            _ExerciseContributionRow(contribution: load!.exercises[index]),
          ],
          if (onOpenMuscle != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => onOpenMuscle!(muscle!),
                icon: const Icon(AppIcons.progress, size: 16),
                label: const Text('Open progress'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailShell extends StatelessWidget {
  const _DetailShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _ExerciseContributionRow extends StatelessWidget {
  const _ExerciseContributionRow({required this.contribution});
  final ExerciseMuscleContribution contribution;

  String get _roleText {
    final roles = <String>[];
    if (contribution.primarySets > 0) {
      roles.add('${contribution.primarySets} primary');
    }
    if (contribution.secondarySets > 0) {
      roles.add('${contribution.secondarySets} secondary');
    }
    return roles.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            contribution.exerciseName,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _roleText,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

List<MaterialOverride> _materialOverrides(
  ThemeData theme,
  LiveMuscleState state,
) {
  final intensities = muscleModelIntensities(state);
  return [
    for (final entry in intensities.entries)
      MaterialOverride(
        name: entry.key,
        color: _rgba(_muscleColor(theme, entry.value)),
        emissive: _emissive(_muscleColor(theme, entry.value), entry.value),
        metallic: 0.0,
        roughness: 0.72,
      ),
  ];
}

Color _muscleColor(ThemeData theme, double intensity) {
  final dark = theme.brightness == Brightness.dark;
  final resting = dark ? const Color(0xFF8A7A6E) : const Color(0xFF75695E);
  final low = dark ? const Color(0xFF8D5A3D) : const Color(0xFF9A6144);
  final active = dark ? const Color(0xFFFFB24A) : const Color(0xFFD98931);
  if (intensity <= 0) return resting;
  if (intensity < 0.55) {
    return Color.lerp(resting, low, 0.32 + intensity.clamp(0, 0.55))!;
  }
  return Color.lerp(low, active, ((intensity - 0.55) / 0.45).clamp(0, 1))!;
}

List<double> _rgba(Color color) => [color.r, color.g, color.b, color.a];

List<double> _emissive(Color color, double intensity) {
  final boost = intensity <= 0 ? 0.36 : 0.28;
  return [color.r * boost, color.g * boost, color.b * boost];
}

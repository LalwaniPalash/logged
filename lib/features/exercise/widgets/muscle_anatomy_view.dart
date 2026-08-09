import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:interactive_3d/interactive_3d.dart';

import '../../../core/app_icons.dart';
import '../../../core/domain/live_muscle_state.dart';
import '../../../core/domain/muscle.dart';
import '../../../core/domain/muscle_map.dart';
import '../../../core/domain/muscle_model.dart';
import '../../../core/domain/volume_landmarks.dart';
import 'muscle_heatmap.dart';

@visibleForTesting
Future<void> resetMuscleModelView({
  required bool supports3d,
  required Interactive3dController controller,
}) async {
  if (!supports3d) return;
  try {
    await controller.resetCamera();
  } on StateError {
    // The native view can still be attaching during first load.
  }
}

class MuscleAnatomyView extends StatefulWidget {
  const MuscleAnatomyView({
    super.key,
    required this.state,
    this.enable3d = true,
    this.onOpenMuscle,
    this.onOpenAllMuscles,
    this.emptyAction,
    this.landmarks = defaultLandmarks,
    this.onBuildFromMuscle,
  });

  final LiveMuscleState state;

  /// Lets tests and future unsupported platforms disable the native renderer.
  final bool enable3d;
  final ValueChanged<MuscleId>? onOpenMuscle;
  final VoidCallback? onOpenAllMuscles;
  final Widget? emptyAction;
  final Map<MuscleId, VolumeLandmarks> landmarks;
  final ValueChanged<MuscleId>? onBuildFromMuscle;

  @override
  State<MuscleAnatomyView> createState() => _MuscleAnatomyViewState();
}

class _MuscleAnatomyViewState extends State<MuscleAnatomyView> {
  final Interactive3dController _controller = Interactive3dController();
  MuscleId? _selectedMuscle;
  bool _showAllMuscles = false;

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
        _materialOverrides(Theme.of(context), widget.state, widget.landmarks),
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
    await resetMuscleModelView(
      supports3d: _supports3d,
      controller: _controller,
    );
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
                landmarks: widget.landmarks,
                controller: _controller,
                defaultZoom: _ThreeDimensionalMuscleModel.defaultModelZoom,
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
                  landmarks: widget.landmarks[muscle]!,
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
            emptyAction: widget.emptyAction,
            landmarks: _selectedMuscle == null
                ? null
                : widget.landmarks[_selectedMuscle!],
            onBuildFromMuscle: widget.onBuildFromMuscle,
          ),
        ),
      ],
    );
  }
}

class _ThreeDimensionalMuscleModel extends StatelessWidget {
  const _ThreeDimensionalMuscleModel({
    required this.state,
    required this.landmarks,
    required this.controller,
    required this.defaultZoom,
    required this.onSelectionChanged,
  });

  static const double defaultModelZoom = 3.0;

  final LiveMuscleState state;
  final Map<MuscleId, VolumeLandmarks> landmarks;
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
          initialMaterialOverrides: _materialOverrides(theme, state, landmarks),
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
      label: 'Volume coaching zones from below MEV to recovery risk',
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        children: [
          for (final zone in VolumeZone.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: _zoneColor(theme, zone, 0.85),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  zone == VolumeZone.overreaching
                      ? 'recovery risk'
                      : zone.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
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
    required this.landmarks,
  });

  final MuscleId muscle;
  final MuscleLoad? load;
  final bool selected;
  final VoidCallback onTap;
  final VolumeLandmarks landmarks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      onPressed: onTap,
      avatar: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: _zoneColor(
            theme,
            zoneFor(load?.effectiveSets ?? 0, landmarks),
            coachingIntensity(load?.effectiveSets ?? 0, landmarks),
          ),
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
    required this.emptyAction,
    required this.landmarks,
    required this.onBuildFromMuscle,
  });

  final MuscleId? muscle;
  final MuscleLoad? load;
  final bool isEmpty;
  final ValueChanged<MuscleId>? onOpenMuscle;
  final Widget? emptyAction;
  final VolumeLandmarks? landmarks;
  final ValueChanged<MuscleId>? onBuildFromMuscle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (muscle == null) {
      if (isEmpty) {
        return _DetailShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
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
              if (emptyAction != null) ...[
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: emptyAction!),
              ],
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    if (load == null) {
      final target = landmarks!;
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
            const SizedBox(height: 6),
            Text(
              '0.0 effective sets · below MEV ${_sets(target.mev)}',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text('Add about ${_sets(target.mev)} sets this week to reach MEV.'),
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
            if (onBuildFromMuscle != null)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => onBuildFromMuscle!(muscle!),
                  icon: const Icon(AppIcons.add, size: 16),
                  label: Text('Add exercise for ${muscle!.label}'),
                ),
              ),
          ],
        ),
      );
    }

    final target = landmarks!;
    final zone = load!.zone(target);
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
                  color: _zoneColor(
                    theme,
                    zone,
                    load!.coachingColorIntensity(target),
                  ),
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
            '${_formatSetCount(load!.primarySets)} primary · '
            '${_formatSetCount(load!.secondarySets.toDouble())} secondary · '
            '${load!.effectiveSets.toStringAsFixed(1)} effective sets',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${zone.label} · MEV ${_sets(target.mev)} · '
            'MAV ${_sets(target.mav)} · MRV ${_sets(target.mrv)}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: _zoneColor(theme, zone, 0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _zoneSuggestion(zone, load!.effectiveSets, target),
            style: theme.textTheme.bodySmall,
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
          if (onBuildFromMuscle != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onBuildFromMuscle!(muscle!),
                icon: const Icon(AppIcons.add, size: 16),
                label: Text('Build from ${muscle!.label}'),
              ),
            ),
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
      roles.add('${_formatSetCount(contribution.primarySets)} primary');
    }
    if (contribution.secondarySets > 0) {
      roles.add(
        '${_formatSetCount(contribution.secondarySets.toDouble())} secondary',
      );
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
  Map<MuscleId, VolumeLandmarks> landmarks,
) {
  return [
    for (final entry in muscleModelEntities.entries)
      for (final entity in entry.value)
        MaterialOverride(
          name: entity,
          color: _rgba(
            _zoneColor(
              theme,
              zoneFor(
                state[entry.key]?.effectiveSets ?? 0,
                landmarks[entry.key]!,
              ),
              coachingIntensity(
                state[entry.key]?.effectiveSets ?? 0,
                landmarks[entry.key]!,
              ),
            ),
          ),
          emissive: _emissive(
            _zoneColor(
              theme,
              zoneFor(
                state[entry.key]?.effectiveSets ?? 0,
                landmarks[entry.key]!,
              ),
              coachingIntensity(
                state[entry.key]?.effectiveSets ?? 0,
                landmarks[entry.key]!,
              ),
            ),
            coachingIntensity(
              state[entry.key]?.effectiveSets ?? 0,
              landmarks[entry.key]!,
            ),
          ),
          metallic: 0.0,
          roughness: 0.72,
        ),
  ];
}

Color _zoneColor(ThemeData theme, VolumeZone zone, double intensity) {
  final dark = theme.brightness == Brightness.dark;
  final base = switch (zone) {
    VolumeZone.belowMev =>
      dark ? const Color(0xFF7D8791) : const Color(0xFF697783),
    VolumeZone.developing =>
      dark ? const Color(0xFF4DB6AC) : const Color(0xFF23877E),
    VolumeZone.optimal =>
      dark ? const Color(0xFF66BB6A) : const Color(0xFF388E3C),
    VolumeZone.diminishing =>
      dark ? const Color(0xFFFFB74D) : const Color(0xFFE08A17),
    VolumeZone.overreaching =>
      dark ? const Color(0xFFEF6C72) : const Color(0xFFC94149),
  };
  final surface = dark ? const Color(0xFF443F3B) : const Color(0xFFD1CBC5);
  return Color.lerp(surface, base, (0.38 + intensity * 0.62).clamp(0, 1))!;
}

String _sets(double value) => value == value.roundToDouble()
    ? '${value.toInt()}'
    : value.toStringAsFixed(1);

String _formatSetCount(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

String _zoneSuggestion(
  VolumeZone zone,
  double effectiveSets,
  VolumeLandmarks landmarks,
) => switch (zone) {
  VolumeZone.belowMev =>
    'Add about ${_sets(landmarks.mev - effectiveSets)} sets to reach MEV.',
  VolumeZone.developing =>
    'Keep building gradually toward your maximum adaptive range.',
  VolumeZone.optimal => 'You are in a productive weekly volume range.',
  VolumeZone.diminishing =>
    'Growth may continue here, but returns are diminishing.',
  VolumeZone.overreaching =>
    'Recovery risk is elevated; reduce volume or prioritize recovery.',
};

List<double> _rgba(Color color) => [color.r, color.g, color.b, color.a];

List<double> _emissive(Color color, double intensity) {
  final boost = intensity <= 0 ? 0.36 : 0.28;
  return [color.r * boost, color.g * boost, color.b * boost];
}

import 'package:flutter/material.dart';

import '../../../core/domain/muscle_map.dart';

/// A stylized front + back body whose muscle regions glow by how much they were
/// trained. Intensities are 0..1 per [BodyRegion]; 0 shows the neutral base.
class MuscleHeatmap extends StatelessWidget {
  const MuscleHeatmap({super.key, required this.intensities});

  final Map<BodyRegion, double> intensities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHighest;
    final worked = theme.colorScheme.primary;
    final outline = theme.colorScheme.outlineVariant;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _LabeledFigure(
                label: 'Front',
                child: CustomPaint(
                  painter: _BodyPainter(
                    front: true,
                    intensities: intensities,
                    base: base,
                    worked: worked,
                    outline: outline,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _LabeledFigure(
                label: 'Back',
                child: CustomPaint(
                  painter: _BodyPainter(
                    front: false,
                    intensities: intensities,
                    base: base,
                    worked: worked,
                    outline: outline,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Legend(base: base, worked: worked),
      ],
    );
  }
}

class _LabeledFigure extends StatelessWidget {
  const _LabeledFigure({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        AspectRatio(aspectRatio: 0.5, child: child),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.base, required this.worked});
  final Color base;
  final Color worked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Less',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        for (final t in const [0.0, 0.35, 0.7, 1.0])
          Container(
            width: 22,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Color.lerp(base, worked, t),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        const SizedBox(width: 8),
        Text(
          'More',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Part {
  const _Part(this.region, this.rect, {this.oval = false, this.radius = 8});
  final BodyRegion? region; // null = neutral silhouette part
  final Rect rect; // unit coordinates (0..1)
  final bool oval;
  final double radius;
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.front,
    required this.intensities,
    required this.base,
    required this.worked,
    required this.outline,
  });

  final bool front;
  final Map<BodyRegion, double> intensities;
  final Color base;
  final Color worked;
  final Color outline;

  // Neutral silhouette shared by both views.
  static const _silhouette = [
    _Part(null, Rect.fromLTRB(0.42, 0.02, 0.58, 0.14), oval: true), // head
    _Part(null, Rect.fromLTRB(0.34, 0.15, 0.66, 0.50), radius: 14), // torso
    _Part(
      null,
      Rect.fromLTRB(0.18, 0.17, 0.31, 0.34),
      radius: 10,
    ), // upper arm L
    _Part(
      null,
      Rect.fromLTRB(0.69, 0.17, 0.82, 0.34),
      radius: 10,
    ), // upper arm R
    _Part(null, Rect.fromLTRB(0.19, 0.34, 0.30, 0.50), radius: 8), // forearm L
    _Part(null, Rect.fromLTRB(0.70, 0.34, 0.81, 0.50), radius: 8), // forearm R
    _Part(
      null,
      Rect.fromLTRB(0.37, 0.50, 0.49, 0.74),
      radius: 10,
    ), // upper leg L
    _Part(
      null,
      Rect.fromLTRB(0.51, 0.50, 0.63, 0.74),
      radius: 10,
    ), // upper leg R
    _Part(
      null,
      Rect.fromLTRB(0.38, 0.74, 0.48, 0.96),
      radius: 8,
    ), // lower leg L
    _Part(
      null,
      Rect.fromLTRB(0.52, 0.74, 0.62, 0.96),
      radius: 8,
    ), // lower leg R
  ];

  static const _front = [
    _Part(
      BodyRegion.shoulders,
      Rect.fromLTRB(0.30, 0.16, 0.42, 0.24),
      oval: true,
    ),
    _Part(
      BodyRegion.shoulders,
      Rect.fromLTRB(0.58, 0.16, 0.70, 0.24),
      oval: true,
    ),
    _Part(BodyRegion.chest, Rect.fromLTRB(0.36, 0.20, 0.495, 0.31), radius: 8),
    _Part(BodyRegion.chest, Rect.fromLTRB(0.505, 0.20, 0.64, 0.31), radius: 8),
    _Part(BodyRegion.core, Rect.fromLTRB(0.42, 0.32, 0.58, 0.49), radius: 8),
    _Part(BodyRegion.arms, Rect.fromLTRB(0.19, 0.18, 0.30, 0.33), radius: 9),
    _Part(BodyRegion.arms, Rect.fromLTRB(0.70, 0.18, 0.81, 0.33), radius: 9),
    _Part(BodyRegion.quads, Rect.fromLTRB(0.375, 0.51, 0.485, 0.72), radius: 9),
    _Part(BodyRegion.quads, Rect.fromLTRB(0.515, 0.51, 0.625, 0.72), radius: 9),
  ];

  static const _back = [
    _Part(
      BodyRegion.shoulders,
      Rect.fromLTRB(0.30, 0.16, 0.42, 0.24),
      oval: true,
    ),
    _Part(
      BodyRegion.shoulders,
      Rect.fromLTRB(0.58, 0.16, 0.70, 0.24),
      oval: true,
    ),
    _Part(BodyRegion.back, Rect.fromLTRB(0.36, 0.19, 0.64, 0.40), radius: 10),
    _Part(BodyRegion.core, Rect.fromLTRB(0.40, 0.40, 0.60, 0.49), radius: 8),
    _Part(BodyRegion.arms, Rect.fromLTRB(0.19, 0.18, 0.30, 0.33), radius: 9),
    _Part(BodyRegion.arms, Rect.fromLTRB(0.70, 0.18, 0.81, 0.33), radius: 9),
    _Part(
      BodyRegion.glutes,
      Rect.fromLTRB(0.37, 0.49, 0.495, 0.585),
      oval: true,
    ),
    _Part(
      BodyRegion.glutes,
      Rect.fromLTRB(0.505, 0.49, 0.63, 0.585),
      oval: true,
    ),
    _Part(
      BodyRegion.hamstrings,
      Rect.fromLTRB(0.375, 0.59, 0.485, 0.73),
      radius: 9,
    ),
    _Part(
      BodyRegion.hamstrings,
      Rect.fromLTRB(0.515, 0.59, 0.625, 0.73),
      radius: 9,
    ),
    _Part(BodyRegion.calves, Rect.fromLTRB(0.38, 0.75, 0.48, 0.93), radius: 8),
    _Part(BodyRegion.calves, Rect.fromLTRB(0.52, 0.75, 0.62, 0.93), radius: 8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = outline;

    void draw(_Part part, Color fill) {
      final r = Rect.fromLTRB(
        part.rect.left * size.width,
        part.rect.top * size.height,
        part.rect.right * size.width,
        part.rect.bottom * size.height,
      );
      final paint = Paint()..color = fill;
      if (part.oval) {
        canvas.drawOval(r, paint);
        canvas.drawOval(r, stroke);
      } else {
        final rr = RRect.fromRectAndRadius(r, Radius.circular(part.radius));
        canvas.drawRRect(rr, paint);
        canvas.drawRRect(rr, stroke);
      }
    }

    for (final part in _silhouette) {
      draw(part, base);
    }
    for (final part in (front ? _front : _back)) {
      final intensity = intensities[part.region] ?? 0;
      final fill = intensity <= 0
          ? base
          : Color.lerp(base, worked, 0.25 + 0.75 * intensity)!;
      draw(part, fill);
    }
  }

  @override
  bool shouldRepaint(_BodyPainter oldDelegate) =>
      oldDelegate.intensities != intensities ||
      oldDelegate.front != front ||
      oldDelegate.base != base ||
      oldDelegate.worked != worked;
}

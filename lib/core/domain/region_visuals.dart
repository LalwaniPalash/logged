import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../app_icons.dart';
import 'muscle_map.dart';

/// Phosphor has no real chest/back/shoulder/leg glyphs, so regions share a
/// small set of generic icons and lean on [colorForRegion] to stay tellable
/// apart at a glance.
PhosphorIconData iconForRegion(BodyRegion region) => switch (region) {
  BodyRegion.chest ||
  BodyRegion.back ||
  BodyRegion.shoulders ||
  BodyRegion.arms => AppIcons.plates,
  BodyRegion.core => AppIcons.body,
  BodyRegion.quads ||
  BodyRegion.hamstrings ||
  BodyRegion.glutes ||
  BodyRegion.calves => AppIcons.footprints,
};

/// Nine evenly-spaced hues rotated off the theme's primary colour, so every
/// region gets a distinct accent that still belongs to the app's palette in
/// both light and dark mode (deriving from `scheme.primary` at render time
/// keeps it theme-aware for free, rather than hand-picking 18 fixed hexes).
///
/// Rotation is capped to a warm arc (red-orange through olive-green — the
/// same family as the app's clay/streak/sage accents) rather than the full
/// 360° wheel: going further wraps into blues and purples that read as an
/// out-of-theme accent against the warm-earth palette.
Color colorForRegion(BodyRegion region, ColorScheme scheme) {
  final base = HSLColor.fromColor(scheme.primary);
  const arcSpan = 110.0;
  final step = arcSpan / (BodyRegion.values.length - 1);
  final hue = (base.hue + region.index * step) % 360;
  return base.withHue(hue).toColor();
}

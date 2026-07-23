import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Single source of truth for iconography, using the Phosphor set. Referencing
/// icons through here keeps them consistent and makes future swaps trivial.
class AppIcons {
  const AppIcons._();

  // Navigation
  static const home = PhosphorIconsRegular.house;
  static const homeFill = PhosphorIconsFill.house;
  static const history = PhosphorIconsRegular.calendarBlank;
  static const historyFill = PhosphorIconsFill.calendarBlank;
  static const progress = PhosphorIconsRegular.chartLineUp;
  static const progressFill = PhosphorIconsFill.chartLineUp;
  static const settings = PhosphorIconsRegular.gearSix;
  static const settingsFill = PhosphorIconsFill.gearSix;

  // Actions
  static const play = PhosphorIconsFill.play;
  static const videoAdd = PhosphorIconsRegular.youtubeLogo;
  static const add = PhosphorIconsRegular.plus;
  static const check = PhosphorIconsRegular.check;
  static const circle = PhosphorIconsRegular.circle;
  static const close = PhosphorIconsRegular.x;
  static const chevronRight = PhosphorIconsRegular.caretRight;
  static const chevronDown = PhosphorIconsRegular.caretDown;
  static const more = PhosphorIconsRegular.dotsThreeOutline;
  static const search = PhosphorIconsRegular.magnifyingGlass;
  static const edit = PhosphorIconsRegular.pencilSimple;
  static const trash = PhosphorIconsRegular.trash;
  static const drag = PhosphorIconsRegular.dotsSixVertical;
  static const refresh = PhosphorIconsRegular.arrowClockwise;
  static const cube = PhosphorIconsRegular.cube;
  static const body = PhosphorIconsRegular.personArmsSpread;

  // Concepts
  static const fire = PhosphorIconsFill.fire;
  static const bolt = PhosphorIconsRegular.lightning;
  static const target = PhosphorIconsRegular.target;
  static const rest = PhosphorIconsRegular.bed;
  static const restFill = PhosphorIconsFill.bed;
  static const trophy = PhosphorIconsFill.trophy;
  static const calendarCheck = PhosphorIconsRegular.calendarCheck;
  static const note = PhosphorIconsRegular.note;
  static const warning = PhosphorIconsRegular.warningCircle;
  static const templates = PhosphorIconsRegular.cards;
  static const swap = PhosphorIconsRegular.arrowsLeftRight;

  // Exercise categories
  static const strength = PhosphorIconsRegular.barbell;
  static const cardio = PhosphorIconsRegular.personSimpleRun;
  static const bodyweight = PhosphorIconsRegular.personArmsSpread;
  static const stretching = PhosphorIconsRegular.personSimpleTaiChi;

  // Settings / backup
  static const archive = PhosphorIconsRegular.archive;
  static const export = PhosphorIconsRegular.shareNetwork;
  static const import = PhosphorIconsRegular.folderOpen;
  static const inventory = PhosphorIconsRegular.squaresFour;
  static const dumbbell = PhosphorIconsRegular.barbell;

  static PhosphorIconData forCategoryName(String category) {
    switch (category) {
      case 'strength':
        return strength;
      case 'cardio':
        return cardio;
      case 'bodyweight':
        return bodyweight;
      case 'stretching':
        return stretching;
      default:
        return PhosphorIconsRegular.star;
    }
  }
}

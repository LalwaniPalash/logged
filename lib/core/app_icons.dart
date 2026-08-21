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
  static const minus = PhosphorIconsRegular.minus;
  static const check = PhosphorIconsRegular.check;
  static const circle = PhosphorIconsRegular.circle;
  static const close = PhosphorIconsRegular.x;
  static const chevronRight = PhosphorIconsRegular.caretRight;
  static const chevronDown = PhosphorIconsRegular.caretDown;
  static const more = PhosphorIconsRegular.dotsThreeOutlineVertical;
  static const search = PhosphorIconsRegular.magnifyingGlass;
  static const edit = PhosphorIconsRegular.pencilSimple;
  static const info = PhosphorIconsRegular.info;
  static const trash = PhosphorIconsRegular.trash;
  static const drag = PhosphorIconsRegular.dotsSixVertical;
  static const refresh = PhosphorIconsRegular.arrowClockwise;
  static const cube = PhosphorIconsRegular.cube;
  static const body = PhosphorIconsRegular.personArmsSpread;
  static const plates = PhosphorIconsRegular.barbell;
  static const footprints = PhosphorIconsRegular.footprints;
  // Bolder variants for places where a hairline outline reads as weedy against
  // large numbers — the session stats row and the per-exercise action row.
  static const clockBold = PhosphorIconsBold.clock;
  static const dumbbellBold = PhosphorIconsBold.barbell;
  static const volumeBold = PhosphorIconsBold.stack;
  static const platesBold = PhosphorIconsBold.barbell;
  static const refreshBold = PhosphorIconsBold.arrowClockwise;
  static const swapBold = PhosphorIconsBold.arrowsLeftRight;
  static const addBold = PhosphorIconsBold.plus;
  static const checkBold = PhosphorIconsBold.check;
  // Accumulated load: deliberately NOT `barbell`, which `plates`/`dumbbell`
  // already use — three identical icons in one stats row read as a mistake.
  static const volume = PhosphorIconsRegular.stack;
  static const warmup = PhosphorIconsFill.fire;

  // Concepts
  static const fire = PhosphorIconsFill.fire;
  static const bolt = PhosphorIconsRegular.lightning;
  static const lightbulb = PhosphorIconsRegular.lightbulb;
  static const target = PhosphorIconsRegular.target;
  static const clock = PhosphorIconsRegular.clock;
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
  static const health = PhosphorIconsRegular.heartbeat;
  static const widget = PhosphorIconsRegular.appWindow;

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

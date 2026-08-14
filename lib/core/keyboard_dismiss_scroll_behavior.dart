import 'package:flutter/material.dart';

/// Makes every scrollable in the app dismiss the keyboard as soon as the
/// user starts dragging/scrolling, without each screen opting in
/// individually. Set once on [MaterialApp.scrollBehavior].
class KeyboardDismissScrollBehavior extends MaterialScrollBehavior {
  @override
  ScrollViewKeyboardDismissBehavior getKeyboardDismissBehavior(
    BuildContext context,
  ) => ScrollViewKeyboardDismissBehavior.onDrag;
}

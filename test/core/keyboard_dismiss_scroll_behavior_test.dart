import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logged/core/keyboard_dismiss_scroll_behavior.dart';

void main() {
  testWidgets(
    'dismisses the keyboard on drag for every scrollable in the app',
    (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: KeyboardDismissScrollBehavior(),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final behavior = ScrollConfiguration.of(capturedContext);
      expect(
        behavior.getKeyboardDismissBehavior(capturedContext),
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
    },
  );
}

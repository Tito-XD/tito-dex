import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/widgets/handheld_input.dart';

void main() {
  testWidgets('D-pad traverses focus and A activates the focused control', (
    tester,
  ) async {
    var activated = '';
    await tester.pumpWidget(
      MaterialApp(
        home: HandheldInputShell(
          child: Column(
            children: [
              TextButton(
                autofocus: true,
                onPressed: () => activated = 'first',
                child: const Text('first'),
              ),
              TextButton(
                onPressed: () => activated = 'second',
                child: const Text('second'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.gameButtonA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pump();

    expect(activated, 'second');
  });
}

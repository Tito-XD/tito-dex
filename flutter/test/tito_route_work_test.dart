import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/navigation/tito_route_work.dart';

void main() {
  _registerRouteFocusTests();
  testWidgets('route work starts only after the incoming transition settles', (
    tester,
  ) async {
    final starts = ValueNotifier<int>(0);
    addTearDown(starts.dispose);

    await tester.pumpWidget(_RouteWorkHarness(starts: starts));
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(starts.value, 0);

    await tester.pump(const Duration(milliseconds: 120));
    expect(starts.value, 0);

    await tester.pumpAndSettle();
    expect(starts.value, 1);
  });

  testWidgets('route work is cancelled when the incoming page is popped', (
    tester,
  ) async {
    final starts = ValueNotifier<int>(0);
    addTearDown(starts.dispose);

    await tester.pumpWidget(_RouteWorkHarness(starts: starts));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(starts.value, 0);

    tester
        .state<NavigatorState>(
          find.byKey(const ValueKey('route-work-navigator')),
        )
        .pop();
    await tester.pumpAndSettle();
    expect(starts.value, 0);
  });
}

class _RouteWorkHarness extends StatefulWidget {
  const _RouteWorkHarness({required this.starts});

  final ValueNotifier<int> starts;

  @override
  State<_RouteWorkHarness> createState() => _RouteWorkHarnessState();
}

class _RouteWorkHarnessState extends State<_RouteWorkHarness> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Navigator(
        key: const ValueKey('route-work-navigator'),
        pages: [
          MaterialPage<void>(
            key: const ValueKey('route-work-home'),
            child: Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => setState(() => _open = true),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          if (_open)
            MaterialPage<void>(
              key: const ValueKey('route-work-detail'),
              child: _DeferredProbe(onStart: () => widget.starts.value += 1),
            ),
        ],
        onDidRemovePage: (_) {
          if (_open) setState(() => _open = false);
        },
      ),
    );
  }
}

class _DeferredProbe extends StatefulWidget {
  const _DeferredProbe({required this.onStart});

  final VoidCallback onStart;

  @override
  State<_DeferredProbe> createState() => _DeferredProbeState();
}

class _DeferredProbeState extends State<_DeferredProbe> {
  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    if (await waitForIncomingRouteSettled(context)) {
      widget.onStart();
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('detail')));
}

void _registerRouteFocusTests() {
  testWidgets('returning from a route does not restore text input focus', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final fieldFocus = FocusNode();
    addTearDown(fieldFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [TitoRouteFocusObserver()],
        home: Scaffold(
          body: TextField(
            key: const ValueKey('search-field'),
            focusNode: fieldFocus,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('search-field')));
    await tester.pump();
    expect(fieldFocus.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('detail')),
      ),
    );
    await tester.pumpAndSettle();
    expect(fieldFocus.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-field')), findsOneWidget);
    expect(fieldFocus.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.tap(find.byKey(const ValueKey('search-field')));
    await tester.pump();
    expect(fieldFocus.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('explicit autofocus on a new editor remains available', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final originalFocus = FocusNode();
    final editorFocus = FocusNode();
    addTearDown(originalFocus.dispose);
    addTearDown(editorFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [TitoRouteFocusObserver()],
        home: Scaffold(body: TextField(focusNode: originalFocus)),
      ),
    );
    originalFocus.requestFocus();
    await tester.pump();

    navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            Scaffold(body: TextField(autofocus: true, focusNode: editorFocus)),
      ),
    );
    await tester.pumpAndSettle();

    expect(originalFocus.hasFocus, isFalse);
    expect(editorFocus.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  });
}

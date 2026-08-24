import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:titodex/pages/dex/dex_reference_list.dart';

void main() {
  testWidgets('paints the reference shell before repository work starts', (
    tester,
  ) async {
    var loadCalls = 0;
    final router = _referenceRouter(
      loadEntries: () async {
        loadCalls += 1;
        return const [1, 2, 3];
      },
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_testApp(router));

    expect(find.text('招式图鉴'), findsOneWidget);
    expect(find.text('魂银 · HGSS'), findsOneWidget);
    expect(loadCalls, 0);

    await tester.pump();
    await tester.pumpAndSettle();

    expect(loadCalls, 1);
    expect(find.text('条目 1'), findsOneWidget);
  });

  testWidgets('materializes a bounded first batch then grows near the tail', (
    tester,
  ) async {
    final router = _referenceRouter(
      loadEntries: () async => List<int>.generate(100, (index) => index),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_testApp(router));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('条目 35'), findsOneWidget);
    expect(find.text('条目 36'), findsNothing);
    await tester.drag(find.byType(ListView).first, const Offset(0, -5000));
    await tester.pumpAndSettle();

    expect(find.text('条目 36'), findsOneWidget);
  });

  testWidgets('debounces search and cancels the superseded query', (
    tester,
  ) async {
    var filterCalls = 0;
    final router = _referenceRouter(
      loadEntries: () async => List<int>.generate(100, (index) => index),
      filterEntry: (entry, query) {
        filterCalls += 1;
        return '$entry'.contains(query);
      },
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_testApp(router));
    await tester.pump();
    await tester.pumpAndSettle();

    final search = find.byType(TextField);
    await tester.enterText(search, '1');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(search, '99');
    await tester.pump(const Duration(milliseconds: 199));

    expect(filterCalls, 0);
    expect(find.text('条目 0'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(filterCalls, 100);
    expect(find.text('条目 99'), findsOneWidget);
    expect(find.text('条目 0'), findsNothing);
  });

  testWidgets('caches category counts across search rebuilds', (tester) async {
    var labelCalls = 0;
    final categoryFilter = DexReferenceCategoryFilter<int>(
      options: const [null, '偶数', '奇数'],
      label: (entry) {
        labelCalls += 1;
        return entry.isEven ? '偶数' : '奇数';
      },
      filter: (entry, category) =>
          category == null || (entry.isEven ? '偶数' : '奇数') == category,
    );
    final router = _referenceRouter(
      loadEntries: () async => List<int>.generate(10, (index) => index),
      categoryFilter: categoryFilter,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_testApp(router));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(labelCalls, 10);
    expect(find.text('全部 (10)'), findsOneWidget);
    expect(find.text('偶数 (5)'), findsOneWidget);
    expect(find.text('奇数 (5)'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(labelCalls, 10);
    expect(find.text('全部 (10)'), findsOneWidget);
  });
}

GoRouter _referenceRouter({
  required Future<List<int>> Function() loadEntries,
  bool Function(int entry, String query)? filterEntry,
  DexReferenceCategoryFilter<int>? categoryFilter,
}) {
  return GoRouter(
    initialLocation: '/reference',
    routes: [
      GoRoute(
        path: '/reference',
        builder: (context, state) => Scaffold(
          body: DexReferenceListPage<int>(
            title: '招式图鉴',
            subtitle: '魂银 · HGSS',
            loadEntries: loadEntries,
            filterEntry:
                filterEntry ?? (entry, query) => '$entry'.contains(query),
            primaryLabel: (entry) => '条目 $entry',
            secondaryLabel: (entry) => '#$entry',
            detailSheet: (_, _) {},
            categoryFilter: categoryFilter,
            entryId: (entry) => entry,
          ),
        ),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
    ],
  );
}

Widget _testApp(GoRouter router) {
  return MaterialApp.router(
    routerConfig: router,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  );
}

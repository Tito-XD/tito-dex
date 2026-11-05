import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/pages/dex/dex_reference_list.dart';
import 'package:titodex/widgets/tito_state_panel.dart';

void main() {
  testWidgets(
    'direct entry opens general detail even when current game excludes it',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/reference',
        routes: [
          GoRoute(
            path: '/reference',
            builder: (context, state) => Scaffold(
              body: DexReferenceListPage<int>(
                title: '招式图鉴',
                loadEntries: () async => const [1, 2],
                filterEntry: (entry, query) => '$entry'.contains(query),
                primaryLabel: (entry) => '招式 $entry',
                secondaryLabel: (entry) => '#$entry',
                detailSheet: (_, _) {},
                scopedDetailSheet: (context, entry, notice) {
                  showDialog<void>(
                    context: context,
                    builder: (_) =>
                        AlertDialog(content: Text('$entry · $notice')),
                  );
                },
                includeEntry: (entry) => entry == 1,
                scopeNotice: (entry) =>
                    entry == 2 ? AppZh.dexReferenceUnavailableInGame : null,
                initialEntryId: 2,
                openInitialEntry: true,
                entryId: (entry) => entry,
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('2 · 当前版本不可用'), findsOneWidget);
    },
  );

  testWidgets('missing stable id shows a data-package state', (tester) async {
    final router = GoRouter(
      initialLocation: '/reference',
      routes: [
        GoRoute(
          path: '/reference',
          builder: (context, state) => Scaffold(
            body: DexReferenceListPage<int>(
              title: '道具',
              loadEntries: () async => const [1],
              filterEntry: (_, _) => true,
              primaryLabel: (entry) => '$entry',
              secondaryLabel: (_) => '',
              detailSheet: (_, _) {},
              includeEntry: (_) => false,
              initialEntryId: 99,
              openInitialEntry: true,
              entryId: (entry) => entry,
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text(AppZh.dexReferenceDataMissing), findsOneWidget);
  });

  testWidgets('load failure shows a user-facing panel and retries', (
    tester,
  ) async {
    var attempts = 0;
    final router = GoRouter(
      initialLocation: '/reference',
      routes: [
        GoRoute(
          path: '/reference',
          builder: (context, state) => Scaffold(
            body: DexReferenceListPage<int>(
              title: '道具',
              loadEntries: () async {
                attempts += 1;
                if (attempts == 1) {
                  throw StateError('raw-internal-boom');
                }
                return const [7];
              },
              filterEntry: (_, _) => true,
              primaryLabel: (entry) => '道具 $entry',
              secondaryLabel: (_) => '',
              detailSheet: (_, _) {},
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(TitoErrorPanel), findsOneWidget);
    expect(find.textContaining('raw-internal-boom'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tito-error-retry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byType(TitoErrorPanel), findsNothing);
    expect(find.text('道具 7'), findsOneWidget);
  });
}

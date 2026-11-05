import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/pokeapi_client.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/handheld_input.dart';
import 'package:titodex/widgets/sticker_card.dart';
import 'package:titodex/widgets/tito_state_panel.dart';

Widget _host(Widget child, AppVisualStyle style) => MaterialApp(
  theme: buildTitoTheme(style),
  builder: (context, navigator) => HandheldInputShell(child: navigator!),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  for (final style in AppVisualStyle.values) {
    testWidgets('error panel shows mapped copy and retries (${style.name})', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(
          TitoErrorPanel.fromError(
            PokeApiException('/pokemon/1', 503),
            onRetry: () => retries++,
          ),
          style,
        ),
      );
      expect(find.text(AppZh.dexLoadFailed), findsOneWidget);
      expect(find.text(AppZh.dexLoadFailedDetail(503)), findsOneWidget);
      expect(find.textContaining('PokeApiException'), findsNothing);
      expect(find.byType(StickerCard), findsOneWidget);
      final retry = find.byKey(const ValueKey('tito-error-retry'));
      expect(tester.getSize(retry).height, greaterThanOrEqualTo(40));
      await tester.tap(retry);
      expect(retries, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('retry is a D-pad stop activated with A', (tester) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    var retries = 0;
    await tester.pumpWidget(
      _host(
        TitoErrorPanel(message: '网络不可用', onRetry: () => retries++),
        AppVisualStyle.classic,
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pumpAndSettle();
    expect(retries, 1);
  });

  testWidgets('unframed variants draw no card; empty state centres', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TitoErrorPanel(title: '读取失败', framed: false),
            SizedBox(
              height: 200,
              width: 300,
              child: TitoEmptyState(
                message: '没有结果',
                framed: false,
                centered: true,
                action: TextButton(onPressed: () {}, child: const Text('刷新')),
              ),
            ),
          ],
        ),
        AppVisualStyle.flatUi,
      ),
    );
    expect(find.byType(StickerCard), findsNothing);
    expect(find.byKey(const ValueKey('tito-error-retry')), findsNothing);
    expect(find.text('刷新'), findsOneWidget);
    final box = tester.getRect(find.byType(SizedBox).last);
    final text = tester.getCenter(find.text('没有结果'));
    expect((text.dx - box.center.dx).abs(), lessThan(2));
  });
}

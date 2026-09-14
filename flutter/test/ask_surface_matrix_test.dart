import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/journey/ask_titodex_entity_links.dart';
import 'package:titodex/features/journey/ask_titodex_history.dart';
import 'package:titodex/features/journey/progression_hints.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/retro_style.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/ask/ask_answer_card.dart';
import 'package:titodex/widgets/ask/ask_history_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('SURFACE_PHASE');
  for (final style in AppVisualStyle.values) {
    for (final size in [const Size(390, 844), const Size(640, 480)]) {
      for (final depth in [false, true]) {
        final id = '${style.name}-${size.width.toInt()}-$depth';
        testWidgets(id, (tester) async {
          SharedPreferences.setMockInitialValues({});
          await appVisualStyle.setStyle(style);
          await retroStyle.setEnabled(depth);
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final captureKey = GlobalKey();
          final opened = <Uri>[];
          const result = AskTitoDexResult(
            status: AskTitoDexStatus.answered,
            answer: '用雷之石使皮卡丘进化。',
            sources: [
              ProgressionSource(
                title: 'Evolution reference',
                url: 'https://example.test/evolution',
                accessedAt: '2026-09-14',
              ),
            ],
          );
          Future<void> capture(String state) async {
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (phase.isEmpty) return;
            final boundary =
                captureKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final file = File('../logs/p2/ask-surfaces-$phase/$id-$state.png');
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          await tester.pumpWidget(
            RepaintBoundary(
              key: captureKey,
              child: MaterialApp(
                theme: buildTitoTheme(style),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: SafeArea(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          AskAnswerCard(
                            question: '皮卡丘怎么进化？',
                            result: result,
                            entityResolver: DexAskTitoDexEntityResolver(
                              catalogLoader: () async => const [],
                            ),
                            sourceOpener: (uri) async {
                              opened.add(uri);
                              return true;
                            },
                            animateEvidence: false,
                            onRetry: () {},
                            onClarificationSelected: (_) {},
                          ),
                          TextButton(
                            key: const Key('open-history'),
                            onPressed: () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => AskHistoryManagerSheet(
                                entries: [
                                  AskTitoDexHistoryEntry(
                                    game: 'general',
                                    question: '皮卡丘怎么进化？',
                                    result: result,
                                    createdAt: DateTime(2026, 9, 14, 9, 30),
                                  ),
                                ],
                              ),
                            ),
                            child: const Text('History'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await capture('answer');
          await tester.tap(find.byKey(const Key('ask-titodex-source-summary')));
          await capture('sources');
          await tester.tap(find.byKey(const Key('ask-titodex-source-0')));
          expect(opened.single.toString(), 'https://example.test/evolution');
          await tester.tap(
            find.byKey(const Key('ask-titodex-source-sheet-close')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('open-history')));
          await capture('history');
          expect(find.text('通用 · 09-14 09:30'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/journey/ask_titodex_source_browser.dart';
import 'package:titodex/features/journey/progression_hints.dart';
import 'package:titodex/features/journey/ask_titodex_entity_links.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/ask/ask_answer_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const customTabs = MethodChannel(
    'plugins.flutter.droibit.github.io/custom_tabs',
  );
  const external = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final source = Uri.parse(
    'https://www.pokemon.com/us/pokemon-news?lang=en#reference',
  );

  tearDown(() {
    messenger.setMockMethodCallHandler(customTabs, null);
    messenger.setMockMethodCallHandler(external, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('public citations preserve the original query and fragment', () {
    expect(askTitoDexSourceUri(source.toString()), source);
    expect(
      askTitoDexSourceUri('https://new-pokemon-guide.net/guide'),
      isNotNull,
    );
    for (final url in [
      'http://www.pokemon.com/',
      'https://user:secret@www.pokemon.com/',
      'https://www.pokemon.com:8443/',
      'https://localhost/',
      'https://guide.local/',
      'https://127.0.0.1/',
      'https://10.0.0.1/',
      'https://[::1]/',
      'file:///etc/passwd',
      'javascript:alert(1)',
    ]) {
      expect(askTitoDexSourceUri(url), isNull, reason: url);
    }
  });

  test(
    'mobile sources open in the browser without rewriting the URL',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      MethodCall? opened;
      messenger.setMockMethodCallHandler(customTabs, (call) async {
        opened = call;
        return null;
      });
      messenger.setMockMethodCallHandler(
        external,
        (_) async => fail('Unexpected fallback'),
      );
      expect(await openAskTitoDexSource(source, theme: ThemeData()), isTrue);
      expect(opened?.method, 'launch');
      expect(opened?.arguments['url'], source.toString());
      expect(opened?.arguments['prefersDeepLink'], isFalse);
    },
  );

  test('a missing in-app browser falls back to the external browser', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(customTabs, (_) async {
      throw PlatformException(code: 'browser_unavailable');
    });
    MethodCall? opened;
    messenger.setMockMethodCallHandler(external, (call) async {
      opened = call;
      return true;
    });
    expect(await openAskTitoDexSource(source, theme: ThemeData()), isTrue);
    expect(opened?.arguments['url'], source.toString());
    expect(opened?.arguments['useWebView'], isFalse);
    expect(opened?.arguments['useSafariVC'], isFalse);
  });

  test(
    'text fallback trace survives history serialization and local tracing',
    () {
      final result = AskTitoDexResult.fromJson({
        'status': 'answered',
        'answer': '资料整理',
        'answerMode': 'curated_sources_qwen',
        'modelUsed': true,
        'modelProviders': [
          'workers-ai-qwen',
          'deepseek-text',
          'unrecognized',
          'deepseek-text',
        ],
        'outlineMode': 'basic_web_outline',
        'sourceKinds': ['exa'],
      });
      final restored = AskTitoDexResult.fromJson(
        result.toJson(),
      ).withRuntimeTrace(onlineAttempted: true);
      expect(restored.modelProviders, ['workers-ai-qwen', 'deepseek-text']);
      expect(restored.sourceKinds, ['exa']);
      expect(restored.outlineMode, 'basic_web_outline');
      expect(restored.answerMode, AskTitoDexAnswerMode.curatedSourcesQwen);
      expect(
        AskTitoDexResult.fromJson({'status': 'answered'}).modelProviders,
        isEmpty,
      );
    },
  );
  for (final mode in [
    AskTitoDexAnswerMode.curatedSourcesQwen,
    AskTitoDexAnswerMode.auditedOnline,
    AskTitoDexAnswerMode.aiSearchAudited,
  ]) {
    for (final mixed in [false, true]) {
      testWidgets(
        'fallback model is shown accurately for ${mode.name} / $mixed',
        (tester) async {
          final result = AskTitoDexResult(
            status: AskTitoDexStatus.answered,
            answer: '本条回答来自提供的资料。',
            answerMode: mode,
            modelUsed: true,
            modelProviders: [if (mixed) 'workers-ai-qwen', 'deepseek-text'],
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: buildTitoTheme(),
              home: Scaffold(
                body: ListView(
                  children: [
                    AskAnswerCard(
                      question: '资料说明',
                      result: result,
                      entityResolver: DexAskTitoDexEntityResolver(
                        catalogLoader: () async => const [],
                      ),
                      sourceOpener: (_) async => true,
                      animateEvidence: false,
                      onRetry: () {},
                      onClarificationSelected: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(AppZh.askTitoDexTraceDeepseekText), findsNothing);
          await tester.tap(find.byKey(const Key('ask-titodex-source-summary')));
          await tester.pumpAndSettle();
          expect(
            find.text(
              mixed
                  ? AppZh.askTitoDexTraceQwenDeepseek
                  : AppZh.askTitoDexTraceDeepseekText,
            ),
            findsOneWidget,
          );
          expect(find.text(AppZh.askTitoDexTraceModel), findsNothing);
          expect(find.text(AppZh.askTitoDexRouteCuratedQwen), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

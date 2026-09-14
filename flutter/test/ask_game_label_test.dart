import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/journey/ask_titodex_history.dart';
import 'package:titodex/features/journey/progression_hints.dart';
import 'package:titodex/l10n/app_locale.dart';
import 'package:titodex/widgets/ask/ask_conversation.dart';
import 'package:titodex/widgets/ask/ask_history_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppUiLanguage previousLanguage;
  setUp(() {
    previousLanguage = AppLocale.instance.language;
    AppLocale.instance.debugOverride(AppUiLanguage.zh);
  });
  tearDown(() => AppLocale.instance.debugOverride(previousLanguage));

  testWidgets('general history uses the Chinese label and keeps exact names', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const AskQuestionBubble(
                question: '通用问题',
                game: 'general',
                showGame: true,
              ),
              AskHistoryManagerSheet(
                entries: [
                  for (final game in ['general', 'soulsilver'])
                    AskTitoDexHistoryEntry(
                      game: game,
                      question: '历史问题',
                      result: const AskTitoDexResult(
                        status: AskTitoDexStatus.answered,
                        answer: '历史回答',
                      ),
                      createdAt: DateTime(2026, 9, 14, 9, 30),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('通用'), findsOneWidget);
    expect(find.text('通用 · 09-14 09:30'), findsOneWidget);
    expect(find.text('魂银 · 09-14 09:30'), findsOneWidget);
    expect(find.textContaining('general'), findsNothing);
  });
}

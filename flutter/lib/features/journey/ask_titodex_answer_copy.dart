import 'progression_hints.dart';
import 'ask_titodex_source_browser.dart';
import '../../l10n/app_zh.dart';

String askTitoDexAnswerCopyText(String question, AskTitoDexResult result) {
  final body = askTitoDexAnswerBody(result.answer ?? '');
  final parts = [question.trim(), body];
  final seen = <String>{};
  final sources = <String>[];
  for (final source in result.sources) {
    final uri = askTitoDexSourceUri(source.url);
    if (uri == null || !seen.add(uri.replace(fragment: '').toString())) {
      continue;
    }
    sources.add('[${sources.length + 1}] ${source.title}\n${uri.toString()}');
  }
  if (sources.isNotEmpty) {
    parts.add('${AppZh.askTitoDexCopySources}\n${sources.join('\n\n')}');
  }
  return parts.where((part) => part.isNotEmpty).join('\n\n');
}

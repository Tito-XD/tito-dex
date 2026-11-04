// Ratchet for UI consistency debt outside lib/theme and lib/l10n.
//
// Each rule counts one ad-hoc pattern in feature code. A count above its
// budget means new code bypassed the design system: use the replacement named
// in the rule (see docs/DESIGN_SYSTEM.md, "新增 UI 前必读"). A count below its
// budget means debt was paid down: lower the budget to the new count in the
// same change so it cannot creep back.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class _Rule {
  const _Rule(
    this.name,
    this.pattern,
    this.budget,
    this.instead, {
    this.allowFiles = const {},
    this.onlyUnder = const [],
  });

  final String name;
  final RegExp pattern;
  final int budget;
  final String instead;

  /// Repository-relative paths (forward slashes) that own the pattern.
  final Set<String> allowFiles;

  /// When non-empty, only paths under these prefixes are counted.
  final List<String> onlyUnder;
}

final _rules = <_Rule>[
  _Rule(
    'raw bottom sheet',
    RegExp(r'\bshowModalBottomSheet\s*[<(]'),
    0,
    'showTitoModalBottomSheet (themed handle, safe area and keyboard inset)',
    allowFiles: {'lib/navigation/tito_page_transition.dart'},
  ),
  _Rule(
    'bare progress indicator',
    RegExp(r'\b(Circular|Linear)ProgressIndicator\s*[.(]'),
    0,
    'TitoInlineLoading, TitoLoadingPanel, TitoPokeballLoading or '
        'TitoProgressBar',
  ),
  _Rule(
    'Material textTheme style',
    RegExp(r'\.textTheme\b'),
    1, // Home header title keeps its device-scaled headline size.
    'SecondaryTypography.onPage(context) / onCard / onGradient tokens',
  ),
  _Rule(
    'TitoColors.mutedInk',
    RegExp(r'\bTitoColors\.mutedInk\b'),
    0,
    'TitoTypography.mutedColor (resolves per theme)',
  ),
  _Rule(
    'per-theme branch',
    RegExp(
      r'\bappVisualStyle\s*\.\s*uses(FlatUi|SolidPlastic|TrainerJournal)\b',
    ),
    0,
    'a TitoSurfaceTokens role, titoChoiceTile, TitoTypography.inkColor / '
        'mutedColor, or a shared widget that switches on '
        'TitoSurfaceTokens.of(context).finish',
  ),
  _Rule(
    'finish branch in a page',
    RegExp(r'\bTitoSurfaceFinish\.'),
    0,
    'a TitoSurfaceTokens role or a shared widget in lib/widgets that owns '
        'the per-finish look (TitoHeaderRoundButton, TitoScrollToTopButton)',
    onlyUnder: [
      'lib/pages/',
      'lib/features/',
      'lib/navigation/',
      'lib/app.dart',
    ],
  ),
  _Rule(
    'colour literal',
    RegExp(r'\bColor\(0x'),
    10,
    'a TitoColors / TrainerJournal token or a TitoSurfaceTokens role',
    // Data palettes and hand-painted art, not UI chrome.
    allowFiles: {
      'lib/features/dex/type_chart.dart',
      'lib/features/game/game_edition.dart',
      'lib/widgets/ask_answer_motion_title.dart',
    },
  ),
  _Rule(
    'raw TextStyle',
    RegExp(r'(?<![.\w])TextStyle\('),
    19,
    'SecondaryTypography tokens or TitoTypography.style',
  ),
  _Rule(
    'coral accent',
    RegExp(r'\bTitoColors\.coral\b'),
    26,
    'coral is for CTAs and destructive actions only; selection uses '
        'softYellow / mint, text uses ink or muted',
  ),
  _Rule(
    'inline locale pick',
    RegExp(r'\bAppLocale\.pick\('),
    87,
    'a getter in lib/l10n/app_zh.dart / app_en.dart',
  ),
];

/// Feature code. Theme, l10n, models and services own their primitives.
const _scannedRoots = [
  'lib/pages',
  'lib/widgets',
  'lib/features',
  'lib/navigation',
  'lib/app.dart',
];

Iterable<File> _dartFiles() sync* {
  for (final root in _scannedRoots) {
    final type = FileSystemEntity.typeSync(root);
    if (type == FileSystemEntityType.file) {
      yield File(root);
    } else if (type == FileSystemEntityType.directory) {
      yield* Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
    }
  }
}

/// Drops `//` line comments so doc comments may name the patterns they ban.
/// String literals containing `//` (URLs) are cut short too; the rules never
/// match inside URLs, so that only under-counts harmless text.
String _code(String line) {
  final comment = line.indexOf('//');
  return comment < 0 ? line : line.substring(0, comment);
}

void main() {
  final counts = {for (final rule in _rules) rule: <String, int>{}};
  for (final file in _dartFiles()) {
    final path = file.path.replaceAll(r'\', '/');
    // Whole file, so a call the formatter wrapped across lines still counts.
    final code = file.readAsLinesSync().map(_code).join('\n');
    for (final rule in _rules) {
      if (rule.allowFiles.contains(path)) continue;
      if (rule.onlyUnder.isNotEmpty &&
          !rule.onlyUnder.any((prefix) => path.startsWith(prefix))) {
        continue;
      }
      final hits = rule.pattern.allMatches(code).length;
      if (hits > 0) counts[rule]![path] = hits;
    }
  }

  test('scanner sees the feature sources', () {
    expect(_dartFiles().length, greaterThan(50));
  });

  for (final rule in _rules) {
    test('UI consistency budget: ${rule.name}', () {
      final byFile = counts[rule]!;
      final total = byFile.values.fold<int>(0, (sum, n) => sum + n);
      final worst =
          (byFile.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
              .take(8)
              .map((e) => '  ${e.value}× ${e.key}')
              .join('\n');
      if (total > rule.budget) {
        fail(
          '${rule.name}: $total found, budget ${rule.budget}.\n'
          'Use ${rule.instead} instead.\n'
          'Most occurrences:\n$worst',
        );
      }
      if (total < rule.budget) {
        fail(
          '${rule.name}: $total found, budget ${rule.budget}. Debt went '
          'down; lower the budget in test/ui_consistency_budget_test.dart '
          'to $total so it cannot return.',
        );
      }
    });
  }
}

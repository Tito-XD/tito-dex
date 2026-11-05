// D-pad reachability scan over the real app router.
//
// For every main route this checks two things on the visible screen:
//  1. Every control a finger can tap is also a focus stop, so a handheld user
//     can land on it (no tap-only GestureDetector islands).
//  2. Every focus stop can be reached from the first one using only the four
//     D-pad directions with the app's own traversal policy.
//
// A failure names the route and the control so the gap can be fixed at the
// shared widget that drew it.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/app.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/dex_repository.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/widgets/handheld_focus_geometry.dart';
import 'package:titodex/widgets/handheld_input.dart';
import 'package:titodex/widgets/tito_page_container.dart';

const _summary = PokemonSummary(
  id: 1,
  nameEn: 'Bulbasaur',
  nameZh: '妙蛙种子',
  types: ['grass', 'poison'],
);

const _detail = PokemonDetail(
  summary: _summary,
  forms: [
    PokemonFormDetail(
      key: 'bulbasaur',
      pokemonId: 1,
      nameEn: 'bulbasaur',
      nameZh: '妙蛙种子',
      kind: PokemonFormKind.form,
      isDefault: true,
      isBattleOnly: false,
      isMega: false,
      isCosmetic: false,
      types: ['grass', 'poison'],
      heightDm: 7,
      weightHg: 69,
      availableVersionGroups: ['scarlet-violet'],
    ),
  ],
  genusZh: '种子宝可梦',
  heightDm: 7,
  weightHg: 69,
  weaknesses: ['fire', 'flying'],
  resistances: ['water'],
  immunities: [],
  stabSuperEffective: ['water'],
  baseStats: PokemonBaseStats(
    hp: 45,
    attack: 49,
    defense: 49,
    specialAttack: 65,
    specialDefense: 65,
    speed: 45,
  ),
  abilities: [
    PokemonAbility(
      nameEn: 'overgrow',
      nameZh: '茂盛',
      descriptionZh: '危急时招式威力提高。',
    ),
  ],
  evolutionChain: EvolutionNode(
    id: 1,
    nameEn: 'bulbasaur',
    nameZh: '妙蛙种子',
    children: [
      EvolutionNode(
        id: 2,
        nameEn: 'ivysaur',
        nameZh: '妙蛙草',
        triggerZh: 'Lv.16',
      ),
    ],
  ),
  moveSet: PokemonMoveSet(
    levelUp: [
      PokemonMove(
        move: CachedMove(
          id: 33,
          nameEn: 'tackle',
          nameZh: '撞击',
          type: 'normal',
          category: 'physical',
        ),
        method: 'level-up',
        level: 1,
      ),
    ],
  ),
);

/// Routes a handheld user opens directly. Detail tabs are walked separately.
const _routes = [
  '/',
  '/team',
  '/journey',
  '/dex',
  '/dex/1',
  '/dex/moves',
  '/dex/abilities',
  '/dex/locations',
  '/dex/quiz',
  '/search',
  '/search/reference',
  '/search/companion/type-matchup',
  '/search/companion/stat-calc',
  '/search/companion/blind-spot',
  '/search/companion/quick-damage',
  '/search/sleep-tools',
  '/settings',
  '/settings/profile',
  '/settings/assistant',
  '/settings/companion',
  '/settings/appearance',
  '/settings/data',
  '/settings/about',
  '/settings/media-resources',
];

/// `--dart-define=HANDHELD_SCAN_ROUTES=/search,/dex/1` narrows a local rerun.
const _only = String.fromEnvironment('HANDHELD_SCAN_ROUTES');

/// `--dart-define=HANDHELD_SCAN_TRACE=true` prints every D-pad move.
const _trace = bool.fromEnvironment('HANDHELD_SCAN_TRACE');

const _sizes = {'portrait': Size(400, 800), 'landscape': Size(960, 540)};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final documents = Directory('build/handheld-scan-fixture').absolute;
    final cache = Directory('${documents.path}/dex_offline')
      ..createSync(recursive: true);
    Directory('${cache.path}/details').createSync(recursive: true);
    File('${cache.path}/manifest.json').writeAsStringSync(
      jsonEncode(
        const DexCacheManifest(
          version: DexCacheManifest.currentVersion,
          complete: true,
          preferOffline: true,
          pokemonCount: 9,
        ).toJson(),
      ),
    );
    File('${cache.path}/summaries.json').writeAsStringSync(
      jsonEncode([
        for (var id = 1; id <= 9; id++)
          PokemonSummary(
            id: id,
            nameEn: 'fixture-$id',
            nameZh: '测试$id',
            types: const ['grass'],
          ).toJson(),
      ]),
    );
    File(
      '${cache.path}/details/1.json',
    ).writeAsStringSync(jsonEncode(_detail.toJson()));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => documents.path,
        );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (_) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        final args = call.arguments as Map<dynamic, dynamic>?;
        if (call.method == 'create' && args?['playerId'] != null) {
          messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/${args!['playerId']}'),
            (_) async => null,
          );
        }
        return 1;
      },
    );
    await dexRepository.getAllSummaries().timeout(const Duration(seconds: 10));
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding.completed.v1': true});
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  for (final style in AppVisualStyle.values) {
    for (final size in _sizes.entries) {
      testWidgets('every tappable control is a D-pad stop '
          '(${style.name}, ${size.key})', (tester) async {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        addTearDown(() => appVisualStyle.setStyle(AppVisualStyle.classic));
        await appVisualStyle.setStyle(style);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(const TitoDexApp());
        await _settle(tester);
        final problems = <String>[];
        for (final route in _routes) {
          if (_only.isNotEmpty && !_only.split(',').contains(route)) continue;
          GoRouter.of(
            tester.element(find.byType(TitoPageContainer).last),
          ).go(route);
          await _settle(tester);
          final tabs = route == '/dex/1' ? 4 : 1;
          for (var tab = 0; tab < tabs; tab++) {
            if (tab > 0) {
              await tester.tap(find.byKey(ValueKey('detail-tab-surface-$tab')));
              await _settle(tester);
            }
            final where = tab == 0 ? route : '$route#tab$tab';
            problems.addAll(
              (await _scan(tester)).map((problem) => '$where  $problem'),
            );
          }
        }
        expect(tester.takeException(), isNull);
        semantics.dispose();
        expect(problems, isEmpty, reason: problems.join('\n'));
      });
    }
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Visible semantics nodes that accept a tap but are not focusable.
Set<String> _tapOnly(WidgetTester tester) {
  final root =
      tester.binding.renderViews.first.owner!.semanticsOwner?.rootSemanticsNode;
  if (root == null) return const {};
  final screen = Offset.zero & tester.view.physicalSize;
  final out = <String>{};
  void visit(SemanticsNode node, Matrix4 transform, bool focusableAbove) {
    final data = node.getSemanticsData();
    final local = node.transform == null
        ? transform
        : (transform.clone()..multiply(node.transform!));
    final rect = MatrixUtils.transformRect(local, node.rect);
    final focusable = data.flagsCollection.isFocused != ui.Tristate.none;
    if (data.hasAction(ui.SemanticsAction.tap) &&
        !focusable &&
        !focusableAbove &&
        !node.isInvisible &&
        rect.overlaps(screen)) {
      final label = data.label.isNotEmpty
          ? data.label
          : data.tooltip.isNotEmpty
          ? data.tooltip
          : '(unlabelled ${rect.size.width.round()}x'
                '${rect.size.height.round()})';
      out.add('tap-only  ${label.replaceAll('\n', ' ')}');
    }
    node.visitChildren((child) {
      visit(child, local, focusable && data.label.isEmpty);
      return true;
    });
  }

  visit(root, Matrix4.identity(), false);
  return out;
}

/// Walks the page with the four D-pad directions from its first stop.
/// Reports tap-only controls seen at any scroll position, and stops that were
/// on screen at some point but never reached.
Future<List<String>> _scan(WidgetTester tester) async {
  final scope = FocusScope.of(
    tester.element(find.byType(TitoPageContainer).last),
  );
  // Keyed by description: focus-driven reveals rebuild their controls, so
  // the same chip can come back with a new FocusNode.
  final visibleEver = <String, String>{};
  final reached = <String>{};
  final problems = <String>{..._tapOnly(tester)};
  void noteVisible() {
    for (final node in scope.traversalDescendants) {
      if (node.canRequestFocus &&
          !node.skipTraversal &&
          HandheldFocusGeometry.of(node)?.isVisible == true) {
        final description = _describe(node);
        visibleEver.putIfAbsent(_identity(description), () => description);
      }
    }
  }

  noteVisible();
  if (_trace) {
    // ignore: avoid_print
    print(
      'START primary=${FocusManager.instance.primaryFocus} '
      'visible=${visibleEver.values.join(' | ')}',
    );
  }
  if (visibleEver.isEmpty) return problems.toList();
  final start = scope.traversalDescendants.firstWhere(
    (node) =>
        node.canRequestFocus &&
        !node.skipTraversal &&
        HandheldFocusGeometry.of(node)?.isVisible == true,
  );
  reached.add(_identity(_describe(start)));
  const keys = [
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  ];
  Future<void> settleFocus() async {
    // Let focus-driven reveals (Search suggestions) finish before moving.
    // A focused text field scrolls itself into view on the next frame; the
    // Scrollable ignores pointers (and the cue hides) until that ends.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  // Re-enter a stop. Controls that only exist while a neighbour holds focus
  // (Search chips under the focused field) are reached by replaying the
  // D-pad path that found them, as a player would.
  Future<FocusNode?> arrive(
    FocusNode node,
    List<LogicalKeyboardKey> path,
  ) async {
    if (node.context?.mounted == true &&
        node.canRequestFocus &&
        HandheldFocusGeometry.of(node)?.isVisible == true) {
      node.requestFocus();
      await settleFocus();
      return node;
    }
    if (start.context?.mounted != true) return null;
    start.requestFocus();
    await settleFocus();
    for (final key in path) {
      await tester.sendKeyEvent(key);
      await settleFocus();
    }
    final now = FocusManager.instance.primaryFocus;
    return now?.context?.mounted == true ? now : null;
  }

  final seen = <FocusNode>{start};
  // Rebuilt controls come back as new nodes in the same place.
  final seenAt = <String>{_describe(start)};
  final queue = <(FocusNode, List<LogicalKeyboardKey>)>[(start, const [])];
  var steps = 0;
  while (queue.isNotEmpty && steps < 1200) {
    final (node, path) = queue.removeAt(0);
    for (final key in keys) {
      final from = await arrive(node, path);
      if (from == null) break;
      await tester.sendKeyEvent(key);
      await settleFocus();
      steps++;
      final now = FocusManager.instance.primaryFocus;
      if (_trace) {
        // ignore: avoid_print
        print(
          'MOVE ${_describe(from)} ${key.keyLabel} -> '
          '${now == null || now.context == null ? now : _describe(now)}',
        );
      }
      if (now != null &&
          now.context?.mounted == true &&
          HandheldFocusGeometry.of(now) != null &&
          seen.add(now) &&
          seenAt.add(_describe(now))) {
        queue.add((now, [...path, key]));
        reached.add(_identity(_describe(now)));
      }
      noteVisible();
      problems.addAll(_tapOnly(tester));
    }
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  return [
    ...problems,
    for (final entry in visibleEver.entries)
      if (!reached.contains(entry.key)) 'unreachable  ${entry.value}',
  ];
}

String _identity(String description) =>
    description.replaceFirst(RegExp(r' @Offset\(.*\)$'), '');

String _describe(FocusNode node) {
  final element = node.context! as Element;
  final texts = <String>[];
  void collect(Element e) {
    final widget = e.widget;
    if (widget is Text && widget.data != null) texts.add(widget.data!);
    if (widget is Icon && widget.semanticLabel != null) {
      texts.add(widget.semanticLabel!);
    }
    if (texts.length < 3) e.visitChildElements(collect);
  }

  collect(element);
  final owner = element.findAncestorWidgetOfExactType<HandheldFocusDecorator>();
  return '${element.widget.runtimeType}'
      '${owner == null ? '' : ' in HandheldFocusDecorator'}'
      ' "${texts.take(3).join(' / ')}"'
      ' @${HandheldFocusGeometry.of(node)?.bounds.topLeft}';
}

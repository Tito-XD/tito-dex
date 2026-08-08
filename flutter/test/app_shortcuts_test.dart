import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/app_shortcuts/app_shortcuts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to dex and search and persists stable ids', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = AppShortcutPreferences();
    await preferences.load();

    expect(preferences.selected.map((item) => item.id), ['dex', 'search']);
    expect(await preferences.toggle(AppShortcutOption.moves), isTrue);

    final restored = AppShortcutPreferences();
    await restored.load();
    expect(restored.selected.map((item) => item.id), [
      'dex',
      'search',
      'moves',
    ]);
  });

  test('selection is unique and capped at three', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = AppShortcutPreferences();
    await preferences.setSelected([
      AppShortcutOption.dex,
      AppShortcutOption.dex,
      AppShortcutOption.search,
      AppShortcutOption.moves,
      AppShortcutOption.typeMatchup,
    ]);

    expect(preferences.selected.map((item) => item.id), [
      'dex',
      'search',
      'moves',
    ]);
    expect(await preferences.toggle(AppShortcutOption.typeMatchup), isFalse);
  });

  test('stored unknown shortcut ids are ignored', () async {
    SharedPreferences.setMockInitialValues({
      'appShortcuts.selected': ['unknown', 'type-matchup'],
    });
    final preferences = AppShortcutPreferences();
    await preferences.load();

    expect(preferences.selected.single, AppShortcutOption.typeMatchup);
  });

  test('defaults can be replaced with reference and tool pages', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = AppShortcutPreferences();
    await preferences.load();

    expect(await preferences.toggle(AppShortcutOption.dex), isTrue);
    expect(await preferences.toggle(AppShortcutOption.items), isTrue);
    expect(await preferences.toggle(AppShortcutOption.quickDamage), isTrue);

    expect(preferences.selected.map((item) => item.id), [
      'search',
      'items',
      'quick-damage',
    ]);
  });

  test('every customizable destination has a stable unique id and route', () {
    expect(AppShortcutOption.all.length, greaterThan(4));
    expect(
      AppShortcutOption.all.map((item) => item.id).toSet().length,
      AppShortcutOption.all.length,
    );
    expect(
      AppShortcutOption.all.map((item) => item.route).toSet().length,
      AppShortcutOption.all.length,
    );
    expect(
      AppShortcutOption.all.every((item) => item.route.startsWith('/')),
      isTrue,
    );
    expect(
      AppShortcutOption.all
          .where((item) => item.route.contains('/reference/json?kind='))
          .every((item) => item.referenceFilename?.endsWith('.json') == true),
      isTrue,
    );
  });
}

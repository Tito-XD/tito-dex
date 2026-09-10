import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/app_shortcuts/app_shortcuts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'trainer shortcut uses a named home entry without replacing dynamic shortcuts',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('com.tito.titodex/app_shortcuts');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'trainerShortcutSupported' => true,
          'pinTrainerShortcut' => 'requested',
          'updateTrainerShortcut' => 'updated',
          _ => null,
        };
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final platform = AppShortcutsPlatform(channel: channel);
      expect(await platform.trainerShortcutSupported(), isTrue);
      expect(await platform.pinTrainerShortcut('小智'), 'requested');
      expect(await platform.updateTrainerShortcut('小霞'), 'updated');
      expect(calls.map((c) => c.method), [
        'trainerShortcutSupported',
        'pinTrainerShortcut',
        'updateTrainerShortcut',
      ]);
      expect((calls[1].arguments as Map)['label'], '小智Dex');
      expect((calls[2].arguments as Map)['label'], '小霞Dex');
    },
  );

  test('launcher rejection does not prevent saving a trainer name', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('com.tito.titodex/app_shortcuts');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'unsupported'),
    );
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final platform = AppShortcutsPlatform(channel: channel);
    expect(await platform.trainerShortcutSupported(), isFalse);
    expect(await platform.updateTrainerShortcut('小霞'), 'failed');
  });

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

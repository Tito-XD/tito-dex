import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/l10n/app_zh.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('vendored asset licenses ship with complete identifying text', () async {
    final nunito = await rootBundle.loadString(
      'assets/licenses/nunito-OFL.txt',
    );
    final pokesprite = await rootBundle.loadString(
      'assets/licenses/pokesprite-MIT.txt',
    );
    final neroli = await rootBundle.loadString(
      'assets/licenses/nerolis-lab-Apache-2.0.txt',
    );
    final neroliNotice = await rootBundle.loadString(
      'assets/licenses/nerolis-lab-NOTICE.txt',
    );

    expect(nunito, contains('SIL OPEN FONT LICENSE Version 1.1'));
    expect(nunito, contains('The Nunito Project Authors'));
    expect(pokesprite, contains('The MIT License (MIT)'));
    expect(pokesprite, contains('c5aaa610ff2acdf7fd8e2dccd181bca8be9fcb3e'));
    expect(neroli, contains('Apache License'));
    expect(neroli, contains('Version 2.0, January 2004'));
    expect(neroliNotice, contains("Neroli's Lab"));
    expect(neroliNotice, contains("Copyright The Neroli's Lab Authors"));
  });

  test('human-visible credits use the audited source boundaries', () {
    expect(AppZh.settingsAttributionBody, contains('CC BY-NC-SA 3.0'));
    final retiredClaim = ['CC BY-NC-SA', '4.0'].join(' ');
    expect(AppZh.settingsAttributionBody, isNot(contains(retiredClaim)));
    expect(AppZh.settingsAttributionBody, contains('PokéSprite'));
    expect(AppZh.settingsAttributionBody, contains('Nunito'));
    expect(AppZh.settingsAttributionBody, contains('Neroli’s Lab'));
    expect(AppZh.settingsAttributionBody, contains('Apache-2.0'));
  });

  test('every bundled game icon has a source or derivation record', () {
    final manifest =
        jsonDecode(File('assets/game_icons/SOURCES.json').readAsStringSync())
            as Map<String, dynamic>;
    final flavorAssets = manifest['flavorAssets'] as Map<String, dynamic>;
    final mergedAssets = manifest['mergedAssets'] as Map<String, dynamic>;
    final documented = {...flavorAssets.keys, ...mergedAssets.keys};
    final bundled = Directory('assets/game_icons')
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith('.png'))
        .toSet();

    expect(documented, bundled);
    expect(manifest['auditedAt'], '2026-08-10');
  });
}

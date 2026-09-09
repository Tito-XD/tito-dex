import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/journey/ask_motion_catalog.dart';
import 'package:titodex/features/journey/ask_motion_theme.dart';
import 'package:titodex/features/journey/ask_motion_images.dart';

void main() {
  const root = 'item-sprites/';
  const book = '${root}sonias-book.png';

  test('all question categories use Dex resources or existing App icons', () {
    const examples = <String, (String, AskMotionKind)>{
      '火球鼠在哪里可以捕捉？': ('capture', AskMotionKind.ball),
      '火球鼠什么时候学会喷射火焰？': ('moves', AskMotionKind.book),
      '火属性克制草属性吗？': ('types', AskMotionKind.emblems),
      '橙橙果有什么效果？': ('berry', AskMotionKind.berry),
      '橙橙果和桃桃果有什么区别？': ('berries', AskMotionKind.berries),
      '皮卡丘怎么进化，雷之石有什么用？': ('evolution', AskMotionKind.tokens),
      '幸运蛋可以加快升级吗？': ('level', AskMotionKind.tokens),
      '剩饭这个道具有什么效果？': ('items', AskMotionKind.tokens),
      '从桔梗市怎么走到桧皮镇？': ('route', AskMotionKind.map),
      '威吓这个特性有什么作用？': ('abilities', AskMotionKind.tokens),
      '宝可梦怎么孵蛋，蛋群是什么？': ('breeding', AskMotionKind.tokens),
      '努力值和个体值有什么区别？': ('stats', AskMotionKind.tokens),
      '下雨天气会影响什么招式？': ('weather', AskMotionKind.emblems),
      '怎么查当前游戏的资料？': ('general', AskMotionKind.book),
    };
    for (final entry in examples.entries) {
      final theme = classifyAskMotionTheme(entry.key);
      expect(theme.topic, entry.value.$1, reason: entry.key);
      expect(theme.kind, entry.value.$2, reason: entry.key);
      expect(theme.assets, isNotEmpty, reason: entry.key);
      for (final asset in theme.assets) {
        expect(
          asset.startsWith('item-sprites/') || File(asset).existsSync(),
          isTrue,
          reason: asset,
        );
      }
    }
    expect(askMotionIdleThemes.map((t) => t.topic).toSet(), hasLength(13));
  });

  test('named berries retain their identity and comparison order', () {
    final single = classifyAskMotionTheme('巧可果对火属性伤害有什么作用？');
    expect(single.kind, AskMotionKind.berry);
    expect(single.assets, ['${root}occa-berry.png']);
    final pair = classifyAskMotionTheme('文柚果和谜芝果有什么区别？');
    expect(pair.kind, AskMotionKind.berries);
    expect(pair.assets, ['${root}sitrus-berry.png', '${root}enigma-berry.png']);
    final repeated = classifyAskMotionTheme('文柚果（Sitrus Berry）有什么用？');
    expect(repeated.kind, AskMotionKind.berry);
    expect(repeated.assets, ['${root}sitrus-berry.png']);
  });

  test('every catalog berry keeps its exact Dex resource', () {
    final berries = askMotionCatalogItems.where((row) => row[2] == 'berry');
    expect(berries.length, greaterThanOrEqualTo(73));
    for (final row in berries) {
      final theme = classifyAskMotionTheme('${row[0]}有什么效果？');
      expect(theme.assets, contains(row[3]), reason: row[0]);
      expect(row[3], isNot(book), reason: row[0]);
    }
  });

  test('all eighteen explicit types use their own emblem', () {
    for (final row in askMotionCatalogTypes) {
      final theme = classifyAskMotionTheme('${row[0]}属性有什么弱点？');
      expect(theme.topic, 'types', reason: row[0]);
      expect(theme.assets, ['assets/type_icons/${row[1]}.png'], reason: row[0]);
    }
    expect(classifyAskMotionTheme('水属性克制火属性吗？').assets, [
      'assets/type_icons/water.png',
      'assets/type_icons/fire.png',
    ]);
  });

  test('species and move names do not invent explicit types', () {
    expect(classifyAskMotionTheme('喷火龙是什么宝可梦？').topic, 'capture');
    expect(classifyAskMotionTheme('喷火龙的属性是什么？').assets, hasLength(6));
    expect(classifyAskMotionTheme('喷射火焰是什么属性的招式？').assets, [
      'assets/type_icons/fire.png',
    ]);
    expect(classifyAskMotionTheme('火球鼠什么时候学会喷射火焰？').assets, [
      book,
      'assets/type_icons/fire.png',
    ]);
  });

  test(
    'specific items survive category intent; missing artwork stays neutral',
    () {
      expect(classifyAskMotionTheme('皮卡丘用雷之石进化吗？').assets, [
        '${root}thunder-stone.png',
      ]);
      expect(classifyAskMotionTheme('幸运蛋怎么加快升级？').assets, [
        '${root}lucky-egg.png',
      ]);
      expect(classifyAskMotionTheme('剩饭有什么用？').assets, [
        '${root}leftovers.png',
      ]);
      expect(classifyAskMotionTheme('神奇糖果有什么用？').assets, [
        '${root}rare-candy.png',
      ]);
    },
  );

  test('English names use boundaries and full-width input is normalized', () {
    expect(classifyAskMotionTheme('Ｗｈａｔ ｄｏｅｓ Ｏｃｃａ Ｂｅｒｒｙ ｄｏ？').assets, [
      '${root}occa-berry.png',
    ]);
    expect(
      classifyAskMotionTheme('When does Cyndaquil learn Flamethrower?').assets,
      [book, 'assets/type_icons/fire.png'],
    );
    expect(classifyAskMotionTheme('thunderboltish').topic, 'general');
    expect(classifyAskMotionTheme('').assets, [book]);
  });

  test('weather words do not match inside move or species names', () {
    expect(classifyAskMotionTheme('How does Drain Punch work?').assets, [
      book,
      'assets/type_icons/fighting.png',
    ]);
    expect(
      classifyAskMotionTheme('When can Eevee learn Draining Kiss?').assets,
      [book, 'assets/type_icons/fairy.png'],
    );
    expect(
      classifyAskMotionTheme('Where can I catch Abomasnow?').topic,
      'capture',
    );
    expect(
      classifyAskMotionTheme('How to train Eevee?').topic,
      isNot('weather'),
    );
    expect(classifyAskMotionTheme('What does rainy weather change?').assets, [
      '${root}damp-rock.png',
    ]);
    expect(classifyAskMotionTheme('What happens when it is snowing?').assets, [
      '${root}icy-rock.png',
    ]);
  });

  test(
    'catalog keeps safe relative resources and only starter props are packaged',
    () {
      final paths = <String>{
        ...askMotionCatalogItems.map((row) => row[3]),
        ...askMotionCatalogTypes.map(
          (row) => 'assets/type_icons/${row[1]}.png',
        ),
        ...askMotionIdleThemes.expand((theme) => theme.assets),
      };
      for (final path in paths) {
        if (path.startsWith('assets/')) {
          expect(File(path).existsSync(), isTrue, reason: path);
        } else {
          expect(
            RegExp(r'^item-sprites/[a-z0-9-]+\.png$').hasMatch(path),
            isTrue,
            reason: path,
          );
        }
      }
      final packaged = Directory('assets/ask_motion')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .toList();
      expect(packaged, hasLength(AskMotionImages.fallbackSlugs.length));
      expect(
        packaged.fold<int>(0, (sum, f) => sum + f.lengthSync()),
        lessThan(120000),
      );
      for (final slug in AskMotionImages.fallbackSlugs) {
        expect(File('assets/ask_motion/$slug.png').existsSync(), isTrue);
      }
    },
  );
}

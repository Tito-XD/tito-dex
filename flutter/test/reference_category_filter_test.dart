import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/pages/dex/ability_encyclopedia_page.dart';
import 'package:titodex/pages/dex/dex_json_reference_page.dart';
import 'package:titodex/widgets/dex_reference_detail.dart';

CachedAbility _abilityWithOwners(int count) => CachedAbility(
  id: count,
  nameEn: 'ability-$count',
  nameZh: '特性$count',
  descriptionZh: '',
  pokemonIds: List<int>.generate(count, (index) => index + 1),
);

void main() {
  test('ability filter groups signature, rare and common abilities', () {
    expect(abilityUsageCategoryLabel(_abilityWithOwners(1)), '专属');
    expect(abilityUsageCategoryLabel(_abilityWithOwners(5)), '少见');
    expect(abilityUsageCategoryLabel(_abilityWithOwners(6)), '常见');
  });

  test('nature filter groups by increased stat and keeps neutral natures', () {
    final filter = referenceCategoryFilterForKind(DexReferenceKind.nature)!;
    expect(filter.options, containsAll(['中性', '攻击↑', '速度↑']));
    expect(natureCategoryLabel({'slug': 'hardy'}), '中性');
    expect(
      natureCategoryLabel({'slug': 'adamant', 'increasedStat': 'attack'}),
      '攻击↑',
    );
  });

  test('egg groups separate water and special breeding groups', () {
    expect(eggGroupCategoryLabel({'slug': 'monster'}), '常规组');
    expect(eggGroupCategoryLabel({'slug': 'water2'}), '水中组');
    expect(eggGroupCategoryLabel({'slug': 'ditto'}), '特殊组');
    expect(eggGroupCategoryLabel({'slug': 'no-eggs'}), '特殊组');
  });

  test('weather and status filters use canonical battle groupings', () {
    expect(weatherCategoryLabel({'slug': 'rain'}), '常规天气');
    expect(weatherCategoryLabel({'slug': 'heavy-rain'}), '强天气');
    expect(statusCategoryLabel({'slug': 'burn'}), '主要异常');
    expect(statusCategoryLabel({'slug': 'confusion'}), '其他状态');
  });

  test('short terrain catalog stays unfiltered', () {
    expect(referenceCategoryFilterForKind(DexReferenceKind.terrain), isNull);
  });
}

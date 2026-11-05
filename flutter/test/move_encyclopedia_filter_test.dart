import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/pages/dex/move_encyclopedia_page.dart';

const _fireMove = CachedMove(
  id: 52,
  nameEn: 'ember',
  nameZh: '火花',
  type: 'fire',
  category: '特殊',
);

const _waterMove = CachedMove(
  id: 55,
  nameEn: 'water-gun',
  nameZh: '水枪',
  type: 'water',
  category: '特殊',
);

void main() {
  test('move type filter exposes all 18 types in canonical Chinese order', () {
    expect(moveTypeCategoryFilter.options, hasLength(19));
    expect(moveTypeCategoryFilter.options.first, isNull);
    expect(moveTypeCategoryFilter.options.sublist(1, 5), ['一般', '火', '水', '电']);
    expect(moveTypeCategoryFilter.options.last, '妖精');
  });

  test('move type filter matches only the selected Chinese type', () {
    expect(moveTypeCategoryFilter.label(_fireMove), '火');
    expect(moveTypeCategoryFilter.filter(_fireMove, '火'), isTrue);
    expect(moveTypeCategoryFilter.filter(_waterMove, '火'), isFalse);
  });

  test('move list subtitle localizes the bundle category slug', () {
    const move = CachedMove(
      id: 53,
      nameEn: 'flamethrower',
      nameZh: '喷射火焰',
      type: 'fire',
      category: 'special',
    );
    final label = moveSecondaryLabel(move);
    expect(label, '#53 · 火 · 特殊');
    expect(label, isNot(contains('special')));
  });
}

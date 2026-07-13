import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_filter.dart';

void main() {
  test('DexFilter.empty is not active', () {
    expect(DexFilter.empty.isActive, isFalse);
  });

  test('DexFilter detects move filter', () {
    const filter = DexFilter(
      learnsMoveId: 33,
      labelZh: '招式 · 撞击',
    );
    expect(filter.isActive, isTrue);
    expect(filter.learnsMoveId, 33);
  });

  test('DexFilter detects egg group filter', () {
    const filter = DexFilter(
      eggGroupSlug: 'monster',
      labelZh: '蛋群：怪兽',
    );
    expect(filter.isActive, isTrue);
    expect(filter.eggGroupSlug, 'monster');
  });

  test('DexFilterController set and clear', () {
    final controller = dexFilterController;
    addTearDown(controller.clearFilter);

    controller.setFilter(
      const DexFilter(
        abilityId: 65,
        labelZh: '特性 · 战斗盔甲',
      ),
    );
    expect(controller.hasActiveFilter, isTrue);
    expect(controller.currentFilter.abilityId, 65);

    controller.clearFilter();
    expect(controller.hasActiveFilter, isFalse);
    expect(controller.currentFilter, DexFilter.empty);
  });
}

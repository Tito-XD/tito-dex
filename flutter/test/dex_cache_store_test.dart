import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_cache_store.dart';
import 'package:titodex/features/dex/dex_models.dart';

void main() {
  test('mergeMoves deduplicates shared move definitions by id', () {
    const tackle = CachedMove(
      id: 33,
      nameEn: 'Tackle',
      nameZh: '撞击',
      type: 'normal',
      category: 'physical',
      power: 40,
      accuracy: 100,
      pp: 35,
    );
    const scratch = CachedMove(
      id: 10,
      nameEn: 'Scratch',
      nameZh: '抓',
      type: 'normal',
      category: 'physical',
      power: 40,
      accuracy: 100,
      pp: 35,
    );

    final merged = mergeMoves(
      {33: tackle},
      [tackle, scratch],
    );

    expect(merged.length, 2);
    expect(merged[33]?.nameZh, '撞击');
    expect(merged[10]?.nameZh, '抓');
  });
}

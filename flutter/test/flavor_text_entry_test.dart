import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/features/dex/dex_models.dart';

void main() {
  test('FlavorTextEntry displayLabel uses per-version title for dual games', () {
    const sharedLabel = '晶灿钻石/明亮珍珠';

    const brilliant = FlavorTextEntry(
      version: 'brilliant-diamond',
      text: 'A',
      labelZh: sharedLabel,
    );
    const shining = FlavorTextEntry(
      version: 'shining-pearl',
      text: 'B',
      labelZh: sharedLabel,
    );

    expect(brilliant.displayLabel, '晶灿钻石');
    expect(shining.displayLabel, '明亮珍珠');
    expect(brilliant.displayLabel, isNot(shining.displayLabel));
  });

  test('FlavorTextEntry displayLabel falls back to edition label for unknown version',
      () {
    const entry = FlavorTextEntry(
      version: 'unknown-edition',
      text: 'text',
      labelZh: '自定义版本',
    );

    expect(entry.displayLabel, '自定义版本');
  });
}

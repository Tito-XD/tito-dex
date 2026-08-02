import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_encounter_labels.dart';

void main() {
  test('encounter methods use concise Chinese labels', () {
    expect(encounterMethodLabelZh('max-raid'), '极巨团体战');
    expect(encounterMethodLabelZh('honey-tree'), '甜甜蜜树');
    expect(encounterMethodLabelZh('future-method'), '特殊遭遇方式');
  });

  test('patterned encounter conditions do not expose raw slugs', () {
    expect(encounterConditionLabelZh('max-den-rating-5-star'), '5★巢穴');
    expect(
      encounterConditionLabelZh('johto-safari-blocks-forest-min-10'),
      '狩猎地带：森林摆设≥10',
    );
    expect(
      encounterConditionLabelZh('story-progress-future-chapter'),
      '达到指定剧情进度',
    );
    expect(encounterConditionLabelZh('unknown-future-condition'), '特殊出现条件');
  });
}

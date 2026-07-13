import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/l10n/game_zh.dart';
import 'package:titodex/widgets/dex_reference_detail.dart';

void main() {
  group('formatNatureStatLine', () {
    test('shows increased and decreased stats in Chinese', () {
      expect(
        formatNatureStatLine(
          increasedStat: 'attack',
          decreasedStat: 'specialAttack',
        ),
        '↑ 攻击 · ↓ 特攻',
      );
    });

    test('uses pre-localized stat labels when provided', () {
      expect(
        formatNatureStatLine(
          increasedStatZh: '速度',
          decreasedStatZh: '防御',
        ),
        '↑ 速度 · ↓ 防御',
      );
    });

    test('returns neutral label when no stat changes', () {
      expect(formatNatureStatLine(), contains('中性'));
    });
  });

  group('itemCategoryLabelZh', () {
    test('maps healing category to 药品', () {
      expect(itemCategoryLabelZh('healing'), '药品');
    });

    test('maps standard-balls category to 精灵球', () {
      expect(itemCategoryLabelZh('standard-balls'), '精灵球');
    });

    test('falls back to slug for unknown categories', () {
      expect(itemCategoryLabelZh('unknown-category'), 'unknown-category');
    });
  });

  group('itemCostLabel', () {
    test('formats numeric cost with yen prefix', () {
      expect(itemCostLabel(200), '售价 ¥200');
    });

    test('returns null when cost missing', () {
      expect(itemCostLabel(null), isNull);
    });
  });

  group('flavorLabelZh', () {
    test('maps spicy to 辣', () {
      expect(flavorLabelZh('spicy'), flavorLabelsZh['spicy']);
    });
  });

  group('referenceTypeModifiers', () {
    test('reads explicit typeModifiers from entry', () {
      final modifiers = referenceTypeModifiers({
        'slug': 'custom',
        'typeModifiers': {'fire': 2.0, 'water': 0.5},
      });
      expect(modifiers?['fire'], 2.0);
      expect(modifiers?['water'], 0.5);
    });

    test('falls back to known weather modifiers by slug', () {
      final modifiers = referenceTypeModifiers({'slug': 'sun'});
      expect(modifiers?['fire'], 1.5);
      expect(modifiers?['water'], 0.5);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/journey/progression_hints.dart';
import 'package:titodex/features/journey/ask_titodex_entity_links.dart';

void main() {
  test(
    'structured identity survives response, runtime trace and history serialization',
    () {
      final result = AskTitoDexResult.fromJson({
        'status': 'answered',
        'answer': '火球鼠 → 火岩鼠 → 火暴兽',
        'confidence': 'medium',
        'evidence': {
          'basis': 'structured',
          'scope': 'general',
          'complete': true,
          'entityIds': ['pokemon:155', 'pokemon:156', 'pokemon:157'],
        },
      });
      final restored = AskTitoDexResult.fromJson(
        result.withRuntimeTrace(onlineAttempted: true).toJson(),
      );
      expect(restored.evidence?.entityIds, [
        'pokemon:155',
        'pokemon:156',
        'pokemon:157',
      ]);
      expect(restored.evidence?.scope, 'general');
    },
  );
  test(
    'malformed evidence cannot claim verification or supply an arbitrary route',
    () {
      expect(
        AskTitoDexEvidence.parse({
          'basis': 'structured',
          'scope': 'game',
          'complete': true,
          'entityIds': ['https://example.com'],
        }),
        isNull,
      );
      expect(
        AskTitoDexEvidence.parse({
          'basis': 'model_says_verified',
          'scope': 'game',
          'complete': true,
          'entityIds': [],
        }),
        isNull,
      );
    },
  );
  test(
    'entity buttons use the executed query IDs instead of contradictory text',
    () async {
      final resolver = DexAskTitoDexEntityResolver(
        catalogLoader: () async => const [
          AskTitoDexEntityRecord(
            kind: AskTitoDexEntityKind.pokemon,
            id: 130,
            nameZh: '暴鲤龙',
            nameEn: 'Gyarados',
          ),
          AskTitoDexEntityRecord(
            kind: AskTitoDexEntityKind.pokemon,
            id: 157,
            nameZh: '火暴兽',
            nameEn: 'Typhlosion',
          ),
        ],
      );
      final links = await resolver.resolve(
        question: '会进化成暴鲤龙吗？',
        answer: '火暴兽（Typhlosion）',
        stableIds: ['pokemon:157'],
      );
      expect(links.map((link) => link.id), [157]);
      expect(links.single.route, '/dex/157');
      expect(
        await resolver.resolve(question: '暴鲤龙', answer: '火暴兽', stableIds: []),
        isEmpty,
      );
    },
  );
}

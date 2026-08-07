import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/online_media_catalog.dart';
import 'package:titodex/features/dex/sprite_generation_catalog.dart';

void main() {
  group('OnlineMediaEntry', () {
    OnlineMediaEntry entry() => OnlineMediaEntry.fromJson({
      'id': 25,
      'nameZh': '皮卡丘',
      'cries': [
        {'title': '0025_cry.opus', 'url': 'https://media/standard.webm'},
        {'title': '0025GM_cry.opus', 'url': 'https://media/gmax.webm'},
        {'title': '0025O_cry.opus', 'url': 'https://media/cap.webm'},
      ],
      'forms': [
        {'file': 'HOME_025.png', 'kind': 'HOME'},
        {'file': 'HOME_025GM.png', 'kind': 'HOME'},
      ],
    });

    test('bestCryUrl prefers the standard cry', () {
      expect(entry().bestCryUrl(), 'https://media/standard.webm');
    });

    test('bestCryUrl matches a forme token when given', () {
      expect(
        entry().bestCryUrl(formKey: 'gigantamax'),
        'https://media/gmax.webm',
      );
    });

    test('named form aliases match compact 52poke cry suffixes', () {
      const koraidon = OnlineMediaEntry(
        id: 1007,
        nameZh: '故勒顿',
        cries: [
          OnlineCry(title: '1007_cry.opus', url: 'https://media/default'),
          OnlineCry(title: '1007L_cry.opus', url: 'https://media/limited'),
        ],
        forms: [],
      );
      expect(
        koraidon.bestCryUrl(formKey: 'koraidon-limited-build'),
        'https://media/limited',
      );
    });

    test('cry labels expose standard and form choices in Chinese', () {
      expect(entry().cries[0].labelZh, '标准叫声');
      expect(entry().cries[1].labelZh, '超极巨化');
      expect(entry().cries[2].labelZh, '初始帽子');
      expect(
        const OnlineCry(
          title: '1023_cry.ogg',
          url: 'https://pokeapi/1023.ogg',
        ).labelZh,
        '标准叫声',
      );
    });

    test('fromJson parses id from string keys too', () {
      final parsed = OnlineMediaEntry.fromJson({
        'id': '25',
        'nameZh': '皮卡丘',
        'cries': <Map<String, dynamic>>[],
        'forms': <Map<String, dynamic>>[],
      });
      expect(parsed.id, 25);
    });
  });

  group('cryCandidatesForMedia', () {
    test('52poke best cry leads, then CDN + PokeAPI fallbacks', () {
      final entry = OnlineMediaEntry.fromJson({
        'id': 25,
        'nameZh': '皮卡丘',
        'cries': [
          {'title': '0025_cry.opus', 'url': 'https://media/standard.webm'},
        ],
        'forms': <Map<String, dynamic>>[],
      });
      final candidates = cryCandidatesForMedia(25, entry);
      expect(candidates.first, 'https://media/standard.webm');
      expect(candidates.sublist(1), cryCandidatesFor(25));
    });
  });
}

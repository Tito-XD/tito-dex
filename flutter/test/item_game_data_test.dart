import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/item_game_data.dart';
import 'package:titodex/features/game/game_edition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('item availability follows the selected game', () async {
    final teraOrb = {'id': 3458, 'slug': 'tera-orb'};

    final hgss = await itemGameDataRepository.viewFor(
      teraOrb,
      GameEdition.hgss,
    );
    final scarletViolet = await itemGameDataRepository.viewFor(
      teraOrb,
      gameEditionFromSlug('sv')!,
    );

    expect(hgss.availability, ItemGameAvailability.unavailable);
    expect(scarletViolet.availability, ItemGameAvailability.available);
  });

  test('item prices vary by game and LZA uses canonical matrix key', () async {
    final pokeBall = {'id': 4, 'slug': 'poke-ball'};
    final hgss = await itemGameDataRepository.viewFor(
      pokeBall,
      GameEdition.hgss,
    );
    final lza = await itemGameDataRepository.viewFor(
      pokeBall,
      gameEditionFromSlug('lza')!,
    );

    expect(hgss.buy, 200);
    expect(lza.versionGroup, 'legends-z-a');
    expect(lza.availability, ItemGameAvailability.available);
    expect(lza.buy, 100);
  });

  test('paired-game key items respect the exact selected flavor', () async {
    final clearBell = {'id': 2450, 'slug': 'clear-bell'};
    final heartGold = await itemGameDataRepository.viewFor(
      clearBell,
      GameEdition.hgss.withFlavor('heartgold'),
    );
    final soulSilver = await itemGameDataRepository.viewFor(
      clearBell,
      GameEdition.hgss.withFlavor('soulsilver'),
    );

    expect(heartGold.availability, ItemGameAvailability.available);
    expect(soulSilver.availability, ItemGameAvailability.unavailable);
  });

  test('missing matrix entries stay visible as unknown', () async {
    final view = await itemGameDataRepository.viewFor({
      'id': 999999,
    }, GameEdition.hgss);
    expect(view.availability, ItemGameAvailability.unknown);
  });

  test(
    'games outside the source matrix do not hide the whole catalog',
    () async {
      final view = await itemGameDataRepository.viewFor({
        'id': 4,
        'slug': 'poke-ball',
      }, gameEditionFromSlug('champions')!);
      expect(view.availability, ItemGameAvailability.unknown);
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/companion/companion_media.dart';
import 'package:titodex/features/dex/sprite_generation_catalog.dart';

void main() {
  test('bundled set covers nine starter trios plus Pikachu and Eevee', () {
    expect(bundledCompanionIds, hasLength(29));
    // One trio spot-check per relevant generation boundary.
    expect(bundledCompanionIds, containsAll({1, 4, 7, 155, 906, 912, 25, 133}));
    expect(bundledCompanionIds.contains(2), isFalse); // evolutions excluded
  });

  test('bundled asset paths map by id and stay null for other species', () {
    expect(bundledCompanionGifAsset(155), 'assets/companion_media/155.gif');
    expect(bundledCompanionCryAsset(155), 'assets/companion_media/155.ogg');
    expect(bundledCompanionGifAsset(156), isNull);
    expect(bundledCompanionCryAsset(156), isNull);
  });

  test('gif download candidates are animated-only, CDN first', () {
    expect(companionGifDownloadCandidates(175), [
      cdnAnimatedGifUrlFor(175),
      showdownGifUrlFor(175),
      bwAnimatedGifUrlFor(175),
    ]);
    // Beyond the BW ceiling the BW gif drops out.
    expect(companionGifDownloadCandidates(1000), [
      cdnAnimatedGifUrlFor(1000),
      showdownGifUrlFor(1000),
    ]);
  });
}

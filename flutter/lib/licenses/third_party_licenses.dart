import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registers licenses for assets vendored directly by TitoDex.
///
/// Dart and Flutter package licenses are registered by their packages. These
/// entries cover files shipped from `assets/` rather than package code.
void registerThirdPartyLicenses() {
  _registerAssetLicense(
    packageNames: const ['Nunito'],
    assetPath: 'assets/licenses/nunito-OFL.txt',
  );
  _registerAssetLicense(
    packageNames: const ['PokéSprite type icons'],
    assetPath: 'assets/licenses/pokesprite-MIT.txt',
  );
  _registerAssetLicense(
    packageNames: const ['Neroli’s Lab formula ports'],
    assetPath: 'assets/licenses/nerolis-lab-Apache-2.0.txt',
    noticeAssetPath: 'assets/licenses/nerolis-lab-NOTICE.txt',
  );
}

void _registerAssetLicense({
  required List<String> packageNames,
  required String assetPath,
  String? noticeAssetPath,
}) {
  LicenseRegistry.addLicense(() async* {
    var text = await rootBundle.loadString(assetPath);
    if (noticeAssetPath != null) {
      final notice = await rootBundle.loadString(noticeAssetPath);
      text = '$notice\n\n$text';
    }
    yield LicenseEntryWithLineBreaks(packageNames, text);
  });
}

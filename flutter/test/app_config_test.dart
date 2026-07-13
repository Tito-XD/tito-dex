import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/config/app_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppConfig.instance.resetForTest();
  });

  test('loads bundled sleep tool links from assets', () async {
    await AppConfig.instance.ensureLoaded();

    expect(AppConfig.instance.sleepToolsLinks, isNotEmpty);
    expect(
      AppConfig.instance.sleepToolsLinks.first.url,
      startsWith('https://'),
    );
    expect(AppConfig.instance.configVersion, greaterThan(0));
  });
}

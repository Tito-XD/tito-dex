import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/tito_colors.dart';
import 'package:titodex/theme/tito_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Material is the default style for the experiment branch', () async {
    SharedPreferences.setMockInitialValues({});
    final preference = AppVisualStylePreference();

    await preference.load();

    expect(preference.style, AppVisualStyle.material);
  });

  test('selected visual style persists independently', () async {
    SharedPreferences.setMockInitialValues({});
    final preference = AppVisualStylePreference();
    await preference.load();

    await preference.setStyle(AppVisualStyle.classic);

    final restored = AppVisualStylePreference();
    await restored.load();
    expect(restored.style, AppVisualStyle.classic);
  });

  test('built-in styles produce distinct app-wide surfaces', () {
    final material = buildTitoTheme(AppVisualStyle.material);
    final classic = buildTitoTheme(AppVisualStyle.classic);

    expect(material.scaffoldBackgroundColor, TitoColors.materialSurface);
    expect(classic.scaffoldBackgroundColor, TitoColors.slateBlue);
    expect(material.colorScheme.surface, isNot(classic.colorScheme.surface));
  });
}

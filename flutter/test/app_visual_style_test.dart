import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/tito_colors.dart';
import 'package:titodex/theme/tito_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("Trainer's Journal is the default style for new installs", () async {
    SharedPreferences.setMockInitialValues({});
    final preference = AppVisualStylePreference();

    await preference.load();

    expect(preference.style, AppVisualStyle.classic);
  });

  test('unknown saved styles fall back to Trainer\'s Journal', () async {
    SharedPreferences.setMockInitialValues({'style.visual': 'unknown'});
    final preference = AppVisualStylePreference();

    await preference.load();

    expect(preference.style, AppVisualStyle.classic);
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

  test('Solid Plastic persists as a built-in visual style', () async {
    SharedPreferences.setMockInitialValues({});
    final preference = AppVisualStylePreference();
    await preference.load();

    await preference.setStyle(AppVisualStyle.solidPlastic);

    final restored = AppVisualStylePreference();
    await restored.load();
    expect(restored.style, AppVisualStyle.solidPlastic);
    expect(restored.usesSolidPlastic, isTrue);
  });

  test('built-in styles produce distinct app-wide surfaces', () {
    final flatUi = buildTitoTheme(AppVisualStyle.flatUi);
    final classic = buildTitoTheme(AppVisualStyle.classic);
    final solidPlastic = buildTitoTheme(AppVisualStyle.solidPlastic);

    expect(flatUi.scaffoldBackgroundColor, TitoColors.flatSurface);
    expect(classic.scaffoldBackgroundColor, TitoColors.slateBlue);
    expect(
      solidPlastic.scaffoldBackgroundColor,
      TitoColors.glassBackgroundBottom,
    );
    expect(flatUi.colorScheme.surface, isNot(classic.colorScheme.surface));
    expect(buildTitoTheme().scaffoldBackgroundColor, TitoColors.slateBlue);
  });

  test('first preview Material storage value migrates to Flat UI', () async {
    SharedPreferences.setMockInitialValues({'style.visual': 'material'});
    final preference = AppVisualStylePreference();

    await preference.load();

    expect(preference.style, AppVisualStyle.flatUi);
  });

  test('theme family labels follow the active locale', () {
    const zh = Locale('zh', 'CN');
    const en = Locale('en', 'US');

    expect(TitoThemeFamily.trainerJournal.labelFor(zh), '训练家手帐');
    expect(TitoThemeFamily.trainerJournal.labelFor(en), "Trainer's Journal");
    expect(TitoThemeFamily.solidPlastic.labelFor(zh), '固态塑料');
    expect(TitoThemeFamily.solidPlastic.labelFor(en), 'Solid Plastic');
    expect(TitoThemeFamily.flatUi.labelFor(zh), '扁平贴纸');
    expect(TitoThemeFamily.flatUi.labelFor(en), 'Flat UI');
  });
}

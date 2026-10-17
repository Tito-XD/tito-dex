// Theme gallery + key-screen screenshots for the three TitoSkin themes.
//
//   cd flutter
//   flutter test test/visual/theme_gallery_test.dart \
//     --dart-define=TITODEX_THEME_SHOTS=true
//
// PNGs land in flutter/build/theme_shots/<theme>_<screen>_<480|800>.png.
// Without the define the primitive galleries still pump as a smoke test
// and the full-app screens are skipped, so the normal `flutter test` gate
// stays fast.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/app.dart';
import 'package:titodex/navigation/tito_page_transition.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/retro_style.dart';
import 'package:titodex/theme/tito_buttons.dart';
import 'package:titodex/theme/tito_colors.dart';
import 'package:titodex/theme/tito_skin.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/app_header.dart';
import 'package:titodex/widgets/handheld_input.dart';
import 'package:titodex/widgets/retro_forms.dart';
import 'package:titodex/widgets/secondary_page_scaffold.dart';
import 'package:titodex/widgets/sticker_card.dart';
import 'package:titodex/widgets/tito_chips.dart';
import 'package:titodex/widgets/tito_page_container.dart';

import 'theme_shot_harness.dart';

const _themeNames = {
  AppVisualStyle.classic: 'journal',
  AppVisualStyle.solidPlastic: 'plastic',
  AppVisualStyle.flatUi: 'flat',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    WidgetsApp.debugAllowBannerOverride = false;
    installThemeShotPlatformMocks();
    await loadThemeShotFonts();
  });

  Future<void> useStyle(AppVisualStyle style) async {
    SharedPreferences.setMockInitialValues({
      'style.visual': style.storageValue,
    });
    await appVisualStyle.setStyle(style);
    await retroStyle.setEnabled(true);
  }

  tearDown(() async {
    await appVisualStyle.setStyle(AppVisualStyle.classic);
    await retroStyle.setEnabled(true);
  });

  Future<void> pumpGallery(
    WidgetTester tester,
    AppVisualStyle style,
    Widget page,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => page),
        GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: themeShotBoundaryKey,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: buildTitoTheme(style),
          routerConfig: router,
        ),
      ),
    );
    await pumpThemeShotFrames(tester, frames: 4);
  }

  final galleries = <String, Widget Function()>{
    'surfaces': () => const _SurfacesGallery(),
    'controls': () => const _ControlsGallery(),
    'secondary': () => const _SecondaryGallery(),
  };

  for (final style in AppVisualStyle.values) {
    final theme = _themeNames[style]!;
    for (final viewport in ThemeShotViewport.all) {
      for (final entry in galleries.entries) {
        testWidgets('$theme ${entry.key} gallery @${viewport.name}', (
          tester,
        ) async {
          viewport.apply(tester);
          addTearDown(tester.view.reset);
          await useStyle(style);
          await pumpGallery(tester, style, entry.value());
          expect(tester.takeException(), isNull);
          await captureThemeShot(
            tester,
            '${theme}_${entry.key}_${viewport.name}',
          );
        });
      }

      testWidgets('$theme sheet + dialog gallery @${viewport.name}', (
        tester,
      ) async {
        viewport.apply(tester);
        addTearDown(tester.view.reset);
        await useStyle(style);
        await pumpGallery(tester, style, const _SurfacesGallery());
        final context = tester.element(find.byType(_SurfacesGallery));

        showTitoModalBottomSheet<void>(
          context: context,
          builder: (_) => const _SheetBody(),
        );
        await pumpThemeShotFrames(tester);
        expect(tester.takeException(), isNull);
        await captureThemeShot(tester, '${theme}_sheet_${viewport.name}');

        Navigator.of(context).pop();
        await pumpThemeShotFrames(tester);
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('切换存档？'),
            content: const Text('当前队伍会保留，旅程时间线不会被覆盖。'),
            actions: [
              TextButton(onPressed: () {}, child: const Text('取消')),
              FilledButton(onPressed: () {}, child: const Text('切换')),
            ],
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('已同步 HGSS 存档'),
            action: SnackBarAction(label: '查看', onPressed: () {}),
          ),
        );
        await pumpThemeShotFrames(tester);
        expect(tester.takeException(), isNull);
        await captureThemeShot(tester, '${theme}_dialog_${viewport.name}');
      });

      testWidgets('$theme app screens @${viewport.name}', (tester) async {
        viewport.apply(tester);
        addTearDown(tester.view.reset);
        await useStyle(style);
        await withThemeShotHostNoiseIgnored(() async {
          await tester.pumpWidget(
            RepaintBoundary(
              key: themeShotBoundaryKey,
              child: const TitoDexApp(),
            ),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 400)),
          );
          await pumpThemeShotFrames(tester);
          await captureThemeShot(tester, '${theme}_home_${viewport.name}');

          for (final route in ['/team', '/dex', '/search', '/settings']) {
            final context = tester.element(find.byType(Scaffold).first);
            GoRouter.of(context).go(route);
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 300)),
            );
            await pumpThemeShotFrames(tester, frames: 12);
            await captureThemeShot(
              tester,
              '${theme}_${route.substring(1)}_${viewport.name}',
            );
          }
          // Unmount inside the guard so late plugin callbacks are muted.
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
        });
      }, skip: !kThemeShots);
    }
  }
}

/// Home-like composition: header, trainer hero, shelf/journey heroes,
/// normal and dense cards, stamp chip.
class _SurfacesGallery extends StatelessWidget {
  const _SurfacesGallery();

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    final wide = MediaQuery.sizeOf(context).aspectRatio > 1.3;
    final trainer = StickerCard.hero(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('训练家 Tito', style: skin.heading(17)),
              const Spacer(),
              const TitoStampChip(label: '10·17', onPage: false, fontSize: 11),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('42', style: skin.display(46)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('/ 493 已捕获', style: skin.heading(13)),
              ),
            ],
          ),
          Text(
            '徽章 4 · 游戏时间 18:24',
            style: TextStyle(
              color: skin.heroTint(TitoHeroRole.trainer).mutedInk,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    final shelf = StickerCard.hero(
      role: TitoHeroRole.shelf,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('队伍', style: skin.heading(14)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final c in [
                TitoColors.coral,
                TitoColors.mint,
                TitoColors.skyBlue,
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: StickerIconPlate(
                    icon: Icons.catching_pokemon,
                    color: c,
                    size: 28,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    final journey = StickerCard.hero(
      role: TitoHeroRole.journey,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('下一站', style: skin.heading(14)),
          const SizedBox(height: 4),
          const Text('桔梗市 · 道馆', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
    final normal = StickerCard(
      padding: const EdgeInsets.all(12),
      child: Text('普通卡片 · 设置分组', style: skin.heading(13)),
    );
    final dense = StickerCard.dense(
      child: Row(
        children: [
          StickerIconPlate(
            icon: Icons.local_fire_department,
            color: TitoColors.coral,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text('#155 火球鼠', style: skin.heading(13)),
        ],
      ),
    );

    return TitoPageContainer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppHeader(trainerName: 'Tito'),
            const SizedBox(height: 10),
            if (wide)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: trainer),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          shelf,
                          const SizedBox(height: 10),
                          journey,
                          const SizedBox(height: 10),
                          normal,
                          const SizedBox(height: 8),
                          dense,
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              trainer,
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: shelf),
                  const SizedBox(width: 10),
                  Expanded(child: journey),
                ],
              ),
              const SizedBox(height: 10),
              normal,
              const SizedBox(height: 8),
              dense,
            ],
          ],
        ),
      ),
    );
  }
}

/// Buttons, quick tiles, chips, round keys, form controls, focus ring.
class _ControlsGallery extends StatelessWidget {
  const _ControlsGallery();

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    return TitoPageContainer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TitoPrimaryButton(
                  label: '继续旅程',
                  compact: true,
                  onPressed: () {},
                ),
                const SizedBox(width: 10),
                TitoRoundKey(
                  size: 40,
                  semanticLabel: '设置',
                  onTap: () {},
                  child: const Icon(Icons.settings_rounded, size: 24),
                ),
                const SizedBox(width: 10),
                TitoRoundKey(
                  size: 44,
                  semanticLabel: '开始',
                  tone: TitoKeyTone.action,
                  onTap: () {},
                  child: const Icon(Icons.play_arrow_rounded, size: 26),
                ),
                const SizedBox(width: 10),
                const TitoStampChip(label: '今日 10·17'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 88,
              child: Row(
                children: [
                  Expanded(
                    child: TitoQuickTile(
                      label: '队伍',
                      icon: Icons.groups_rounded,
                      iconPlateColor: TitoColors.softYellow,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TitoQuickTile(
                      label: '图鉴',
                      icon: Icons.menu_book_rounded,
                      iconPlateColor: TitoColors.skyBlue,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TitoQuickTile(
                      label: '搜索',
                      icon: Icons.search_rounded,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TitoChip(label: '全部', selected: true, onTap: () {}),
                TitoChip(label: '草', onTap: () {}),
                TitoChip(label: '城都', tag: true, onTap: () {}),
                TitoChip(
                  label: '已捕获',
                  icon: Icons.check_rounded,
                  dense: true,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const StickerGroupLabel(text: '外观'),
                const SizedBox(width: 10),
                StickerSwitch(value: true, onChanged: (_) {}),
                const SizedBox(width: 8),
                StickerSwitch(value: false, onChanged: (_) {}),
                const SizedBox(width: 10),
                StickerPillToggle(label: '晴天', value: true, onChanged: (_) {}),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TitoFocusRing(
                    focused: true,
                    borderRadius: BorderRadius.circular(skin.radiusLg),
                    child: StickerCard(
                      padding: const EdgeInsets.all(10),
                      child: Text('手柄焦点', style: skin.heading(13)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: retroInsetDecoration(hintText: '搜索宝可梦'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryGallery extends StatelessWidget {
  const _SecondaryGallery();

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    return TitoPageContainer(
      child: SecondaryPageScaffold(
        title: '设置',
        subtitle: '外观、存档与离线数据',
        children: [
          const StickerGroupLabel(text: '外观'),
          const SizedBox(height: 8),
          StickerCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                for (final (label, on) in [
                  ('Retro 贴纸手感', true),
                  ('减少动效', false),
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(label, style: skin.heading(14))),
                        StickerSwitch(value: on, onChanged: (_) {}),
                      ],
                    ),
                  ),
                  if (label != '减少动效') const StickerRowDivider(),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final name in ['#152 菊草叶', '#155 火球鼠', '#158 小锯鳄'])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: StickerCard.dense(
                child: Text(name, style: skin.heading(13)),
              ),
            ),
        ],
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody();

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('选择游戏', style: skin.heading(18, color: skin.ink)),
          const SizedBox(height: 10),
          for (final game in ['心金', '魂银', '白金'])
            ListTile(
              dense: true,
              leading: const Icon(Icons.videogame_asset_rounded),
              title: Text(game),
              trailing: game == '心金'
                  ? const Icon(Icons.check_circle_rounded)
                  : null,
            ),
        ],
      ),
    );
  }
}

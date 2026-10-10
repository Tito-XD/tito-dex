import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/companion/companion_repository.dart';
import 'package:titodex/features/game/game_edition_repository.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/home_page.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/theme/device_layout.dart';
import 'package:titodex/widgets/device_shell.dart';
import 'package:titodex/widgets/handheld_input.dart';
import 'package:titodex/widgets/tito_page_container.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android Home RG layout keeps D-pad highlight and action aligned',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await companionRepository.setEnabled(false);
      await gameEditionRepository.saveSlug('hgss');
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      tester.view.physicalSize = const Size(720, 720);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await binding.convertFlutterSurfaceToImage();
      for (final style in AppVisualStyle.values) {
        await appVisualStyle.setStyle(style);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => TitoPageContainer(
                child: HomePage(
                  journey: const CurrentJourney(
                    game: 'SoulSilver',
                    trainerName: 'Tito',
                    location: '满金市',
                    badges: 3,
                    maxBadges: 8,
                    playTime: '1:00',
                    party: [],
                    timeline: [],
                    companion: '',
                  ),
                  onJourneyOpen: () => context.push('/journey'),
                  onGameBadgeTap: (_) {},
                ),
              ),
            ),
            for (final path in [
              '/team',
              '/dex',
              '/search',
              '/settings',
              '/journey',
            ])
              GoRoute(
                path: path,
                builder: (_, __) => Scaffold(body: Text(path)),
              ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp.router(
            theme: buildTitoTheme(style),
            routerConfig: router,
            builder: (context, child) => HandheldInputShell(
              child: DeviceShell(child: child!),
              onBack: () => router.pop(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          DeviceLayout.useSquareDashboard(
            tester.element(find.byType(HomePage)),
          ),
          isTrue,
        );
        Finder control(String label) => find.ancestor(
          of: find.text(label),
          matching: find.byType(HandheldFocusDecorator),
        );
        FocusNode node(Finder finder) => Focus.of(
          tester.element(
            find.descendant(of: finder, matching: find.byType(HandheldPressed)),
          ),
        );
        final team = control(AppZh.navTeam),
            dex = control(AppZh.navDex),
            search = control(AppZh.navSearch);
        node(team).requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(node(dex).hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(node(search).hasPrimaryFocus, isTrue);
        final paint =
            tester
                    .widget<CustomPaint>(
                      find.byKey(const ValueKey('handheld-focus-cue')),
                    )
                    .painter!
                as HandheldFocusCuePainter;
        expect(paint.bounds, tester.getRect(search));
        await binding.takeScreenshot('home_focus_${style.name}_search');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(node(search).hasPrimaryFocus, isTrue);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.gameButtonA);
        await tester.pumpAndSettle();
        expect(find.text('/search'), findsOneWidget);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.gameButtonA);
        router.pop();
        await tester.pumpAndSettle();
        expect(node(search).hasPrimaryFocus, isTrue);
        expect(
          tester
              .widget<HandheldPressed>(
                find.descendant(
                  of: search,
                  matching: find.byType(HandheldPressed),
                ),
              )
              .pressed,
          isFalse,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      }
    },
  );
}

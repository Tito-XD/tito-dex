import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/dex_offline_service.dart';
import 'package:titodex/features/save/save_types.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/settings_page.dart';
import 'package:titodex/widgets/tito_confirm_dialog.dart';

void main() {
  group('showTitoConfirmDialog', () {
    Future<Future<bool>> open(WidgetTester tester) async {
      late Future<bool> result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => result = showTitoConfirmDialog(
                  context,
                  title: '删除？',
                  body: '无法撤销。',
                  confirmLabel: '删除',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('删除？'), findsOneWidget);
      expect(find.text('无法撤销。'), findsOneWidget);
      return result;
    }

    testWidgets('cancel has initial focus and resolves false', (tester) async {
      final result = await open(tester);
      final cancel = find.byKey(const Key('tito-confirm-cancel'));
      final cancelFocus = Focus.of(
        tester.element(
          find.descendant(of: cancel, matching: find.byType(Text)),
        ),
      );
      expect(cancelFocus.hasPrimaryFocus, isTrue);

      // An accidental A / Enter press activates the focused cancel button.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('删除？'), findsNothing);
      expect(await result, isFalse);
    });

    testWidgets('tapping cancel resolves false', (tester) async {
      final result = await open(tester);
      await tester.tap(find.text(AppZh.cancel));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('barrier dismiss resolves false', (tester) async {
      final result = await open(tester);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('删除？'), findsNothing);
      expect(await result, isFalse);
    });

    testWidgets('confirm resolves true', (tester) async {
      final result = await open(tester);
      await tester.tap(find.byKey(const Key('tito-confirm-accept')));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    });
  });

  group('settings destructive actions', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    for (final confirm in [false, true]) {
      final choice = confirm
          ? find.byKey(const Key('tito-confirm-accept'))
          : find.byKey(const Key('tito-confirm-cancel'));

      testWidgets(
        'clear offline cache ${confirm ? 'runs after confirm' : 'is kept on cancel'}',
        (tester) async {
          final service = _CompleteService();
          await _pumpSettings(
            tester,
            _settings(section: SettingsSection.data, offlineService: service),
          );
          final clear = find.text(AppZh.settingsDexOfflineClear);
          await _reveal(tester, clear);
          await tester.tap(clear);
          await _settle(tester);
          expect(find.text(AppZh.confirmDexOfflineClearBody), findsOneWidget);
          await tester.tap(choice);
          await _settle(tester);
          expect(find.text(AppZh.confirmDexOfflineClearBody), findsNothing);
          expect(service.clears, confirm ? 1 : 0);
          await tester.pumpWidget(const SizedBox());
        },
      );

      for (final restore in [true, false]) {
        final label = restore
            ? AppZh.settingsResetMock
            : AppZh.settingsImportSave;
        testWidgets(
          '$label ${confirm ? 'runs after confirm' : 'is skipped on cancel'}',
          (tester) async {
            var resets = 0;
            var imports = 0;
            await _pumpSettings(
              tester,
              _settings(
                section: SettingsSection.about,
                offlineService: _CompleteService(),
                onResetMock: () => resets += 1,
                onImportFixture: () => imports += 1,
              ),
            );
            final advanced = find.text(AppZh.settingsGroupAdvanced);
            await _reveal(tester, advanced);
            await tester.tap(advanced);
            await _settle(tester);
            final button = find.text(label);
            await _reveal(tester, button);
            await tester.tap(button);
            await _settle(tester);
            final body = restore
                ? AppZh.confirmResetMockBody
                : AppZh.confirmImportSaveBody;
            expect(find.text(body), findsOneWidget);
            // Nothing runs while the dialog is still open.
            expect(resets + imports, 0);
            await tester.tap(choice);
            await _settle(tester);
            expect(find.text(body), findsNothing);
            expect(restore ? resets : imports, confirm ? 1 : 0);
            expect(restore ? imports : resets, 0);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  });
}

/// Settings app bars read GoRouterState, so host the page in a router.
Future<void> _pumpSettings(WidgetTester tester, SettingsPage page) async {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (_, _) => Scaffold(body: page),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await _settle(tester);
}

/// Settings content is a lazy list: scroll until [finder] is built, then
/// bring it fully on screen so the tap hits it.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 100,
  );
  await tester.ensureVisible(finder);
  await _settle(tester);
}

/// Bounded pumping: some settings sections keep a looping animation alive,
/// so pumpAndSettle would never return.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

SettingsPage _settings({
  required SettingsSection section,
  required DexOfflineService offlineService,
  VoidCallback? onResetMock,
  VoidCallback? onImportFixture,
}) => SettingsPage(
  journey: CurrentJourney.mock(),
  saveConfig: const SaveFileConfig(),
  emulatorChoice: null,
  onImportFixture: onImportFixture ?? () {},
  onResetMock: onResetMock ?? () {},
  onSaveJourney: (_) {},
  onPickSaveFile: () {},
  onClearSaveFile: () {},
  onToggleAutoLoad: (_) {},
  onSyncNow: () {},
  onExportJourney: () {},
  onImportJourney: () {},
  onPickEmulator: () {},
  onClearEmulator: () {},
  offlineService: offlineService,
  section: section,
);

class _CompleteService extends DexOfflineService {
  int clears = 0;

  @override
  bool get isDownloading => false;

  @override
  DexCacheProgress? get progress => null;

  @override
  Future<DexCacheStatus> getStatus() async => DexCacheStatus(
    manifest: DexCacheManifest(
      version: DexCacheManifest.currentVersion,
      complete: true,
      preferOffline: true,
      pokemonCount: 1025,
    ),
    sizeBytes: 0,
    isDownloading: false,
    progress: null,
  );

  @override
  Future<void> clearAll() async => clears += 1;
}

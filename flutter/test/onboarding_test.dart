import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/onboarding/onboarding_preferences.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/l10n/app_locale.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/onboarding_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('profile save failure leaves the guide available to retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingDialog(
            journey: CurrentJourney.mock(),
            onSave: (_) async => throw StateError('disk full'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppZh.onboardingLater));
    await tester.pumpAndSettle();
    expect(find.text(AppZh.onboardingSaveFailed), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        OnboardingPreferences.completedKey,
      ),
      isNot(true),
    );
  });
  test('first run survives interruption and completes once', () async {
    final prefs = OnboardingPreferences();
    expect(await prefs.shouldShow(), isTrue);
    await (await SharedPreferences.getInstance()).setString(
      'titodex.current_journey',
      '{}',
    );
    expect(await OnboardingPreferences().shouldShow(), isTrue);
    await prefs.complete();
    expect(await OnboardingPreferences().shouldShow(), isFalse);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'titodex_offline_prompt_shown',
      ),
      isTrue,
    );
  });
  test('existing installs are not forced through onboarding', () async {
    for (final key in [
      'titodex.current_journey',
      'titodex.global_game_edition',
      'titodex_offline_prompt_shown',
    ]) {
      SharedPreferences.setMockInitialValues({
        key: key == 'titodex_offline_prompt_shown' ? true : 'stored',
      });
      expect(await OnboardingPreferences().shouldShow(), isFalse);
    }
  });

  for (final style in AppVisualStyle.values) {
    testWidgets(
      '${style.name}: all guide steps fit small screens with large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await appVisualStyle.setStyle(style);
        addTearDown(() => appVisualStyle.setStyle(AppVisualStyle.classic));
        AppLocale.instance.debugOverride(AppUiLanguage.en);
        addTearDown(() => AppLocale.instance.debugOverride(AppUiLanguage.zh));
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTitoTheme(style),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 480),
                textScaler: TextScaler.linear(1.6),
              ),
              child: Scaffold(
                body: OnboardingDialog(
                  journey: CurrentJourney.mock(),
                  onSave: (_) async {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (var step = 0; step < 3; step++) {
          expect(tester.takeException(), isNull);
          expect(find.text('TitoDex · ${step + 1}/3'), findsOneWidget);
          expect(
            find.text(
              [
                AppZh.onboardingProfileTitle,
                AppZh.onboardingFeaturesTitle,
                AppZh.onboardingReadyTitle,
              ][step],
            ),
            findsOneWidget,
          );
          if (step < 2) {
            await tester.tap(find.byKey(const Key('onboarding-next')));
            await tester.pumpAndSettle();
          }
        }
      },
    );
  }

  testWidgets(
    'guide preserves game data and marks the new name as user-owned',
    (tester) async {
      CurrentJourney? saved;
      final original = CurrentJourney.mock();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTrainerOnboarding(
                  context,
                  journey: original,
                  onSave: (journey) async => saved = journey,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('onboarding-name')), '小智');
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('onboarding-next')));
        await tester.pumpAndSettle();
      }
      expect(saved?.trainerName, '小智');
      expect(saved?.trainerNameCustomized, isTrue);
      expect(saved?.party, original.party);
      expect(saved?.game, original.game);
      expect(find.byType(OnboardingDialog), findsNothing);
    },
  );
}

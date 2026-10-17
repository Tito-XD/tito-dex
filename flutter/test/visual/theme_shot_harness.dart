import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screenshot harness for the TitoSkin themes.
///
/// PNGs are written only when the suite runs with
/// `--dart-define=TITODEX_THEME_SHOTS=true`; otherwise every gallery still
/// pumps (a fast layout/overflow smoke test) and the full-app screens skip.
const bool kThemeShots = bool.fromEnvironment('TITODEX_THEME_SHOTS');

/// Output directory, relative to `flutter/` (already ignored via `/build/`).
const String kThemeShotDir = 'build/theme_shots';

/// Wrap the pumped tree in a [RepaintBoundary] with this key so
/// [captureThemeShot] grabs routes, sheets, dialogs and snackbars too.
final GlobalKey themeShotBoundaryKey = GlobalKey(debugLabel: 'theme-shot');

class ThemeShotViewport {
  const ThemeShotViewport(this.name, this.logical, this.devicePixelRatio);

  final String name;
  final Size logical;
  final double devicePixelRatio;

  /// RG Rotate-class square handheld (720×720 physical).
  static const square = ThemeShotViewport('480', Size(480, 480), 1.5);

  /// 16:9 handheld (1280×720 physical).
  static const wide = ThemeShotViewport('800', Size(800, 450), 1.6);

  static const all = [square, wide];

  void apply(WidgetTester tester) {
    tester.view.physicalSize = logical * devicePixelRatio;
    tester.view.devicePixelRatio = devicePixelRatio;
  }
}

/// Fakes battery_plus / connectivity_plus so the handheld status icons
/// render a stable 82% / Wi-Fi state instead of throwing
/// MissingPluginException in the test host.
void installThemeShotPlatformMocks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/battery'),
    (call) async => switch (call.method) {
      'getBatteryLevel' => 82,
      'getBatteryState' => 'discharging',
      _ => false,
    },
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity'),
    (call) async => ['wifi'],
  );
  final docs = Directory.systemTemp.createTempSync('titodex_theme_shots_');
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => docs.path,
  );
  for (final name in [
    'xyz.luan/audioplayers',
    'xyz.luan/audioplayers.global',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
  }
  for (final name in [
    'dev.fluttercommunity.plus/charging',
    'dev.fluttercommunity.plus/connectivity_status',
    'xyz.luan/audioplayers.global/events',
  ]) {
    messenger.setMockStreamHandler(
      EventChannel(name),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  }
}

bool _fontsLoaded = false;

/// Loads every bundled font (Nunito, MaterialIcons) from the asset
/// FontManifest plus a macOS system CJK face registered as the theme's
/// `Noto Sans CJK SC` fallback, so Chinese copy renders instead of tofu.
Future<void> loadThemeShotFonts() async {
  if (_fontsLoaded) {
    return;
  }
  _fontsLoaded = true;
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }

  const cjkCandidates = [
    '/System/Library/Fonts/Hiragino Sans GB.ttc',
    '/System/Library/Fonts/STHeiti Medium.ttc',
    '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
  ];
  for (final path in cjkCandidates) {
    final file = File(path);
    if (!file.existsSync()) {
      continue;
    }
    final bytes = file.readAsBytesSync();
    final loader = FontLoader('Noto Sans CJK SC')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    break;
  }
}

/// Decodes every on-screen asset image for real (widget tests use a fake
/// async zone) and pumps so they paint.
Future<void> settleThemeShotImages(WidgetTester tester) async {
  ImageProvider<Object> unwrap(ImageProvider<Object> provider) =>
      provider is ResizeImage ? unwrap(provider.imageProvider) : provider;
  final elements = find
      .byType(Image)
      .evaluate()
      .where((e) => unwrap((e.widget as Image).image) is! NetworkImage)
      .toList();
  await tester.runAsync(() async {
    await Future.wait([
      for (final element in elements)
        precacheImage(
          (element.widget as Image).image,
          element,
        ).timeout(const Duration(seconds: 2), onTimeout: () {}),
    ]);
  });
  await tester.pump();
}

/// Writes `build/theme_shots/<name>.png` when [kThemeShots] is set.
Future<void> captureThemeShot(WidgetTester tester, String name) async {
  if (!kThemeShots) {
    return;
  }
  await settleThemeShotImages(tester);
  final boundary =
      themeShotBoundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$kThemeShotDir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Runs [body] while dropping test-host noise from the full app: plugins
/// without a test implementation and network sprites (HTTP 400 in tests).
/// Real layout / render errors still fail the test.
Future<void> withThemeShotHostNoiseIgnored(Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    final error = details.exception;
    if (error is MissingPluginException || error is NetworkImageLoadException) {
      return;
    }
    original?.call(details);
  };
  try {
    await body();
  } finally {
    FlutterError.onError = original;
  }
}

/// Pumps a few frames without `pumpAndSettle` (shimmer / idle loops never
/// settle).
Future<void> pumpThemeShotFrames(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

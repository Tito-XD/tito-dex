import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/tito_progress_dialog.dart';

void main() {
  test('Offline APK seed phases map to continuous overall progress', () {
    expect(dexProgressDisplayFraction(null), 0);
    expect(
      dexProgressDisplayFraction(
        const DexCacheProgress(
          phase: 'apk_seed_manifest',
          current: 1,
          total: 1,
        ),
      ),
      0.02,
    );
    expect(
      dexProgressDisplayFraction(
        const DexCacheProgress(
          phase: 'apk_seed_extract',
          current: 50,
          total: 100,
        ),
      ),
      closeTo(0.675, 0.0001),
    );
    expect(
      dexProgressDisplayFraction(
        const DexCacheProgress(phase: 'done', current: 1, total: 1),
      ),
      1,
    );
  });

  test('CDN phases map to continuous overall progress', () {
    expect(
      dexProgressDisplayFraction(
        const DexCacheProgress(phase: 'cdn_manifest', current: 0, total: 1),
      ),
      0,
    );
    expect(
      dexProgressDisplayFraction(
        const DexCacheProgress(phase: 'cdn_download', current: 50, total: 100),
      ),
      closeTo(0.36, 0.0001),
    );
    expect(
      dexProgressDisplayFraction(
        const DexCacheProgress(phase: 'cdn_verify', current: 0, total: 1),
      ),
      closeTo(0.70, 0.0001),
    );
    expect(
      dexProgressDisplayFraction(
        const DexCacheProgress(phase: 'cdn_extract', current: 50, total: 100),
      ),
      closeTo(0.93, 0.0001),
    );
    expect(
      dexProgressDisplayFraction(
        const DexCacheProgress(phase: 'done', current: 1, total: 1),
      ),
      1,
    );
  });

  testWidgets('progress dialog renders with semantics enabled (iOS)', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    void Function(DexCacheProgress) progressCallback = (progress) {};
    late Future<DexCacheProgress?> Function() finishDownload;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTitoTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  trackWhileDownloading(
                    context: context,
                    title: '下载数据包',
                    onCancel: () {},
                    download: (onProgress) {
                      progressCallback = onProgress;
                      final completer = Completer<DexCacheProgress?>();
                      finishDownload = () {
                        completer.complete(null);
                        return completer.future;
                      };
                      return completer.future;
                    },
                  );
                },
                child: const Text('start'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('下载数据包'), findsOneWidget);

    progressCallback(
      const DexCacheProgress(
        phase: 'cdn_download',
        current: 50,
        total: 100,
        label: '26.1 MB / 52.2 MB',
      ),
    );
    await tester.pump();
    expect(find.textContaining('正在下载数据包'), findsOneWidget);
    expect(find.textContaining('36%'), findsOneWidget);
    expect(find.text('26.1 MB / 52.2 MB'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    finishDownload();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    debugDefaultTargetPlatformOverride = null;
    semantics.dispose();
  });

  testWidgets('first Offline seed shows percentage without a cancel action', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    void Function(DexCacheProgress) progressCallback = (progress) {};
    late Future<void> Function() finishSeed;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: buildTitoTheme(),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );

    final tracked = trackWhileDownloading(
      context: navigatorKey.currentContext!,
      title: '正在准备离线图鉴',
      showCancel: false,
      onCancel: () {},
      download: (onProgress) {
        progressCallback = onProgress;
        final completer = Completer<DexCacheProgress?>();
        finishSeed = () async => completer.complete();
        return completer.future;
      },
    );
    await tester.pumpAndSettle();
    progressCallback(
      const DexCacheProgress(
        phase: 'apk_seed_extract',
        current: 50,
        total: 100,
        label: 'details/512.json',
      ),
    );
    await tester.pump();

    expect(find.text('正在准备离线图鉴'), findsOneWidget);
    expect(find.textContaining('68%'), findsOneWidget);
    expect(find.text('details/512.json'), findsOneWidget);
    expect(find.text('取消'), findsNothing);

    await finishSeed();
    await tracked;
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('CDN download can minimize without cancelling the task', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    void Function(DexCacheProgress) progressCallback = (progress) {};
    late Completer<DexCacheProgress?> downloadCompleter;
    DexCacheProgress? minimizedProgress;
    var cancelCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: buildTitoTheme(),
        home: const Scaffold(body: Text('settings page')),
      ),
    );

    final tracked = trackWhileDownloading(
      context: navigatorKey.currentContext!,
      title: '下载完整离线资料包',
      onCancel: () => cancelCount++,
      onMinimize: (progress) async => minimizedProgress = progress,
      download: (onProgress) {
        progressCallback = onProgress;
        downloadCompleter = Completer<DexCacheProgress?>();
        return downloadCompleter.future;
      },
    );
    await tester.pumpAndSettle();
    progressCallback(
      const DexCacheProgress(
        phase: 'cdn_download',
        current: 25,
        total: 100,
        label: '13.1 MB / 52.2 MB',
      ),
    );
    await tester.pump();

    await tester.tap(find.text('后台下载'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('settings page'), findsOneWidget);
    expect(cancelCount, 0);
    expect(minimizedProgress?.phase, 'cdn_download');
    expect(minimizedProgress?.current, 25);

    downloadCompleter.complete(
      const DexCacheProgress(phase: 'done', current: 1, total: 1),
    );
    await tracked;
    await tester.pumpAndSettle();
    expect(find.text('settings page'), findsOneWidget);
  });
}

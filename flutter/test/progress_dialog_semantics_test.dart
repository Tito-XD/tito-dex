import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/tito_progress_dialog.dart';

void main() {
  testWidgets('progress dialog renders with semantics enabled (iOS)',
      (tester) async {
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
      const DexCacheProgress(phase: '下载中', current: 3, total: 200),
    );
    await tester.pump();
    expect(find.textContaining('下载中'), findsOneWidget);

    finishDownload();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    debugDefaultTargetPlatformOverride = null;
    semantics.dispose();
  });
}

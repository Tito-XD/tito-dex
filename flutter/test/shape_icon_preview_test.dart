@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_search_terms.dart';
import 'package:titodex/widgets/dex_shape_icon.dart';

/// Renders every body-style + size icon to a PNG so a human (or a coding
/// agent) can look at them. Not a golden test — nothing here asserts pixels.
///
/// Run with:
/// `SHAPE_ICON_PREVIEW_PATH=… flutter test test/shape_icon_preview_test.dart --tags preview`
void main() {
  testWidgets('render shape and size icon sheet', (tester) async {
    final key = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(800, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFFFDF6E7),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Shape',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final slug in kDexShapeSlugs)
                        SizedBox(
                          width: 96,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DexShapeIcon(slug: slug, size: 48),
                              const SizedBox(height: 4),
                              Text(
                                dexShapeLabelZh(slug) ?? slug,
                                style: const TextStyle(fontSize: 11),
                              ),
                              Text(
                                slug,
                                style: const TextStyle(fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Size',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final bucket in DexSizeBucket.values)
                        SizedBox(
                          width: 72,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DexSizeIcon(bucket: bucket, size: 40),
                              const SizedBox(height: 4),
                              Text(
                                bucket.labelZh,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final out = Platform.environment['SHAPE_ICON_PREVIEW_PATH'];
    if (out == null) return;

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}

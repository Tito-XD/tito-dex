import 'package:flutter/widgets.dart';
import 'package:titodex/features/journey/ask_motion_images.dart';

// Image decoding has real I/O timing; stream pacing uses the test clock.
// Real bundle lookup and decoding are covered by ask_motion_images_test.dart.
Future<Map<String, ImageProvider>> prepareTestAskMotionImages(
  BuildContext _,
  Iterable<String> resources,
) async => {
  for (final resource in {
    ...resources,
    AskMotionImages.book,
    AskMotionImages.ball,
  })
    resource: resource.startsWith('assets/')
        ? AssetImage(resource)
        : AskMotionImages.fallback(resource),
};

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Compress remote sprite bytes into compact WebP for offline storage.
class DexSpriteCodec {
  const DexSpriteCodec({
    this.maxWidth = 220,
    this.quality = 78,
  });

  final int maxWidth;
  final int quality;

  Uint8List? compressPngBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return null;
    }

    final resized = decoded.width > maxWidth
        ? img.copyResize(decoded, width: maxWidth)
        : decoded;

    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }
}

String formatCacheSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

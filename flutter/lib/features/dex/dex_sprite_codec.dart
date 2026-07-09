import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Resize PNG sprites for offline storage while preserving alpha.
class DexSpriteCodec {
  const DexSpriteCodec({
    this.thumbMaxWidth = 220,
    this.artworkMaxWidth,
  });

  final int thumbMaxWidth;
  final int? artworkMaxWidth;

  Uint8List? compressThumbPngBytes(Uint8List bytes) {
    return _encodePng(bytes, maxWidth: thumbMaxWidth);
  }

  Uint8List? compressArtworkPngBytes(Uint8List bytes) {
    return _encodePng(bytes, maxWidth: artworkMaxWidth);
  }

  /// Backward-compatible alias used by offline bulk download.
  Uint8List? compressPngBytes(Uint8List bytes) => compressThumbPngBytes(bytes);

  Uint8List? _encodePng(Uint8List bytes, {required int? maxWidth}) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return null;
    }

    final resized = maxWidth != null && decoded.width > maxWidth
        ? img.copyResize(decoded, width: maxWidth)
        : decoded;

    return Uint8List.fromList(img.encodePng(resized));
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

String pokeApiOfficialArtworkUrl(int id) =>
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png';

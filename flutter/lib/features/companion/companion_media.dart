import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../dex/sprite_generation_catalog.dart';

/// Core-series starter trios Gen I–IX plus Pikachu / Eevee. Their animated
/// GIF and cry ship inside the APK (~1.4 MB total) so the default companions
/// appear instantly; every other species is fetched once and cached on disk.
const Set<int> bundledCompanionIds = {
  1, 4, 7, //
  152, 155, 158,
  252, 255, 258,
  387, 390, 393,
  495, 498, 501,
  650, 653, 656,
  722, 725, 728,
  810, 813, 816,
  906, 909, 912,
  25, 133,
};

String? bundledCompanionGifAsset(int id) =>
    bundledCompanionIds.contains(id) ? 'assets/companion_media/$id.gif' : null;

String? bundledCompanionCryAsset(int id) =>
    bundledCompanionIds.contains(id) ? 'assets/companion_media/$id.ogg' : null;

/// GIF network candidates worth caching (animated only — the static PNG
/// fallbacks stay a render-time concern).
List<String> companionGifDownloadCandidates(int id) => [
  cdnAnimatedGifUrlFor(id),
  showdownGifUrlFor(id),
  if (id <= bwAnimatedMaxId) bwAnimatedGifUrlFor(id),
];

/// Disk cache for non-bundled companion media under app documents.
class CompanionMediaCache {
  Directory? _dir;

  Future<Directory> _cacheDir() async {
    final cached = _dir;
    if (cached != null) {
      return cached;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/companion_media');
    await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  Future<File> _file(int id, String extension) async {
    final dir = await _cacheDir();
    return File('${dir.path}/$id.$extension');
  }

  Future<String?> _existingPath(int id, String extension) async {
    try {
      final file = await _file(id, extension);
      if (await file.exists() && await file.length() > 0) {
        return file.path;
      }
    } catch (_) {
      // Cache probing must never break rendering.
    }
    return null;
  }

  Future<String?> cachedGifPath(int id) => _existingPath(id, 'gif');

  Future<String?> cachedCryPath(int id) => _existingPath(id, 'ogg');

  Future<String?> _download(
    int id,
    String extension,
    List<String> candidates,
  ) async {
    final existing = await _existingPath(id, extension);
    if (existing != null) {
      return existing;
    }
    for (final url in candidates) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 20));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          final file = await _file(id, extension);
          await file.writeAsBytes(response.bodyBytes, flush: true);
          return file.path;
        }
      } catch (_) {
        // Try the next source.
      }
    }
    return null;
  }

  /// Download-and-cache the animated GIF; returns the local path or null.
  Future<String?> ensureGif(int id) =>
      _download(id, 'gif', companionGifDownloadCandidates(id));

  /// Download-and-cache the cry; returns the local path or null.
  Future<String?> ensureCry(int id) =>
      _download(id, 'ogg', cryCandidatesFor(id));
}

final companionMediaCache = CompanionMediaCache();

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../dex/dex_cdn_config.dart';
import '../dex/dex_offline_service.dart';

typedef AskMotionImagePreparer =
    Future<Map<String, ImageProvider>> Function(
      BuildContext context,
      Iterable<String> resources,
    );

/// Motion uses the same item-sprites paths and image cache as the Dex. Only a
/// small set of starter props is in the APK for use before a bundle is installed.
class AskMotionImages {
  AskMotionImages({DexOfflineService? offline, DexCdnConfig? cdn})
    : _offline = offline ?? dexOfflineService,
      _cdn = cdn ?? const DexCdnConfig();

  final DexOfflineService _offline;
  final DexCdnConfig _cdn;
  static const book = 'item-sprites/sonias-book.png';
  static const ball = 'item-sprites/poke-ball.png';
  static const fallbackSlugs = {
    'poke-ball',
    'great-ball',
    'town-map',
    'sonias-book',
    'thunder-stone',
    'fire-stone',
    'water-stone',
    'oran-berry',
    'pecha-berry',
    'leppa-berry',
    'exp-candy-m',
    'lucky-egg',
    'egg',
    'destiny-knot',
    'ability-capsule',
    'protein',
    'calcium',
    'soothe-bell',
    'potion',
    'heat-rock',
    'damp-rock',
    'smooth-rock',
    'icy-rock',
    'leftovers',
  };

  static String? _itemSlug(String resource) => RegExp(
    r'^item-sprites/([a-z0-9]+(?:-[a-z0-9]+|--[a-z0-9]+)*)\.png$',
  ).firstMatch(resource)?.group(1);

  static ImageProvider fallback(String resource) {
    if (resource.startsWith('assets/')) return AssetImage(resource);
    final slug = _itemSlug(resource);
    return AssetImage(
      'assets/ask_motion/${fallbackSlugs.contains(slug) ? slug : 'sonias-book'}.png',
    );
  }

  Future<ImageProvider> resolve(String resource) async {
    if (resource.startsWith('assets/')) return AssetImage(resource);
    if (_itemSlug(resource) == null) return fallback(resource);
    if (!kIsWeb) {
      try {
        final path = await _offline.absolutePathForRelative(resource);
        if (path != null) return FileImage(File(path));
      } catch (_) {
        // A missing/unavailable local store must not block a conversation.
      }
    }
    if (fallbackSlugs.contains(_itemSlug(resource))) return fallback(resource);
    return NetworkImage(_cdn.referenceUrl(resource));
  }

  Future<Map<String, ImageProvider>> prepare(
    BuildContext context,
    Iterable<String> resources,
  ) async {
    final selected = {...resources.take(6), book, ball};
    final images = await Future.wait(
      selected.map((resource) async {
        var provider = fallback(resource);
        try {
          provider = await resolve(
            resource,
          ).timeout(const Duration(seconds: 2));
          if (!context.mounted) return MapEntry(resource, provider);
          var failed = false;
          await precacheImage(
            provider,
            context,
            onError: (_, _) => failed = true,
          ).timeout(const Duration(seconds: 2));
          if (!failed) return MapEntry(resource, provider);
        } catch (_) {
          // Prepare a neutral local prop on timeout or failed image decoding.
        }
        provider = fallback(resource);
        if (context.mounted) {
          try {
            await precacheImage(
              provider,
              context,
              onError: (_, _) {},
            ).timeout(const Duration(seconds: 1));
          } catch (_) {}
        }
        return MapEntry(resource, provider);
      }),
    );
    return Map.fromEntries(images);
  }
}

final askMotionImages = AskMotionImages();

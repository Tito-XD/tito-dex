import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/tito_colors.dart';
import 'tito_pokeball_loading.dart';
import 'tito_skeleton.dart';

class DexSpriteImage extends StatelessWidget {
  const DexSpriteImage({
    super.key,
    required this.source,
    this.height = 56,
    this.width,
    this.fit = BoxFit.contain,
    this.showPokeball = false,
  });

  final String? source;

  /// Pass `null` explicitly to let the parent constraints size the image
  /// (e.g. inside an [Expanded] grid-card slot).
  final double? height;
  final double? width;
  final BoxFit fit;

  /// Spin the pale Poké Ball while the frame decodes instead of pulsing a
  /// skeleton box. The ball is drawn for type-tinted deep headers; leave this
  /// off on cream / white cards where the skeleton placeholder belongs.
  final bool showPokeball;

  @override
  Widget build(BuildContext context) {
    if (source == null || source!.isEmpty) {
      return _placeholder();
    }

    if (source!.startsWith('assets/')) {
      return _image(Image.asset(source!, fit: fit));
    }

    final uri = Uri.tryParse(source!);
    if (uri != null && uri.hasScheme && uri.scheme.startsWith('http')) {
      return _image(Image.network(source!, fit: fit));
    }

    return _image(Image.file(File(source!), fit: fit));
  }

  Widget _image(Image image) {
    return Image(
      image: image.image,
      height: height,
      width: width,
      fit: fit,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return _placeholder(loading: true);
      },
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder({bool loading = false}) {
    if (loading && showPokeball) {
      return SizedBox(
        height: height,
        width: width,
        child: Center(
          child: TitoPokeballLoading(
            size: ((height ?? 56) * .4).clamp(12.0, 28.0),
          ),
        ),
      );
    }
    return TitoSkeletonBox(
      height: height,
      width: width,
      radius: TitoRadii.sm,
      shimmer: loading,
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/tito_colors.dart';

class DexSpriteImage extends StatelessWidget {
  const DexSpriteImage({
    super.key,
    required this.source,
    this.height = 56,
    this.width,
    this.fit = BoxFit.contain,
  });

  final String? source;

  /// Pass `null` explicitly to let the parent constraints size the image
  /// (e.g. inside an [Expanded] grid-card slot).
  final double? height;
  final double? width;
  final BoxFit fit;

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
        return _placeholder(shimmer: true);
      },
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder({bool shimmer = false}) {
    final box = Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: TitoColors.card.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(TitoRadii.sm),
        border: Border.all(
          color: TitoColors.ink.withValues(alpha: 0.1),
          width: 2,
        ),
      ),
    );
    if (!shimmer) {
      return box;
    }
    return Shimmer.fromColors(
      baseColor: TitoColors.card.withValues(alpha: 0.3),
      highlightColor: TitoColors.card.withValues(alpha: 0.7),
      child: box,
    );
  }
}

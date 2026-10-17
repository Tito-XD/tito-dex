import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/tito_skin.dart';
import 'type_badge.dart';

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
      return _placeholder(context);
    }

    if (source!.startsWith('assets/')) {
      return _image(context, Image.asset(source!, fit: fit));
    }

    final uri = Uri.tryParse(source!);
    if (uri != null && uri.hasScheme && uri.scheme.startsWith('http')) {
      return _image(context, Image.network(source!, fit: fit));
    }

    return _image(context, Image.file(File(source!), fit: fit));
  }

  Widget _image(BuildContext context, Image image) {
    return Image(
      image: image.image,
      height: height,
      width: width,
      fit: fit,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return _placeholder(context, shimmer: true);
      },
      errorBuilder: (_, __, ___) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context, {bool shimmer = false}) {
    final skin = TitoSkin.of(context);
    final side = dexSkinSide(context);
    final box = Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: skin.paperDense,
        borderRadius: BorderRadius.circular(skin.radiusSm),
        border: side == BorderSide.none
            ? null
            : Border.fromBorderSide(
                side.copyWith(color: side.color.withValues(alpha: 0.45)),
              ),
      ),
    );
    if (!shimmer) {
      return box;
    }
    return Shimmer.fromColors(
      baseColor: skin.paperDense,
      highlightColor: Color.lerp(skin.paperDense, Colors.white, 0.55)!,
      child: box,
    );
  }
}

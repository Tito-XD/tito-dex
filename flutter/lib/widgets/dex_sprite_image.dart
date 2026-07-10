import 'dart:io';

import 'package:flutter/material.dart';

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
      return SizedBox(height: height, width: width);
    }

    if (source!.startsWith('assets/')) {
      return Image.asset(
        source!,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, __, ___) => SizedBox(height: height, width: width),
      );
    }

    final uri = Uri.tryParse(source!);
    if (uri != null && uri.hasScheme && uri.scheme.startsWith('http')) {
      return Image.network(
        source!,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, __, ___) => SizedBox(height: height, width: width),
      );
    }

    final file = File(source!);
    return Image.file(
      file,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (_, __, ___) => SizedBox(height: height, width: width),
    );
  }
}

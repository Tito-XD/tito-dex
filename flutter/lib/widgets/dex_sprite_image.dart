import 'dart:io';

import 'package:flutter/material.dart';

import '../features/dex/type_chart.dart';
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
  final double height;
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

class DexTypeIcon extends StatelessWidget {
  const DexTypeIcon({
    super.key,
    required this.typeEn,
    required this.labelZh,
    this.iconPath,
    this.compact = false,
  });

  final String typeEn;
  final String labelZh;
  final String? iconPath;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 16.0 : 18.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: typeTileColor(typeEn),
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        border: Border.all(color: TitoColors.ink, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DexSpriteImage(
            source: iconPath,
            height: iconSize,
            width: iconSize,
          ),
          if (!compact || iconPath == null) ...[
            const SizedBox(width: 4),
            Text(
              labelZh,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: compact ? 10 : 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

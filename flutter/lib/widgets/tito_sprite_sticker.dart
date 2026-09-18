import 'package:flutter/material.dart';

import '../theme/tito_surface_tokens.dart';
import '../theme/retro_style.dart';
import '../theme/tito_colors.dart';
import 'dex_sprite_image.dart';

/// Sticker-framed Pokémon sprite: white pad + ink outline (design system).
class TitoSpriteSticker extends StatelessWidget {
  const TitoSpriteSticker({
    super.key,
    required this.source,
    this.size = 56,
    this.padding = 3,
    this.radius,
    this.shape = BoxShape.rectangle,
    this.fit = BoxFit.contain,
  });

  final String? source;
  final double size;
  final double padding;
  final double? radius;
  final BoxShape shape;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final inner = size - padding * 2 - 4;
    final borderRadius =
        radius ?? (shape == BoxShape.circle ? size / 2 : TitoRadii.sm);
    final tokens = TitoSurfaceTokens.of(context);
    final surface = tokens.surface(TitoSurfaceRole.sprite);
    return ListenableBuilder(
      listenable: retroStyle,
      builder: (context, child) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: surface.fill,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle
              ? BorderRadius.circular(borderRadius)
              : null,
          border: surface.border,
          boxShadow: retroStyle.enabled ? tokens.elementShadow : null,
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: child,
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: DexSpriteImage(
          source: source,
          width: inner,
          height: inner,
          fit: fit,
        ),
      ),
    );
  }
}

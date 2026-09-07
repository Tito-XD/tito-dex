import 'package:flutter/material.dart';

import '../theme/app_visual_style.dart';
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
    final scheme = Theme.of(context).colorScheme;

    final Color fill;
    final BoxBorder? border;
    final List<BoxShadow>? Function() shadow;
    if (appVisualStyle.usesFlatUi) {
      fill = scheme.surfaceContainerLow;
      border = null;
      shadow = () => retroStyle.enabled ? TitoShadows.stickerSmall : null;
    } else if (appVisualStyle.usesSolidPlastic) {
      fill = Colors.white.withValues(alpha: 0.82);
      border = Border.all(
        color: Colors.white.withValues(alpha: 0.78),
        width: TitoBorders.glass,
      );
      shadow = () => retroStyle.enabled ? SolidPlasticShadows.stickerSmall : null;
    } else {
      fill = Colors.white;
      border = Border.all(color: TitoColors.ink, width: TitoBorders.element);
      shadow = () =>
          retroStyle.enabled ? TrainerJournalShadows.stickerSmall : null;
    }

    return ListenableBuilder(
      listenable: retroStyle,
      builder: (context, child) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fill,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle
              ? BorderRadius.circular(borderRadius)
              : null,
          border: border,
          boxShadow: shadow(),
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

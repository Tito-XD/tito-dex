import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/handheld_input.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/retro_forms.dart';
import '../widgets/sticker_pressable.dart';
import 'tito_colors.dart';
import 'tito_skin.dart';
import 'tito_typography.dart';

/// Primary call-to-action with the compact sizing required by RG screens.
///
/// Journal: deep-blue sticker key with hard drop and press-down sink.
/// Solid Plastic: deep moulded shell. Flat UI: coral stadium block (the
/// theme's `FilledButton` style).
class TitoPrimaryButton extends StatelessWidget {
  const TitoPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.showArrow = true,
    this.expanded = false,
    this.compact = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool showArrow;
  final bool expanded;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    if (!skin.isFlat) {
      final radius = BorderRadius.circular(skin.radiusMd);
      final content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          splashColor: TitoColors.skyBlue.withValues(alpha: 0.3),
          highlightColor: TitoColors.skyBlue.withValues(alpha: 0.15),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 12 : (compact ? 16 : 24),
              vertical: dense ? 8 : (compact ? 10 : 14),
            ),
            child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TitoTypography.style(
                    color: skin.onPrimaryFill,
                    fontWeight: FontWeight.w800,
                    fontSize: dense ? 12 : (compact ? 14 : 16),
                  ),
                ),
                if (showArrow) ...[
                  SizedBox(width: dense ? 4 : (compact ? 6 : 8)),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: skin.onPrimaryFill,
                    size: dense ? 16 : (compact ? 18 : 22),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      final surface = skin.isPlastic
          ? LiquidGlassSurface(
              tint: TitoColors.deepBlue,
              opacity: onPressed == null ? 0.78 : 0.95,
              radius: skin.radiusMd,
              borderColor: Colors.white.withValues(alpha: 0.42),
              child: content,
            )
          : Material(
              color: skin.primaryFill,
              borderRadius: radius,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: const Color(0xFF22324A),
                    width: skin.outlineWidth,
                  ),
                ),
                child: content,
              ),
            );
      final button = StickerPressable(
        borderRadius: radius,
        interactive: onPressed != null,
        child: surface,
      );
      return expanded
          ? SizedBox(width: double.infinity, child: button)
          : button;
    }

    final horizontal = dense ? 12.0 : (compact ? 16.0 : 24.0);
    final vertical = dense ? 8.0 : (compact ? 10.0 : 14.0);
    final iconSize = dense ? 16.0 : (compact ? 18.0 : 20.0);
    final button = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: horizontal,
          vertical: vertical,
        ),
        minimumSize: Size(0, dense ? 36 : (compact ? 40 : 48)),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (showArrow) ...[
            SizedBox(width: dense ? 4 : 8),
            Icon(Icons.arrow_forward_rounded, size: iconSize),
          ],
        ],
      ),
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Square-ish dashboard action tile (Team / Dex / Search).
class TitoQuickTile extends StatelessWidget {
  const TitoQuickTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.compact = false,
    this.dense = false,
    this.square = false,
    this.iconPlateColor,
    this.iconAsset,
    this.backgroundColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;
  final bool dense;
  final bool square;
  final Color? iconPlateColor;
  final String? iconAsset;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    final radius = BorderRadius.circular(skin.radiusHero);
    final labelColor = skin.isFlat ? skin.ink : TitoColors.deepBlue;
    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: skin.isPlastic
            ? Colors.white.withValues(alpha: 0.34)
            : skin.isFlat
            ? skin.ink.withValues(alpha: 0.08)
            : TitoColors.skyBlue.withValues(alpha: 0.35),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = constraints.maxHeight.isFinite
                ? (constraints.maxWidth.isFinite
                      ? math.min(constraints.maxWidth, constraints.maxHeight)
                      : constraints.maxHeight)
                : 88.0;
            final iconSize = side * (skin.isFlat && dense ? 0.34 : 0.38);
            final asset = iconAsset;
            final fontSize = (side * (skin.isFlat ? 0.17 : 0.18))
                .clamp(10.0, skin.isFlat ? 22.0 : 24.0)
                .toDouble();
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (asset != null)
                  Image.asset(
                    asset,
                    width: side * 0.52,
                    height: side * 0.52,
                    fit: BoxFit.contain,
                  )
                else if (iconPlateColor != null)
                  StickerIconPlate(
                    icon: icon,
                    color: iconPlateColor!,
                    size: side * 0.52,
                  )
                else
                  Icon(icon, color: labelColor, size: iconSize),
                SizedBox(height: side * 0.04),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TitoTypography.style(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    color: labelColor,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    final Widget surface;
    if (skin.isPlastic) {
      surface = LiquidGlassSurface(
        tint: backgroundColor ?? TitoColors.card,
        opacity: 0.92,
        radius: skin.radiusHero,
        child: content,
      );
    } else if (skin.isFlat) {
      surface = Material(
        color: backgroundColor ?? TitoColors.flatSurfaceContainerHigh,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: content,
      );
    } else {
      surface = Material(
        color: backgroundColor ?? skin.paper,
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: skin.outline!, width: skin.outlineWidth),
          ),
          child: content,
        ),
      );
    }
    final tile = HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: radius,
      child: StickerPressable(borderRadius: radius, child: surface),
    );
    return square ? AspectRatio(aspectRatio: 1, child: tile) : tile;
  }
}

/// Framed (polaroid-style) quick tile retained for square dashboard call
/// sites. [tiltDegrees] is honoured only by Trainer's Journal.
class TitoPolaroidQuickTile extends StatelessWidget {
  const TitoPolaroidQuickTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.tone = TitoPolaroidTone.blue,
    this.compact = false,
    this.tiltDegrees = 0,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final TitoPolaroidTone tone;
  final bool compact;
  final double tiltDegrees;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    final (frameColor, iconColor) = switch (tone) {
      TitoPolaroidTone.blue => (TitoColors.skyBlue, TitoColors.deepBlue),
      TitoPolaroidTone.yellow => (TitoColors.softYellow, TitoColors.ink),
      TitoPolaroidTone.coral => (TitoColors.coral, TitoColors.ink),
      TitoPolaroidTone.mint => (TitoColors.mint, TitoColors.ink),
    };
    final iconSize = compact ? 22.0 : 30.0;
    final radius = BorderRadius.circular(TitoRadii.md);
    final frameSide = skin.isFlat
        ? null
        : Border.all(
            color: skin.isPlastic
                ? Colors.white.withValues(alpha: 0.85)
                : skin.outline!,
            width: skin.isPlastic ? TitoBorders.glass : skin.outlineWidth,
          );
    final tile = HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: radius,
      child: StickerPressable(
        borderRadius: radius,
        child: Material(
          color: skin.isFlat ? TitoColors.flatSurfaceContainer : skin.paper,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            splashColor: TitoColors.skyBlue.withValues(alpha: 0.35),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: skin.isFlat
                    ? null
                    : Border.all(
                        color: skin.isPlastic
                            ? Colors.white.withValues(alpha: 0.70)
                            : skin.outline!,
                        width: skin.isPlastic
                            ? TitoBorders.glass
                            : skin.outlineWidth,
                      ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 8 : 10,
                  compact ? 8 : 10,
                  compact ? 8 : 10,
                  compact ? 6 : 8,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: frameColor,
                          borderRadius: BorderRadius.circular(
                            skin.isFlat ? skin.radiusMd : TitoRadii.sm,
                          ),
                          border: frameSide,
                        ),
                        alignment: Alignment.center,
                        child: Icon(icon, color: iconColor, size: iconSize),
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 6),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tito.quickTileLabel.copyWith(
                        color: skin.isFlat ? skin.ink : TitoColors.ink,
                        fontSize: compact ? 10 : 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return !skin.isJournal || tiltDegrees.abs() < 0.01
        ? tile
        : Transform.rotate(angle: tiltDegrees * math.pi / 180, child: tile);
  }
}

enum TitoPolaroidTone { blue, yellow, coral, mint }

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/handheld_input.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/retro_forms.dart';
import '../widgets/sticker_pressable.dart';
import 'app_visual_style.dart';
import 'tito_colors.dart';
import 'tito_typography.dart';

/// Flat UI filled action with the compact sizing required by RG screens.
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
    if (!appVisualStyle.usesFlatUi) {
      final radius = BorderRadius.circular(TitoRadii.md);
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
                    color: TitoColors.card,
                    fontWeight: FontWeight.w800,
                    fontSize: dense ? 12 : (compact ? 14 : 16),
                  ),
                ),
                if (showArrow) ...[
                  SizedBox(width: dense ? 4 : (compact ? 6 : 8)),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: TitoColors.card,
                    size: dense ? 16 : (compact ? 18 : 22),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      final surface = appVisualStyle.usesSolidPlastic
          ? LiquidGlassSurface(
              tint: TitoColors.deepBlue,
              opacity: onPressed == null ? 0.78 : 0.95,
              radius: TitoRadii.md,
              borderColor: Colors.white.withValues(alpha: 0.42),
              child: content,
            )
          : Material(
              color: TitoColors.deepBlue,
              borderRadius: radius,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: TitoColors.ink,
                    width: TitoBorders.card,
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

/// Flat UI card action used by the home dashboard grid.
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
    if (!appVisualStyle.usesFlatUi) {
      final radius = BorderRadius.circular(TitoRadii.md);
      final content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: appVisualStyle.usesSolidPlastic
              ? Colors.white.withValues(alpha: 0.34)
              : TitoColors.skyBlue.withValues(alpha: 0.35),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.maxHeight.isFinite
                  ? (constraints.maxWidth.isFinite
                        ? math.min(constraints.maxWidth, constraints.maxHeight)
                        : constraints.maxHeight)
                  : 88.0;
              final iconSize = side * 0.38;
              final asset = iconAsset;
              final fontSize = (side * 0.18).clamp(10.0, 24.0).toDouble();
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
                    Icon(icon, color: TitoColors.deepBlue, size: iconSize),
                  SizedBox(height: side * 0.04),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TitoTypography.style(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      color: TitoColors.deepBlue,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      final surface = appVisualStyle.usesSolidPlastic
          ? LiquidGlassSurface(
              tint: backgroundColor ?? TitoColors.card,
              opacity: 0.92,
              radius: TitoRadii.md,
              child: content,
            )
          : Material(
              color: backgroundColor ?? TitoColors.card,
              borderRadius: radius,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: TitoColors.ink,
                    width: TitoBorders.card,
                  ),
                ),
                child: content,
              ),
            );
      final tile = HandheldFocusDecorator(
        onActivate: onTap,
        borderRadius: radius,
        child: StickerPressable(borderRadius: radius, child: surface),
      );
      return square ? AspectRatio(aspectRatio: 1, child: tile) : tile;
    }

    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(TitoRadii.md);
    final tile = HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: radius,
      child: Material(
        type: MaterialType.card,
        color: backgroundColor ?? scheme.surfaceContainerHigh,
        elevation: 1,
        shadowColor: scheme.shadow,
        surfaceTintColor: scheme.surfaceTint,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: InkWell(
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.maxHeight.isFinite
                  ? (constraints.maxWidth.isFinite
                        ? math.min(constraints.maxWidth, constraints.maxHeight)
                        : constraints.maxHeight)
                  : 88.0;
              final iconSize = side * (dense ? 0.34 : 0.38);
              final asset = iconAsset;
              final fontSize = (side * 0.17).clamp(10.0, 22.0).toDouble();
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (asset != null)
                    Image.asset(
                      asset,
                      width: side * 0.50,
                      height: side * 0.50,
                      fit: BoxFit.contain,
                    )
                  else if (iconPlateColor != null)
                    Material(
                      color: iconPlateColor,
                      shape: const CircleBorder(),
                      child: SizedBox.square(
                        dimension: side * 0.48,
                        child: Icon(
                          icon,
                          color: scheme.onSurface,
                          size: iconSize,
                        ),
                      ),
                    )
                  else
                    Icon(icon, color: scheme.primary, size: iconSize),
                  SizedBox(height: side * 0.04),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: fontSize,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    return square ? AspectRatio(aspectRatio: 1, child: tile) : tile;
  }
}

/// Flat UI tonal tile retained for square dashboard call sites.
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

  /// Kept for API compatibility; Material tiles intentionally stay aligned.
  final double tiltDegrees;

  @override
  Widget build(BuildContext context) {
    if (!appVisualStyle.usesFlatUi) {
      final (frameColor, iconColor) = switch (tone) {
        TitoPolaroidTone.blue => (TitoColors.skyBlue, TitoColors.deepBlue),
        TitoPolaroidTone.yellow => (TitoColors.softYellow, TitoColors.ink),
        TitoPolaroidTone.coral => (TitoColors.coral, TitoColors.ink),
        TitoPolaroidTone.mint => (TitoColors.mint, TitoColors.ink),
      };
      final iconSize = compact ? 22.0 : 30.0;
      final radius = BorderRadius.circular(TitoRadii.md);
      final tile = HandheldFocusDecorator(
        onActivate: onTap,
        borderRadius: radius,
        child: StickerPressable(
          borderRadius: radius,
          child: Material(
            color: TitoColors.card,
            borderRadius: radius,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              splashColor: TitoColors.skyBlue.withValues(alpha: 0.35),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: appVisualStyle.usesSolidPlastic
                        ? Colors.white.withValues(alpha: 0.70)
                        : TitoColors.ink,
                    width: appVisualStyle.usesSolidPlastic
                        ? TitoBorders.glass
                        : TitoBorders.card,
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
                            borderRadius: BorderRadius.circular(TitoRadii.sm),
                            border: Border.all(color: TitoColors.ink, width: 2),
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
                          color: TitoColors.ink,
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
      return tiltDegrees.abs() < 0.01
          ? tile
          : Transform.rotate(angle: tiltDegrees * math.pi / 180, child: tile);
    }

    final scheme = Theme.of(context).colorScheme;
    final (containerColor, contentColor) = switch (tone) {
      TitoPolaroidTone.blue => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      TitoPolaroidTone.yellow => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      TitoPolaroidTone.coral => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      TitoPolaroidTone.mint => (
        scheme.surfaceContainerHighest,
        scheme.onSurface,
      ),
    };
    final radius = BorderRadius.circular(TitoRadii.md);

    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: radius,
      child: Material(
        type: MaterialType.card,
        color: scheme.surfaceContainerLow,
        elevation: 1,
        surfaceTintColor: scheme.surfaceTint,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: InkWell(
          onTap: onTap,
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
                  child: Material(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(TitoRadii.sm),
                    child: SizedBox.expand(
                      child: Icon(
                        icon,
                        color: contentColor,
                        size: compact ? 22 : 30,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: compact ? 4 : 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum TitoPolaroidTone { blue, yellow, coral, mint }

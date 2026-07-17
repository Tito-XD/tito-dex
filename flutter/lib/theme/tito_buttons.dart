import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'tito_colors.dart';
import 'tito_typography.dart';
import '../widgets/handheld_input.dart';

/// Sticker-style primary action — deep blue pill per design reference.
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
    final button = Material(
      color: TitoColors.deepBlue,
      borderRadius: BorderRadius.circular(TitoRadii.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(TitoRadii.md),
        splashColor: TitoColors.skyBlue.withValues(alpha: 0.3),
        highlightColor: TitoColors.skyBlue.withValues(alpha: 0.15),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 12 : (compact ? 16 : 24),
            vertical: dense ? 8 : (compact ? 10 : 14),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TitoRadii.md),
            border: Border.all(color: TitoColors.ink, width: TitoBorders.card),
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

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

/// Cream quick-action tile for home dashboard grid.
class TitoQuickTile extends StatelessWidget {
  const TitoQuickTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.compact = false,
    this.dense = false,
    this.square = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;
  final bool dense;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final tile = HandheldFocusDecorator(
      onActivate: onTap,
      child: Material(
        color: TitoColors.card,
        borderRadius: BorderRadius.circular(TitoRadii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(TitoRadii.md),
          splashColor: TitoColors.skyBlue.withValues(alpha: 0.35),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TitoRadii.md),
              border: Border.all(
                color: TitoColors.ink,
                width: TitoBorders.card,
              ),
            ),
            // Icon and label scale off the tile's own height, never off
            // inherited scale scopes: the portrait grid and the square bar
            // stay visually identical, and the Hero flight to the Dex page
            // re-inflates this subtree in the overlay without the icon or
            // label snapping to a different size mid-transition.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = constraints.maxHeight.isFinite
                    ? (constraints.maxWidth.isFinite
                          ? math.min(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            )
                          : constraints.maxHeight)
                    : 88.0;
                final iconSize = side * 0.38;
                final fontSize = (side * 0.18).clamp(10.0, 24.0).toDouble();
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
        ),
      ),
    );

    if (square) {
      return AspectRatio(aspectRatio: 1, child: tile);
    }
    return tile;
  }
}

/// Colorful quick-action tile with slight tilt for square dashboard mode.
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
                color: TitoColors.ink,
                width: TitoBorders.card,
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
    );

    if (tiltDegrees.abs() < 0.01) {
      return tile;
    }
    return Transform.rotate(angle: tiltDegrees * math.pi / 180, child: tile);
  }
}

enum TitoPolaroidTone { blue, yellow, coral, mint }

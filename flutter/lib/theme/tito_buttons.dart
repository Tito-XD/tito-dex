import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'device_layout.dart';
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
            border: Border.all(color: TitoColors.ink, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x3818283B), offset: Offset(0, 5)),
            ],
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

/// Sky-blue secondary action with dark text and sticker shadow.
class TitoSecondaryButton extends StatelessWidget {
  const TitoSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.expanded = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expanded;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: TitoColors.skyBlue,
      borderRadius: BorderRadius.circular(TitoRadii.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(TitoRadii.md),
        splashColor: TitoColors.deepBlue.withValues(alpha: 0.22),
        highlightColor: TitoColors.deepBlue.withValues(alpha: 0.12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 24,
            vertical: compact ? 10 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TitoRadii.md),
            border: Border.all(color: TitoColors.ink, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x3818283B), offset: Offset(0, 5)),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TitoTypography.style(
              color: TitoColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 14 : 16,
            ),
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

/// Coral CTA variant (secondary emphasis on deep cards).
class TitoCoralButton extends StatelessWidget {
  const TitoCoralButton({
    super.key,
    required this.label,
    this.onPressed,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: TitoColors.coral,
      borderRadius: BorderRadius.circular(TitoRadii.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(TitoRadii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TitoRadii.md),
            border: Border.all(color: TitoColors.ink, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x3818283B), offset: Offset(0, 5)),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TitoTypography.style(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: TitoColors.ink,
            ),
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
    final height = square
        ? null
        : (dense
            ? DeviceLayout.squareQuickTileHeight(context)
            : (compact ? 56.0 : 88.0));
    final iconSize = square
        ? DeviceLayout.quickTileIconSize(context, square: true)
        : (dense ? 18.0 : (compact ? 22.0 : 28.0));

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
              border: Border.all(color: TitoColors.ink, width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0x3818283B), offset: Offset(0, 5)),
              ],
            ),
            child: square
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            color: TitoColors.deepBlue,
                            size: iconSize,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.tito.quickTileLabel,
                          ),
                        ],
                      );
                    },
                  )
                : SizedBox(
                    height: height,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: TitoColors.deepBlue, size: iconSize),
                        SizedBox(height: dense ? 2 : (compact ? 4 : 8)),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tito.quickTileLabel,
                        ),
                      ],
                    ),
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
              border: Border.all(color: TitoColors.ink, width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0x3818283B), offset: Offset(0, 5)),
              ],
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

class TitoBadgePill extends StatelessWidget {
  const TitoBadgePill({
    super.key,
    required this.label,
    this.tone = TitoBadgeTone.yellow,
    this.compact = false,
    this.onTap,
  });

  final String label;
  final TitoBadgeTone tone;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final square = DeviceLayout.useSquareDashboard(context);
    final (bg, fg) = switch (tone) {
      TitoBadgeTone.yellow => (TitoColors.softYellow, TitoColors.ink),
      TitoBadgeTone.sky => (TitoColors.skyBlue, TitoColors.ink),
      TitoBadgeTone.coral => (TitoColors.coral, TitoColors.ink),
    };

    final fontSize = DeviceLayout.dim(
      context,
      square ? 20.0 : (compact ? 16.0 : 18.0),
    );

    final pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: DeviceLayout.dim(context, square ? 14.0 : (compact ? 10.0 : 14.0)),
        vertical: DeviceLayout.dim(context, square ? 8.0 : (compact ? 6.0 : 8.0)),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TitoColors.ink, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x3818283B), offset: Offset(0, 3)),
        ],
      ),
      child: Text(
        label,
        style: TitoTypography.style(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
        ),
      ),
    );

    if (onTap == null) {
      return pill;
    }

    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: pill,
        ),
      ),
    );
  }
}

enum TitoBadgeTone { yellow, sky, coral }

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/handheld_input.dart';
import 'tito_colors.dart';

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

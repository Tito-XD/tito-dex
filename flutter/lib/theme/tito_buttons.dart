import 'package:flutter/material.dart';

import 'device_layout.dart';
import 'tito_colors.dart';

/// Sticker-style primary action — deep blue pill per design reference.
class TitoPrimaryButton extends StatelessWidget {
  const TitoPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.showArrow = true,
    this.expanded = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool showArrow;
  final bool expanded;
  final bool compact;

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
            horizontal: compact ? 16 : 24,
            vertical: compact ? 10 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TitoRadii.md),
            border: Border.all(color: TitoColors.ink, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3818283B),
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: TitoColors.card,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 14 : 16,
                ),
              ),
              if (showArrow) ...[
                SizedBox(width: compact ? 6 : 8),
                Icon(
                  Icons.play_arrow_rounded,
                  color: TitoColors.card,
                  size: compact ? 18 : 22,
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
              BoxShadow(
                color: Color(0x3818283B),
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: TitoColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 16,
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
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final square = DeviceLayout.useSquareDashboard(context);
    return Material(
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
              BoxShadow(
                color: Color(0x3818283B),
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: SizedBox(
            height: compact ? 56 : (square ? 64 : 88),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: TitoColors.deepBlue,
                  size: compact ? 22 : 28,
                ),
                SizedBox(height: compact ? 4 : 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: TitoColors.deepBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 11 : 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TitoBadgePill extends StatelessWidget {
  const TitoBadgePill({
    super.key,
    required this.label,
    this.tone = TitoBadgeTone.yellow,
    this.compact = false,
  });

  final String label;
  final TitoBadgeTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      TitoBadgeTone.yellow => (TitoColors.softYellow, TitoColors.deepBlue),
      TitoBadgeTone.sky => (TitoColors.skyBlue, TitoColors.ink),
      TitoBadgeTone.coral => (TitoColors.coral, TitoColors.ink),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TitoColors.ink, width: 2),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 10 : 12,
        ),
      ),
    );
  }
}

enum TitoBadgeTone { yellow, sky, coral }

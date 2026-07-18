import 'package:flutter/material.dart';

import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';

/// Retro form language shared across Settings, team editing, and the battle
/// tools (v0.6.7 preview): sticker toggle switches, floating group labels,
/// engraved input fills, and pill toggles with a state dot.

/// Hand-drawn style toggle: ink-bordered capsule, mint when on, with a
/// chunky knob that flips sides. Replaces Material's Switch inside the
/// sticker UI so controls share the card language.
class StickerSwitch extends StatelessWidget {
  const StickerSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.45,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            width: 46,
            height: 27,
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: value ? TitoColors.mint : TitoColors.cardWarm,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: TitoColors.ink,
                width: TitoBorders.card,
              ),
              boxShadow: TitoShadows.stickerSmall,
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  color: value ? TitoColors.deepBlue : TitoColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: TitoColors.ink,
                    width: TitoBorders.element,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft-yellow pill floating above a settings card as the group title.
class StickerGroupLabel extends StatelessWidget {
  const StickerGroupLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
        decoration: BoxDecoration(
          color: TitoColors.softYellow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: TitoColors.ink,
            width: TitoBorders.element,
          ),
          boxShadow: TitoShadows.stickerSmall,
        ),
        child: Text(
          text,
          style: SecondaryTypography.onCard.small12.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF6A4A05),
          ),
        ),
      ),
    );
  }
}

/// Small colored plate behind a row/tile icon — gives each entry its own
/// accent without recoloring the icon itself.
class StickerIconPlate extends StatelessWidget {
  const StickerIconPlate({
    super.key,
    required this.icon,
    required this.color,
    this.size = 32,
    this.iconColor,
  });

  final IconData icon;
  final Color color;
  final double size;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: TitoColors.ink, width: TitoBorders.element),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.55, color: iconColor ?? TitoColors.ink),
    );
  }
}

/// Dashed divider between rows inside one settings card.
class StickerRowDivider extends StatelessWidget {
  const StickerRowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 6.0;
        const gap = 5.0;
        final count = (constraints.maxWidth / (dashWidth + gap)).floor();
        return SizedBox(
          height: 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < count; i++)
                Container(
                  width: dashWidth,
                  height: 2,
                  color: TitoColors.mutedInk.withValues(alpha: 0.3),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Engraved ("inset") field decoration — a subtly darker fill so inputs read
/// as carved into the card while buttons pop out of it.
InputDecoration retroInsetDecoration({
  String? labelText,
  String? hintText,
  String? helperText,
  Widget? prefixIcon,
}) {
  OutlineInputBorder border(Color color, [double width = 2]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(TitoRadii.sm),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    prefixIcon: prefixIcon,
    isDense: true,
    filled: true,
    fillColor: TitoColors.cardWarm,
    border: border(TitoColors.ink),
    enabledBorder: border(TitoColors.ink),
    focusedBorder: border(TitoColors.coral),
  );
}

/// Pill toggle with a state dot (battle modifiers): cardWarm when off,
/// mint with a deep-blue dot when on.
class StickerPillToggle extends StatelessWidget {
  const StickerPillToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: value ? TitoColors.mint : TitoColors.cardWarm,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: TitoColors.ink,
            width: TitoBorders.element,
          ),
          boxShadow: TitoShadows.stickerSmall,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: value ? TitoColors.deepBlue : TitoColors.card,
                shape: BoxShape.circle,
                border: Border.all(
                  color: TitoColors.ink,
                  width: TitoBorders.element,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: SecondaryTypography.onCard.small12.copyWith(
                fontWeight: FontWeight.w800,
                color: value ? const Color(0xFF08402F) : TitoColors.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

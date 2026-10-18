import 'package:flutter/material.dart';

import '../theme/app_visual_style.dart';
import '../theme/motion_preferences.dart';
import '../theme/retro_style.dart';
import '../theme/tito_motion.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_skin.dart';

/// Retro form language shared across Settings, team editing, and the battle
/// tools (v0.6.7 preview): sticker toggle switches, floating group labels,
/// engraved input fills, and pill toggles with a state dot. Outlines and
/// drops follow [TitoSkin.controlSide] / [TitoSkin.chipShadow].

/// Hand-drawn style toggle: outlined capsule, mint when on, with a chunky
/// knob that flips sides. Replaces Material's Switch inside the sticker UI
/// so controls share the card language.
class StickerSwitch extends StatelessWidget {
  const StickerSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([motionPreferences, retroStyle]),
    builder: (context, _) {
      final skin = TitoSkin.of(context);
      final motion = TitoMotion.of(context);
      final enabled = onChanged != null;
      final animate = enabled && !TitoMotion.disabled(context);
      final side = skin.controlSide;
      final trackOn = skin.isFlat ? TitoColors.deepBlue : TitoColors.mint;
      final trackOff = skin.isFlat
          ? TitoColors.flatSurfaceContainerHigh
          : TitoColors.cardWarm;
      final knobOn = skin.isFlat ? TitoColors.softYellow : TitoColors.deepBlue;
      final target = value ? 1.0 : 0.0;
      return Semantics(
        toggled: value,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.45,
            child: TweenAnimationBuilder<double>(
              // Start at the selected side; mounting a settings row isn't an
              // interaction. Retarget from the current position on rapid taps.
              tween: Tween<double>(begin: target, end: target),
              duration: animate ? motion.selection : Duration.zero,
              curve: motion.settleCurve,
              builder: (context, value, _) {
                final progress = animate ? value : target;
                final stretch = animate
                    ? motion.switchStretch * 4 * progress * (1 - progress)
                    : 0.0;
                return Container(
                  width: 46,
                  height: 27,
                  padding: EdgeInsets.all(skin.isFlat ? 3 : 1),
                  decoration: BoxDecoration(
                    color: Color.lerp(trackOff, trackOn, progress),
                    borderRadius: BorderRadius.circular(999),
                    border: side == BorderSide.none
                        ? null
                        : Border.fromBorderSide(side),
                    boxShadow: skin.chipShadow,
                  ),
                  child: Align(
                    alignment: Alignment(-1 + 2 * progress, 0),
                    child: Transform.scale(
                      scaleX: 1 + stretch,
                      scaleY: 1 / (1 + stretch),
                      transformHitTests: false,
                      child: Container(
                        width: skin.isFlat ? 21 : 19,
                        height: skin.isFlat ? 21 : 19,
                        decoration: BoxDecoration(
                          color: Color.lerp(TitoColors.card, knobOn, progress),
                          shape: BoxShape.circle,
                          border: side == BorderSide.none
                              ? null
                              : Border.fromBorderSide(side),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

/// Soft-yellow pill floating above a settings card as the group title.
class StickerGroupLabel extends StatelessWidget {
  const StickerGroupLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    final side = skin.controlSide;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
        decoration: BoxDecoration(
          color: TitoColors.softYellow,
          borderRadius: BorderRadius.circular(999),
          border: side == BorderSide.none ? null : Border.fromBorderSide(side),
          boxShadow: skin.chipShadow,
        ),
        child: Text(
          text,
          style: SecondaryTypography.onCard.small12.copyWith(
            fontWeight: FontWeight.w800,
            color: skin.isFlat
                ? TitoColors.flatOnSurface
                : const Color(0xFF6A4A05),
          ),
        ),
      ),
    );
  }
}

/// Small colored plate behind a row/tile icon — gives each entry its own
/// accent without recoloring the icon itself. Flat UI uses circular chips.
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
    final skin = TitoSkin.of(context);
    final side = skin.controlSide;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: skin.isFlat ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: skin.isFlat ? null : BorderRadius.circular(size * 0.32),
        border: side == BorderSide.none ? null : Border.fromBorderSide(side),
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
    final skin = TitoSkin.of(context);
    final color = skin.isJournal
        ? skin.outline!.withValues(alpha: 0.45)
        : TitoColors.mutedInk.withValues(alpha: 0.3);
    if (skin.isFlat) {
      return Container(height: 2, color: TitoColors.flatSurface);
    }
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
                Container(width: dashWidth, height: 1.5, color: color),
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
  final skin = TitoSkin.forStyle(appVisualStyle.style);
  OutlineInputBorder border(BorderSide side) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(TitoRadii.sm),
    borderSide: side,
  );
  final rest = skin.isFlat
      ? BorderSide.none
      : BorderSide(
          color: skin.isPlastic
              ? TitoColors.deepBlue.withValues(alpha: 0.3)
              : skin.outline!,
          width: skin.isPlastic ? 1.1 : 1.4,
        );
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    prefixIcon: prefixIcon,
    isDense: true,
    filled: true,
    fillColor: skin.isFlat
        ? TitoColors.flatSurfaceContainerHigh
        : skin.isPlastic
        ? Colors.white.withValues(alpha: 0.78)
        : TitoColors.cardWarm,
    border: border(rest),
    enabledBorder: border(rest),
    focusedBorder: border(
      BorderSide(
        color: skin.isFlat ? TitoColors.flatOnSurface : TitoColors.coral,
        width: skin.isFlat ? 2.5 : 2,
      ),
    ),
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
    final skin = TitoSkin.of(context);
    final side = skin.controlSide;
    final border = side == BorderSide.none ? null : Border.fromBorderSide(side);
    final onFill = skin.isFlat ? TitoColors.deepBlue : TitoColors.mint;
    final offFill = skin.isFlat
        ? TitoColors.flatSurfaceContainerHigh
        : TitoColors.cardWarm;
    final onInk = skin.isFlat ? TitoColors.card : const Color(0xFF08402F);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: value ? onFill : offFill,
          borderRadius: BorderRadius.circular(999),
          border: border,
          boxShadow: skin.chipShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: value
                    ? (skin.isFlat
                          ? TitoColors.softYellow
                          : TitoColors.deepBlue)
                    : TitoColors.card,
                shape: BoxShape.circle,
                border: border,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: SecondaryTypography.onCard.small12.copyWith(
                fontWeight: FontWeight.w800,
                color: value ? onInk : TitoColors.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

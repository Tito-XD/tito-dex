import 'package:flutter/material.dart';

import '../theme/app_visual_style.dart';
import '../theme/retro_style.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import 'liquid_glass.dart';

/// Retro form language shared across Settings, team editing, and the battle
/// tools (v0.6.7 preview): sticker toggle switches, floating group labels,
/// engraved input fills, and pill toggles with a state dot.
///
/// Every component branches on the three visual styles the same way
/// `sticker_card.dart` does: Trainer's Journal keeps the ink-outlined sticker
/// look with hard offset shadows, Solid Plastic swaps to milky glass, and
/// Flat UI hands the control to Material so it inherits the theme.

Color _glassOutline([double alpha = 0.78]) =>
    Colors.white.withValues(alpha: alpha);

/// Hand-drawn style toggle: ink-bordered capsule, mint when on, with a
/// chunky knob that flips sides. Replaces Material's Switch inside the
/// sticker UI so controls share the card language.
class StickerSwitch extends StatelessWidget {
  const StickerSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (appVisualStyle.usesFlatUi) {
      return Switch(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }
    final enabled = onChanged != null;
    final plastic = appVisualStyle.usesSolidPlastic;
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.45,
          child: ListenableBuilder(
            listenable: retroStyle,
            builder: (context, knob) => AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              width: 46,
              height: 27,
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: value
                    ? (plastic
                          ? TitoColors.mint.withValues(alpha: 0.9)
                          : TitoColors.mint)
                    : (plastic
                          ? Colors.white.withValues(alpha: 0.8)
                          : TitoColors.cardWarm),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: plastic ? _glassOutline() : TitoColors.ink,
                  width: plastic ? TitoBorders.glass : TitoBorders.element,
                ),
                boxShadow: !retroStyle.enabled
                    ? null
                    : plastic
                    ? SolidPlasticShadows.stickerSmall
                    : TrainerJournalShadows.stickerSmall,
              ),
              child: knob,
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  color: value
                      ? TitoColors.deepBlue
                      : (plastic ? Colors.white : TitoColors.card),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: plastic ? _glassOutline() : TitoColors.ink,
                    width: plastic ? TitoBorders.glass : TitoBorders.element,
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

  static const _padding = EdgeInsets.symmetric(horizontal: 13, vertical: 4);

  @override
  Widget build(BuildContext context) {
    final Widget pill;
    if (appVisualStyle.usesFlatUi) {
      final scheme = Theme.of(context).colorScheme;
      pill = Container(
        padding: _padding,
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: SecondaryTypography.onCard.small12.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSecondaryContainer,
          ),
        ),
      );
    } else {
      final label = Text(
        text,
        style: SecondaryTypography.onCard.small12.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF6A4A05),
        ),
      );
      if (appVisualStyle.usesSolidPlastic) {
        pill = ListenableBuilder(
          listenable: retroStyle,
          builder: (context, inner) => LiquidGlassSurface(
            tint: TitoColors.softYellow,
            opacity: 0.9,
            radius: 999,
            padding: _padding,
            boxShadow: retroStyle.enabled
                ? SolidPlasticShadows.stickerSmall
                : null,
            child: inner!,
          ),
          child: label,
        );
      } else {
        pill = ListenableBuilder(
          listenable: retroStyle,
          builder: (context, inner) => Container(
            padding: _padding,
            decoration: BoxDecoration(
              color: TitoColors.softYellow,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: TitoColors.ink,
                width: TitoBorders.element,
              ),
              boxShadow: retroStyle.enabled
                  ? TrainerJournalShadows.stickerSmall
                  : null,
            ),
            child: inner,
          ),
          child: label,
        );
      }
    }
    return Align(alignment: Alignment.centerLeft, child: pill);
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
    if (appVisualStyle.usesFlatUi) {
      final scheme = Theme.of(context).colorScheme;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(TitoRadii.sm),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: size * 0.55,
          color: iconColor ?? scheme.onPrimaryContainer,
        ),
      );
    }
    final glyph = Icon(
      icon,
      size: size * 0.55,
      color: iconColor ?? TitoColors.ink,
    );
    if (appVisualStyle.usesSolidPlastic) {
      return SizedBox(
        width: size,
        height: size,
        child: LiquidGlassSurface(
          tint: color,
          opacity: 0.9,
          radius: size * 0.32,
          child: Center(child: glyph),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: TitoColors.ink, width: TitoBorders.element),
      ),
      alignment: Alignment.center,
      child: glyph,
    );
  }
}

/// Dashed divider between rows inside one settings card.
class StickerRowDivider extends StatelessWidget {
  const StickerRowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    if (appVisualStyle.usesFlatUi) {
      return const Divider(height: 2);
    }
    final dashColor = appVisualStyle.usesSolidPlastic
        ? Colors.white.withValues(alpha: 0.6)
        : TitoColors.ink.withValues(alpha: 0.35);
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
                Container(width: dashWidth, height: 2, color: dashColor),
            ],
          ),
        );
      },
    );
  }
}

/// Engraved ("inset") field decoration — a subtly darker fill so inputs read
/// as carved into the card while buttons pop out of it.
///
/// Pass [context] so Flat UI can resolve the theme's `inputDecorationTheme`;
/// without it Flat UI still returns a bare decoration that `TextField`
/// completes from the theme, so existing call sites stay correct.
InputDecoration retroInsetDecoration({
  String? labelText,
  String? hintText,
  String? helperText,
  Widget? prefixIcon,
  BuildContext? context,
}) {
  if (appVisualStyle.usesFlatUi) {
    final decoration = InputDecoration(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      prefixIcon: prefixIcon,
      isDense: true,
    );
    if (context == null) {
      return decoration;
    }
    return decoration.applyDefaults(Theme.of(context).inputDecorationTheme);
  }
  final plastic = appVisualStyle.usesSolidPlastic;
  OutlineInputBorder border(Color color, [double? width]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(TitoRadii.md),
        borderSide: BorderSide(
          color: color,
          width: width ?? (plastic ? TitoBorders.glass : TitoBorders.card),
        ),
      );
  final outline = plastic ? _glassOutline() : TitoColors.ink;
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    prefixIcon: prefixIcon,
    isDense: true,
    filled: true,
    fillColor: plastic
        ? Colors.white.withValues(alpha: 0.7)
        : TitoColors.cardWarm,
    border: border(outline),
    enabledBorder: border(outline),
    focusedBorder: border(TitoColors.coral, TitoBorders.card),
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
    if (appVisualStyle.usesFlatUi) {
      return FilterChip(
        selected: value,
        onSelected: onChanged,
        label: Text(label),
      );
    }
    final plastic = appVisualStyle.usesSolidPlastic;
    final dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: value
            ? TitoColors.deepBlue
            : (plastic ? Colors.white : TitoColors.card),
        shape: BoxShape.circle,
        border: Border.all(
          color: plastic ? _glassOutline() : TitoColors.ink,
          width: plastic ? TitoBorders.glass : TitoBorders.element,
        ),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: ListenableBuilder(
        listenable: retroStyle,
        builder: (context, content) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: value
                ? (plastic
                      ? TitoColors.mint.withValues(alpha: 0.9)
                      : TitoColors.mint)
                : (plastic
                      ? Colors.white.withValues(alpha: 0.8)
                      : TitoColors.cardWarm),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: plastic ? _glassOutline() : TitoColors.ink,
              width: plastic ? TitoBorders.glass : TitoBorders.element,
            ),
            boxShadow: !retroStyle.enabled
                ? null
                : plastic
                ? SolidPlasticShadows.stickerSmall
                : TrainerJournalShadows.stickerSmall,
          ),
          child: content,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot,
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

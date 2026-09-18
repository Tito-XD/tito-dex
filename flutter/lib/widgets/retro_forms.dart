import 'package:flutter/material.dart';

import '../theme/tito_surface_tokens.dart';
import '../theme/retro_style.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import 'liquid_glass.dart';

/// Retro form language shared across Settings, team editing, and the battle
/// tools (v0.6.7 preview): sticker toggle switches, floating group labels,
/// engraved input fills, and pill toggles with a state dot.
///
/// Shared components read the inherited surface tokens: Trainer's Journal uses a thin gray-blue outline
/// and a paper-edge shadow, Solid Plastic swaps to milky glass, and
/// Flat UI hands the control to Material so it inherits the theme.

/// Hand-drawn style toggle: ink-bordered capsule, mint when on, with a
/// chunky knob that flips sides. Replaces Material's Switch inside the
/// sticker UI so controls share the card language.
class StickerSwitch extends StatelessWidget {
  const StickerSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = TitoSurfaceTokens.of(context);
    if (tokens.usesMaterial) {
      return Switch(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }
    final enabled = onChanged != null;
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
                color: tokens
                    .surface(
                      value
                          ? TitoSurfaceRole.toggleSelected
                          : TitoSurfaceRole.toggle,
                    )
                    .fill,
                borderRadius: BorderRadius.circular(999),
                border: Border.fromBorderSide(tokens.elementOutline),
                boxShadow: !retroStyle.enabled ? null : tokens.elementShadow,
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
                      : tokens.surface(TitoSurfaceRole.knob).fill,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(tokens.elementOutline),
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
    final tokens = TitoSurfaceTokens.of(context);
    final surface = tokens.surface(TitoSurfaceRole.groupLabel);
    final label = Text(
      text,
      style: SecondaryTypography.onCard.small12.copyWith(
        fontWeight: FontWeight.w800,
        color: surface.foreground,
      ),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: ListenableBuilder(
        listenable: retroStyle,
        builder: (context, child) => tokens.usesOptics
            ? LiquidGlassSurface(
                tint: surface.fill,
                opacity: surface.opacity,
                radius: 999,
                padding: _padding,
                borderColor: surface.outline.color,
                borderWidth: surface.outline.width,
                boxShadow: retroStyle.enabled ? tokens.elementShadow : null,
                child: child!,
              )
            : Container(
                padding: _padding,
                decoration: BoxDecoration(
                  color: surface.fill,
                  borderRadius: BorderRadius.circular(999),
                  border: surface.border,
                  boxShadow: retroStyle.enabled && !tokens.usesMaterial
                      ? tokens.elementShadow
                      : null,
                ),
                child: child,
              ),
        child: label,
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
    final tokens = TitoSurfaceTokens.of(context);
    if (tokens.usesMaterial) {
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
    if (tokens.usesOptics) {
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
        border: Border.fromBorderSide(tokens.elementOutline),
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
    final tokens = TitoSurfaceTokens.of(context);
    if (tokens.usesMaterial) {
      return const Divider(height: 2);
    }
    final dashColor = tokens.dividerColor;
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
/// [context] resolves both surface tokens and Material input defaults.
InputDecoration retroInsetDecoration({
  String? labelText,
  String? hintText,
  String? helperText,
  Widget? prefixIcon,
  required BuildContext context,
}) {
  final tokens = TitoSurfaceTokens.of(context);
  if (tokens.usesMaterial) {
    final decoration = InputDecoration(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      prefixIcon: prefixIcon,
      isDense: true,
    );
    return decoration.applyDefaults(Theme.of(context).inputDecorationTheme);
  }
  final surface = tokens.surface(TitoSurfaceRole.inset);
  OutlineInputBorder border(Color color, [double? width]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(TitoRadii.md),
    borderSide: BorderSide(
      color: color,
      width: width ?? tokens.cardOutline.width,
    ),
  );
  final outline = tokens.cardOutline.color;
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    prefixIcon: prefixIcon,
    isDense: true,
    filled: true,
    fillColor: surface.fill,
    border: border(outline),
    enabledBorder: border(outline),
    focusedBorder: border(
      TitoColors.coral,
      tokens.usesOptics ? TitoBorders.card : 1.6,
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
    final tokens = TitoSurfaceTokens.of(context);
    if (tokens.usesMaterial) {
      return Semantics(
        button: true,
        label: label,
        toggled: value,
        onTap: () => onChanged(!value),
        excludeSemantics: true,
        child: FilterChip(
          selected: value,
          onSelected: onChanged,
          label: Text(label),
        ),
      );
    }
    final dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: value
            ? TitoColors.deepBlue
            : tokens.surface(TitoSurfaceRole.knob).fill,
        shape: BoxShape.circle,
        border: Border.fromBorderSide(tokens.elementOutline),
      ),
    );
    return Semantics(
      button: true,
      label: label,
      toggled: value,
      onTap: () => onChanged(!value),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: ListenableBuilder(
          listenable: retroStyle,
          builder: (context, content) => AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: tokens
                  .surface(
                    value
                        ? TitoSurfaceRole.toggleSelected
                        : TitoSurfaceRole.toggle,
                  )
                  .fill,
              borderRadius: BorderRadius.circular(999),
              border: Border.fromBorderSide(tokens.elementOutline),
              boxShadow: !retroStyle.enabled ? null : tokens.elementShadow,
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
      ),
    );
  }
}

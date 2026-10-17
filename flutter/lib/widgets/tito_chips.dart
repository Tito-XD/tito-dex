import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/retro_style.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_skin.dart';
import '../theme/tito_typography.dart';
import 'handheld_input.dart';
import 'liquid_glass.dart';
import 'sticker_pressable.dart';
import 'tito_paper.dart';

/// Short date / status stamp.
///
/// Journal: dashed rubber stamp tilted -2°. Solid Plastic: frosted pill.
/// Flat UI: deep-blue block with cream text. Set [onPage] false when the
/// stamp sits on a card rather than directly on the page background.
class TitoStampChip extends StatelessWidget {
  const TitoStampChip({
    super.key,
    required this.label,
    this.icon,
    this.onPage = true,
    this.fontSize = 13,
  });

  final String label;
  final IconData? icon;
  final bool onPage;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    final ink = skin.isFlat
        ? TitoColors.card
        : (onPage ? skin.pageInk : skin.ink);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: fontSize * 1.1, color: ink),
          SizedBox(width: fontSize * 0.3),
        ],
        Text(
          label,
          maxLines: 1,
          style: TitoTypography.style(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
      ],
    );
    if (skin.isJournal) {
      return Transform.rotate(
        angle: -2 * math.pi / 180,
        child: TitoDashedFrame(
          color: ink,
          radius: 6,
          strokeWidth: 1.5,
          dash: 4,
          gap: 2.5,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: fontSize * 0.55,
              vertical: fontSize * 0.18,
            ),
            child: content,
          ),
        ),
      );
    }
    if (skin.isPlastic) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: onPage
                ? [
                    Colors.white.withValues(alpha: 0.42),
                    Colors.white.withValues(alpha: 0.18),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.9),
                    const Color(0xFFDCEAF0),
                  ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x590A1422),
              blurRadius: 8,
              spreadRadius: -3,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: fontSize * 0.8,
            vertical: fontSize * 0.3,
          ),
          child: content,
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TitoColors.deepBlue,
        borderRadius: BorderRadius.circular(fontSize),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: fontSize * 0.8,
          vertical: fontSize * 0.28,
        ),
        child: content,
      ),
    );
  }
}

/// Pill chip for filters, badges and tags.
///
/// [tag] gives the luggage-tag silhouette (Journal punches a hole on the
/// left; Flat UI switches to the sky block). [onTap] makes it a focusable
/// control with the theme focus ring.
class TitoChip extends StatelessWidget {
  const TitoChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.tag = false,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final bool tag;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    final height = dense ? 28.0 : 34.0;
    final fontSize = dense ? 12.0 : 13.0;
    final full = Radius.circular(height / 2);
    final radius = tag && !skin.isFlat
        ? BorderRadius.horizontal(left: const Radius.circular(5), right: full)
        : BorderRadius.all(full);
    final ink = selected ? skin.onChipSelected : skin.ink;
    final holeInset = tag && skin.isJournal ? 12.0 : 0.0;

    Widget label0 = Padding(
      padding: EdgeInsets.only(
        left: (dense ? 10 : 12) + holeInset,
        right: dense ? 10 : 12,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize * 1.2, color: ink),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TitoTypography.style(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ],
      ),
    );
    if (holeInset > 0) {
      label0 = Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: 7,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD9E2DF),
                border: Border.all(color: skin.outline!, width: 1.25),
              ),
            ),
          ),
          label0,
        ],
      );
    }

    return ListenableBuilder(
      listenable: retroStyle,
      builder: (context, _) {
        final decoration = _decoration(skin, radius);
        Widget chip = DecoratedBox(
          decoration: decoration,
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: SizedBox(
                height: height,
                child: Center(widthFactor: 1, child: label0),
              ),
            ),
          ),
        );
        if (onTap != null) {
          chip = HandheldFocusDecorator(
            onActivate: onTap,
            borderRadius: radius,
            child: chip,
          );
        }
        return Semantics(
          button: onTap != null,
          selected: selected,
          child: chip,
        );
      },
    );
  }

  BoxDecoration _decoration(TitoSkin skin, BorderRadius radius) {
    final depth = retroStyle.enabled;
    if (skin.isJournal) {
      return BoxDecoration(
        color: selected ? skin.chipSelectedFill : skin.chipFill,
        borderRadius: radius,
        border: Border.all(
          color: selected ? skin.chipSelectedFill : skin.outline!,
          width: 1.25,
        ),
        boxShadow: depth
            ? const [BoxShadow(color: Color(0x26566A77), offset: Offset(0, 2))]
            : null,
      );
    }
    if (skin.isPlastic) {
      return BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: selected
              ? const [Color(0xFF5A9DB1), Color(0xFF3D7F93)]
              : const [Color(0xFAFFFFFF), Color(0xFFDCEAF0)],
        ),
        boxShadow: depth
            ? const [
                BoxShadow(
                  color: Color(0x4D0A1422),
                  blurRadius: 8,
                  spreadRadius: -3,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      );
    }
    return BoxDecoration(
      borderRadius: radius,
      color: selected
          ? skin.chipSelectedFill
          : (tag ? TitoColors.skyBlue : skin.chipFill),
    );
  }
}

enum TitoKeyTone {
  /// Header / toolbar key (settings, game badge).
  neutral,

  /// The single primary round key on a screen (the TitoDex key).
  action,
}

/// Round hardware key.
///
/// Journal: paper sticker key with slate outline and hard drop; the action
/// tone is the deep-blue key with a paper ring and stitched inner ring.
/// Solid Plastic: frosted round button; the action tone is a radial
/// die-cast key with a specular cap. Flat UI: solid colour disc (sky /
/// coral) with no outline or shadow.
class TitoRoundKey extends StatelessWidget {
  const TitoRoundKey({
    super.key,
    required this.size,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
    this.tone = TitoKeyTone.neutral,
    this.fill,
  });

  final double size;
  final String semanticLabel;
  final VoidCallback? onTap;
  final Widget child;
  final TitoKeyTone tone;

  /// Overrides the neutral fill (e.g. an edition's accent colour).
  final Color? fill;

  bool get _action => tone == TitoKeyTone.action;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    if (skin.isPlastic && !_action) {
      return LiquidGlassRoundButton(
        size: size,
        semanticLabel: semanticLabel,
        onTap: onTap,
        tint: fill ?? TitoColors.card,
        opacity: fill == null ? 0.9 : 0.95,
        child: IconTheme.merge(
          data: const IconThemeData(color: TitoColors.deepBlue),
          child: child,
        ),
      );
    }

    final iconColor = skin.isFlat
        ? TitoColors.flatOnSurface
        : (_action ? TitoColors.card : TitoColors.deepBlue);
    final radius = BorderRadius.circular(size / 2);
    Widget face = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: size,
          child: IconTheme.merge(
            data: IconThemeData(color: iconColor),
            child: Center(child: child),
          ),
        ),
      ),
    );

    final Decoration decoration;
    if (skin.isJournal) {
      decoration = _action
          ? BoxDecoration(
              shape: BoxShape.circle,
              color: TitoColors.deepBlue,
              boxShadow: [
                const BoxShadow(
                  color: TitoColors.journalOutline,
                  spreadRadius: 5.3,
                ),
                const BoxShadow(
                  color: TitoColors.journalPaper,
                  spreadRadius: 4,
                ),
              ],
            )
          : BoxDecoration(
              shape: BoxShape.circle,
              color: fill ?? skin.paper,
              border: Border.all(
                color: skin.outline!,
                width: skin.outlineWidth,
              ),
            );
      if (_action) {
        face = TitoDashedFrame(
          color: TitoColors.journalPaper.withValues(alpha: 0.55),
          radius: size / 2,
          strokeWidth: 1.5,
          inset: size * 0.09,
          child: face,
        );
      }
    } else if (skin.isPlastic) {
      decoration = const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.32, -0.44),
          radius: 0.9,
          colors: [
            Color(0xFF8AA3C6),
            Color(0xFF3D5779),
            Color(0xFF243650),
            Color(0xFF1A283C),
          ],
          stops: [0, 0.38, 0.78, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x8C0A1422),
            blurRadius: 13,
            spreadRadius: -2,
            offset: Offset(0, 10),
          ),
          BoxShadow(color: Color(0xB3FFFFFF), spreadRadius: 6),
          BoxShadow(color: Color(0x6BFFFFFF), spreadRadius: 5),
        ],
      );
      face = Stack(
        children: [
          face,
          Positioned(
            left: size * 0.2,
            top: size * 0.13,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: -20 * math.pi / 180,
                child: Container(
                  width: size * 0.37,
                  height: size * 0.17,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.all(
                      Radius.elliptical(size * 0.37, size * 0.17),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        color: _action ? TitoColors.coral : (fill ?? TitoColors.skyBlue),
      );
    }

    Widget key = DecoratedBox(decoration: decoration, child: face);
    if (skin.isJournal && !_action) {
      key = StickerPressable(
        borderRadius: radius,
        interactive: onTap != null,
        child: key,
      );
    }
    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: radius,
      child: Semantics(button: onTap != null, label: semanticLabel, child: key),
    );
  }
}

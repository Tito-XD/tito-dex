import 'package:flutter/material.dart';

import '../features/dex/type_chart.dart';
import '../theme/retro_style.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_skin.dart';
import '../theme/tito_typography.dart';

enum TypeBadgeSize { small, medium }

/// Outline for dex chips, plates and fields.
///
/// Journal uses the slate pencil, Solid Plastic the white rim, Flat UI no
/// outline (or the outlined-block fallback when retro stickers are off).
BorderSide dexSkinSide(BuildContext context, {Color? color, double? width}) {
  final skin = TitoSkin.of(context);
  if (skin.outline == null || skin.outlineWidth <= 0) {
    if (skin.isFlat && !retroStyle.enabled) {
      return BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant,
        width: 1.5,
      );
    }
    return BorderSide.none;
  }
  return BorderSide(
    color: color ?? skin.outline!,
    width: width ?? skin.outlineWidth,
  );
}

/// Stadium chip fill for filters and tags. Static paint only — no blur.
BoxDecoration dexSkinChipDecoration(
  BuildContext context, {
  double selected = 0,
  BorderRadiusGeometry radius = const BorderRadius.all(Radius.circular(999)),
}) {
  final skin = TitoSkin.of(context);
  final t = selected.clamp(0.0, 1.0);
  if (skin.isPlastic) {
    return BoxDecoration(
      borderRadius: radius,
      border: Border.all(color: skin.outline!, width: skin.outlineWidth),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(const Color(0xFAFFFFFF), const Color(0xFF5A9DB1), t)!,
          Color.lerp(const Color(0xFFDCEAF0), const Color(0xFF3D7F93), t)!,
        ],
      ),
    );
  }
  final fill = Color.lerp(skin.chipFill, skin.chipSelectedFill, t);
  final side = dexSkinSide(
    context,
    color: skin.isJournal
        ? Color.lerp(skin.outline, skin.chipSelectedFill, t)
        : null,
  );
  return BoxDecoration(
    color: fill,
    borderRadius: radius,
    border: side == BorderSide.none ? null : Border.fromBorderSide(side),
  );
}

Color dexSkinChipInk(BuildContext context, {double selected = 0}) {
  final skin = TitoSkin.of(context);
  return Color.lerp(skin.ink, skin.onChipSelected, selected.clamp(0.0, 1.0))!;
}

/// Flat block one step darker than the page, with the outlined-block stroke.
///
/// Cream paper on Flat UI sits too close to the page to read as a cell.
/// Caught and seen colour blocks stay on [StickerCard] and do not use this.
BoxDecoration dexFlatSeparatedDecoration(
  BuildContext context, {
  required double radius,
}) {
  return BoxDecoration(
    color: TitoColors.flatSurfaceContainerHigh,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: Theme.of(context).colorScheme.outlineVariant,
      width: 1.5,
    ),
  );
}

/// Official Gen VIII-style type icon (pokesprite set, bundled in the APK at
/// assets/type_icons/{type}.png). Falls back to the legacy Material symbol
/// if the asset is missing so unknown type keys never break a row.
class TypeIconImage extends StatelessWidget {
  const TypeIconImage({
    super.key,
    required this.typeEn,
    required this.size,
    this.fallbackColor = TitoColors.ink,
  });

  final String typeEn;
  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final color = fallbackColor == TitoColors.ink
        ? TitoSkin.of(context).ink
        : fallbackColor;
    return Image.asset(
      'assets/type_icons/${typeEn.toLowerCase()}.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) =>
          Icon(typeIconData(typeEn), size: size, color: color),
    );
  }
}

/// Sticker-style type badge: colored pill with symbol icon + Chinese label.
///
/// Journal and Solid Plastic keep a compact colour chip with the skin
/// outline. Flat UI is a colour-block chip with no elevation: the icon sits
/// on a white circular plate and the Chinese label stays on the type fill,
/// so the badge stays readable on paper cards and on the deep detail header.
class TitoTypeBadge extends StatelessWidget {
  const TitoTypeBadge({
    super.key,
    required this.typeEn,
    this.size = TypeBadgeSize.medium,
  });

  final String typeEn;
  final TypeBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    final small = size == TypeBadgeSize.small;
    final iconSize = small ? 11.0 : 14.0;
    final fontSize = small ? 10.0 : 12.0;
    final label = Text(
      typeNameZh(typeEn),
      style: TitoTypography.style(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        height: 1.1,
        color: skin.ink,
      ),
    );
    final plate = iconSize + (small ? 5 : 6);
    final icon = TypeIconImage(typeEn: typeEn, size: iconSize);

    return ListenableBuilder(
      listenable: retroStyle,
      builder: (context, _) {
        final side = dexSkinSide(context);
        return Container(
          padding: EdgeInsets.fromLTRB(
            skin.isFlat ? 2 : (small ? 5 : 8),
            small ? 2 : 3,
            small ? 5 : 8,
            small ? 2 : 3,
          ),
          decoration: BoxDecoration(
            color: typeTileColor(typeEn),
            borderRadius: BorderRadius.circular(999),
            border: side == BorderSide.none
                ? null
                : Border.fromBorderSide(side),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (skin.isFlat)
                Container(
                  width: plate,
                  height: plate,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  // Official type glyphs are white; ink them so they read
                  // on the white plate instead of disappearing.
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(skin.ink, BlendMode.srcIn),
                    child: icon,
                  ),
                )
              else
                icon,
              SizedBox(width: small ? 2 : 4),
              label,
            ],
          ),
        );
      },
    );
  }
}

/// One-line row of type badges; scales down instead of wrapping/overflowing.
class TitoTypeBadgeRow extends StatelessWidget {
  const TitoTypeBadgeRow({
    super.key,
    required this.typesEn,
    this.size = TypeBadgeSize.small,
    this.spacing = 4,
  });

  final List<String> typesEn;
  final TypeBadgeSize size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (typesEn.isEmpty) {
      return const SizedBox.shrink();
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < typesEn.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            TitoTypeBadge(typeEn: typesEn[i], size: size),
          ],
        ],
      ),
    );
  }
}

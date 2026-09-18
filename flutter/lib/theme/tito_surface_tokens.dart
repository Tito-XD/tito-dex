import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'app_visual_style.dart';
import 'tito_colors.dart';
import 'trainer_journal.dart';

/// Rendering primitives stay distinct; colours, edges and depth live here.
enum TitoSurfaceFinish { paper, plastic, material }

enum TitoSurfaceRole {
  card,
  deep,
  sky,
  mint,
  softYellow,
  element,
  toggle,
  toggleSelected,
  field,
  disabledField,
  party,
  emptyParty,
  level,
  avatar,
  groupLabel,
  sprite,
  inset,
  knob,
  selection,
  selectionActive,
  progress,
  fact,
  emptyTeam,
}

@immutable
class TitoSurfaceRecipe {
  const TitoSurfaceRecipe(
    this.fill, {
    this.outline = BorderSide.none,
    this.foreground = TitoColors.ink,
    this.opacity = 1,
    this.radius = TitoRadii.sm,
  });

  final Color fill;
  final BorderSide outline;
  final Color foreground;
  final double opacity;
  final double radius;

  BoxBorder? get border =>
      outline.style == BorderStyle.none ? null : Border.fromBorderSide(outline);

  BoxDecoration decoration({BoxShape shape = BoxShape.rectangle}) =>
      BoxDecoration(
        color: fill,
        border: border,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? BorderRadius.circular(radius)
            : null,
      );

  static TitoSurfaceRecipe lerp(
    TitoSurfaceRecipe a,
    TitoSurfaceRecipe b,
    double t,
  ) => TitoSurfaceRecipe(
    Color.lerp(a.fill, b.fill, t)!,
    outline: BorderSide.lerp(a.outline, b.outline, t),
    foreground: Color.lerp(a.foreground, b.foreground, t)!,
    opacity: lerpDouble(a.opacity, b.opacity, t)!,
    radius: lerpDouble(a.radius, b.radius, t)!,
  );

  Map<String, Object> toJson() => {
    'fill': colorToken(fill),
    'outline': outlineToken(outline),
    'foreground': colorToken(foreground),
    'opacity': opacity,
    'radius': radius,
  };
}

/// Canonical surface recipes. Exported JSON is generated from these instances.
@immutable
class TitoSurfaceTokens extends ThemeExtension<TitoSurfaceTokens> {
  const TitoSurfaceTokens({
    required this.finish,
    required this.surfaces,
    required this.cardShadow,
    required this.deepShadow,
    required this.elementShadow,
    required this.controlShadow,
    required this.pressedShadow,
    required this.pressSink,
    required this.flatCardOutline,
    required this.dividerColor,
  });

  final TitoSurfaceFinish finish;
  final Map<TitoSurfaceRole, TitoSurfaceRecipe> surfaces;
  final List<BoxShadow> cardShadow,
      deepShadow,
      elementShadow,
      controlShadow,
      pressedShadow;
  final double pressSink;
  final BorderSide flatCardOutline;
  final Color dividerColor;

  TitoSurfaceRecipe surface(TitoSurfaceRole role) => surfaces[role]!;
  Color get cardFill => surface(TitoSurfaceRole.card).fill;
  BorderSide get cardOutline => surface(TitoSurfaceRole.card).outline;
  BorderSide get elementOutline => surface(TitoSurfaceRole.element).outline;
  bool get usesMaterial => finish == TitoSurfaceFinish.material;
  bool get usesOptics => finish == TitoSurfaceFinish.plastic;

  static TitoSurfaceTokens of(BuildContext context) =>
      Theme.of(context).extension<TitoSurfaceTokens>() ??
      // Standalone Material hosts have no Tito extension. Follow their scheme;
      // never consult the global preference behind an inherited Theme.
      TitoSurfaceTokens.forStyle(
        AppVisualStyle.flatUi,
        Theme.of(context).colorScheme,
      );

  factory TitoSurfaceTokens.forStyle(AppVisualStyle style, ColorScheme scheme) {
    final flat = style == AppVisualStyle.flatUi;
    final plastic = style == AppVisualStyle.solidPlastic;
    final element = flat
        ? BorderSide.none
        : plastic
        ? BorderSide(
            color: Colors.white.withValues(alpha: .78),
            width: TitoBorders.glass,
          )
        : TrainerJournal.elementSide;
    final card = flat
        ? BorderSide.none
        : plastic
        ? element
        : TrainerJournal.cardSide;
    final ink = flat
        ? scheme.onSurface
        : plastic
        ? TitoColors.ink
        : TrainerJournal.ink;
    TitoSurfaceRecipe recipe(
      Color fill, {
      BorderSide? outline,
      Color? foreground,
      double opacity = 1,
      double radius = TitoRadii.sm,
    }) => TitoSurfaceRecipe(
      fill,
      outline: outline ?? element,
      foreground: foreground ?? ink,
      opacity: opacity,
      radius: radius,
    );
    return TitoSurfaceTokens(
      finish: flat
          ? TitoSurfaceFinish.material
          : plastic
          ? TitoSurfaceFinish.plastic
          : TitoSurfaceFinish.paper,
      surfaces: Map.unmodifiable({
        TitoSurfaceRole.card: recipe(
          flat
              ? scheme.surfaceContainerLow
              : plastic
              ? TitoColors.card
              : TrainerJournal.paperWarm,
          outline: card,
          opacity: plastic ? .92 : 1,
          radius: TitoRadii.lg,
        ),
        TitoSurfaceRole.deep: recipe(
          flat ? scheme.primary : TitoColors.deepBlue,
          outline: plastic
              ? element.copyWith(color: Colors.white.withValues(alpha: .38))
              : card,
          foreground: flat ? scheme.onPrimary : TitoColors.card,
          opacity: plastic ? .95 : 1,
          radius: TitoRadii.lg,
        ),
        TitoSurfaceRole.sky: recipe(
          flat ? scheme.primaryContainer : TitoColors.skyBlue,
          outline: card,
          foreground: flat ? scheme.onPrimaryContainer : ink,
          opacity: plastic ? .9 : 1,
          radius: TitoRadii.lg,
        ),
        TitoSurfaceRole.mint: recipe(
          TitoColors.mint,
          outline: card,
          opacity: plastic ? .92 : 1,
          radius: TitoRadii.lg,
        ),
        TitoSurfaceRole.softYellow: recipe(
          TitoColors.softYellow,
          outline: card,
          opacity: plastic ? .93 : 1,
          radius: TitoRadii.lg,
        ),
        TitoSurfaceRole.element: recipe(
          flat
              ? scheme.surfaceContainerHigh
              : plastic
              ? Colors.white.withValues(alpha: .8)
              : TitoColors.cardWarm,
        ),
        TitoSurfaceRole.toggle: recipe(
          flat
              ? scheme.surfaceContainerHigh
              : plastic
              ? Colors.white.withValues(alpha: .8)
              : TitoColors.cardWarm,
        ),
        TitoSurfaceRole.toggleSelected: recipe(
          flat
              ? scheme.secondaryContainer
              : plastic
              ? TitoColors.mint.withValues(alpha: .9)
              : TitoColors.mint,
        ),
        TitoSurfaceRole.field: recipe(
          flat
              ? scheme.surfaceContainerHighest
              : plastic
              ? Colors.white.withValues(alpha: .7)
              : TitoColors.card,
          outline: card,
        ),
        TitoSurfaceRole.disabledField: recipe(
          flat
              ? scheme.surfaceContainerHighest.withValues(alpha: .6)
              : plastic
              ? Colors.white.withValues(alpha: .45)
              : TitoColors.cardWarm.withValues(alpha: .6),
          outline: card,
        ),
        TitoSurfaceRole.party: recipe(
          flat
              ? scheme.surfaceContainerHighest
              : plastic
              ? Colors.white.withValues(alpha: .35)
              : TrainerJournal.cell,
          outline: plastic ? element : BorderSide.none,
          radius: flat || plastic ? TitoRadii.sm : 6,
        ),
        TitoSurfaceRole.emptyParty: recipe(
          flat
              ? scheme.surfaceContainerHigh
              : plastic
              ? Colors.white.withValues(alpha: .18)
              : TrainerJournal.cell.withValues(alpha: .35),
          outline: plastic
              ? element.copyWith(color: Colors.white.withValues(alpha: .5))
              : BorderSide.none,
          radius: flat || plastic ? TitoRadii.sm : 6,
        ),
        TitoSurfaceRole.level: recipe(
          flat
              ? scheme.tertiaryContainer
              : plastic
              ? TitoColors.softYellow.withValues(alpha: .92)
              : TrainerJournal.levelFill,
          foreground: flat ? scheme.onTertiaryContainer : ink,
          outline: plastic ? element : BorderSide.none,
        ),
        TitoSurfaceRole.avatar: recipe(
          flat
              ? scheme.surfaceContainerHigh
              : plastic
              ? Colors.white.withValues(alpha: .7)
              : TrainerJournal.paper,
        ),
        TitoSurfaceRole.progress: recipe(
          flat
              ? scheme.surfaceContainerHighest
              : plastic
              ? Colors.white.withValues(alpha: .35)
              : TrainerJournal.ink.withValues(alpha: .10),
          foreground: flat ? scheme.primary : TitoColors.deepBlue,
          outline: plastic ? element : BorderSide.none,
        ),
        TitoSurfaceRole.fact: recipe(
          flat
              ? scheme.surfaceContainerLow
              : plastic
              ? Colors.white.withValues(alpha: .46)
              : TrainerJournal.cell,
          outline: flat
              ? BorderSide(
                  color: scheme.outlineVariant,
                  width: TitoBorders.element,
                )
              : plastic
              ? element.copyWith(color: Colors.white.withValues(alpha: .85))
              : BorderSide.none,
        ),
        TitoSurfaceRole.emptyTeam: recipe(
          flat
              ? scheme.surfaceContainerLow
              : plastic
              ? Colors.white.withValues(alpha: .3)
              : TrainerJournal.cell,
          outline: flat
              ? BorderSide(
                  color: scheme.outlineVariant,
                  width: TitoBorders.element,
                )
              : plastic
              ? element.copyWith(color: Colors.white.withValues(alpha: .6))
              : TrainerJournal.hairlineSide,
        ),
        TitoSurfaceRole.sprite: recipe(
          flat
              ? scheme.surfaceContainerLow
              : plastic
              ? Colors.white.withValues(alpha: .82)
              : Colors.white,
        ),
        TitoSurfaceRole.inset: recipe(
          flat
              ? scheme.surfaceContainerHighest
              : plastic
              ? Colors.white.withValues(alpha: .7)
              : TitoColors.cardWarm,
          outline: card,
        ),
        TitoSurfaceRole.knob: recipe(plastic ? Colors.white : TitoColors.card),
        TitoSurfaceRole.selection: recipe(
          flat
              ? scheme.surfaceContainerLow
              : plastic
              ? TitoColors.card.withValues(alpha: .86)
              : TitoColors.card,
          foreground: flat ? scheme.onSurface : TitoColors.ink,
          outline: plastic
              ? element.copyWith(color: Colors.white.withValues(alpha: .8))
              : element,
        ),
        TitoSurfaceRole.selectionActive: recipe(
          flat
              ? scheme.secondaryContainer
              : plastic
              ? TitoColors.softYellow.withValues(alpha: .92)
              : TitoColors.softYellow,
          foreground: flat ? scheme.onSecondaryContainer : TitoColors.ink,
        ),
        TitoSurfaceRole.groupLabel: recipe(
          flat ? scheme.secondaryContainer : TitoColors.softYellow,
          foreground: flat
              ? scheme.onSecondaryContainer
              : const Color(0xFF6A4A05),
          opacity: plastic ? .9 : 1,
        ),
      }),
      cardShadow: flat
          ? TitoShadows.sticker
          : plastic
          ? SolidPlasticShadows.sticker
          : TrainerJournalShadows.sticker,
      deepShadow: flat
          ? TitoShadows.sticker
          : plastic
          ? SolidPlasticShadows.sticker
          : TrainerJournalShadows.deep,
      elementShadow: flat
          ? TitoShadows.stickerSmall
          : plastic
          ? SolidPlasticShadows.stickerSmall
          : TrainerJournalShadows.stickerSmall,
      controlShadow: flat
          ? TitoShadows.sticker
          : plastic
          ? SolidPlasticShadows.sticker
          : TrainerJournalShadows.control,
      pressedShadow: flat
          ? const []
          : plastic
          ? SolidPlasticShadows.stickerPressed
          : TrainerJournalShadows.stickerPressed,
      pressSink: flat
          ? 0
          : plastic
          ? 3
          : TrainerJournal.pressSink,
      flatCardOutline: flat ? BorderSide(color: scheme.outlineVariant) : card,
      dividerColor: flat
          ? scheme.outlineVariant
          : plastic
          ? Colors.white.withValues(alpha: .6)
          : TrainerJournal.ink.withValues(alpha: .22),
    );
  }

  @override
  TitoSurfaceTokens copyWith({
    TitoSurfaceFinish? finish,
    Map<TitoSurfaceRole, TitoSurfaceRecipe>? surfaces,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? deepShadow,
    List<BoxShadow>? elementShadow,
    List<BoxShadow>? controlShadow,
    List<BoxShadow>? pressedShadow,
    double? pressSink,
    BorderSide? flatCardOutline,
    Color? dividerColor,
  }) => TitoSurfaceTokens(
    finish: finish ?? this.finish,
    surfaces: Map.unmodifiable(surfaces ?? this.surfaces),
    cardShadow: cardShadow ?? this.cardShadow,
    deepShadow: deepShadow ?? this.deepShadow,
    elementShadow: elementShadow ?? this.elementShadow,
    controlShadow: controlShadow ?? this.controlShadow,
    pressedShadow: pressedShadow ?? this.pressedShadow,
    pressSink: pressSink ?? this.pressSink,
    flatCardOutline: flatCardOutline ?? this.flatCardOutline,
    dividerColor: dividerColor ?? this.dividerColor,
  );

  @override
  TitoSurfaceTokens lerp(covariant TitoSurfaceTokens? other, double t) {
    if (other == null || t == 0) return this;
    if (t == 1) return other;
    return copyWith(
      finish: t < .5 ? finish : other.finish,
      surfaces: {
        for (final role in TitoSurfaceRole.values)
          role: TitoSurfaceRecipe.lerp(surface(role), other.surface(role), t),
      },
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t),
      deepShadow: BoxShadow.lerpList(deepShadow, other.deepShadow, t),
      elementShadow: BoxShadow.lerpList(elementShadow, other.elementShadow, t),
      controlShadow: BoxShadow.lerpList(controlShadow, other.controlShadow, t),
      pressedShadow: BoxShadow.lerpList(pressedShadow, other.pressedShadow, t),
      pressSink: lerpDouble(pressSink, other.pressSink, t),
      flatCardOutline: BorderSide.lerp(
        flatCardOutline,
        other.flatCardOutline,
        t,
      ),
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t),
    );
  }

  Map<String, Object> toJson() => {
    'finish': finish.name,
    'cardFill': colorToken(cardFill),
    'cardOutline': outlineToken(cardOutline),
    'elementOutline': outlineToken(elementOutline),
    'pressSink': pressSink,
    'flatCardOutline': outlineToken(flatCardOutline),
    'dividerColor': colorToken(dividerColor),
    'surfaces': {
      for (final entry in surfaces.entries)
        entry.key.name: entry.value.toJson(),
    },
    for (final entry in {
      'cardShadow': cardShadow,
      'deepShadow': deepShadow,
      'elementShadow': elementShadow,
      'controlShadow': controlShadow,
      'pressedShadow': pressedShadow,
    }.entries)
      entry.key: [
        for (final shadow in entry.value)
          {
            'color': colorToken(shadow.color),
            'x': shadow.offset.dx,
            'y': shadow.offset.dy,
            'blur': shadow.blurRadius,
            'spread': shadow.spreadRadius,
          },
      ],
  };
}

// CSS-compatible RRGGBBAA, including translucent colours (not Flutter AARRGGBB).
String colorToken(Color color) {
  final argb = color.toARGB32();
  return '#${((argb & 0xffffff) << 8 | (argb >> 24)).toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

Map<String, Object> outlineToken(BorderSide side) => {
  'color': colorToken(side.color),
  'width': side.width,
  'style': side.style.name,
};

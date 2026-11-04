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

  /// Header bar behind the page title. [TitoSurfaceRecipe.foreground] is the
  /// title / icon ink directly on the page (Flat on-surface, gradient cream).
  pageChrome,

  /// Secondary text on the page itself (subtitles, hints above cards).
  pageSubtle,

  /// Tappable icons and outlined controls on the page itself (back arrow,
  /// Dex search pill).
  pageAction,

  /// Round header buttons and the edition avatar. Solid Plastic draws these
  /// with `LiquidGlassRoundButton`; the recipe still resolves for previews.
  headerButton,

  /// Faint frame drawn directly on the page (drag canvas): surface tones in
  /// Flat, a cream wash with a pale edge over the gradient themes.
  pageWell,

  /// Focus and selected rings: Flat's primary, soft yellow on the gradient
  /// themes. Use [TitoSurfaceRecipe.fill] as the ring colour.
  highlight,

  /// Accent icons on cream cards (catalog tiles): Flat primary, deep blue on
  /// the gradient themes. Use [TitoSurfaceRecipe.foreground].
  accent,

  /// Small status labels drawn directly on the page (form flags on the Dex
  /// detail hero): bare tertiary text in Flat, cream on a deep-blue chip
  /// over the gradient themes so it meets AA at the light end.
  pageBadge,
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
        TitoSurfaceRole.pageChrome: recipe(
          flat ? scheme.surface : Colors.transparent,
          foreground: flat ? scheme.onSurface : TitoColors.card,
          outline: BorderSide.none,
        ),
        TitoSurfaceRole.pageSubtle: recipe(
          Colors.transparent,
          foreground: flat ? scheme.onSurfaceVariant : TitoColors.card,
          outline: BorderSide.none,
        ),
        TitoSurfaceRole.pageAction: recipe(
          Colors.transparent,
          foreground: flat ? scheme.primary : TitoColors.card,
          // Outlined page controls (Dex search pill) stroke in the same tint.
          outline: BorderSide(
            color: flat ? scheme.primary : TitoColors.card,
            width: flat
                ? TitoBorders.card
                : plastic
                ? TitoBorders.glass
                : TitoBorders.journalCard,
          ),
        ),
        TitoSurfaceRole.headerButton: recipe(
          flat
              ? scheme.secondaryContainer
              : plastic
              ? Colors.white.withValues(alpha: .8)
              : TitoColors.card,
          foreground: flat ? scheme.onSecondaryContainer : TitoColors.deepBlue,
          outline: card,
          radius: 999,
        ),
        TitoSurfaceRole.pageWell: recipe(
          flat
              ? scheme.surfaceContainerLow
              : TitoColors.cream.withValues(alpha: .16),
          outline: BorderSide(
            color: flat
                ? scheme.outlineVariant
                : TitoColors.card.withValues(alpha: .35),
            width: flat || plastic
                ? TitoBorders.element
                : TitoBorders.journalHairline,
          ),
          radius: TitoRadii.md,
        ),
        TitoSurfaceRole.highlight: recipe(
          flat ? scheme.primary : TitoColors.softYellow,
          foreground: flat ? scheme.onPrimary : TitoColors.ink,
          outline: BorderSide.none,
        ),
        TitoSurfaceRole.accent: recipe(
          Colors.transparent,
          foreground: flat ? scheme.primary : TitoColors.deepBlue,
          outline: BorderSide.none,
        ),
        TitoSurfaceRole.pageBadge: recipe(
          flat
              ? Colors.transparent
              : TitoColors.deepBlue.withValues(alpha: .88),
          foreground: flat ? scheme.tertiary : TitoColors.card,
          outline: BorderSide.none,
          radius: TitoRadii.sm,
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

/// One selectable tile on a sheet or card: edition grids, picker forms and
/// choice rows. Selected tiles take the soft-yellow fill (Flat: secondary
/// container) and a stronger outline; idle tiles sit on the element tone.
TitoSurfaceRecipe titoChoiceTile(
  BuildContext context, {
  required bool selected,
}) {
  final scheme = Theme.of(context).colorScheme;
  return switch (TitoSurfaceTokens.of(context).finish) {
    TitoSurfaceFinish.material => TitoSurfaceRecipe(
      selected ? scheme.secondaryContainer : scheme.surfaceContainerHigh,
      outline: BorderSide(
        color: selected ? scheme.primary : scheme.outlineVariant,
        width: selected ? TitoBorders.card : TitoBorders.element,
      ),
      foreground: selected ? scheme.onSecondaryContainer : scheme.onSurface,
      radius: TitoRadii.md,
    ),
    TitoSurfaceFinish.plastic => TitoSurfaceRecipe(
      selected
          ? TitoColors.softYellow.withValues(alpha: .85)
          : Colors.white.withValues(alpha: .8),
      outline: BorderSide(
        color: Colors.white.withValues(alpha: .85),
        width: TitoBorders.glass,
      ),
      radius: TitoRadii.md,
    ),
    TitoSurfaceFinish.paper => TitoSurfaceRecipe(
      selected ? TitoColors.softYellow : TrainerJournal.paper,
      outline: BorderSide(
        color: selected ? TrainerJournal.edge : TrainerJournal.smallEdge,
        width: selected ? TitoBorders.journalCard : TitoBorders.journalElement,
      ),
      foreground: TrainerJournal.ink,
      radius: TitoRadii.md,
    ),
  };
}

/// Ring around a colour swatch tile (type grid, colour filters). The selected
/// swatch always gets a strong ring; idle swatches fade it (Journal), use a
/// milky hairline (Plastic) or go borderless (Flat).
BorderSide titoSwatchOutline(BuildContext context, {required bool selected}) {
  final finish = TitoSurfaceTokens.of(context).finish;
  if (selected) {
    return finish == TitoSurfaceFinish.paper
        ? const BorderSide(
            color: TrainerJournal.selectedEdge,
            width: TitoBorders.journalElement,
          )
        : const BorderSide(color: TitoColors.ink, width: TitoBorders.element);
  }
  return finish == TitoSurfaceFinish.plastic
      ? BorderSide(
          color: Colors.white.withValues(alpha: .7),
          width: TitoBorders.glass,
        )
      : BorderSide.none;
}

/// Hand-drawn sticker edge kept in every theme (speech bubble, Ask source
/// chips): Journal's gray-blue pencil line, ink elsewhere. [strong] uses the
/// Journal card edge; [alpha] softens the ink in the other themes.
BorderSide titoInkOutline(
  BuildContext context, {
  bool strong = false,
  double alpha = 1,
}) {
  if (TitoSurfaceTokens.of(context).finish == TitoSurfaceFinish.paper) {
    return strong
        ? const BorderSide(
            color: TrainerJournal.edge,
            width: TitoBorders.journalElement,
          )
        : TrainerJournal.elementSide;
  }
  return BorderSide(
    color: TitoColors.ink.withValues(alpha: alpha),
    width: TitoBorders.element,
  );
}

/// Stroke for tiny outlined marks (status dots, battery frame): the Journal
/// pencil hairline, the element stroke elsewhere.
double titoHairlineWidth(BuildContext context) =>
    TitoSurfaceTokens.of(context).finish == TitoSurfaceFinish.paper
    ? TitoBorders.journalHairline
    : TitoBorders.element;

/// Pastel sticker tint for decorative tiles (Home quick actions). Flat UI
/// keeps its Material surface container, so this returns null there and the
/// tile falls back to its default fill.
Color? titoStickerTint(BuildContext context, Color tint) =>
    TitoSurfaceTokens.of(context).finish == TitoSurfaceFinish.material
    ? null
    : tint;

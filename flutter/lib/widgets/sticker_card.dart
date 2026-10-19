import 'package:flutter/material.dart';

import '../theme/app_visual_style.dart';
import '../theme/retro_style.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_skin.dart';
import 'liquid_glass.dart';
import 'tito_paper.dart';

enum StickerVariant { cream, deep, sky, mint, softYellow }

/// The shared card surface for all three skins.
///
/// * `StickerCard(...)` — normal card; [variant] picks the fill.
/// * `StickerCard.hero(role: ...)` — a signature surface (≤ 2–3 per screen):
///   Journal adds washi tape + tilt (trainer) or a stitched dashed frame,
///   Solid Plastic uses the role's moulded tint, Flat UI a bold colour block.
/// * `StickerCard.dense(...)` — list/grid/detail cells: opaque, untilted,
///   smallest theme shadow.
class StickerCard extends StatelessWidget {
  const StickerCard({
    super.key,
    required this.child,
    this.variant = StickerVariant.cream,
    this.padding = const EdgeInsets.all(16),
    this.level = TitoSurfaceLevel.normal,
    this.heroRole = TitoHeroRole.trainer,
    this.decorate = true,
  });

  const StickerCard.hero({
    super.key,
    required this.child,
    TitoHeroRole role = TitoHeroRole.trainer,
    this.padding = const EdgeInsets.all(16),
    this.decorate = true,
  }) : variant = StickerVariant.cream,
       level = TitoSurfaceLevel.hero,
       heroRole = role;

  const StickerCard.dense({
    super.key,
    required this.child,
    this.variant = StickerVariant.cream,
    this.padding = const EdgeInsets.all(12),
  }) : level = TitoSurfaceLevel.dense,
       heroRole = TitoHeroRole.trainer,
       decorate = false;

  final Widget child;
  final StickerVariant variant;
  final EdgeInsets padding;
  final TitoSurfaceLevel level;

  /// Only read when [level] is [TitoSurfaceLevel.hero].
  final TitoHeroRole heroRole;

  /// Hero ornaments (tape, tilt, dashed frame). Disable when a hero card sits
  /// in a tight slot where an overhanging tape would be clipped.
  final bool decorate;

  bool get _hero => level == TitoSurfaceLevel.hero;
  bool get _dense => level == TitoSurfaceLevel.dense;

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    return ListenableBuilder(
      listenable: retroStyle,
      builder: (context, _) => switch (skin.family) {
        TitoThemeFamily.trainerJournal => _journal(context, skin),
        TitoThemeFamily.solidPlastic => _plastic(context, skin),
        TitoThemeFamily.flatUi => _flat(context, skin),
      },
    );
  }

  double _radius(TitoSkin skin) => _hero
      ? skin.radiusHero
      : _dense
      ? skin.radiusMd
      : skin.radiusLg;

  Widget _content(
    BuildContext context,
    TitoHeroTint? tint, {
    bool inkSurface = true,
  }) {
    Widget body = Padding(padding: padding, child: child);
    if (tint != null) {
      body = DefaultTextStyle.merge(
        style: TextStyle(color: tint.ink),
        child: IconTheme.merge(
          data: IconThemeData(color: tint.ink),
          child: body,
        ),
      );
    }
    if (!inkSurface) {
      return body;
    }
    // ListTile / InkWell children paint ink on the nearest Material; this
    // keeps it above the decorated fill. Material would otherwise reset the
    // ambient text style to bodyMedium.
    return Material(
      type: MaterialType.transparency,
      textStyle: DefaultTextStyle.of(context).style,
      child: body,
    );
  }

  Widget _journal(BuildContext context, TitoSkin skin) {
    final tint = _hero ? skin.heroTint(heroRole) : null;
    final fill =
        tint?.top ??
        switch (variant) {
          StickerVariant.cream => skin.paper,
          StickerVariant.deep => TitoColors.deepBlue,
          StickerVariant.sky => TitoColors.skyBlue,
          StickerVariant.mint => TitoColors.mint,
          StickerVariant.softYellow => TitoColors.softYellow,
        };
    final light = fill.computeLuminance() > 0.5;
    final radius = _radius(skin);
    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: light ? skin.outline! : const Color(0xFF22324A),
          width: skin.outlineWidth,
        ),
        boxShadow: skin.cardShadow(small: _dense, paperEdge: light && !_dense),
      ),
      child: _content(context, tint),
    );
    if (!_hero || !decorate) {
      return card;
    }
    if (heroRole == TitoHeroRole.trainer) {
      return Transform.rotate(
        angle: skin.heroTiltRadians,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            card,
            const Positioned(
              top: -9,
              left: 0,
              right: 0,
              child: Center(child: TitoWashiTape()),
            ),
          ],
        ),
      );
    }
    return TitoDashedFrame(
      color: light
          ? skin.outline!.withValues(alpha: 0.55)
          : TitoColors.journalPaper.withValues(alpha: 0.42),
      radius: radius - 5,
      inset: 5,
      child: card,
    );
  }

  Widget _plastic(BuildContext context, TitoSkin skin) {
    final radius = _radius(skin);
    if (_hero) {
      final tint = skin.heroTint(heroRole);
      return LiquidGlassSurface(
        tint: tint.top,
        opacity: heroRole == TitoHeroRole.journey ? 0.95 : 0.92,
        radius: radius,
        boxShadow: skin.cardShadow(),
        child: _content(context, tint),
      );
    }
    final (tint, opacity) = switch (variant) {
      StickerVariant.cream => (TitoColors.card, 0.92),
      StickerVariant.deep => (TitoColors.deepBlue, 0.95),
      StickerVariant.sky => (TitoColors.skyBlue, 0.9),
      StickerVariant.mint => (TitoColors.mint, 0.92),
      StickerVariant.softYellow => (TitoColors.softYellow, 0.93),
    };
    return LiquidGlassSurface(
      tint: tint,
      opacity: _dense ? 1 : opacity,
      radius: radius,
      boxShadow: skin.cardShadow(small: _dense),
      child: _content(context, null),
    );
  }

  Widget _flat(BuildContext context, TitoSkin skin) {
    final scheme = Theme.of(context).colorScheme;
    final tint = _hero ? skin.heroTint(heroRole) : null;
    final fill =
        tint?.top ??
        switch (variant) {
          StickerVariant.cream => skin.paper,
          StickerVariant.deep => TitoColors.deepBlue,
          StickerVariant.sky => TitoColors.skyBlue,
          StickerVariant.mint => TitoColors.mint,
          StickerVariant.softYellow => TitoColors.softYellow,
        };
    // Flat UI never casts a shadow. The surface-depth preference keeps its
    // contract as "solid colour block" (on) vs "outlined block" (off).
    return Material(
      type: MaterialType.card,
      color: fill,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius(skin)),
        side: retroStyle.enabled
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant, width: 1.5),
      ),
      child: _content(context, tint, inkSurface: false),
    );
  }
}

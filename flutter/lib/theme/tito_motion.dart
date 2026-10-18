import 'package:flutter/material.dart';

import 'motion_preferences.dart';
import 'tito_skin.dart';

/// Shared lightweight motion tokens for TitoDex surfaces.
abstract final class TitoMotion {
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 220);
  static const emphasized = Duration(milliseconds: 280);
  static const listReveal = Duration(milliseconds: 260);

  static const switchTravel = 8.0;
  static const listTravel = 6.0;

  /// Local surface motion only; navigation keeps its existing route timeline.
  static TitoSurfaceMotion of(BuildContext context) {
    final skin = TitoSkin.of(context);
    return skin.isJournal
        ? TitoSurfaceMotion.journal
        : skin.isPlastic
        ? TitoSurfaceMotion.plastic
        : TitoSurfaceMotion.flat;
  }

  static bool disabled(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      !motionPreferences.listAnimationsEnabled;

  static Duration duration(BuildContext context, Duration normal) =>
      disabled(context) ? Duration.zero : normal;
}

/// Native Flutter vocabulary: a bounded pop-in, stagger, eased release and
/// a small material-dependent deformation. Never used for an idle loop.
@immutable
class TitoSurfaceMotion {
  const TitoSurfaceMotion({
    required this.enter,
    required this.stagger,
    required this.release,
    required this.selection,
    required this.enterCurve,
    required this.releaseCurve,
    required this.travel,
    required this.startScale,
    required this.pressDepth,
    this.pressScaleX = 1,
    this.pressScaleY = 1,
    this.switchStretch = 0,
  });

  final Duration enter;
  final Duration stagger;
  final Duration release;
  final Duration selection;
  final Curve enterCurve;
  final Curve releaseCurve;
  final double travel;
  final double startScale;
  final double pressDepth;
  final double pressScaleX;
  final double pressScaleY;
  final double switchStretch;

  Duration get press => const Duration(milliseconds: 80);
  Curve get settleCurve => Curves.easeOutCubic;

  static const journal = TitoSurfaceMotion(
    enter: Duration(milliseconds: 300),
    stagger: Duration(milliseconds: 42),
    release: Duration(milliseconds: 220),
    selection: Duration(milliseconds: 200),
    enterCurve: Curves.easeOutBack,
    releaseCurve: Curves.easeOutBack,
    travel: 8,
    startScale: 0.975,
    pressDepth: 3,
    switchStretch: 0.12,
  );
  static const plastic = TitoSurfaceMotion(
    enter: Duration(milliseconds: 320),
    stagger: Duration(milliseconds: 46),
    release: Duration(milliseconds: 240),
    selection: Duration(milliseconds: 240),
    enterCurve: Curves.easeOutCubic,
    releaseCurve: Curves.easeOutCubic,
    travel: 6,
    startScale: 0.985,
    pressDepth: 1.5,
    pressScaleX: 0.997,
    pressScaleY: 0.985,
    switchStretch: 0.18,
  );
  static const flat = TitoSurfaceMotion(
    enter: Duration(milliseconds: 200),
    stagger: Duration(milliseconds: 30),
    release: Duration(milliseconds: 140),
    selection: Duration(milliseconds: 160),
    enterCurve: Curves.easeOutCubic,
    releaseCurve: Curves.easeOutCubic,
    travel: 4,
    startScale: 0.995,
    pressDepth: 0,
  );
}

import 'package:flutter/material.dart';

import '../theme/tito_colors.dart';

enum LocationSceneKind { route, city, interior, dungeon, defaultScene }

LocationSceneKind locationSceneKindFor(String location) {
  final lower = location.toLowerCase();
  if (lower.contains('道路') ||
      lower.contains('route') ||
      lower.contains('水道') ||
      lower.contains('洞窟') && !lower.contains('塔')) {
    return LocationSceneKind.route;
  }
  if (lower.contains('市') ||
      lower.contains('镇') ||
      lower.contains('城') ||
      lower.contains('city') ||
      lower.contains('town')) {
    return LocationSceneKind.city;
  }
  if (lower.contains('宝可梦中心') ||
      lower.contains('友好商店') ||
      lower.contains('道馆') ||
      lower.contains('gym') ||
      lower.contains('mart') ||
      lower.contains('center')) {
    return LocationSceneKind.interior;
  }
  if (lower.contains('塔') ||
      lower.contains('遗迹') ||
      lower.contains('洞') ||
      lower.contains('tower') ||
      lower.contains('ruins')) {
    return LocationSceneKind.dungeon;
  }
  return LocationSceneKind.defaultScene;
}

/// Location-aware pixel thumbnail; tappable when [onTap] is set (continue journey).
class CityIllustration extends StatelessWidget {
  const CityIllustration({
    super.key,
    required this.location,
    this.compact = false,
    this.dense = false,
    this.onTap,
    this.showContinueHint = false,
  });

  final String location;
  final bool compact;
  final bool dense;
  final VoidCallback? onTap;
  final bool showContinueHint;

  @override
  Widget build(BuildContext context) {
    final height = dense ? 44.0 : (compact ? 56.0 : 88.0);
    final kind = locationSceneKindFor(location);

    final scene = Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitoRadii.md),
        border: Border.all(color: TitoColors.ink, width: TitoBorders.card),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _skyColors(kind),
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          ..._sceneBlocks(kind, compact: compact || dense),
          if (showContinueHint)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(TitoRadii.md - 3),
                  color: TitoColors.deepBlue.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: TitoColors.card.withValues(alpha: 0.92),
                    size: dense ? 22 : (compact ? 28 : 36),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap == null) {
      return scene;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TitoRadii.md),
        child: scene,
      ),
    );
  }

  List<Color> _skyColors(LocationSceneKind kind) {
    return switch (kind) {
      LocationSceneKind.route => const [
          Color(0xFF9AD0F0),
          Color(0xFF6AB0DC),
          Color(0xFF4A8C48),
        ],
      LocationSceneKind.city => const [
          Color(0xFF8EC5E8),
          Color(0xFF5A9FD4),
          Color(0xFF6E8A52),
        ],
      LocationSceneKind.interior => const [
          Color(0xFFB8C8E8),
          Color(0xFF8AA0C8),
          Color(0xFF5C4A3A),
        ],
      LocationSceneKind.dungeon => const [
          Color(0xFF6A7A90),
          Color(0xFF4A5568),
          Color(0xFF2E3A30),
        ],
      LocationSceneKind.defaultScene => const [
          Color(0xFF8EC5E8),
          Color(0xFF5A9FD4),
          Color(0xFF3D7A5C),
        ],
    };
  }

  List<Widget> _sceneBlocks(LocationSceneKind kind, {required bool compact}) {
    return switch (kind) {
      LocationSceneKind.route => [
          Positioned(
            left: compact ? 8 : 14,
            right: compact ? 8 : 14,
            bottom: compact ? 10 : 16,
            child: Row(
              children: [
                _Block(width: compact ? 18 : 24, height: compact ? 8 : 10, color: TitoColors.mint),
                const Spacer(),
                _Block(width: compact ? 14 : 18, height: compact ? 12 : 16, color: TitoColors.cream),
                SizedBox(width: compact ? 8 : 12),
                _Block(width: compact ? 20 : 26, height: compact ? 10 : 12, color: TitoColors.deepBlue),
              ],
            ),
          ),
        ],
      LocationSceneKind.city => [
          Positioned(
            left: compact ? 12 : 18,
            bottom: compact ? 12 : 18,
            child: _Block(
              width: compact ? 22 : 30,
              height: compact ? 28 : 40,
              color: TitoColors.cream,
            ),
          ),
          Positioned(
            right: compact ? 10 : 16,
            bottom: compact ? 10 : 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Block(width: compact ? 16 : 22, height: compact ? 18 : 24, color: TitoColors.deepBlue),
                SizedBox(width: compact ? 4 : 6),
                _Block(width: compact ? 22 : 28, height: compact ? 22 : 30, color: TitoColors.slateBlue),
              ],
            ),
          ),
        ],
      LocationSceneKind.interior => [
          Positioned(
            left: compact ? 10 : 16,
            right: compact ? 10 : 16,
            bottom: compact ? 8 : 12,
            child: _Block(
              width: double.infinity,
              height: compact ? 20 : 28,
              color: TitoColors.coral.withValues(alpha: 0.85),
            ),
          ),
        ],
      LocationSceneKind.dungeon => [
          Positioned(
            left: compact ? 14 : 22,
            bottom: compact ? 8 : 12,
            child: _Block(width: compact ? 24 : 32, height: compact ? 24 : 32, color: const Color(0xFF3A4A38)),
          ),
          Positioned(
            right: compact ? 12 : 18,
            top: compact ? 8 : 12,
            child: Text(
              '◆',
              style: TextStyle(
                color: TitoColors.softYellow,
                fontSize: compact ? 10 : 12,
              ),
            ),
          ),
        ],
      LocationSceneKind.defaultScene => [
          Positioned(
            left: compact ? 12 : 18,
            bottom: compact ? 12 : 18,
            child: _Block(width: compact ? 20 : 28, height: compact ? 24 : 34, color: TitoColors.cream),
          ),
        ],
    };
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: TitoColors.ink, width: 2),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/tito_colors.dart';

/// Pixel-style Goldenrod / city scene for Continue Journey card.
class CityIllustration extends StatelessWidget {
  const CityIllustration({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 72.0 : 120.0;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TitoRadii.md),
        border: Border.all(color: TitoColors.ink, width: 3),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF8EC5E8),
            Color(0xFF5A9FD4),
            Color(0xFF3D7A5C),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: compact ? 16 : 24,
            bottom: compact ? 14 : 22,
            child: _Block(
              width: compact ? 28 : 36,
              height: compact ? 40 : 56,
              color: TitoColors.cream,
            ),
          ),
          Positioned(
            right: compact ? 14 : 20,
            bottom: compact ? 12 : 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Block(
                  width: compact ? 22 : 28,
                  height: compact ? 24 : 32,
                  color: TitoColors.deepBlue,
                ),
                SizedBox(width: compact ? 6 : 8),
                _Block(
                  width: compact ? 28 : 36,
                  height: compact ? 30 : 40,
                  color: TitoColors.slateBlue,
                ),
                SizedBox(width: compact ? 6 : 8),
                _Block(
                  width: compact ? 18 : 24,
                  height: compact ? 20 : 28,
                  color: TitoColors.skyBlue,
                ),
              ],
            ),
          ),
          Positioned(
            top: compact ? 10 : 14,
            right: compact ? 18 : 28,
            child: Text(
              '★',
              style: TextStyle(
                color: TitoColors.softYellow,
                fontSize: compact ? 12 : 14,
                shadows: const [
                  Shadow(color: TitoColors.ink, offset: Offset(0, 1)),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: compact ? 22 : 32,
            left: compact ? 12 : 18,
            child: Text(
              '★',
              style: TextStyle(
                color: TitoColors.softYellow,
                fontSize: compact ? 10 : 12,
                shadows: const [
                  Shadow(color: TitoColors.ink, offset: Offset(0, 1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

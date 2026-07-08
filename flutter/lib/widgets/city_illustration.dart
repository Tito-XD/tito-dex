import 'package:flutter/material.dart';

import '../theme/tito_colors.dart';

/// Pixel-style Goldenrod / city scene for Continue Journey card.
class CityIllustration extends StatelessWidget {
  const CityIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
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
            left: 24,
            bottom: 22,
            child: _Block(
              width: 36,
              height: 56,
              color: TitoColors.cream,
            ),
          ),
          Positioned(
            right: 20,
            bottom: 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Block(width: 28, height: 32, color: TitoColors.deepBlue),
                const SizedBox(width: 8),
                _Block(width: 36, height: 40, color: TitoColors.slateBlue),
                const SizedBox(width: 8),
                _Block(width: 24, height: 28, color: TitoColors.skyBlue),
              ],
            ),
          ),
          const Positioned(
            top: 14,
            right: 28,
            child: Text(
              '★',
              style: TextStyle(
                color: TitoColors.softYellow,
                fontSize: 14,
                shadows: [
                  Shadow(color: TitoColors.ink, offset: Offset(0, 1)),
                ],
              ),
            ),
          ),
          const Positioned(
            bottom: 32,
            left: 18,
            child: Text(
              '★',
              style: TextStyle(
                color: TitoColors.softYellow,
                fontSize: 12,
                shadows: [
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

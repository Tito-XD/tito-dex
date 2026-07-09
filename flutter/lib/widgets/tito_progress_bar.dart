import 'package:flutter/material.dart';

import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';

/// Thin, sticker-style progress bar used across TitoDex surfaces.
class TitoProgressBar extends StatelessWidget {
  const TitoProgressBar({
    super.key,
    required this.value,
    this.label,
    this.height = 8,
    this.fillColor,
    this.trackColor,
  });

  final double value;
  final String? label;
  final double height;
  final Color? fillColor;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: context.tito.cardMuted.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: trackColor ?? TitoColors.slateBlue),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: clamped,
                    child: ColoredBox(color: fillColor ?? TitoColors.deepBlue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

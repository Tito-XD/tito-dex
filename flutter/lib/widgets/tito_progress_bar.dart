import 'package:flutter/material.dart';

import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';

/// Thin, sticker-style progress bar used across TitoDex surfaces.
///
/// Fill width is computed explicitly from the available width so the bar
/// renders identically on every backend (Skia, Impeller, web).
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
        LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 120.0;
            final fillWidth = trackWidth * clamped;
            return Container(
              width: trackWidth,
              height: height,
              decoration: BoxDecoration(
                color: trackColor ?? TitoColors.ink.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: TitoColors.ink.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.centerLeft,
              child: fillWidth <= 0
                  ? const SizedBox.shrink()
                  : Container(
                      width: fillWidth,
                      height: height,
                      decoration: BoxDecoration(
                        color: fillColor ?? TitoColors.deepBlue,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
            );
          },
        ),
      ],
    );
  }
}

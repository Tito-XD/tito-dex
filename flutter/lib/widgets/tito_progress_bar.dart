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
        // No LayoutBuilder here: AlertDialog sizes its content via
        // IntrinsicWidth, and LayoutBuilder cannot answer intrinsic queries —
        // in debug builds that assertion kills the whole dialog layout.
        // LimitedBox keeps the 120px fallback for unbounded-width parents.
        LimitedBox(
          maxWidth: 120,
          child: Container(
            width: double.infinity,
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
            child: clamped <= 0
                ? null
                : FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: clamped,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: fillColor ?? TitoColors.deepBlue,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

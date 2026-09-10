import 'package:flutter/material.dart';

import '../theme/app_visual_style.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/trainer_journal.dart';

/// Aligned cells that grow with their contents instead of clipping long values.
class TitoFactGrid extends StatelessWidget {
  const TitoFactGrid({super.key, required this.children, this.columns = 2})
    : assert(columns > 0);

  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final minimumWidth =
          84 *
          (MediaQuery.textScalerOf(context).scale(12) / 12).clamp(
            1.0,
            double.infinity,
          );
      final count = constraints.maxWidth.isFinite
          ? ((constraints.maxWidth + 8) / (minimumWidth + 8)).floor().clamp(
              1,
              columns,
            )
          : columns;
      return Column(
        children: [
          for (var start = 0; start < children.length; start += count) ...[
            if (start > 0) const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < count; column++) ...[
                    if (column > 0) const SizedBox(width: 8),
                    Expanded(
                      child: start + column < children.length
                          ? children[start + column]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

class TitoFactTile extends StatelessWidget {
  const TitoFactTile({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.onTap,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final flat = appVisualStyle.usesFlatUi;
    final plastic = appVisualStyle.usesSolidPlastic;
    final journal = appVisualStyle.usesTrainerJournal;
    final foreground = flat
        ? scheme.onSurface
        : journal
        ? TrainerJournal.ink
        : TitoColors.ink;
    final secondary = flat
        ? scheme.onSurfaceVariant
        : journal
        ? TrainerJournal.muted
        : TitoColors.mutedInk;
    final radius = BorderRadius.circular(TitoRadii.sm);
    return Material(
      color: flat
          ? scheme.surfaceContainerLow
          : journal
          ? TrainerJournal.cell
          : Colors.white.withValues(alpha: .46),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: journal
            ? BorderSide.none
            : BorderSide(
                color: flat
                    ? scheme.outlineVariant
                    : plastic
                    ? Colors.white.withValues(alpha: .85)
                    : TitoColors.ink.withValues(alpha: .2),
                width: plastic ? TitoBorders.glass : TitoBorders.element,
              ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 15, color: secondary),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: SecondaryTypography.onCard.small12.copyWith(
                        color: secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              DefaultTextStyle(
                style: SecondaryTypography.onCard.body14.copyWith(
                  fontWeight: TrainerJournal.weight(FontWeight.w800),
                  color: foreground,
                ),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

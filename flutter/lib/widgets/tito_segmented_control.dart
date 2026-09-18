import 'package:flutter/material.dart';

import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_motion.dart';
import '../theme/tito_surface_tokens.dart';
import 'handheld_input.dart';

/// The tool rail and scope selector share geometry and interaction states.
class TitoSegmentedControl<T> extends StatelessWidget {
  const TitoSegmentedControl({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.railColor,
    this.railForeground,
    this.selectedColor,
    this.selectedForeground,
    this.indicatorKey,
    this.railKey,
    this.optionKeyBuilder,
    this.floating = false,
  });
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final Color? railColor;
  final Color? railForeground;
  final Color? selectedColor;
  final Color? selectedForeground;
  final Key? indicatorKey;
  final Key? railKey;
  final Key Function(T)? optionKeyBuilder;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final tokens = TitoSurfaceTokens.of(context);
    final rail = tokens.surface(TitoSurfaceRole.deep);
    final selected = tokens.surface(TitoSurfaceRole.card);
    final keys = options.keys.toList();
    final index = keys.indexOf(value).clamp(0, keys.length - 1);
    const radius = BorderRadius.all(Radius.circular(TitoRadii.md));
    const indicatorRadius = BorderRadius.all(Radius.circular(TitoRadii.sm));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          top: 4,
          bottom: 4,
          child: DecoratedBox(
            key: railKey,
            decoration: railColor == null
                ? rail.decoration().copyWith(
                    borderRadius: radius,
                    boxShadow: floating ? TitoNavigationShadows.floating : null,
                  )
                : BoxDecoration(
                    color: railColor,
                    borderRadius: radius,
                    boxShadow: floating ? TitoNavigationShadows.floating : null,
                  ),
          ),
        ),
        Positioned.fill(
          top: 15,
          bottom: 15,
          child: Row(
            children: [
              for (var i = 0; i < keys.length; i++)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedOpacity(
                      duration: TitoMotion.duration(context, TitoMotion.fast),
                      opacity:
                          i < keys.length - 1 && i != index && i + 1 != index
                          ? 1
                          : 0,
                      child: SizedBox(
                        width: 1,
                        height: double.infinity,
                        child: ColoredBox(
                          color: (railForeground ?? rail.foreground).withValues(
                            alpha: .18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned.fill(
          top: 7,
          bottom: 7,
          left: 3,
          right: 3,
          child: AnimatedAlign(
            duration: TitoMotion.duration(context, TitoMotion.emphasized),
            curve: Curves.easeOutCubic,
            alignment: Alignment(
              keys.length == 1 ? 0 : -1 + 2 * index / (keys.length - 1),
              0,
            ),
            child: FractionallySizedBox(
              widthFactor: 1 / keys.length,
              child: DecoratedBox(
                key: indicatorKey,
                decoration: BoxDecoration(
                  color: selectedColor ?? selected.fill,
                  borderRadius: indicatorRadius,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        Row(
          children: [
            for (final entry in options.entries)
              Expanded(
                child: HandheldFocusDecorator(
                  borderRadius: radius,
                  onActivate: () => onChanged(entry.key),
                  child: Semantics(
                    button: true,
                    selected: entry.key == value,
                    child: Material(
                      key: optionKeyBuilder?.call(entry.key),
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: radius,
                        onTap: () => onChanged(entry.key),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 10,
                            ),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: TitoMotion.duration(
                                  context,
                                  TitoMotion.emphasized,
                                ),
                                curve: Curves.easeOutCubic,
                                style: SecondaryTypography.onCard.small12
                                    .copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: value == entry.key
                                          ? selectedForeground ??
                                                selected.foreground
                                          : railForeground ?? rail.foreground,
                                    ),
                                child: Text(
                                  entry.value,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

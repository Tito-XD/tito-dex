import 'package:flutter/material.dart';

import '../theme/secondary_typography.dart';
import 'handheld_input.dart';
import 'sticker_card.dart';
import '../theme/tito_typography.dart';

/// Collapsible block for long settings sections (Sleep links, cache filters, …).
class SettingsExpandableSection extends StatefulWidget {
  const SettingsExpandableSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.variant = StickerVariant.cream,
    this.initiallyExpanded = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final StickerVariant variant;
  final bool initiallyExpanded;

  @override
  State<SettingsExpandableSection> createState() =>
      _SettingsExpandableSectionState();
}

class _SettingsExpandableSectionState extends State<SettingsExpandableSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final chevronColor = TitoTypography.inkColor;
    final subtitleColor = TitoTypography.mutedColor;
    return StickerCard(
      variant: widget.variant,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HandheldFocusDecorator(
            onActivate: () => setState(() => _expanded = !_expanded),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: SecondaryTypography.onCard.h15,
                          ),
                          if (widget.subtitle != null && !_expanded) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: SecondaryTypography.onCard.small12
                                  .copyWith(color: subtitleColor),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: chevronColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded) ...[const SizedBox(height: 12), widget.child],
        ],
      ),
    );
  }
}

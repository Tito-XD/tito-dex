import 'package:flutter/material.dart';

import '../features/dex/dex_filter.dart';
import '../features/dex/dex_search_terms.dart';
import '../l10n/app_zh.dart';
import '../theme/device_layout.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';

/// Swatch for each Pokédex colour.
///
/// Deliberately *shown* rather than named. The in-game palette has ten entries
/// and no orange, so a player hunting an orange Pokémon reads the label 「棕」
/// and gives up — but pointed at a row of swatches they pick the two nearest
/// and get what they wanted. Multi-select exists for the same reason.
const _swatches = <String, Color>{
  'black': Color(0xFF3A3A3A),
  'blue': Color(0xFF4E7FD1),
  'brown': Color(0xFF9C6B4A),
  'gray': Color(0xFF9AA3AC),
  'green': Color(0xFF63B75E),
  'pink': Color(0xFFF08FB4),
  'purple': Color(0xFF9668C4),
  'red': Color(0xFFE0524A),
  'white': Color(0xFFF4F1EA),
  'yellow': Color(0xFFF2C443),
};

/// Body style / colour / relative size picker for the dex list.
Future<DexFilter?> showDexSpeciesFilterSheet(
  BuildContext context, {
  required DexFilter selected,
}) {
  return showModalBottomSheet<DexFilter>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scrollController) =>
            _SheetBody(initial: selected, scrollController: scrollController),
      ),
    ),
  );
}

class _SheetBody extends StatefulWidget {
  const _SheetBody({required this.initial, required this.scrollController});

  final DexFilter initial;
  final ScrollController scrollController;

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody> {
  late String? _shape = widget.initial.shapeSlug;
  late Set<String> _colors = {...widget.initial.colorSlugs};
  late String? _size = widget.initial.sizeSlug;

  DexFilter get _result => widget.initial.withSpeciesAxes(
    shapeSlug: _shape,
    colorSlugs: _colors,
    sizeSlug: _size,
    generation: widget.initial.generation,
    tag: widget.initial.tag,
  );

  void _reset() => setState(() {
    _shape = null;
    _colors = {};
    _size = null;
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppZh.dexSpeciesFilterTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: _result.hasSpeciesAxis ? _reset : null,
                child: Text(AppZh.dexSpeciesFilterReset),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [
              _SectionLabel(AppZh.dexSpeciesFilterShape),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final slug in kDexShapeSlugs)
                    _TextChip(
                      label: dexShapeLabelZh(slug) ?? slug,
                      selected: _shape == slug,
                      onTap: () => setState(
                        () => _shape = _shape == slug ? null : slug,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _SectionLabel(
                AppZh.dexSpeciesFilterColor,
                hint: AppZh.dexSpeciesFilterColorHint,
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final slug in kDexColorSlugs)
                    _Swatch(
                      slug: slug,
                      color: _swatches[slug] ?? TitoColors.card,
                      selected: _colors.contains(slug),
                      onTap: () => setState(() {
                        if (!_colors.remove(slug)) {
                          _colors.add(slug);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _SectionLabel(AppZh.dexSpeciesFilterSize),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final bucket in DexSizeBucket.values)
                    _TextChip(
                      label: bucket.labelZh,
                      selected: _size == bucket.slug,
                      onTap: () => setState(
                        () => _size = _size == bucket.slug ? null : bucket.slug,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: FilledButton(
            onPressed: () => Navigator.pop(context, _result),
            child: Text(AppZh.dexSpeciesFilterApply),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.hint});

  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: SecondaryTypography.onCard.body14.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                hint!,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TextChip extends StatelessWidget {
  const _TextChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? TitoColors.softYellow : TitoColors.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: TitoColors.ink, width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: SecondaryTypography.onCard.small12.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.slug,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String slug;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = DeviceLayout.useSquareDashboard(context) ? 34.0 : 40.0;
    // The label is the accessible name only — sighted users pick by colour.
    return Semantics(
      label: dexColorLabelZh(slug) ?? slug,
      selected: selected,
      button: true,
      child: Tooltip(
        message: dexColorLabelZh(slug) ?? slug,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: TitoColors.ink,
                  width: selected ? 4 : 2,
                ),
              ),
              child: selected
                  ? Icon(
                      Icons.check_rounded,
                      size: size * 0.5,
                      color: _onSwatch(color),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  static Color _onSwatch(Color swatch) =>
      swatch.computeLuminance() > 0.5 ? TitoColors.ink : Colors.white;
}

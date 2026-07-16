import 'dart:io';

import 'package:flutter/material.dart';

import '../features/dex/dex_models.dart';
import '../features/dex/sprite_generation_catalog.dart';
import '../theme/tito_colors.dart';
import 'dex_sprite_image.dart';

Future<void> showPokemonArtworkViewer(
  BuildContext context, {
  required PokemonSummary summary,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    builder: (context) => _PokemonArtworkViewer(summary: summary),
  );
}

class _PokemonArtworkViewer extends StatefulWidget {
  const _PokemonArtworkViewer({required this.summary});

  final PokemonSummary summary;

  @override
  State<_PokemonArtworkViewer> createState() => _PokemonArtworkViewerState();
}

class _PokemonArtworkViewerState extends State<_PokemonArtworkViewer> {
  late String? _mainSource;
  late bool _showAnimated;
  late final List<SpriteEditionOption> _options;
  late final Map<int, List<SpriteEditionOption>> _grouped;

  @override
  void initState() {
    super.initState();
    _options = spriteEditionOptionsForPokemon(
      widget.summary.id,
      cdnUrlsByVersion: widget.summary.spriteUrlsByVersion,
      fallbackSpriteUrl:
          widget.summary.displaySpritePath ?? widget.summary.spriteUrl,
    );
    _grouped = groupSpriteOptionsByGeneration(_options);
    _mainSource = widget.summary.artworkUrl ??
        officialArtworkUrlFor(widget.summary.id);
    _showAnimated = false;
  }

  void _selectOption(SpriteEditionOption option, {bool animated = false}) {
    setState(() {
      _showAnimated = animated;
      _mainSource = animated ? (option.animatedUrl ?? option.spriteUrl) : option.spriteUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;

    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.nameZh,
                      style: const TextStyle(
                        color: TitoColors.card,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: TitoColors.card),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: _mainSource == null
                    ? const Icon(
                        Icons.image_not_supported_outlined,
                        color: TitoColors.card,
                        size: 48,
                      )
                    : InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _ArtworkImage(source: _mainSource!),
                        ),
                      ),
              ),
            ),
            if (_options.isNotEmpty)
              SizedBox(
                height: 168,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    for (final entry in _grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 6),
                        child: Text(
                          generationRomanLabel(entry.key),
                          style: const TextStyle(
                            color: TitoColors.softYellow,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: entry.value.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final option = entry.value[index];
                            final selected = !_showAnimated &&
                                _mainSource == option.spriteUrl;
                            return _SpritePickerTile(
                              option: option,
                              selected: selected,
                              animatedSelected:
                                  _showAnimated && _mainSource == option.animatedUrl,
                              onSelectStatic: () =>
                                  _selectOption(option, animated: false),
                              onSelectAnimated: option.animatedUrl == null
                                  ? null
                                  : () => _selectOption(option, animated: true),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpritePickerTile extends StatelessWidget {
  const _SpritePickerTile({
    required this.option,
    required this.selected,
    required this.animatedSelected,
    required this.onSelectStatic,
    this.onSelectAnimated,
  });

  final SpriteEditionOption option;
  final bool selected;
  final bool animatedSelected;
  final VoidCallback onSelectStatic;
  final VoidCallback? onSelectAnimated;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected || animatedSelected
        ? TitoColors.softYellow
        : TitoColors.card.withValues(alpha: 0.35);

    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Expanded(
            child: Material(
              color: TitoColors.ink.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onSelectStatic,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: 2),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: DexSpriteImage(
                    source: option.spriteUrl,
                    width: 56,
                    height: 56,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            option.editionLabelZh,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: TitoColors.card.withValues(alpha: 0.92),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          if (onSelectAnimated != null)
            TextButton(
              onPressed: onSelectAnimated,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: animatedSelected
                    ? TitoColors.softYellow
                    : TitoColors.skyBlue,
              ),
              child: const Text('动图', style: TextStyle(fontSize: 9)),
            ),
        ],
      ),
    );
  }
}

class _ArtworkImage extends StatelessWidget {
  const _ArtworkImage({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    Widget missing(BuildContext _, Object __, StackTrace? ___) => const Icon(
      Icons.image_not_supported_outlined,
      color: TitoColors.card,
      size: 48,
    );

    final uri = Uri.tryParse(source);
    if (uri != null && uri.hasScheme && uri.scheme.startsWith('http')) {
      return Image.network(source, fit: BoxFit.contain, errorBuilder: missing);
    }
    return Image.file(File(source), fit: BoxFit.contain, errorBuilder: missing);
  }
}

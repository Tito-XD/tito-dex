import 'dart:io';

import 'package:flutter/material.dart';

import '../features/dex/dex_models.dart';
import '../features/dex/sprite_generation_catalog.dart';
import '../theme/tito_colors.dart';
import 'dex_sprite_image.dart';

String pokemonArtworkHeroTag(PokemonSummary summary) =>
    'pokemon-artwork-${summary.id}-${summary.spriteResourceId ?? summary.id}';

Future<void> showPokemonArtworkViewer(
  BuildContext context, {
  required PokemonSummary summary,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            Navigator.of(context).pop();
          }
        },
        child: _PokemonArtworkViewer(summary: summary),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _PokemonArtworkViewer extends StatefulWidget {
  const _PokemonArtworkViewer({required this.summary});

  final PokemonSummary summary;

  @override
  State<_PokemonArtworkViewer> createState() => _PokemonArtworkViewerState();
}

class _PokemonArtworkViewerState extends State<_PokemonArtworkViewer> {
  late final List<SpriteEditionOption> _options;
  late final Map<int, List<SpriteEditionOption>> _grouped;
  late SpriteEditionOption? _selectedOption;
  late bool _showAnimated;
  var _shiny = false;

  int get _spriteResourceId =>
      widget.summary.spriteResourceId ?? widget.summary.id;

  String? get _selectedStaticSource {
    final option = _selectedOption;
    final spriteResourceId = _spriteResourceId;
    if (option == null) {
      // Default / official artwork: prefer the summary's artwork, then the
      // PokeAPI official-artwork fallback.
      return widget.summary.artworkUrl ??
          officialArtworkUrlFor(spriteResourceId);
    }
    // If the selected option is the default artwork class, use the official
    // shiny artwork when the toggle is on.
    if (option.isOfficialArtwork) {
      return officialArtworkUrlFor(spriteResourceId);
    }
    return option.spriteUrl;
  }

  String? get _selectedShinySource {
    final option = _selectedOption;
    final spriteResourceId = _spriteResourceId;
    if (option == null || option.isOfficialArtwork) {
      return shinyOfficialArtworkUrlFor(spriteResourceId);
    }
    return shinySpriteVariantUrl(option.spriteUrl) ?? option.spriteUrl;
  }

  String? get _selectedAnimatedSource {
    final option = _selectedOption;
    if (option == null) {
      return widget.summary.animatedSpriteUrl ??
          showdownGifUrlFor(_spriteResourceId);
    }
    return option.animatedUrl ?? option.spriteUrl;
  }

  String? get _selectedAnimatedShinySource {
    final option = _selectedOption;
    if (option == null) {
      return showdownGifUrlFor(_spriteResourceId, shiny: true);
    }
    final animated = option.animatedUrl;
    if (animated == null) {
      return null;
    }
    if (animated.contains('/showdown/')) {
      return showdownGifUrlFor(_spriteResourceId, shiny: true);
    }
    if (animated.contains('/black-white/animated/')) {
      return bwAnimatedShinyGifUrlFor(_spriteResourceId);
    }
    return shinySpriteVariantUrl(animated) ?? animated;
  }

  String? get _displaySource {
    if (_showAnimated) {
      final animated = _shiny
          ? _selectedAnimatedShinySource
          : _selectedAnimatedSource;
      return animated;
    }
    return _shiny ? _selectedShinySource : _selectedStaticSource;
  }

  @override
  void initState() {
    super.initState();
    final spriteResourceId = _spriteResourceId;
    _options = spriteEditionOptionsForPokemon(
      spriteResourceId,
      cdnUrlsByVersion: widget.summary.spriteUrlsByVersion,
      fallbackSpriteUrl:
          widget.summary.displaySpritePath ?? widget.summary.spriteUrl,
    );
    _grouped = groupSpriteOptionsByGeneration(_options);
    _selectedOption = null;
    _showAnimated = false;
  }

  void _selectOption(SpriteEditionOption option, {bool animated = false}) {
    setState(() {
      _selectedOption = option;
      _showAnimated = animated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final displaySource = _displaySource;
    final heroTag = pokemonArtworkHeroTag(summary);

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
                  TextButton.icon(
                    onPressed: () => setState(() => _shiny = !_shiny),
                    style: TextButton.styleFrom(
                      foregroundColor: _shiny
                          ? TitoColors.softYellow
                          : TitoColors.card.withValues(alpha: 0.8),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: const Text(
                      '闪光',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: TitoColors.card,
                    ),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: displaySource == null
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
                          child: Hero(
                            tag: heroTag,
                            child: _ArtworkImage(
                              key: ValueKey('$_shiny-$displaySource'),
                              source: displaySource,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            if (_options.isNotEmpty)
              Expanded(
                flex: 1,
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
                            final selectedStatic =
                                !_showAnimated && _selectedOption == option;
                            final selectedAnimated =
                                _showAnimated && _selectedOption == option;
                            return _SpritePickerTile(
                              option: option,
                              selected: selectedStatic,
                              animatedSelected: selectedAnimated,
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
  const _ArtworkImage({super.key, required this.source});

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
      return Image.network(
        source,
        fit: BoxFit.contain,
        errorBuilder: missing,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          final total = progress.expectedTotalBytes;
          return Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                value: total == null || total == 0
                    ? null
                    : progress.cumulativeBytesLoaded / total,
                strokeWidth: 3,
                color: TitoColors.card,
              ),
            ),
          );
        },
      );
    }
    return Image.file(File(source), fit: BoxFit.contain, errorBuilder: missing);
  }
}

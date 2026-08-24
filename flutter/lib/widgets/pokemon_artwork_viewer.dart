import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/dex/dex_models.dart';
import '../features/dex/sprite_generation_catalog.dart';
import '../theme/tito_colors.dart';
import 'dex_sprite_image.dart';

String pokemonArtworkHeroTag(PokemonSummary summary) =>
    'pokemon-artwork-${summary.id}-${summary.spriteResourceId ?? summary.id}';

const pokemonArtworkViewerTransitionDuration = Duration(milliseconds: 360);
const pokemonArtworkViewerReverseTransitionDuration = Duration(
  milliseconds: 300,
);

Future<void> showPokemonArtworkViewer(
  BuildContext context, {
  required PokemonSummary summary,
}) {
  // Keep the viewer on the ShellRoute Navigator and use a PageRoute, not a
  // dialog route. Flutter's HeroController only pairs shared elements between
  // PageRoutes, so a PopupRoute made the old artwork Hero inert.
  return Navigator.of(
    context,
  ).push<void>(_PokemonArtworkPageRoute(summary: summary));
}

class _PokemonArtworkPageRoute extends PageRoute<void> {
  _PokemonArtworkPageRoute({required this.summary});

  static const _kBackGestureRunway = 0.02;

  final PokemonSummary summary;

  @override
  void handleUpdateBackGestureProgress({required double progress}) {
    super.handleUpdateBackGestureProgress(
      progress: math.max(_kBackGestureRunway, progress),
    );
  }

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  bool get fullscreenDialog => false;

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.88);

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => '关闭宝可梦大图';

  @override
  Duration get transitionDuration => pokemonArtworkViewerTransitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      pokemonArtworkViewerReverseTransitionDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: _PokemonArtworkViewer(summary: summary, routeAnimation: animation),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return PredictiveBackPageTransitionsBuilder(
      fallbackColor: Colors.black,
    ).buildTransitions(this, context, animation, secondaryAnimation, child);
  }
}

class _PokemonArtworkViewer extends StatefulWidget {
  const _PokemonArtworkViewer({
    required this.summary,
    required this.routeAnimation,
  });

  final PokemonSummary summary;
  final Animation<double> routeAnimation;

  @override
  State<_PokemonArtworkViewer> createState() => _PokemonArtworkViewerState();
}

class _PokemonArtworkViewerState extends State<_PokemonArtworkViewer> {
  late final List<SpriteEditionOption> _options;
  late final Map<int, List<SpriteEditionOption>> _grouped;
  late SpriteEditionOption? _selectedOption;
  late bool _showAnimated;
  var _showBack = false;
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

  String? get _selectedBackStaticSource {
    final option = _selectedOption;
    final backUrl = option?.backSpriteUrl;
    if (backUrl == null) {
      return null;
    }
    return _shiny ? shinySpriteVariantUrl(backUrl) ?? backUrl : backUrl;
  }

  String? get _selectedBackAnimatedSource {
    final option = _selectedOption;
    final backUrl = option?.animatedBackUrl;
    if (backUrl == null) {
      return null;
    }
    return _shiny ? shinySpriteVariantUrl(backUrl) ?? backUrl : backUrl;
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
    if (_showBack) {
      final back = _showAnimated
          ? _selectedBackAnimatedSource
          : _selectedBackStaticSource;
      if (back != null) {
        return back;
      }
      // No back art for this edition — fall back to the front view.
    }
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
      _showBack = false;
    });
  }

  void _toggleBackForOption(SpriteEditionOption option) {
    if (option.backSpriteUrl == null) {
      return;
    }
    setState(() {
      final isSameOption = _selectedOption == option;
      _selectedOption = option;
      _showBack = isSameOption ? !_showBack : true;
      if (_showAnimated && option.animatedBackUrl == null) {
        _showAnimated = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final displaySource = _displaySource;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final chromeOpacity = CurvedAnimation(
      parent: widget.routeAnimation,
      curve: reduceMotion
          ? const Interval(0, 0.01)
          : const Interval(0.48, 0.88, curve: Curves.easeOutCubic),
      reverseCurve: reduceMotion
          ? const Interval(0, 0.01)
          : const Interval(0.35, 0.78, curve: Curves.easeInCubic),
    );
    final chromePosition = Tween<Offset>(
      begin: reduceMotion ? Offset.zero : const Offset(0, 0.018),
      end: Offset.zero,
    ).animate(chromeOpacity);
    final highResolutionOpacity = CurvedAnimation(
      parent: widget.routeAnimation,
      curve: reduceMotion
          ? const Interval(0, 0.01)
          : const Interval(0.72, 1, curve: Curves.easeOutCubic),
      reverseCurve: reduceMotion
          ? const Interval(0, 0.01)
          : const Interval(0.62, 0.92, curve: Curves.easeInCubic),
    );

    return Material(
      key: const ValueKey('pokemon-artwork-viewer'),
      type: MaterialType.transparency,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SlideTransition(
              position: chromePosition,
              child: FadeTransition(
                key: const ValueKey('artwork-viewer-chrome'),
                opacity: chromeOpacity,
                child: Padding(
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
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _ArtworkHeroStage(
                      summary: summary,
                      displaySource: displaySource,
                      highResolutionOpacity: highResolutionOpacity,
                      variantKey: '$_shiny-$_showAnimated-$_showBack',
                    ),
                  ),
                ),
              ),
            ),
            if (_options.isNotEmpty)
              Expanded(
                flex: 1,
                child: SlideTransition(
                  position: chromePosition,
                  child: FadeTransition(
                    key: const ValueKey('artwork-viewer-editions'),
                    opacity: chromeOpacity,
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
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final option = entry.value[index];
                                final selectedStatic =
                                    !_showAnimated && _selectedOption == option;
                                final selectedAnimated =
                                    _showAnimated && _selectedOption == option;
                                final showingBack =
                                    _showBack && _selectedOption == option;
                                return _SpritePickerTile(
                                  option: option,
                                  selected: selectedStatic,
                                  animatedSelected: selectedAnimated,
                                  showingBack: showingBack,
                                  onSelectStatic: () =>
                                      _selectOption(option, animated: false),
                                  onSelectAnimated: option.animatedUrl == null
                                      ? null
                                      : () => _selectOption(
                                          option,
                                          animated: true,
                                        ),
                                  onToggleBack: option.backSpriteUrl == null
                                      ? null
                                      : () => _toggleBackForOption(option),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArtworkHeroStage extends StatelessWidget {
  const _ArtworkHeroStage({
    required this.summary,
    required this.displaySource,
    required this.highResolutionOpacity,
    required this.variantKey,
  });

  final PokemonSummary summary;
  final String? displaySource;
  final Animation<double> highResolutionOpacity;
  final String variantKey;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final dimension = math.min(viewport.width - 32, viewport.height * 0.42);
    final stableHeroOpacity = displaySource == null
        ? const AlwaysStoppedAnimation<double>(1)
        : ReverseAnimation(highResolutionOpacity);
    return SizedBox.square(
      dimension: dimension.clamp(160.0, 460.0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            key: const ValueKey('artwork-stable-hero-fade'),
            opacity: stableHeroOpacity,
            child: Hero(
              key: const ValueKey('artwork-stable-hero'),
              tag: pokemonArtworkHeroTag(summary),
              transitionOnUserGestures: true,
              child: Material(
                type: MaterialType.transparency,
                child: DexSpriteImage(
                  source: summary.displaySpritePath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          if (displaySource != null)
            FadeTransition(
              key: const ValueKey('artwork-high-res-reveal'),
              opacity: highResolutionOpacity,
              child: _ArtworkImage(
                key: ValueKey('$variantKey-$displaySource'),
                source: displaySource!,
              ),
            ),
        ],
      ),
    );
  }
}

class _SpritePickerTile extends StatelessWidget {
  const _SpritePickerTile({
    required this.option,
    required this.selected,
    required this.animatedSelected,
    required this.showingBack,
    required this.onSelectStatic,
    this.onSelectAnimated,
    this.onToggleBack,
  });

  final SpriteEditionOption option;
  final bool selected;
  final bool animatedSelected;
  final bool showingBack;
  final VoidCallback onSelectStatic;
  final VoidCallback? onSelectAnimated;
  final VoidCallback? onToggleBack;

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
                  child: Stack(
                    children: [
                      DexSpriteImage(
                        source: option.spriteUrl,
                        width: 56,
                        height: 56,
                      ),
                      if (onToggleBack != null)
                        Positioned(
                          top: -7,
                          right: -7,
                          child: IconButton(
                            key: ValueKey('flip-${option.versionGroup}'),
                            onPressed: onToggleBack,
                            tooltip: showingBack ? '切回正面' : '翻到背面',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: TitoColors.ink.withValues(
                                alpha: 0.88,
                              ),
                              foregroundColor: showingBack
                                  ? TitoColors.softYellow
                                  : TitoColors.card,
                            ),
                            icon: const Icon(
                              Icons.swap_horiz_rounded,
                              size: 17,
                            ),
                          ),
                        ),
                    ],
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

import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/companion/companion_art.dart';
import '../features/companion/companion_media.dart';
import '../features/companion/companion_metrics.dart';
import '../features/companion/companion_repository.dart';
import '../features/dex/dex_repository.dart';
import '../features/dex/shiny_odds.dart';
import '../features/dex/sprite_generation_catalog.dart';
import '../features/game/game_edition_repository.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'companion_picker_sheet.dart';
import 'fallback_sprite_image.dart';

/// Home standby companion — animated sprite fetched on demand (never
/// bundled), sized by the species' dex height. Tap to pat (bounce + hearts +
/// a classic quote bubble, 10 pats → friendship badge); long-press to pick a
/// different companion.
class CompanionStandby extends StatefulWidget {
  const CompanionStandby({
    super.key,
    required this.speciesId,
    required this.nameZh,
    this.compact = false,
    this.sizeScale = 1.0,
  });

  final int speciesId;
  final String nameZh;
  final bool compact;

  /// User multiplier from Settings (1.0–1.5) on top of height-based sizing.
  final double sizeScale;

  @override
  State<CompanionStandby> createState() => _CompanionStandbyState();
}

class _HeartParticle {
  _HeartParticle(this.id, math.Random random)
    : dx = random.nextDouble() * 36 - 18,
      angle = random.nextDouble() * 0.9 - 0.45,
      size = 12.0 + random.nextDouble() * 6;

  final int id;
  final double dx;
  final double angle;
  final double size;
}

class _CompanionStandbyState extends State<CompanionStandby>
    with SingleTickerProviderStateMixin {
  static const _friendshipPats = 10;
  static const _quoteDuration = Duration(milliseconds: 1900);
  static const _easterEggOdds = 50;

  /// One roll per app session per species — same scheme as the party strip,
  /// so remounts don't reroll the sparkle.
  static final int _sessionSeed = DateTime.now().millisecondsSinceEpoch;

  late final AnimationController _bounce;
  late final Animation<double> _bounceScale;
  final _random = math.Random();
  final _hearts = <_HeartParticle>[];
  final _cryPlayer = AudioPlayer();
  late Future<int?> _heightFuture;
  List<String>? _spriteSources;
  Timer? _quoteTimer;
  String? _quoteTemplate;
  var _cryUrlIndex = 0;
  var _cryBusy = false;
  var _nextHeartId = 0;
  var _pats = 0;
  var _shiny = false;

  bool get _friend => _pats >= _friendshipPats;

  @override
  void initState() {
    super.initState();
    _initForSpecies();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.16), weight: 28),
      TweenSequenceItem(tween: Tween(begin: 1.16, end: 0.94), weight: 32),
      TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant CompanionStandby oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speciesId != widget.speciesId) {
      _pats = 0;
      _hearts.clear();
      _quoteTemplate = null;
      _cryUrlIndex = 0;
      _quoteTimer?.cancel();
      _spriteSources = null;
      _initForSpecies();
    }
  }

  void _initForSpecies() {
    final id = widget.speciesId;
    _shiny = shinyRoll(_sessionSeed, id);
    _heightFuture = _loadHeight(id);
    _resolveSpriteSources();
    _loadPats(id);
  }

  Future<void> _loadPats(int id) async {
    final count = await companionRepository.patCountFor(id);
    if (mounted && id == widget.speciesId) {
      setState(() => _pats = count);
    }
  }

  /// Sprite source order: (shiny session: cached/network shiny first) →
  /// bundled asset (starters) → disk cache (chosen via the picker's preload
  /// dialog) → network candidates. Every miss falls through to the normal
  /// look, so a shiny roll can never blank the companion.
  Future<void> _resolveSpriteSources() async {
    final id = widget.speciesId;
    final shiny = _shiny;
    final bundled = bundledCompanionGifAsset(id);
    final cached = bundled == null
        ? await companionMediaCache.cachedGifPath(id)
        : null;
    final cachedShiny = shiny
        ? await companionMediaCache.cachedShinyGifPath(id)
        : null;
    if (shiny && cachedShiny == null) {
      // Prime the disk cache so the sparkle survives going offline later.
      unawaited(companionMediaCache.ensureShinyGif(id));
    }
    if (!mounted || id != widget.speciesId) {
      return;
    }
    setState(() {
      _spriteSources = [
        if (cachedShiny != null) cachedShiny,
        if (shiny) ...animatedShinySpriteCandidatesFor(id),
        if (bundled != null) bundled,
        if (cached != null) cached,
        ...animatedSpriteCandidatesFor(id),
      ];
    });
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _cryPlayer.dispose();
    _bounce.dispose();
    super.dispose();
  }

  /// Play the species cry: bundled asset (starters) → disk cache → network
  /// stream (which also backfills the cache). Guarded so rapid taps don't
  /// stack downloads; silent on total failure — the pat animation carries
  /// the interaction offline.
  Future<void> _playCry() async {
    if (_cryBusy) {
      return;
    }
    _cryBusy = true;
    final id = widget.speciesId;
    try {
      final bundled = bundledCompanionCryAsset(id);
      if (bundled != null) {
        await _cryPlayer.stop();
        await _cryPlayer.play(
          AssetSource(bundled.substring('assets/'.length)),
          volume: 0.55,
        );
        return;
      }
      final cached = await companionMediaCache.cachedCryPath(id);
      if (cached != null) {
        await _cryPlayer.stop();
        await _cryPlayer.play(DeviceFileSource(cached), volume: 0.55);
        return;
      }
      final candidates = cryCandidatesFor(id);
      for (var i = _cryUrlIndex; i < candidates.length; i++) {
        try {
          await _cryPlayer.stop();
          await _cryPlayer.play(UrlSource(candidates[i]), volume: 0.55);
          _cryUrlIndex = i;
          // Backfill the disk cache so the next pat is instant.
          unawaited(companionMediaCache.ensureCry(id));
          return;
        } catch (_) {
          // Try the next source.
        }
      }
    } finally {
      _cryBusy = false;
    }
  }

  static Future<int?> _loadHeight(int speciesId) async {
    try {
      final detail = await dexRepository.getDetail(speciesId);
      return detail.heightDm;
    } catch (_) {
      // Offline without cached detail — keep the midpoint size.
      return null;
    }
  }

  void _onPat() {
    HapticFeedback.lightImpact();
    _bounce.forward(from: 0);
    unawaited(_playCry());
    unawaited(companionRepository.incrementPats(widget.speciesId));
    final becameFriend = _pats + 1 == _friendshipPats;
    final easterEgg = _random.nextInt(_easterEggOdds) == 0;
    _quoteTimer?.cancel();
    _quoteTimer = Timer(_quoteDuration, () {
      if (mounted) {
        setState(() => _quoteTemplate = null);
      }
    });
    final edition = gameEditionRepository.edition;
    setState(() {
      _pats += 1;
      final heartCount = easterEgg ? 6 : 1;
      for (var i = 0; i < heartCount; i++) {
        _hearts.add(_HeartParticle(_nextHeartId++, _random));
      }
      _quoteTemplate = becameFriend
          ? companionFriendshipQuote
          : easterEgg
          ? companionEasterEggQuote
          : pickCompanionQuote(
              companionQuotePoolFor(
                generation: edition.generation,
                editionSlug: edition.slug,
                patCount: _pats,
                hour: DateTime.now().hour,
                shiny: _shiny,
              ),
              _random,
              previous: _quoteTemplate,
            );
    });
  }

  void _removeHeart(int id) {
    if (!mounted) {
      return;
    }
    setState(() => _hearts.removeWhere((heart) => heart.id == id));
  }

  Future<void> _openPicker() async {
    HapticFeedback.mediumImpact();
    final choice = await showCompanionPickerSheet(context);
    if (choice != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppZh.companionPicked(choice.nameZh))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final square = DeviceLayout.useSquareDashboard(context);
    // Floors stay at the previous defaults (can't shrink below); the phone
    // ceiling rises to the Showdown source resolution (~140px), tablets keep
    // the same phone:tablet ratio, square handhelds stay a bit tighter.
    final minSize = square || widget.compact ? 36.0 : 52.0;
    final maxSize = square ? 120.0 : (widget.compact ? 140.0 : 208.0);
    final scale = widget.sizeScale.clamp(0.75, 1.5);

    return FutureBuilder<int?>(
      future: _heightFuture,
      builder: (context, snapshot) {
        final spriteSize =
            companionSpriteSizeFor(
              snapshot.data,
              minSize: minSize,
              maxSize: maxSize,
            ) *
            scale;
        return _buildSticker(context, spriteSize, maxSize * scale);
      },
    );
  }

  Widget _buildSticker(
    BuildContext context,
    double spriteSize,
    double maxSize,
  ) {
    // Frameless — the animated sprite stands on the dashboard directly,
    // like a follower Pokémon rather than a badge.
    final sticker = AnimatedContainer(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      width: spriteSize,
      height: spriteSize,
      alignment: Alignment.bottomCenter,
      child: FallbackSpriteImage(
        sources:
            _spriteSources ??
            [
              if (bundledCompanionGifAsset(widget.speciesId) != null)
                bundledCompanionGifAsset(widget.speciesId)!,
              ...animatedSpriteCandidatesFor(widget.speciesId),
            ],
        width: spriteSize,
        height: spriteSize,
        showLoadingProgress: true,
        // Beyond ~1.3× the Showdown source starts to blur when smoothed —
        // nearest-neighbor keeps the pixel-art edges crisp instead.
        filterQuality: widget.sizeScale > 1.3
            ? FilterQuality.none
            : FilterQuality.low,
      ),
    );

    // The sticker itself hugs the bottom-right corner; the reserved headroom
    // to the left/top only hosts the bubble and hearts, so height-based
    // resizing never shifts the anchor.
    final stackWidth = math.max(maxSize + 60, 168.0);
    final stackHeight = maxSize + 72;

    return Semantics(
      button: true,
      label: '${AppZh.companionStandbyLabel}：${widget.nameZh}',
      child: SizedBox(
        width: stackWidth,
        height: stackHeight,
        child: Stack(
          alignment: Alignment.bottomRight,
          clipBehavior: Clip.none,
          children: [
            for (final heart in _hearts)
              Positioned(
                right: spriteSize / 2 - heart.size / 2,
                bottom: 0,
                child: _RisingHeart(
                  key: ValueKey(heart.id),
                  particle: heart,
                  riseHeight: spriteSize + 22,
                  onDone: () => _removeHeart(heart.id),
                ),
              ),
            GestureDetector(
              onTap: _onPat,
              onLongPress: _openPicker,
              child: ScaleTransition(
                scale: _bounceScale,
                alignment: Alignment.bottomCenter,
                child: sticker,
              ),
            ),
            if (_shiny)
              Positioned(
                right: spriteSize - 10,
                bottom: spriteSize - 10,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) =>
                      Transform.scale(scale: value, child: child),
                  child: const IgnorePointer(
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: TitoColors.softYellow,
                      shadows: [
                        Shadow(color: TitoColors.ink, blurRadius: 2),
                      ],
                    ),
                  ),
                ),
              ),
            if (_friend)
              Positioned(
                right: -2,
                bottom: spriteSize - 12,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) =>
                      Transform.scale(scale: value, child: child),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: TitoColors.softYellow,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: TitoColors.ink,
                        width: TitoBorders.element,
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      size: 12,
                      color: TitoColors.coral,
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 0,
              bottom: spriteSize + 8,
              child: _QuoteBubble(
                quote: _quoteTemplate == null
                    ? null
                    : formatCompanionQuote(_quoteTemplate!, widget.nameZh),
                maxWidth: stackWidth,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Speech bubble above the companion; fades/scales in per pat.
class _QuoteBubble extends StatelessWidget {
  const _QuoteBubble({required this.quote, required this.maxWidth});

  final String? quote;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final visible = quote != null;
    return IgnorePointer(
      child: AnimatedScale(
        scale: visible ? 1.0 : 0.6,
        // Anchored bottom-right so the bubble pops toward the upper-left,
        // away from the corner-pinned sticker.
        alignment: Alignment.bottomRight,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 160),
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: TitoColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TitoColors.ink, width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0x2818283B), offset: Offset(0, 3)),
              ],
            ),
            child: Text(
              quote ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TitoTypography.style(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: TitoColors.deepBlue,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RisingHeart extends StatelessWidget {
  const _RisingHeart({
    super.key,
    required this.particle,
    required this.riseHeight,
    required this.onDone,
  });

  final _HeartParticle particle;
  final double riseHeight;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOut,
      onEnd: onDone,
      builder: (context, t, child) {
        return Transform.translate(
          offset: Offset(particle.dx * t, -(12 + riseHeight * t)),
          child: Transform.rotate(
            angle: particle.angle * t,
            child: Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: Icon(
                Icons.favorite_rounded,
                size: particle.size,
                color: TitoColors.coral,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom-right home overlay hosting [CompanionStandby]; resolves the chosen
/// companion (Settings) or falls back to the journey starter.
class CompanionStandbyOverlay extends StatelessWidget {
  const CompanionStandbyOverlay({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  Widget build(BuildContext context) {
    final square = DeviceLayout.useSquareDashboard(context);
    final compact = !square && MediaQuery.sizeOf(context).shortestSide < 520;

    return ListenableBuilder(
      listenable: companionRepository,
      builder: (context, _) {
        if (!companionRepository.enabled) {
          return const SizedBox.shrink();
        }
        final choice = companionRepository.choice;
        final speciesId =
            choice?.pokemonId ??
            speciesIdForName(journey.companion) ??
            companionSpeciesIds[hgssDefaultCompanion]!;
        final nameZh =
            choice?.nameZh ?? localizeSpecies(journey.companion);

        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.only(
                right: square ? 8 : (compact ? 6 : 10),
                bottom: DeviceLayout.companionOverlayBottom(context),
              ),
              child: CompanionStandby(
                speciesId: speciesId,
                nameZh: nameZh,
                compact: compact,
                sizeScale: companionRepository.sizeScale,
              ),
            ),
          ),
        );
      },
    );
  }
}

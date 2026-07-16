import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/companion/companion_art.dart';
import '../features/companion/companion_metrics.dart';
import '../features/companion/companion_repository.dart';
import '../features/dex/dex_repository.dart';
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
  });

  final int speciesId;
  final String nameZh;
  final bool compact;

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

  late final AnimationController _bounce;
  late final Animation<double> _bounceScale;
  final _random = math.Random();
  final _hearts = <_HeartParticle>[];
  final _cryPlayer = AudioPlayer();
  late Future<int?> _heightFuture;
  Timer? _quoteTimer;
  String? _quoteTemplate;
  var _cryUrlIndex = 0;
  var _nextHeartId = 0;
  var _pats = 0;

  bool get _friend => _pats >= _friendshipPats;

  @override
  void initState() {
    super.initState();
    _heightFuture = _loadHeight(widget.speciesId);
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
      _heightFuture = _loadHeight(widget.speciesId);
    }
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _cryPlayer.dispose();
    _bounce.dispose();
    super.dispose();
  }

  /// Play the species cry, walking the CDN→GitHub candidate list once and
  /// then sticking with whichever source worked. Silent on total failure —
  /// the pat animation carries the interaction offline.
  Future<void> _playCry() async {
    final candidates = cryCandidatesFor(widget.speciesId);
    for (var i = _cryUrlIndex; i < candidates.length; i++) {
      try {
        await _cryPlayer.stop();
        await _cryPlayer.play(UrlSource(candidates[i]), volume: 0.55);
        _cryUrlIndex = i;
        return;
      } catch (_) {
        // Try the next source.
      }
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
    final becameFriend = _pats + 1 == _friendshipPats;
    _quoteTimer?.cancel();
    _quoteTimer = Timer(_quoteDuration, () {
      if (mounted) {
        setState(() => _quoteTemplate = null);
      }
    });
    final edition = gameEditionRepository.edition;
    setState(() {
      _pats += 1;
      _hearts.add(_HeartParticle(_nextHeartId++, _random));
      _quoteTemplate = becameFriend
          ? companionFriendshipQuote
          : pickCompanionQuote(
              companionQuotePoolFor(
                generation: edition.generation,
                editionSlug: edition.slug,
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
    final scaled = square || widget.compact;
    // Frameless GIF gets more room than the old bordered circle did.
    final minSize = scaled ? DeviceLayout.dim(context, 48.0) : 52.0;
    final maxSize = scaled ? DeviceLayout.dim(context, 104.0) : 116.0;

    return FutureBuilder<int?>(
      future: _heightFuture,
      builder: (context, snapshot) {
        final spriteSize = companionSpriteSizeFor(
          snapshot.data,
          minSize: minSize,
          maxSize: maxSize,
        );
        return _buildSticker(context, spriteSize, maxSize);
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
        sources: animatedSpriteCandidatesFor(widget.speciesId),
        width: spriteSize,
        height: spriteSize,
        showLoadingProgress: true,
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
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../features/companion/companion_art.dart';
import '../features/companion/companion_media.dart';
import '../features/companion/companion_repository.dart';
import '../features/dex/sprite_generation_catalog.dart';
import '../features/journey/ask_titodex_service.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import 'fallback_sprite_image.dart';
import 'sticker_card.dart';

/// A small, asset-light waiting scene. Motion follows the popular fade/slide/
/// bob patterns used by Flutter animation packages, but stays on framework
/// primitives so the assistant does not add a Lottie runtime or JSON assets.
class AskTitoDexLoadingCard extends StatefulWidget {
  const AskTitoDexLoadingCard({
    super.key,
    required this.journey,
    required this.progress,
    required this.requestSeed,
  });

  final CurrentJourney journey;
  final AskTitoDexProgress progress;
  final int requestSeed;

  @override
  State<AskTitoDexLoadingCard> createState() => _AskTitoDexLoadingCardState();
}

class _AskTitoDexLoadingCardState extends State<AskTitoDexLoadingCard>
    with SingleTickerProviderStateMixin {
  static const _localMessageTemplates = <String>[
    '{name}正在树果口袋里翻找线索…',
    '{name}沿着脚印追踪可靠答案…',
    '{name}正在核对版本，免得跑错地图…',
    '{name}把资料卡一张张摆整齐…',
    '{name}对资料页使用了「看破」…',
  ];
  static const _workerMessageTemplates = <String>[
    '{name}正在等洛托姆线路传回消息…',
    '{name}在等 Worker 判断该由索引还是 Qwen 接手…',
    '{name}正在询问 PokeAPI 与审核索引…',
    '{name}正在确认这条提示真的适合当前版本…',
  ];

  late final AnimationController _motion;
  late final List<String> _localMessages;
  late final List<String> _workerMessages;
  Timer? _messageTimer;
  var _messageIndex = 0;
  var _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _localMessages = List<String>.of(_localMessageTemplates)
      ..shuffle(math.Random(widget.requestSeed));
    _workerMessages = List<String>.of(_workerMessageTemplates)
      ..shuffle(math.Random(widget.requestSeed + 1));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion &&
        (_motion.isAnimating || reduceMotion)) {
      return;
    }
    _reduceMotion = reduceMotion;
    _messageTimer?.cancel();
    if (reduceMotion) {
      _motion.stop();
      _motion.value = 0.5;
      return;
    }
    _motion.repeat();
    _messageTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (mounted) {
        setState(() => _messageIndex += 1);
      }
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: companionRepository,
      builder: (context, _) {
        final choice = companionRepository.choice;
        final speciesId =
            choice?.pokemonId ??
            speciesIdForName(widget.journey.companion) ??
            companionSpeciesIds[hgssDefaultCompanion]!;
        final nameZh =
            choice?.nameZh ?? localizeSpecies(widget.journey.companion);
        final messages = widget.progress == AskTitoDexProgress.checkingLocal
            ? _localMessages
            : _workerMessages;
        final message = messages[_messageIndex % messages.length].replaceAll(
          '{name}',
          nameZh,
        );
        final bundled = bundledCompanionGifAsset(speciesId);
        final sources = <String>[
          if (choice?.animationSourceUrl case final source?) source,
          if (bundled != null) bundled,
          ...companionGifDownloadCandidates(speciesId),
          cdnStaticSpriteUrlFor(speciesId),
          defaultSpriteUrlFor(speciesId),
        ];

        return Semantics(
          liveRegion: true,
          label: '$nameZh正在查找答案',
          child: StickerCard(
            key: const Key('ask-titodex-loading-card'),
            variant: StickerVariant.sky,
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 92,
                  child: AnimatedBuilder(
                    animation: _motion,
                    builder: (context, child) {
                      final phase = _motion.value * math.pi * 2;
                      final bob = _reduceMotion ? 0.0 : math.sin(phase) * 4;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size.square(88),
                            painter: _BerryOrbitPainter(
                              progress: _motion.value,
                              still: _reduceMotion,
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(0, bob),
                            child: child,
                          ),
                        ],
                      );
                    },
                    child: FallbackSpriteImage(
                      sources: sources,
                      width: 66,
                      height: 66,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Shimmer.fromColors(
                        enabled: !_reduceMotion,
                        baseColor: TitoColors.deepBlue,
                        highlightColor: TitoColors.card,
                        child: Text(
                          widget.progress == AskTitoDexProgress.checkingLocal
                              ? '先翻本地审核笔记'
                              : '正在连接 Journey Assistant',
                          key: const Key('ask-titodex-loading-stage'),
                          style: SecondaryTypography.onCard.h15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: _reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 260),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.18),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Text(
                          message,
                          key: ValueKey(message),
                          style: SecondaryTypography.onCard.body14.copyWith(
                            color: TitoColors.deepBlue,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.progress == AskTitoDexProgress.checkingLocal
                            ? '这一阶段不会调用在线模型'
                            : '本地未唯一命中；正在请求 Worker',
                        style: SecondaryTypography.onCard.small12.copyWith(
                          color: TitoColors.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BerryOrbitPainter extends CustomPainter {
  const _BerryOrbitPainter({required this.progress, required this.still});

  final double progress;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const colors = [TitoColors.coral, TitoColors.softYellow, TitoColors.mint];
    final orbit = size.shortestSide * 0.42;
    for (var index = 0; index < colors.length; index += 1) {
      final angle =
          (still ? 0.12 : progress) * math.pi * 2 +
          index * math.pi * 2 / colors.length;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * orbit;
      canvas.drawCircle(
        point,
        5.5,
        Paint()
          ..color = TitoColors.ink
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        point,
        3.5,
        Paint()
          ..color = colors[index]
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BerryOrbitPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.still != still;
}

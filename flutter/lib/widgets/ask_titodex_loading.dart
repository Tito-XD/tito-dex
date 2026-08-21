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
import 'assistant_surface.dart';
import 'fallback_sprite_image.dart';

/// Keeps the selected home companion beside the conversation at all times.
/// The orbit, bob, rotating copy and shimmer start only while a request runs.
class AskTitoDexLoadingCard extends StatefulWidget {
  const AskTitoDexLoadingCard({
    super.key,
    required this.journey,
    required this.loading,
    required this.progress,
    required this.requestSeed,
  });

  final CurrentJourney journey;
  final bool loading;
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
    '{name}在等索引或模型接手这道题…',
    '{name}正在询问资料库与联网来源…',
    '{name}正在确认答案真的适合当前版本…',
  ];

  late final AnimationController _motion;
  late List<String> _localMessages;
  late List<String> _workerMessages;
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
    _shuffleMessages();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant AskTitoDexLoadingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestSeed != widget.requestSeed) {
      _messageIndex = 0;
      _shuffleMessages();
    }
    if (oldWidget.loading != widget.loading ||
        oldWidget.requestSeed != widget.requestSeed) {
      _syncMotion();
    }
  }

  void _shuffleMessages() {
    _localMessages = List<String>.of(_localMessageTemplates)
      ..shuffle(math.Random(widget.requestSeed));
    _workerMessages = List<String>.of(_workerMessageTemplates)
      ..shuffle(math.Random(widget.requestSeed + 1));
  }

  void _syncMotion() {
    _messageTimer?.cancel();
    _messageTimer = null;
    if (!widget.loading || _reduceMotion) {
      _motion.stop();
      _motion.value = widget.loading ? 0.12 : 0;
      return;
    }
    _motion.repeat();
    _messageTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (mounted && widget.loading) {
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
          liveRegion: widget.loading,
          label: widget.loading ? '$nameZh正在查找答案' : '$nameZh已准备好',
          child: AssistantSurface(
            key: const Key('ask-titodex-companion-card'),
            color: Color.alphaBlend(
              TitoColors.skyBlue.withValues(alpha: 0.5),
              TitoColors.card,
            ),
            padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
            radius: 18,
            cornerAccent: TitoColors.deepBlue.withValues(alpha: 0.28),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: TitoColors.card.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: TitoColors.deepBlue.withValues(alpha: 0.38),
                      width: 1.25,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F18283B),
                        offset: Offset(0, 3),
                        blurRadius: 7,
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _motion,
                    builder: (context, child) {
                      final phase = _motion.value * math.pi * 2;
                      final bob = widget.loading && !_reduceMotion
                          ? math.sin(phase) * 3
                          : 0.0;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          if (widget.loading)
                            CustomPaint(
                              key: const Key('ask-titodex-loading-card'),
                              size: const Size.square(56),
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
                      width: 46,
                      height: 46,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: _reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    child: widget.loading
                        ? Column(
                            key: const ValueKey('loading'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Shimmer.fromColors(
                                enabled: !_reduceMotion,
                                baseColor: TitoColors.deepBlue,
                                highlightColor: TitoColors.card,
                                child: Text(
                                  widget.progress ==
                                          AskTitoDexProgress.checkingLocal
                                      ? '先翻本地审核笔记'
                                      : '正在连接 Journey Assistant',
                                  key: const Key('ask-titodex-loading-stage'),
                                  style: SecondaryTypography.onCard.h15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              AnimatedSwitcher(
                                duration: _reduceMotion
                                    ? Duration.zero
                                    : const Duration(milliseconds: 260),
                                child: Text(
                                  message,
                                  key: ValueKey(message),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: SecondaryTypography.onCard.small12
                                      .copyWith(
                                        color: TitoColors.deepBlue,
                                        height: 1.25,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 6,
                                child: AnimatedBuilder(
                                  animation: _motion,
                                  builder: (context, _) => CustomPaint(
                                    painter: _CompanionRoutePainter(
                                      progress: _reduceMotion
                                          ? 0.35
                                          : _motion.value,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            key: const ValueKey('idle'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$nameZh在这里陪你',
                                key: const Key('ask-titodex-companion-idle'),
                                style: SecondaryTypography.onCard.h15,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '可以问路线、捕捉地点，也可以问刚开始玩什么最重要。',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: SecondaryTypography.onCard.small12
                                    .copyWith(color: TitoColors.mutedInk),
                              ),
                            ],
                          ),
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
        5,
        Paint()
          ..color = TitoColors.ink
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        point,
        3.2,
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

class _CompanionRoutePainter extends CustomPainter {
  const _CompanionRoutePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = TitoColors.deepBlue.withValues(alpha: 0.18)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const dash = 7.0;
    const gap = 5.0;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, size.width), y),
        line,
      );
    }
    final position = Offset(size.width * progress.clamp(0.0, 1.0), y);
    canvas.drawCircle(position, 3.6, Paint()..color = TitoColors.card);
    canvas.drawCircle(position, 2.6, Paint()..color = TitoColors.coral);
  }

  @override
  bool shouldRepaint(covariant _CompanionRoutePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

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
              TitoColors.skyBlue.withValues(alpha: 0.62),
              const Color(0xFFFFFBF2),
            ),
            padding: const EdgeInsets.fromLTRB(10, 7, 13, 7),
            radius: 18,
            borderColor: TitoColors.deepBlue.withValues(alpha: 0.4),
            child: Row(
              children: [
                SizedBox(
                  width: 66,
                  height: 58,
                  child: AnimatedBuilder(
                    animation: _motion,
                    builder: (context, child) {
                      final phase = _motion.value * math.pi * 2;
                      final bob = widget.loading && !_reduceMotion
                          ? math.sin(phase) * 2.4
                          : 0.0;
                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          if (widget.loading)
                            Positioned.fill(
                              key: const Key('ask-titodex-loading-card'),
                              child: _CompanionSparkleCluster(
                                progress: _reduceMotion ? 0.18 : _motion.value,
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
                      width: 52,
                      height: 52,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
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
                                highlightColor: const Color(0xFFFFFBF2),
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

class _CompanionSparkleCluster extends StatelessWidget {
  const _CompanionSparkleCluster({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final pulse = (0.72 + math.sin(progress * math.pi * 2) * 0.2).clamp(
      0.5,
      1.0,
    );
    final counterPulse = (0.72 + math.cos(progress * math.pi * 2) * 0.2).clamp(
      0.5,
      1.0,
    );
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 2,
            top: 5,
            child: Opacity(
              opacity: pulse,
              child: Transform.scale(
                scale: pulse,
                child: const AssistantSparkle(size: 13),
              ),
            ),
          ),
          Positioned(
            right: 1,
            bottom: 7,
            child: Opacity(
              opacity: counterPulse,
              child: Transform.scale(
                scale: counterPulse,
                child: const AssistantSparkle(size: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

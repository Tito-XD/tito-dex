import 'package:flutter/material.dart';

import '../features/journey/journey_assistant.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'handheld_input.dart';
import 'sticker_card.dart';
import 'sticker_pressable.dart';

class JourneyCard extends StatelessWidget {
  const JourneyCard({
    super.key,
    required this.journey,
    required this.onOpenDetail,
    this.compact = false,
    this.dense = false,
    this.assistantFuture,
  });

  final CurrentJourney journey;
  final VoidCallback? onOpenDetail;
  final bool compact;
  final bool dense;
  final Future<JourneyAssistantSnapshot>? assistantFuture;

  @override
  Widget build(BuildContext context) {
    // Always share the layout's cardPadding so this card's edges line up
    // with the trainer card above it in every density (v0.6.7 fix for the
    // mismatched gutters / squeezed look on square dashboards).
    final padding = DeviceLayout.cardPadding(context);
    final location = localizeLocation(journey.location);
    // Dense shrinks the glyph size only — keep Nunito's natural line height
    // or the stacked meta rows read as squeezed against the card's center.
    TextStyle denseStyle(TextStyle style) =>
        style.copyWith(fontSize: (style.fontSize ?? 14) * 0.85);

    return Semantics(
      button: true,
      label: AppZh.journeyOpenDetail,
      child: HandheldFocusDecorator(
        onActivate: onOpenDetail,
        borderRadius: BorderRadius.circular(DeviceLayout.rLg(context)),
        child: StickerPressable(
          borderRadius: BorderRadius.circular(DeviceLayout.rLg(context)),
          ownShadow: false,
          child: StickerCard(
            variant: StickerVariant.deep,
            padding: padding,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onOpenDetail,
                borderRadius: BorderRadius.circular(DeviceLayout.rLg(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  // The square layout stretches this card to fill the column —
                  // keep the text block vertically centered instead of top-stuck.
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppZh.journeyCardTitle.toUpperCase(),
                                style: dense
                                    ? denseStyle(
                                        context.titoHome.onDeepOverline,
                                      )
                                    : context.titoHome.onDeepOverline,
                              ),
                              SizedBox(height: dense ? 4 : (compact ? 6 : 8)),
                              Text(
                                location,
                                style: dense
                                    ? denseStyle(context.titoHome.onDeepHeading)
                                    : context.titoHome.onDeepHeading,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: TitoColors.card,
                          size: dense
                              ? DeviceLayout.dim(context, 28.0)
                              : (compact ? 28 : 32),
                        ),
                      ],
                    ),
                    SizedBox(height: dense ? 4 : (compact ? 8 : 10)),
                    // Square dashboards only get ~78px for this card — the two
                    // meta columns merge into one row in dense mode so the
                    // badge count and play time survive instead of overflowing.
                    if (dense)
                      _AssistantDenseMeta(
                        journey: journey,
                        future:
                            assistantFuture ??
                            journeyAssistantRepository.loadPreview(journey),
                        style: denseStyle(
                          context.titoHome.onDeepMetaLabel,
                        ).copyWith(fontWeight: FontWeight.w800),
                      )
                    else
                      Row(
                        children: [
                          _Meta(
                            label: AppZh.labelBadges,
                            value: journey.badgeProgressLabel,
                            dense: dense,
                          ),
                          _Meta(
                            label: AppZh.labelPlayTime,
                            value: journey.playTime,
                            dense: dense,
                          ),
                          _AssistantMeta(
                            future:
                                assistantFuture ??
                                journeyAssistantRepository.loadPreview(journey),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantDenseMeta extends StatelessWidget {
  const _AssistantDenseMeta({
    required this.journey,
    required this.future,
    required this.style,
  });

  final CurrentJourney journey;
  final Future<JourneyAssistantSnapshot> future;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<JourneyAssistantSnapshot>(
      future: future,
      builder: (context, snapshot) {
        final assistant = snapshot.data?.cardSummary;
        return Text(
          '${AppZh.labelBadges} ${journey.badgeProgressLabel}'
          ' · ${assistant ?? AppZh.journeyAssistantLoading}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }
}

class _AssistantMeta extends StatelessWidget {
  const _AssistantMeta({required this.future});

  final Future<JourneyAssistantSnapshot> future;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FutureBuilder<JourneyAssistantSnapshot>(
        future: future,
        builder: (context, snapshot) {
          return _MetaContent(
            label: AppZh.journeyAssistantMeta,
            value: snapshot.data?.cardSummary ?? AppZh.journeyAssistantLoading,
          );
        },
      ),
    );
  }
}

class _MetaContent extends StatelessWidget {
  const _MetaContent({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.titoHome.onDeepMetaLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          value,
          style: context.titoHome.onDeepMetaValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value, required this.dense});

  final String label;
  final String value;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    TextStyle denseStyle(TextStyle style) =>
        style.copyWith(fontSize: (style.fontSize ?? 14) * 0.85);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: dense
                ? denseStyle(context.titoHome.onDeepMetaLabel)
                : context.titoHome.onDeepMetaLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            value,
            style: dense
                ? denseStyle(context.titoHome.onDeepMetaValue)
                : context.titoHome.onDeepMetaValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

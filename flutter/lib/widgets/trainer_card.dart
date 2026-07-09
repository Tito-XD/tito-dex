import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'handheld_input.dart';
import 'sticker_card.dart';

class TrainerCard extends StatelessWidget {
  const TrainerCard({
    super.key,
    required this.journey,
    this.compact = false,
    this.dense = false,
    this.micro = false,
    this.onAvatarTap,
  });

  final CurrentJourney journey;
  final bool compact;
  final bool dense;
  final bool micro;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final compactMode = compact || dense;
    final avatarSize = micro ? 56.0 : (dense ? 44.0 : (compact ? 52.0 : 72.0));
    final padding = (compactMode || micro)
        ? DeviceLayout.cardPadding(context)
        : null;

    if (micro) {
      return StickerCard(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: SizedBox(
          height: 104,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TrainerAvatar(
                journey: journey,
                size: avatarSize,
                onTap: onAvatarTap,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      journey.trainerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tito.cardValueLarge.copyWith(height: 1.0),
                    ),
                    Text(
                      localizeGame(journey.game),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tito.captionStrong,
                    ),
                  ],
                ),
              ),
              _BadgeRow(journey: journey, dense: true, micro: true),
            ],
          ),
        ),
      );
    }

    return StickerCard(
      padding: padding ?? const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TrainerAvatar(
            journey: journey,
            size: avatarSize,
            onTap: onAvatarTap,
          ),
          SizedBox(width: dense ? 8 : (compact ? 10 : 14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!dense) ...[
                  Text(
                    AppZh.trainerCard.toUpperCase(),
                    style: context.tito.overline,
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  journey.trainerName,
                  style: context.tito.cardValueLarge.copyWith(height: 1.1),
                ),
                if (!compactMode) ...[
                  const SizedBox(height: 4),
                  Text(AppZh.journeySince2026, style: context.tito.caption),
                ],
                SizedBox(height: dense ? 0 : 2),
                Text(
                  localizeGame(journey.game),
                  style: context.tito.captionStrong,
                ),
                if (!compactMode)
                  Text(
                    '${AppZh.companion} · ${localizeCompanion(journey.companion)}',
                    style: context.tito.caption,
                  ),
                SizedBox(height: dense ? 4 : (compact ? 6 : 10)),
                _BadgeRow(journey: journey, dense: dense, compact: compact),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerAvatar extends StatelessWidget {
  const _TrainerAvatar({
    required this.journey,
    required this.size,
    this.onTap,
  });

  final CurrentJourney journey;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatarPath = journey.trainerAvatarPath;
    final hasImage = avatarPath != null &&
        avatarPath.isNotEmpty &&
        File(avatarPath).existsSync();

    final child = hasImage
        ? ClipOval(
            child: Image.file(
              File(avatarPath),
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          )
        : Text(
            journey.trainerName.isNotEmpty
                ? journey.trainerName[0].toUpperCase()
                : 'T',
            style: TitoTypography.style(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w900,
              color: TitoColors.deepBlue,
            ),
          );

    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: hasImage
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [TitoColors.softYellow, TitoColors.coral],
                    ),
              shape: BoxShape.circle,
              border: Border.all(color: TitoColors.ink, width: 3),
            ),
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({
    required this.journey,
    this.dense = false,
    this.compact = false,
    this.micro = false,
  });

  final CurrentJourney journey;
  final bool dense;
  final bool compact;
  final bool micro;

  @override
  Widget build(BuildContext context) {
    final dot = micro ? 10.0 : (dense ? 10.0 : (compact ? 12.0 : 14.0));
    return Row(
      mainAxisSize: micro ? MainAxisSize.min : MainAxisSize.max,
      children: [
        for (var index = 0; index < journey.maxBadges; index++)
          Container(
            width: dot,
            height: dot,
            margin: EdgeInsets.only(
              right: micro ? 3 : (dense ? 3 : (compact ? 4 : 6)),
            ),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index < journey.badges
                  ? TitoColors.softYellow
                  : TitoColors.skyBlue,
              border: Border.all(color: TitoColors.ink, width: 2),
            ),
          ),
      ],
    );
  }
}

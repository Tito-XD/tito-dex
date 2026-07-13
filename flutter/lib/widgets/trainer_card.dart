import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
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
    final baseAvatarSize = micro
        ? DeviceLayout.trainerMicroAvatarSize(context)
        : (dense
            ? DeviceLayout.trainerDenseAvatarSize(context)
            : (compact ? 52.0 : 72.0));
    final avatarSize =
        (micro || dense) ? baseAvatarSize * 1.2 : baseAvatarSize;
    final padding = (compactMode || micro)
        ? DeviceLayout.cardPadding(context)
        : null;
    final greetingStyle = micro
        ? context.tito.cardValueLarge.copyWith(height: 1.0)
        : context.tito.cardValueLarge.copyWith(height: 1.1);

    if (micro) {
      return StickerCard(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: SizedBox(
          height: DeviceLayout.trainerMicroCardHeight(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TrainerAvatar(journey: journey, size: avatarSize),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppZh.trainerGreeting(journey.trainerName),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: greetingStyle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _BadgeGrid(journey: journey, micro: true),
                ),
              ),
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
          _TrainerAvatar(journey: journey, size: avatarSize),
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
                  AppZh.trainerGreeting(journey.trainerName),
                  style: greetingStyle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.topRight,
              child: _BadgeGrid(
                journey: journey,
                dense: dense,
                compact: compact,
              ),
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
  });

  final CurrentJourney journey;
  final double size;

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

    return Container(
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
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({
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
    final dot = micro
        ? DeviceLayout.dim(context, 9.0)
        : (dense
            ? DeviceLayout.dim(context, 10.0)
            : (compact ? DeviceLayout.dim(context, 12.0) : 14.0));
    final gap = micro ? 3.0 : (dense ? 3.0 : 4.0);
    final rowGap = micro ? 2.0 : 3.0;
    const perRow = 4;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var row = 0; row < (journey.maxBadges / perRow).ceil(); row++) ...[
          if (row > 0) SizedBox(height: rowGap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var col = 0; col < perRow; col++) ...[
                if (col > 0) SizedBox(width: gap),
                _BadgeDot(
                  index: row * perRow + col,
                  journey: journey,
                  size: dot,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _BadgeDot extends StatelessWidget {
  const _BadgeDot({
    required this.index,
    required this.journey,
    required this.size,
  });

  final int index;
  final CurrentJourney journey;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (index >= journey.maxBadges) {
      return SizedBox(width: size, height: size);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: index < journey.badges
            ? TitoColors.softYellow
            : TitoColors.skyBlue,
        border: Border.all(color: TitoColors.ink, width: 2),
      ),
    );
  }
}

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
        micro ? baseAvatarSize * 1.2 : (dense ? baseAvatarSize : baseAvatarSize);
    final padding = (compactMode || micro)
        ? DeviceLayout.cardPadding(context)
        : null;
    final greetingStyle = micro
        ? context.tito.cardValueLarge.copyWith(height: 1.0)
        : context.tito.cardValueLarge.copyWith(height: 1.1);
    final nameStyle = greetingStyle.copyWith(fontWeight: FontWeight.w900);

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
              Expanded(child: _GreetingBlock(greetingStyle: greetingStyle, nameStyle: nameStyle, journey: journey)),
            ],
          ),
        ),
      );
    }

    final cardMinHeight = dense ? DeviceLayout.trainerDenseCardHeight(context) : null;

    return StickerCard(
      padding: padding ?? const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: cardMinHeight ?? 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _TrainerAvatar(journey: journey, size: avatarSize),
            SizedBox(width: dense ? 12 : (compact ? 10 : 14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!dense) ...[
                    Text(
                      AppZh.trainerCard.toUpperCase(),
                      style: context.tito.overline,
                    ),
                    const SizedBox(height: 2),
                  ],
                  _GreetingBlock(
                    greetingStyle: greetingStyle,
                    nameStyle: nameStyle,
                    journey: journey,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GreetingBlock extends StatelessWidget {
  const _GreetingBlock({
    required this.greetingStyle,
    required this.nameStyle,
    required this.journey,
  });

  final TextStyle greetingStyle;
  final TextStyle nameStyle;
  final CurrentJourney journey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppZh.timeGreeting(DateTime.now()),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: greetingStyle,
        ),
        const SizedBox(height: 2),
        Text(
          journey.trainerName.isNotEmpty ? journey.trainerName : 'Tito',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: nameStyle,
        ),
      ],
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

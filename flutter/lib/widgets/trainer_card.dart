import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'sticker_card.dart';

/// Shared [Hero] tags for bootstrap → home trainer card continuity.
abstract final class TrainerCardHero {
  static const avatar = 'trainer-card-avatar';
  static const greeting = 'trainer-card-greeting';
  static const name = 'trainer-card-name';
}

enum TrainerCardDensity { standard, dense, micro }

class TrainerCard extends StatelessWidget {
  const TrainerCard({
    super.key,
    required this.journey,
    this.compact = false,
    this.dense = false,
    this.micro = false,
    this.onAvatarTap,
    this.useHero = false,
    this.avatarPlaceholder = false,
  });

  final CurrentJourney journey;
  final bool compact;
  final bool dense;
  final bool micro;
  final VoidCallback? onAvatarTap;
  final bool useHero;
  final bool avatarPlaceholder;

  TrainerCardDensity get _density {
    if (micro) return TrainerCardDensity.micro;
    if (dense || compact) return TrainerCardDensity.dense;
    return TrainerCardDensity.standard;
  }

  @override
  Widget build(BuildContext context) {
    final density = _density;
    final metrics = _TrainerCardMetrics.forDensity(context, density);
    final padding = density == TrainerCardDensity.standard
        ? const EdgeInsets.all(16)
        : DeviceLayout.cardPadding(context);

    return StickerCard(
      padding: padding,
      child: SizedBox(
        height: metrics.cardHeight,
        child: _TrainerCardBody(
          journey: journey,
          metrics: metrics,
          useHero: useHero,
          avatarPlaceholder: avatarPlaceholder,
          onAvatarTap: onAvatarTap,
        ),
      ),
    );
  }
}

@immutable
class _TrainerCardMetrics {
  const _TrainerCardMetrics({
    required this.cardHeight,
    required this.rowCount,
    required this.avatarSpanRows,
    required this.gutter,
    required this.textGap,
    required this.greetingFontSize,
    required this.nameFontSize,
  });

  final double cardHeight;
  final int rowCount;
  final int avatarSpanRows;
  final double gutter;
  final double textGap;
  final double greetingFontSize;
  final double nameFontSize;

  double get rowUnit => cardHeight / rowCount;

  double get avatarSize => rowUnit * avatarSpanRows;

  static _TrainerCardMetrics forDensity(
    BuildContext context,
    TrainerCardDensity density,
  ) {
    return switch (density) {
      TrainerCardDensity.micro => _TrainerCardMetrics(
          cardHeight: DeviceLayout.trainerMicroCardHeight(context),
          rowCount: 3,
          avatarSpanRows: 2,
          gutter: DeviceLayout.dim(context, 8),
          textGap: DeviceLayout.dim(context, 4),
          greetingFontSize: DeviceLayout.dim(context, 15),
          nameFontSize: DeviceLayout.dim(context, 14),
        ),
      TrainerCardDensity.dense => _TrainerCardMetrics(
          cardHeight: DeviceLayout.trainerDenseCardHeight(context),
          rowCount: 5,
          avatarSpanRows: 3,
          gutter: DeviceLayout.dim(context, 12),
          textGap: DeviceLayout.dim(context, 8),
          greetingFontSize: DeviceLayout.dim(context, 22),
          nameFontSize: DeviceLayout.dim(context, 18),
        ),
      TrainerCardDensity.standard => _TrainerCardMetrics(
          cardHeight: DeviceLayout.trainerDenseCardHeight(context) +
              DeviceLayout.dim(context, 16),
          rowCount: 5,
          avatarSpanRows: 3,
          gutter: DeviceLayout.dim(context, 14),
          textGap: DeviceLayout.dim(context, 10),
          greetingFontSize: DeviceLayout.dim(context, 24),
          nameFontSize: DeviceLayout.dim(context, 20),
        ),
    };
  }
}

class _TrainerCardBody extends StatelessWidget {
  const _TrainerCardBody({
    required this.journey,
    required this.metrics,
    required this.useHero,
    required this.avatarPlaceholder,
    this.onAvatarTap,
  });

  final CurrentJourney journey;
  final _TrainerCardMetrics metrics;
  final bool useHero;
  final bool avatarPlaceholder;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final rowUnit = metrics.rowUnit;
    final topPad = rowUnit;
    final contentHeight = metrics.avatarSize;
    final bottomPad =
        rowUnit * (metrics.rowCount - metrics.avatarSpanRows - 1);

    final greetingStyle = TitoTypography.style(
      fontSize: metrics.greetingFontSize,
      fontWeight: FontWeight.w800,
      height: 1.05,
    );
    final nameStyle = TitoTypography.style(
      fontSize: metrics.nameFontSize,
      fontWeight: FontWeight.w900,
      height: 1.05,
    );

    final trainerName =
        journey.trainerName.isNotEmpty ? journey.trainerName : 'Tito';

    Widget avatar = _TrainerAvatar(
      journey: journey,
      size: metrics.avatarSize,
      placeholder: avatarPlaceholder,
    );
    if (useHero) {
      avatar = Hero(tag: TrainerCardHero.avatar, child: avatar);
    }

    Widget greeting = Text(
      AppZh.timeGreeting(DateTime.now()),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: greetingStyle,
    );
    if (useHero) {
      greeting = Hero(tag: TrainerCardHero.greeting, child: greeting);
    }

    Widget nameLine = Text(
      AppZh.trainerNameLine(trainerName),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: nameStyle,
    );
    if (useHero) {
      nameLine = Hero(tag: TrainerCardHero.name, child: nameLine);
    }

    final textColumn = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        greeting,
        SizedBox(height: metrics.textGap),
        nameLine,
      ],
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        avatar,
        SizedBox(width: metrics.gutter),
        Expanded(child: textColumn),
      ],
    );

    final content = SizedBox(
      height: contentHeight,
      child: row,
    );

    final body = Column(
      children: [
        SizedBox(height: topPad),
        content,
        if (bottomPad > 0) SizedBox(height: bottomPad),
      ],
    );

    if (onAvatarTap != null) {
      return GestureDetector(
        onTap: onAvatarTap,
        behavior: HitTestBehavior.opaque,
        child: body,
      );
    }

    return body;
  }
}

class _TrainerAvatar extends StatelessWidget {
  const _TrainerAvatar({
    required this.journey,
    required this.size,
    this.placeholder = false,
  });

  final CurrentJourney journey;
  final double size;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    if (placeholder) {
      return _avatarContainer(
        child: Icon(
          Icons.person_rounded,
          size: size * 0.45,
          color: TitoColors.mutedInk,
        ),
        hasImage: false,
      );
    }

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

    return _avatarContainer(child: child, hasImage: hasImage);
  }

  Widget _avatarContainer({required Widget child, required bool hasImage}) {
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

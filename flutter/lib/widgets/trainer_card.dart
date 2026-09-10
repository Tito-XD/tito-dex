import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/app_visual_style.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import '../theme/trainer_journal.dart';
import 'sticker_card.dart';

enum TrainerCardDensity { standard, dense, micro }

class TrainerCard extends StatelessWidget {
  const TrainerCard({
    super.key,
    required this.journey,
    this.compact = false,
    this.dense = false,
    this.micro = false,
    this.onAvatarTap,
    this.avatarPlaceholder = false,
    this.stacked = false,
  });

  final CurrentJourney journey;
  final bool compact;
  final bool dense;
  final bool micro;
  final VoidCallback? onAvatarTap;
  final bool avatarPlaceholder;

  /// Square-dashboard solo layout: avatar / greeting / name stack in three
  /// centered rows instead of the side-by-side row — visually balances the
  /// left column when there is no journey card below (no linked save).
  final bool stacked;

  TrainerCardDensity get _density {
    if (micro) return TrainerCardDensity.micro;
    if (dense || compact) return TrainerCardDensity.dense;
    return TrainerCardDensity.standard;
  }

  @override
  Widget build(BuildContext context) {
    // Square dashboards keep the micro card height so the Journey card below
    // still fits, but the micro content itself is intentionally larger: the
    // old avatar/type left most of the card visually empty on the RG panel.
    final density = DeviceLayout.useSquareDashboard(context)
        ? TrainerCardDensity.micro
        : _density;
    final metrics = _TrainerCardMetrics.forDensity(context, density);
    final padding = density == TrainerCardDensity.standard
        ? const EdgeInsets.all(16)
        : DeviceLayout.cardPadding(context);

    final body = _TrainerCardBody(
      journey: journey,
      metrics: metrics,
      avatarPlaceholder: avatarPlaceholder,
      onAvatarTap: onAvatarTap,
    );
    final card = StickerCard(
      padding: padding,
      child: appVisualStyle.usesTrainerJournal
          ? body
          : SizedBox(height: metrics.cardHeight, child: body),
    );
    if (!appVisualStyle.usesTrainerJournal) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        const Positioned(top: -7, right: 28, child: JournalTape()),
      ],
    );
  }
}

@immutable
class _TrainerCardMetrics {
  const _TrainerCardMetrics({
    required this.cardHeight,
    required this.avatarSize,
    required this.gutter,
    required this.textGap,
    required this.greetingFontSize,
    required this.nameFontSize,
  });

  final double cardHeight;
  final double avatarSize;
  final double gutter;
  final double textGap;
  final double greetingFontSize;
  final double nameFontSize;

  static _TrainerCardMetrics forDensity(
    BuildContext context,
    TrainerCardDensity density,
  ) {
    return switch (density) {
      TrainerCardDensity.micro => _TrainerCardMetrics(
        cardHeight: DeviceLayout.trainerMicroCardHeight(context),
        avatarSize: DeviceLayout.trainerMicroAvatarSize(context),
        gutter: DeviceLayout.dim(context, 12),
        textGap: DeviceLayout.dim(context, 5),
        greetingFontSize: DeviceLayout.dim(context, 20),
        nameFontSize: DeviceLayout.dim(context, 18),
      ),
      TrainerCardDensity.dense => _TrainerCardMetrics(
        cardHeight: DeviceLayout.useSquareDashboard(context)
            ? DeviceLayout.trainerSquareCardHeight(context)
            : DeviceLayout.trainerDenseCardHeight(context),
        avatarSize: DeviceLayout.trainerDenseAvatarSize(context),
        gutter: DeviceLayout.dim(context, 12),
        textGap: DeviceLayout.dim(context, 8),
        greetingFontSize: DeviceLayout.dim(context, 33),
        nameFontSize: DeviceLayout.dim(context, 27),
      ),
      TrainerCardDensity.standard => _TrainerCardMetrics(
        cardHeight:
            DeviceLayout.trainerDenseCardHeight(context) +
            DeviceLayout.dim(context, 16),
        avatarSize: DeviceLayout.trainerDenseAvatarSize(context),
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
    required this.avatarPlaceholder,
    this.onAvatarTap,
  });

  final CurrentJourney journey;
  final _TrainerCardMetrics metrics;
  final bool avatarPlaceholder;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    // The trainer card is the dashboard hero: it keeps the home card styles
    // (family, ink, weight) but at the density metrics above, which are
    // already device-scaled through `DeviceLayout.dim` — no home token is
    // this large.
    final greetingStyle = context.titoHome.cardSectionTitle.copyWith(
      fontSize: metrics.greetingFontSize,
      fontWeight: TrainerJournal.weight(FontWeight.w800),
      height: 1.05,
    );
    final nameStyle = context.titoHome.cardTitle.copyWith(
      fontSize: metrics.nameFontSize,
      fontWeight: TrainerJournal.weight(FontWeight.w900),
      height: 1.05,
    );

    final trainerName = journey.trainerName.isNotEmpty
        ? journey.trainerName
        : 'Tito';

    final avatar = TrainerAvatar(
      journey: journey,
      size: metrics.avatarSize,
      placeholder: avatarPlaceholder,
    );
    final greeting = Text(
      AppZh.timeGreeting(DateTime.now()),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: greetingStyle,
    );
    final nameLine = Text(
      AppZh.trainerNameLine(trainerName),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: nameStyle,
    );
    final textColumn = Column(
      mainAxisSize: appVisualStyle.usesTrainerJournal
          ? MainAxisSize.min
          : MainAxisSize.max,
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

    // Keep the normal card height and existing font sizes. Large accessibility
    // text may grow the Journal card; long names ellipsize within the row.
    final Widget body = appVisualStyle.usesTrainerJournal
        ? ConstrainedBox(
            constraints: BoxConstraints(minHeight: metrics.cardHeight),
            child: Center(heightFactor: 1, child: row),
          )
        : SizedBox(
            height: metrics.cardHeight,
            child: Center(
              child: SizedBox(height: metrics.avatarSize, child: row),
            ),
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

class TrainerAvatar extends StatelessWidget {
  const TrainerAvatar({
    super.key,
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
        context,
        child: Icon(
          Icons.person_rounded,
          size: size * 0.45,
          color: TitoColors.mutedInk,
        ),
        hasImage: false,
      );
    }

    final avatarPath = journey.trainerAvatarPath;
    final hasImage =
        avatarPath != null &&
        avatarPath.isNotEmpty &&
        File(avatarPath).existsSync();

    final child = hasImage
        ? (appVisualStyle.usesTrainerJournal
              ? Image.file(
                  File(avatarPath),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                )
              : ClipOval(
                  child: Image.file(
                    File(avatarPath),
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  ),
                ))
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

    return _avatarContainer(context, child: child, hasImage: hasImage);
  }

  Widget _avatarContainer(
    BuildContext context, {
    required Widget child,
    required bool hasImage,
  }) {
    if (appVisualStyle.usesTrainerJournal) {
      return JournalPhotoFrame(size: size, child: child);
    }
    final BoxBorder? border;
    if (appVisualStyle.usesFlatUi) {
      border = null;
    } else if (appVisualStyle.usesSolidPlastic) {
      border = Border.all(
        color: Colors.white.withValues(alpha: 0.78),
        width: TitoBorders.glass,
      );
    } else {
      border = Border.all(color: TitoColors.ink, width: TitoBorders.element);
    }
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
        border: border,
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

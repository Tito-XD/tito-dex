import 'package:flutter/material.dart';

import '../l10n/app_zh.dart';
import '../theme/error_text.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_typography.dart';
import 'sticker_card.dart';

/// The one "something failed" layout: bold title, muted detail, and a
/// refresh-icon retry button on the leading edge.
///
/// [framed] wraps it in the cream [StickerCard]; pass `false` when the host
/// already draws a card (battle result card, bottom sheet).
class TitoErrorPanel extends StatelessWidget {
  const TitoErrorPanel({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.retryLabel,
    this.framed = true,
  });

  /// Maps [error] to user-facing copy; never shows the raw exception.
  factory TitoErrorPanel.fromError(
    Object error, {
    Key? key,
    VoidCallback? onRetry,
    bool framed = true,
  }) {
    final (title, message) = splitUserFacingError(error);
    return TitoErrorPanel(
      key: key,
      title: title,
      message: message,
      onRetry: onRetry,
      framed: framed,
    );
  }

  /// Defaults to [AppZh.dexLoadFailed]. Set to the specific failure when
  /// [message] alone would read as a fragment.
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final detail = message;
    final body = Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title ?? AppZh.dexLoadFailed,
            style: SecondaryTypography.onCard.body14.copyWith(
              fontWeight: TitoTypography.weight(FontWeight.w800),
            ),
          ),
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              detail,
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoTypography.mutedColor,
                height: 1.45,
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('tito-error-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(retryLabel ?? AppZh.retry),
            ),
          ],
        ],
      ),
    );
    if (!framed) return body;
    return StickerCard(
      child: SizedBox(width: double.infinity, child: body),
    );
  }
}

/// The one "nothing here" layout: a muted line, optionally with a leading
/// icon and an action. Use inside lists, sheets and result cards.
class TitoEmptyState extends StatelessWidget {
  const TitoEmptyState({
    super.key,
    required this.message,
    this.icon,
    this.action,
    this.framed = true,
    this.centered = false,
  });

  final String message;
  final IconData? icon;

  /// Usually a TextButton or OutlinedButton that resolves the emptiness.
  final Widget? action;
  final bool framed;

  /// Centre in the available space (empty sheet or grid).
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final muted = TitoTypography.mutedColor;
    final text = Text(
      message,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: SecondaryTypography.onCard.body14.copyWith(
        color: muted,
        fontWeight: TitoTypography.weight(FontWeight.w700),
        height: 1.4,
      ),
    );
    Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 28, color: muted),
          const SizedBox(height: 8),
        ],
        text,
        if (action != null) ...[const SizedBox(height: 8), action!],
      ],
    );
    if (framed) {
      body = StickerCard(
        child: SizedBox(width: double.infinity, child: body),
      );
    }
    return centered ? Center(child: body) : body;
  }
}

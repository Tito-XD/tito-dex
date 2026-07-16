import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/game/game_catalog.dart';
import '../features/game/game_edition.dart';
import '../features/game/game_edition_repository.dart';
import '../l10n/app_zh.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'handheld_input.dart';
import 'handheld_status_icons.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.gameBadge = 'HGSS',
    this.showSettings = true,
    this.onGameBadgeTap,
    this.trainerName,
  });

  final String gameBadge;
  final bool showSettings;
  final VoidCallback? onGameBadgeTap;
  final String? trainerName;

  @override
  Widget build(BuildContext context) {
    final compact = DeviceLayout.isCompact(context);
    final square = DeviceLayout.useSquareDashboard(context);
    final barHeight = DeviceLayout.headerBarHeight(context);

    return Padding(
      padding: EdgeInsets.only(bottom: square ? 4 : (compact ? 8 : 16)),
      child: SizedBox(
        height: barHeight,
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppZh.displayTitleForTrainer(trainerName ?? ''),
                  style: context.tito.pageTitleOnGradient.copyWith(
                    fontSize: DeviceLayout.headerTitleSize(context),
                    letterSpacing: -0.5,
                    shadows: const [
                      Shadow(
                        color: Color(0x4018283B),
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _GameBadgeButton(
              edition: gameEditionRepository.edition,
              semanticLabel: gameBadge,
              onTap: onGameBadgeTap,
            ),
            if (DeviceLayout.useHandheldChrome(context)) ...[
              SizedBox(width: square ? 8 : 10),
              HandheldStatusIcons(compact: square || compact),
            ],
            if (showSettings) ...[
              SizedBox(width: square ? 6 : 8),
              _HeaderIconButton(
                icon: Icons.settings_rounded,
                onTap: () => context.push('/settings'),
                label: AppZh.navSettings,
                compact: compact,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Home game switcher — the current edition's icon in the same circular
/// frame and size as the settings button. Square HOME icons are clipped to
/// the circle (BoxFit.cover crops the corners); pre-Gen-VI editions show
/// the version-tinted letter code instead.
class _GameBadgeButton extends StatelessWidget {
  const _GameBadgeButton({
    required this.edition,
    required this.semanticLabel,
    this.onTap,
  });

  final GameEdition edition;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final size = DeviceLayout.headerIconSize(context);
    final asset = edition.iconAsset;
    final accent = edition.accentColor;
    final darkAccent = accent.computeLuminance() < 0.4;

    final content = asset != null
        ? Image.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _letterContent(size, accent, darkAccent),
          )
        : _letterContent(size, accent, darkAccent);

    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Semantics(
        button: onTap != null,
        label: '$semanticLabel · ${edition.labelZh}',
        child: Material(
          color: asset != null ? TitoColors.card : accent,
          shape: const CircleBorder(
            side: BorderSide(color: TitoColors.ink, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(width: size, height: size, child: content),
          ),
        ),
      ),
    );
  }

  Widget _letterContent(double size, Color accent, bool darkAccent) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.12),
          child: Text(
            gameEditionShortCode(edition),
            style: TitoTypography.style(
              fontSize: size * 0.30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: darkAccent ? TitoColors.card : TitoColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = DeviceLayout.headerIconSize(context);
    final iconSize = size * 0.55;

    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: TitoColors.card,
          shape: const CircleBorder(
            side: BorderSide(color: TitoColors.ink, width: 2),
          ),
          elevation: 0,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                color: TitoColors.deepBlue,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

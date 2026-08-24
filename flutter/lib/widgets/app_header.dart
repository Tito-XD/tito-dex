import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/game/game_catalog.dart';
import '../features/game/game_edition.dart';
import '../features/game/game_edition_repository.dart';
import '../l10n/app_zh.dart';
import '../theme/app_visual_style.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'handheld_input.dart';
import 'handheld_status_icons.dart';
import 'liquid_glass.dart';

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
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: square ? 2 : (compact ? 4 : 8)),
      child: SizedBox(
        height: barHeight,
        child: Material(
          color: appVisualStyle.usesFlatUi
              ? scheme.surface
              : Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppZh.displayTitleForTrainer(trainerName ?? ''),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: appVisualStyle.usesFlatUi
                          ? scheme.onSurface
                          : TitoColors.card,
                      fontSize: DeviceLayout.headerTitleSize(context),
                      letterSpacing: -0.3,
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
                ),
              ],
            ],
          ),
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
    final scheme = Theme.of(context).colorScheme;

    final content = asset != null
        ? Padding(
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: Image.asset(
                asset,
                width: size - 6,
                height: size - 6,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _letterContent(size, accent, darkAccent),
              ),
            ),
          )
        : _letterContent(size, accent, darkAccent);

    if (appVisualStyle.usesSolidPlastic) {
      return LiquidGlassRoundButton(
        size: size,
        semanticLabel: '$semanticLabel · ${edition.labelZh}',
        onTap: onTap,
        tint: asset != null ? TitoColors.card : accent,
        opacity: asset != null ? 0.92 : 0.95,
        child: content,
      );
    }

    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Semantics(
        button: onTap != null,
        label: '$semanticLabel · ${edition.labelZh}',
        child: Material(
          color: asset != null
              ? (appVisualStyle.usesFlatUi
                    ? scheme.primaryContainer
                    : TitoColors.card)
              : accent,
          shape: CircleBorder(
            side: appVisualStyle.usesFlatUi
                ? BorderSide.none
                : const BorderSide(color: TitoColors.ink, width: 2),
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
  });

  final IconData icon;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final size = DeviceLayout.headerIconSize(context);
    final iconSize = size * 0.62;
    final scheme = Theme.of(context).colorScheme;

    if (appVisualStyle.usesSolidPlastic) {
      return LiquidGlassRoundButton(
        size: size,
        semanticLabel: label,
        onTap: onTap,
        child: Icon(icon, color: TitoColors.deepBlue, size: iconSize),
      );
    }

    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: IconButton(
        tooltip: label,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: size, height: size),
        style: IconButton.styleFrom(
          backgroundColor: appVisualStyle.usesFlatUi
              ? scheme.secondaryContainer
              : TitoColors.card,
          foregroundColor: appVisualStyle.usesFlatUi
              ? scheme.onSecondaryContainer
              : TitoColors.deepBlue,
          side: appVisualStyle.usesFlatUi
              ? BorderSide.none
              : const BorderSide(color: TitoColors.ink, width: 2),
          shape: const CircleBorder(),
        ),
        icon: Icon(icon, size: iconSize),
      ),
    );
  }
}

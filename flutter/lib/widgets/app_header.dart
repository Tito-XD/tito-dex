import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_zh.dart';
import '../theme/device_layout.dart';
import '../theme/tito_buttons.dart';
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
  });

  final String gameBadge;
  final bool showSettings;
  final VoidCallback? onGameBadgeTap;

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
                  AppZh.appTitle,
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
            TitoBadgePill(
              label: gameBadge,
              tone: TitoBadgeTone.yellow,
              compact: compact,
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

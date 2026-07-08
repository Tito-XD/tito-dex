import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_zh.dart';
import '../theme/device_layout.dart';
import '../theme/tito_buttons.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'handheld_status_icons.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.gameBadge = 'HGSS',
    this.showSettings = true,
  });

  final String gameBadge;
  final bool showSettings;

  @override
  Widget build(BuildContext context) {
    final compact = DeviceLayout.isCompact(context);
    final square = DeviceLayout.useSquareDashboard(context);
    final iconSize = DeviceLayout.appTitleIconSize(context);

    return Padding(
      padding: EdgeInsets.only(bottom: square ? 4 : (compact ? 8 : 16)),
      child: Row(
        children: [
          Icon(
            Icons.pets_rounded,
            color: TitoColors.softYellow,
            size: iconSize,
          ),
          SizedBox(width: square ? 6 : 8),
          Expanded(
            child: Text(
              AppZh.appTitle,
              style: context.tito.pageTitleOnGradient.copyWith(
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
          if (!square)
            TitoBadgePill(
              label: gameBadge,
              tone: TitoBadgeTone.yellow,
              compact: compact,
            ),
          if (DeviceLayout.isNativeTarget) ...[
            SizedBox(width: square ? 4 : 8),
            HandheldStatusIcons(compact: compact),
          ],
          if (showSettings) ...[
            SizedBox(width: square ? 4 : 8),
            _HeaderIconButton(
              icon: Icons.settings_rounded,
              onTap: () => context.push('/settings'),
              label: AppZh.navSettings,
              compact: compact,
            ),
          ],
        ],
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
    final square = DeviceLayout.useSquareDashboard(context);
    final size = square ? 28.0 : (compact ? 34.0 : 40.0);
    final iconSize = square ? 16.0 : (compact ? 18.0 : 22.0);

    return Semantics(
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
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_zh.dart';
import '../theme/device_layout.dart';
import '../theme/tito_buttons.dart';
import '../theme/tito_colors.dart';

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
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 16),
      child: Row(
        children: [
          Icon(
            Icons.pets_rounded,
            color: TitoColors.softYellow,
            size: compact ? 26 : 32,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppZh.appTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: TitoColors.card,
                    fontSize: compact ? 22 : null,
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
          TitoBadgePill(label: gameBadge, tone: TitoBadgeTone.yellow),
          if (showSettings) ...[
            const SizedBox(width: 8),
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
            width: compact ? 34 : 40,
            height: compact ? 34 : 40,
            child: Icon(
              icon,
              color: TitoColors.deepBlue,
              size: compact ? 18 : 22,
            ),
          ),
        ),
      ),
    );
  }
}

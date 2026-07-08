import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_zh.dart';
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          const Icon(
            Icons.pets_rounded,
            color: TitoColors.softYellow,
            size: 32,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppZh.appTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: TitoColors.card,
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
  });

  final IconData icon;
  final VoidCallback onTap;
  final String label;

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
            width: 40,
            height: 40,
            child: Icon(icon, color: TitoColors.deepBlue, size: 22),
          ),
        ),
      ),
    );
  }
}

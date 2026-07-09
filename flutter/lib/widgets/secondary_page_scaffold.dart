import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_zh.dart';
import '../navigation/back_navigation.dart';
import '../theme/device_layout.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'handheld_input.dart';

/// Standard shell for N3 secondary routes with shared top navigation.
class SecondaryPageScaffold extends StatelessWidget {
  const SecondaryPageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.showSettings = true,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showSettings;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: (padding ?? DeviceLayout.pagePadding(context)).copyWith(
        bottom: 96,
      ),
      children: [
        SecondaryPageAppBar(title: title, showSettings: showSettings),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: context.tito.pageSubtitleOnGradient),
        ],
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

/// Shared header row: "← Title" with optional settings action.
class SecondaryPageAppBar extends StatelessWidget {
  const SecondaryPageAppBar({
    super.key,
    required this.title,
    this.showSettings = true,
  });

  final String title;
  final bool showSettings;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final canOpenSettings = showSettings && path != '/settings';
    final backIconSize = DeviceLayout.backIconSize(context);

    return Row(
      children: [
        Expanded(
          child: _BackTitleButton(
            title: title,
            onTap: () => _handleBack(context, path),
            iconSize: backIconSize,
          ),
        ),
        if (canOpenSettings) ...[
          SizedBox(width: DeviceLayout.useSquareDashboard(context) ? 10 : 8),
          _SecondaryHeaderIconButton(
            icon: Icons.settings_rounded,
            label: AppZh.navSettings,
            onTap: () => context.push('/settings'),
          ),
        ],
      ],
    );
  }

  void _handleBack(BuildContext context, String path) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
      return;
    }
    TitoBackNavigation.navigateBack(context, path);
  }
}

class _BackTitleButton extends StatelessWidget {
  const _BackTitleButton({
    required this.title,
    required this.onTap,
    required this.iconSize,
  });

  final String title;
  final VoidCallback onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final radius = DeviceLayout.rMd(context);
    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Semantics(
        button: true,
        label: '$title · ${AppZh.navHome}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_back_rounded,
                    color: TitoColors.card,
                    size: iconSize,
                  ),
                  SizedBox(width: iconSize * 0.15),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SecondaryTypography.onGradient.title.copyWith(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryHeaderIconButton extends StatelessWidget {
  const _SecondaryHeaderIconButton({
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
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: TitoColors.deepBlue, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }
}

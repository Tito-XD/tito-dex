import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_zh.dart';
import '../navigation/back_navigation.dart';
import '../theme/device_layout.dart';
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

    return Row(
      children: [
        Expanded(
          child: _BackTitleButton(
            title: title,
            onTap: () => _handleBack(context, path),
          ),
        ),
        if (canOpenSettings) ...[
          const SizedBox(width: 8),
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
  const _BackTitleButton({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: BorderRadius.circular(TitoRadii.md),
      child: Semantics(
        button: true,
        label: '$title · ${AppZh.navHome}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(TitoRadii.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_back_rounded,
                    color: TitoColors.card,
                    size: 24,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
    final compact = DeviceLayout.isCompact(context);
    final square = DeviceLayout.useSquareDashboard(context);
    final size = square ? 28.0 : (compact ? 34.0 : 40.0);
    final iconSize = square ? 16.0 : (compact ? 18.0 : 22.0);

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

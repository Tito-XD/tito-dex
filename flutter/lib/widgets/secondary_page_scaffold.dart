import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_zh.dart';
import '../navigation/back_navigation.dart';
import '../theme/device_layout.dart';
import '../theme/secondary_typography.dart';
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
    final pagePadding = padding ?? DeviceLayout.pagePadding(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            pagePadding.left,
            pagePadding.top,
            pagePadding.right,
            0,
          ),
          child: SecondaryPageAppBar(title: title, showSettings: showSettings),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              pagePadding.left,
              subtitle == null ? 12 : 6,
              pagePadding.right,
              96,
            ),
            children: [
              if (subtitle != null) ...[
                SecondaryPageSubtitle(text: subtitle!),
                const SizedBox(height: 12),
              ],
              ...children,
            ],
          ),
        ),
      ],
    );
  }
}

/// Material on-surface subtitle shared by secondary pages.
class SecondaryPageSubtitle extends StatelessWidget {
  const SecondaryPageSubtitle({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: SecondaryTypography.onCard.body14.copyWith(
        color: scheme.onSurfaceVariant,
      ),
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
    // Every page using this scaffold must be a GoRouter route: GoRouterState.of
    // throws for a page pushed with a bare Navigator.push (how the companion
    // position page used to crash on open — it is a proper /settings child now).
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
    final scheme = Theme.of(context).colorScheme;
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
                    color: scheme.primary,
                    size: iconSize,
                  ),
                  SizedBox(width: iconSize * 0.15),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SecondaryTypography.onGradient.title.copyWith(
                        color: scheme.onSurface,
                        letterSpacing: -0.5,
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
    // Same glyph ratio as the home header's settings button (app_header.dart)
    // so the gear reads at one size on every title bar.
    final iconSize = size * 0.62;
    final scheme = Theme.of(context).colorScheme;

    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: IconButton.filledTonal(
        tooltip: label,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: size, height: size),
        style: IconButton.styleFrom(
          backgroundColor: scheme.secondaryContainer,
          foregroundColor: scheme.onSecondaryContainer,
        ),
        icon: Icon(icon, size: iconSize),
      ),
    );
  }
}

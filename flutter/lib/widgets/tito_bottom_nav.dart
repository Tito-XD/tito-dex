import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_zh.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';

class TitoBottomNav extends StatelessWidget {
  const TitoBottomNav({super.key, required this.location});

  final String location;

  static const _routes = [
    _NavSpec('/team', AppZh.navTeam, Icons.groups_rounded),
    _NavSpec('/', AppZh.navHome, Icons.pets_rounded, center: true),
    _NavSpec('/dex', AppZh.navDex, Icons.grid_view_rounded),
    _NavSpec('/search', AppZh.navSearch, Icons.search_rounded),
  ];

  bool _isActive(String path) {
    if (path == '/') {
      return location == '/';
    }
    return location.startsWith(path);
  }

  @override
  Widget build(BuildContext context) {
    final compact = DeviceLayout.isCompact(context);
    final square = DeviceLayout.useSquareDashboard(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final hPad = compact ? 6.0 : 12.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        hPad,
        compact ? 2 : 0,
        hPad,
        (compact ? 4 : 8) + bottomInset,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 6,
          vertical: compact ? 3 : 8,
        ),
        decoration: BoxDecoration(
          color: TitoColors.deepBlue,
          borderRadius: BorderRadius.circular(TitoRadii.lg),
          border: Border.all(color: TitoColors.ink, width: TitoBorders.card),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3818283B),
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final spec in _routes) ...[
              Expanded(
                child: spec.center
                    ? _CenterNavItem(
                        spec: spec,
                        selected: _isActive(spec.path),
                        compact: compact,
                        square: square,
                        onTap: () => context.go(spec.path),
                      )
                    : _NavItem(
                        spec: spec,
                        selected: _isActive(spec.path),
                        compact: compact,
                        onTap: () => context.go(spec.path),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavSpec {
  const _NavSpec(this.path, this.label, this.icon, {this.center = false});

  final String path;
  final String label;
  final IconData icon;
  final bool center;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final _NavSpec spec;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? TitoColors.deepBlue : TitoColors.skyBlue;
    final bg = selected ? TitoColors.cream : Colors.transparent;
    final iconSize = compact ? 18.0 : 22.0;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(TitoRadii.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(TitoRadii.sm),
          splashColor: TitoColors.skyBlue.withValues(alpha: 0.28),
          highlightColor: TitoColors.skyBlue.withValues(alpha: 0.14),
          child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 3 : 8,
            horizontal: 2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(spec.icon, color: fg, size: iconSize),
              SizedBox(height: compact ? 1 : 2),
              Text(
                spec.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TitoTypography.navLabel(context, selected: selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterNavItem extends StatelessWidget {
  const _CenterNavItem({
    required this.spec,
    required this.selected,
    required this.compact,
    required this.square,
    required this.onTap,
  });

  final _NavSpec spec;
  final bool selected;
  final bool compact;
  final bool square;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = compact ? (square ? 40.0 : 44.0) : 56.0;
    final lift = compact ? (square ? -4.0 : -6.0) : -14.0;
    final iconSize = compact ? 20.0 : 26.0;

    return Transform.translate(
      offset: Offset(0, lift),
      child: Material(
        color: selected ? TitoColors.softYellow : TitoColors.cream,
        shape: const CircleBorder(
          side: BorderSide(color: TitoColors.ink, width: TitoBorders.element),
        ),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          splashColor: TitoColors.deepBlue.withValues(alpha: 0.12),
          highlightColor: TitoColors.deepBlue.withValues(alpha: 0.08),
          child: SizedBox(
            width: size,
            height: size,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  spec.icon,
                  color: TitoColors.deepBlue,
                  size: iconSize,
                ),
                if (!compact)
                  Text(
                    spec.label,
                    style: TitoTypography.style(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: TitoColors.deepBlue,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

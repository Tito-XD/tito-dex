import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_zh.dart';
import '../theme/tito_colors.dart';

class TitoBottomNav extends StatelessWidget {
  const TitoBottomNav({super.key, required this.location});

  final String location;

  static const _routes = [
    _NavSpec('/team', AppZh.navTeam, Icons.groups_rounded),
    _NavSpec('/journey', AppZh.navJourney, Icons.map_rounded),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: TitoColors.deepBlue,
          borderRadius: BorderRadius.circular(TitoRadii.lg),
          border: Border.all(color: TitoColors.ink, width: 3),
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
                        onTap: () => context.go(spec.path),
                      )
                    : _NavItem(
                        spec: spec,
                        selected: _isActive(spec.path),
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
    required this.onTap,
  });

  final _NavSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? TitoColors.deepBlue : TitoColors.skyBlue;
    final bg = selected ? TitoColors.cream : Colors.transparent;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(TitoRadii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TitoRadii.sm),
        splashColor: TitoColors.skyBlue.withValues(alpha: 0.2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(spec.icon, color: fg, size: 22),
              const SizedBox(height: 2),
              Text(
                spec.label,
                style: TextStyle(
                  color: fg,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                ),
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
    required this.onTap,
  });

  final _NavSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -14),
      child: Material(
        color: selected ? TitoColors.softYellow : TitoColors.cream,
        shape: const CircleBorder(
          side: BorderSide(color: TitoColors.ink, width: 3),
        ),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  spec.icon,
                  color: TitoColors.deepBlue,
                  size: 26,
                ),
                Text(
                  spec.label,
                  style: const TextStyle(
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

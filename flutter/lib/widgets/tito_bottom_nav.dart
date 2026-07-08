import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tito_colors.dart';

class TitoBottomNav extends StatelessWidget {
  const TitoBottomNav({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TitoColors.card,
        border: Border(top: BorderSide(color: TitoColors.ink, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                label: 'Home',
                icon: Icons.home_rounded,
                selected: location == '/',
                onTap: () => context.go('/'),
              ),
              _NavItem(
                label: 'Team',
                icon: Icons.groups_rounded,
                selected: location.startsWith('/team'),
                onTap: () => context.go('/team'),
              ),
              _NavItem(
                label: 'Journey',
                icon: Icons.map_rounded,
                selected: location.startsWith('/journey'),
                onTap: () => context.go('/journey'),
              ),
              _NavItem(
                label: 'Settings',
                icon: Icons.settings_rounded,
                selected: location.startsWith('/settings'),
                onTap: () => context.go('/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? TitoColors.deepBlue : TitoColors.mutedInk;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TitoRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

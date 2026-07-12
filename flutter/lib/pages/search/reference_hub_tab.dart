import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_zh.dart';
import '../../theme/device_layout.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import '../../widgets/handheld_input.dart';
import '../../widgets/sticker_card.dart';

/// v0.4.0: §7.4 reference hub — moves, abilities, CDN placeholders, LZA map.
class ReferenceHubTab extends StatelessWidget {
  const ReferenceHubTab({super.key});

  @override
  Widget build(BuildContext context) {
    final columns = DeviceLayout.isCompact(context) ? 2 : 3;

    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.dexReferenceTitle,
            style: SecondaryTypography.onCard.h15,
          ),
          const SizedBox(height: 4),
          Text(
            AppZh.searchReferenceCdnNote,
            style: SecondaryTypography.onCard.small12.copyWith(
              color: TitoColors.mutedInk,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppZh.searchReferenceGuideTitle,
            style: SecondaryTypography.onCard.body14.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _ReferenceHubTile(
            icon: Icons.map_rounded,
            title: AppZh.searchLzaMapTitle,
            subtitle: AppZh.searchLzaMapHint,
            available: true,
            onTap: () => _openExternalLink(context),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.35,
            children: [
              _ReferenceHubTile.grid(
                icon: Icons.bolt_rounded,
                title: AppZh.dexReferenceMoves,
                available: true,
                onTap: () => context.push('/dex/moves'),
              ),
              _ReferenceHubTile.grid(
                icon: Icons.auto_awesome_rounded,
                title: AppZh.dexReferenceAbilities,
                available: true,
                onTap: () => context.push('/dex/abilities'),
              ),
              _ReferenceHubTile.grid(
                icon: Icons.egg_rounded,
                title: AppZh.dexEggGroups,
                onTap: () => _showComingSoon(context, AppZh.dexEggGroups),
              ),
              _ReferenceHubTile.grid(
                icon: Icons.psychology_rounded,
                title: AppZh.dexReferenceNatures,
                onTap: () => _showComingSoon(context, AppZh.dexReferenceNatures),
              ),
              _ReferenceHubTile.grid(
                icon: Icons.backpack_rounded,
                title: AppZh.dexReferenceItems,
                onTap: () => _showComingSoon(context, AppZh.dexReferenceItems),
              ),
              _ReferenceHubTile.grid(
                icon: Icons.wb_sunny_rounded,
                title: AppZh.dexReferenceWeather,
                onTap: () => _showComingSoon(context, AppZh.dexReferenceWeather),
              ),
              _ReferenceHubTile.grid(
                icon: Icons.landscape_rounded,
                title: AppZh.dexReferenceTerrain,
                onTap: () => _showComingSoon(context, AppZh.dexReferenceTerrain),
              ),
              _ReferenceHubTile.grid(
                icon: Icons.healing_rounded,
                title: AppZh.dexReferenceStatus,
                onTap: () => _showComingSoon(context, AppZh.dexReferenceStatus),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static void _showComingSoon(BuildContext context, String title) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
          '${AppZh.searchReferenceComingSoon}\n${AppZh.searchReferenceCdnNote}',
          style: SecondaryTypography.onCard.body14.copyWith(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  // v0.4.0: url_launcher not in pubspec — offer copy-to-clipboard for external map.
  static void _openExternalLink(BuildContext context) {
    const url = AppZh.searchLzaMapUrl;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppZh.searchLzaMapTitle),
        content: SelectableText(
          url,
          style: SecondaryTypography.onCard.body14,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: url));
              if (!context.mounted) {
                return;
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text(AppZh.searchExternalLinkCopied)),
              );
            },
            child: const Text(AppZh.searchExternalLinkCopy),
          ),
        ],
      ),
    );
  }
}

class _ReferenceHubTile extends StatelessWidget {
  const _ReferenceHubTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.available = false,
  });

  const _ReferenceHubTile.grid({
    required this.icon,
    required this.title,
    required this.onTap,
    this.available = false,
  }) : subtitle = null;

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final isList = subtitle != null;

    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: BorderRadius.circular(DeviceLayout.rMd(context)),
      child: Material(
        color: available ? TitoColors.skyBlue : TitoColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DeviceLayout.rMd(context)),
          side: const BorderSide(color: TitoColors.ink, width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DeviceLayout.rMd(context)),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isList ? 12 : 8,
              vertical: isList ? 10 : 12,
            ),
            child: isList
                ? Row(
                    children: [
                      Icon(icon, color: TitoColors.deepBlue, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: SecondaryTypography.onCard.body14.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                style: SecondaryTypography.onCard.small12
                                    .copyWith(
                                  color: TitoColors.mutedInk,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.open_in_new_rounded,
                        color: TitoColors.mutedInk,
                        size: 18,
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: TitoColors.deepBlue, size: 26),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SecondaryTypography.onCard.small12.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      if (!available) ...[
                        const SizedBox(height: 4),
                        Text(
                          AppZh.searchReferenceComingSoon,
                          style: SecondaryTypography.onCard.small12.copyWith(
                            color: TitoColors.mutedInk,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

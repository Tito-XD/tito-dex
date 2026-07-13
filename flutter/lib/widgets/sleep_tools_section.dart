import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_zh.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import 'sticker_card.dart';

/// Tier A — static Pokémon Sleep tool links (clipboard; no account sync).
class SleepToolsSection extends StatelessWidget {
  const SleepToolsSection({super.key});

  static const _links = [
    (AppZh.sleepToolsMain, 'https://nerolislab.com'),
    (AppZh.sleepToolsGuides, 'https://nerolislab.com/guides/'),
    (AppZh.sleepToolsDocs, 'https://docs.nerolislab.com'),
  ];

  Future<void> _openLink(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$url · ${AppZh.sleepLinkCopied}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.sleepToolsTitle,
            style: SecondaryTypography.onCard.h15,
          ),
          const SizedBox(height: 4),
          Text(
            AppZh.sleepToolsTierAHint,
            style: SecondaryTypography.onCard.small12.copyWith(
              color: TitoColors.mutedInk,
            ),
          ),
          for (final (label, url) in _links)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                label,
                style: SecondaryTypography.onCard.body14.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                url,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                ),
              ),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => _openLink(context, url),
            ),
        ],
      ),
    );
  }
}

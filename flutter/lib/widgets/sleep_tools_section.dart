import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../l10n/app_zh.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import 'sticker_card.dart';

/// Tier A — static Pokémon Sleep tool links (clipboard; no account sync).
class SleepToolsSection extends StatefulWidget {
  const SleepToolsSection({super.key});

  @override
  State<SleepToolsSection> createState() => _SleepToolsSectionState();
}

class _SleepToolsSectionState extends State<SleepToolsSection> {
  @override
  void initState() {
    super.initState();
    AppConfig.instance.ensureLoaded().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

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
    final config = AppConfig.instance;
    final links = config.sleepToolsLinks;

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
            config.sleepToolsTierAHint,
            style: SecondaryTypography.onCard.small12.copyWith(
              color: TitoColors.mutedInk,
            ),
          ),
          for (final link in links)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                link.labelZh,
                style: SecondaryTypography.onCard.body14.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                link.url,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                ),
              ),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => _openLink(context, link.url),
            ),
        ],
      ),
    );
  }
}

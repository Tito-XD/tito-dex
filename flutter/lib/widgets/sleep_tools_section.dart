import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../l10n/app_zh.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import 'settings_expandable_section.dart';

/// Tier A integration: local deterministic helpers plus reference links, with
/// no Pokémon Sleep account access.
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
      if (mounted) setState(() {});
    });
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppZh.sleepLinkCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final config = AppConfig.instance;
    return SettingsExpandableSection(
      title: AppZh.sleepToolsTitle,
      subtitle: config.sleepToolsTierAHint,
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bedtime_rounded),
            title: Text(
              AppZh.sleepToolsOpen,
              style: SecondaryTypography.onCard.body14.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              AppZh.sleepToolsOpenHint,
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/search/sleep-tools'),
          ),
          const Divider(),
          for (final link in config.sleepToolsLinks)
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
              trailing: const Icon(Icons.content_copy_rounded, size: 18),
              onTap: () => _copyLink(link.url),
            ),
        ],
      ),
    );
  }
}

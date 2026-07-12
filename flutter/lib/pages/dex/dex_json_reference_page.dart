import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_zh.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import '../../widgets/secondary_page_scaffold.dart';
import '../../widgets/sticker_card.dart';

/// Placeholder list page for CDN reference JSON (natures, items, etc.).
class DexJsonReferencePage extends StatelessWidget {
  const DexJsonReferencePage({
    super.key,
    required this.title,
    required this.cdnPath,
  });

  final String title;
  final String cdnPath;

  @override
  Widget build(BuildContext context) {
    return SecondaryPageScaffold(
      title: title,
      children: [
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppZh.searchRefPlaceholder,
                style: SecondaryTypography.onCard.body14,
              ),
              const SizedBox(height: 8),
              Text(
                'CDN: $cdnPath',
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void openDexJsonReference(
  BuildContext context, {
  required String title,
  required String cdnPath,
}) {
  context.push(
    '/search/reference/json',
    extra: {'title': title, 'cdnPath': cdnPath},
  );
}

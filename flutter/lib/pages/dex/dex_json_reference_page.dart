import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dex/dex_repository.dart';
import '../../l10n/app_zh.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import 'dex_reference_list.dart';

/// CDN / offline reference list (natures, weather, items, …).
///
/// Reads from the installed offline bundle first (`dex_offline/*.json`),
/// then falls back to live CDN — same priority as summaries/details.
class DexJsonReferencePage extends StatelessWidget {
  const DexJsonReferencePage({
    super.key,
    required this.title,
    required this.cdnFilename,
  });

  final String title;
  final String cdnFilename;

  @override
  Widget build(BuildContext context) {
    return DexReferenceListPage<Map<String, dynamic>>(
      title: title,
      loadEntries: () => dexRepository.getReferenceEntries(cdnFilename),
      filterEntry: _filterReferenceEntry,
      primaryLabel: _primaryLabel,
      secondaryLabel: _secondaryLabel,
      detailSheet: _showReferenceDetailSheet,
    );
  }
}

bool _filterReferenceEntry(Map<String, dynamic> entry, String query) {
  final haystack = [
    entry['nameZh'],
    entry['nameEn'],
    entry['slug'],
    entry['descriptionZh'],
    entry['category'],
    '${entry['id']}',
  ].whereType<Object>().join(' ').toLowerCase();
  return haystack.contains(query);
}

String _primaryLabel(Map<String, dynamic> entry) {
  final zh = entry['nameZh'] as String?;
  if (zh != null && zh.isNotEmpty) {
    return zh;
  }
  return entry['nameEn'] as String? ?? entry['slug'] as String? ?? '—';
}

String _secondaryLabel(Map<String, dynamic> entry) {
  final parts = <String>[];
  final en = entry['nameEn'] as String?;
  if (en != null && en.isNotEmpty) {
    parts.add(en);
  }
  final increased = entry['increasedStat'] as String?;
  final decreased = entry['decreasedStat'] as String?;
  if (increased != null && decreased != null) {
    parts.add('↑$increased ↓$decreased');
  }
  final category = entry['category'] as String?;
  if (category != null) {
    parts.add(category);
  }
  final cost = entry['cost'];
  if (cost != null) {
    parts.add('¥$cost');
  }
  final desc = entry['descriptionZh'] as String?;
  if (desc != null && desc.isNotEmpty) {
    parts.add(desc.length > 48 ? '${desc.substring(0, 48)}…' : desc);
  }
  return parts.isEmpty ? (entry['slug'] as String? ?? '') : parts.join(' · ');
}

void _showReferenceDetailSheet(
  BuildContext context,
  Map<String, dynamic> entry,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _primaryLabel(entry),
                  style: SecondaryTypography.onCard.h15.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (entry['nameEn'] != null)
                  Text(
                    entry['nameEn'] as String,
                    style: SecondaryTypography.onCard.small12.copyWith(
                      color: TitoColors.mutedInk,
                    ),
                  ),
                const SizedBox(height: 12),
                ...entry.entries.where((e) {
                  final key = e.key;
                  return key != 'nameZh' &&
                      key != 'nameEn' &&
                      e.value != null &&
                      '$e.value'.isNotEmpty;
                }).map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${e.key}: ${e.value}',
                      style: SecondaryTypography.onCard.body14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void openDexJsonReference(
  BuildContext context, {
  required String title,
  required String cdnPath,
}) {
  final filename = cdnPath.split('/').last;
  context.push(
    '/search/reference/json',
    extra: {'title': title, 'cdnFilename': filename},
  );
}

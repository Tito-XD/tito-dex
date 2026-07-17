import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dex/dex_repository.dart';
import '../../widgets/dex_reference_detail.dart';
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

  DexReferenceKind get _kind => referenceKindForFilename(cdnFilename);

  @override
  Widget build(BuildContext context) {
    return DexReferenceListPage<Map<String, dynamic>>(
      title: title,
      loadEntries: () => dexRepository.getReferenceEntries(cdnFilename),
      filterEntry: _filterReferenceEntry,
      primaryLabel: referencePrimaryLabel,
      secondaryLabel: (entry) => _secondaryLabel(entry, _kind),
      detailSheet: (context, entry) => showJsonReferenceDetailSheet(
        context,
        entry: entry,
        kind: _kind,
      ),
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
    itemCategoryLabelZh(entry['category'] as String?),
    '${entry['id']}',
  ].whereType<Object>().join(' ').toLowerCase();
  return haystack.contains(query);
}

String _secondaryLabel(Map<String, dynamic> entry, DexReferenceKind kind) {
  final parts = <String>[];
  final en = entry['nameEn'] as String?;
  if (en != null && en.isNotEmpty) {
    parts.add(en);
  }
  if (kind == DexReferenceKind.nature) {
    parts.add(
      formatNatureStatLine(
        increasedStat: entry['increasedStat'] as String?,
        decreasedStat: entry['decreasedStat'] as String?,
        increasedStatZh: entry['increasedStatZh'] as String?,
        decreasedStatZh: entry['decreasedStatZh'] as String?,
      ),
    );
  }
  if (kind == DexReferenceKind.item) {
    final category = entry['category'] as String?;
    final categoryLabel = itemCategoryLabelZh(category);
    if (categoryLabel.isNotEmpty) {
      parts.add(categoryLabel);
    }
    final cost = entry['cost'];
    if (cost != null) {
      parts.add('¥$cost');
    }
  }
  final desc = referenceDescriptionZh(entry);
  if (desc != null && desc.isNotEmpty) {
    parts.add(desc.length > 48 ? '${desc.substring(0, 48)}…' : desc);
  }
  return parts.isEmpty ? (entry['slug'] as String? ?? '') : parts.join(' · ');
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

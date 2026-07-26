import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dex/dex_repository.dart';
import '../../theme/tito_colors.dart';
import '../../widgets/dex_sprite_image.dart';
import '../../widgets/dex_reference_detail.dart';
import '../../widgets/type_badge.dart';
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
      leadingBuilder: (entry) => _referenceLeading(entry, _kind),
      categoryFilter:
          _kind == DexReferenceKind.item ? _itemCategoryFilter : null,
      gridMode: _kind == DexReferenceKind.item,
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

Widget? _referenceLeading(Map<String, dynamic> entry, DexReferenceKind kind) {
  switch (kind) {
    case DexReferenceKind.item:
      final spriteUrl = entry['spriteUrl'] as String?;
      if (spriteUrl == null) return null;
      return DexSpriteImage(source: spriteUrl, width: 40, height: 40);
    case DexReferenceKind.move:
      final type = entry['type'] as String?;
      if (type == null || type.isEmpty) return null;
      return TypeIconImage(typeEn: type, size: 28);
    case DexReferenceKind.ability:
      return const Icon(
        Icons.auto_awesome_rounded,
        size: 28,
        color: TitoColors.ink,
      );
    default:
      return null;
  }
}

// Bulbapedia Browse:Items-style player groups; must match the `categoryZh`
// values written by tools/build_items_dataset.py (null = 全部).
final _itemCategoryFilter = DexReferenceCategoryFilter<Map<String, dynamic>>(
  options: const [
    null, '精灵球', '回复药品', '树果', '携带道具', '进化道具', '能力提升', '战斗道具',
  ],
  label: _itemCategoryLabel,
  filter: (entry, category) => _itemCategoryLabel(entry) == category,
);

/// Resolve item category label: CDN `categoryZh` first, then PokeAPI slug map.
String _itemCategoryLabel(Map<String, dynamic> entry) {
  final zh = entry['categoryZh'] as String?;
  if (zh != null && zh.isNotEmpty) return zh;
  final slug = entry['category'] as String? ?? '';
  return itemCategoryLabelZh(slug).isNotEmpty ? itemCategoryLabelZh(slug) : '道具';
}

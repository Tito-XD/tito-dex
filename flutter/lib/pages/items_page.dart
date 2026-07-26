import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../features/game/game_edition_repository.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import '../widgets/dex_sprite_image.dart';
import '../widgets/handheld_input.dart';
import '../widgets/app_header.dart';

const _cdnBase = 'https://dex.tito.cafe';

/// Lightweight item data loaded from CDN-optimized JSON.
class _ItemEntry {
  const _ItemEntry({
    required this.id,
    required this.nameZh,
    required this.categoryZh,
    required this.cost,
    this.spriteUrl,
  });

  final int id;
  final String nameZh;
  final String categoryZh;
  final int cost;
  final String? spriteUrl;
}

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  final _scrollController = ScrollController();
  List<_ItemEntry> _allItems = const [];
  List<_ItemEntry> _filtered = const [];
  String? _selectedCategory;
  bool _loading = true;

  static const _categoryOrder = [
    null, // all
    '标准球', '特殊球', '柑果球',
    '药品', '状态恢复', 'PP恢复', '复活',
    '携带道具',
    '进化道具',
    '重要物品',
    '道具',
  ];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    try {
      final response = await http.get(Uri.parse('$_cdnBase/v5/items.json'));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = <_ItemEntry>[];
      for (final entry in data.values) {
        final m = entry as Map<String, dynamic>;
        items.add(_ItemEntry(
          id: m['id'] as int,
          nameZh: m['nameZh'] as String? ?? m['nameEn'] as String,
          categoryZh: m['categoryZh'] as String? ?? '道具',
          cost: m['cost'] as int? ?? 0,
          spriteUrl: m['spriteUrl'] as String?,
        ));
      }
      items.sort((a, b) => a.id.compareTo(b.id));
      if (mounted) {
        setState(() {
          _allItems = items;
          _filtered = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterCategory(String? cat) {
    setState(() {
      _selectedCategory = cat;
      _filtered = cat == null
          ? _allItems
          : _allItems.where((i) => i.categoryZh == cat).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final compact = DeviceLayout.isCompact(context);
    final columns = DeviceLayout.useSquareDashboard(context) ? 4 : (compact ? 4 : 5);
    final gap = DeviceLayout.sectionSpacing(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: AppHeader(
              showSettings: false,
              gameBadge: gameEditionRepository.edition.slug.toUpperCase(),
            ),
          ),
          SliverToBoxAdapter(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildCategoryBar(),
          ),
          if (_filtered.isEmpty && !_loading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('暂无道具数据', style: TextStyle(color: TitoColors.mutedInk)),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: gap),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ItemCard(item: _filtered[index]),
                  childCount: _filtered.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildCategoryBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categoryOrder.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final cat = _categoryOrder[index];
          final selected = _selectedCategory == cat;
          final label = cat ?? '全部';
          final count = cat == null
              ? _allItems.length
              : _allItems.where((i) => i.categoryZh == cat).length;
          return FilterChip(
            selected: selected,
            label: Text('$label ($count)', style: const TextStyle(fontSize: 12)),
            onSelected: (_) => _filterCategory(selected ? null : cat),
            backgroundColor: TitoColors.card,
            selectedColor: TitoColors.mint,
            checkmarkColor: TitoColors.deepBlue,
            side: BorderSide(color: selected ? TitoColors.mint : TitoColors.ink.withValues(alpha: 0.2)),
          );
        },
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});
  final _ItemEntry item;

  @override
  Widget build(BuildContext context) {
    return HandheldFocusDecorator(
      onActivate: () {},
      borderRadius: BorderRadius.circular(DeviceLayout.rLg(context)),
      child: Material(
        color: TitoColors.card,
        borderRadius: BorderRadius.circular(DeviceLayout.rLg(context)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: item.spriteUrl != null
                      ? DexSpriteImage(
                          source: item.spriteUrl,
                          width: 32,
                          height: 32,
                        )
                      : const Icon(Icons.category, size: 28, color: TitoColors.mutedInk),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.nameZh,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TitoTypography.style(fontSize: 11, color: TitoColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

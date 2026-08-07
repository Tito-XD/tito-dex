import 'package:flutter/material.dart';

import '../features/companion/companion_media.dart';
import '../features/dex/online_media_catalog.dart';
import '../theme/secondary_typography.dart';

/// Settings resource manager: inspect/delete cached companion media and
/// selectively download cries / animated GIFs for any species in the
/// online media catalog.
class MediaResourcePage extends StatefulWidget {
  const MediaResourcePage({super.key});

  @override
  State<MediaResourcePage> createState() => _MediaResourcePageState();
}

class _MediaResourcePageState extends State<MediaResourcePage> {
  List<CachedMediaFile> _cached = const [];
  List<OnlineMediaEntry> _catalog = const [];
  var _query = '';
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final cached = await companionMediaCache.listCached();
    final entries = await onlineMediaCatalog.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _cached = cached;
      _catalog = entries.values.toList()
        ..sort((a, b) => a.id.compareTo(b.id));
    });
  }

  String _sizeLabel(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  Future<void> _downloadCry(OnlineMediaEntry entry) async {
    setState(() => _busy = true);
    final path = await companionMediaCache.ensureCry(
      entry.id,
      candidates: cryCandidatesForMedia(entry.id, entry),
    );
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    _snack(path == null ? '叫声下载失败' : '已缓存 ${entry.nameZh} 的叫声');
    _refresh();
  }

  Future<void> _downloadGif(OnlineMediaEntry entry) async {
    setState(() => _busy = true);
    final path = await companionMediaCache.ensureGif(entry.id);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    _snack(path == null ? '动图下载失败' : '已缓存 ${entry.nameZh} 的动图');
    _refresh();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalBytes = _cached.fold<int>(
      0,
      (sum, file) => sum + file.sizeBytes,
    );
    final matches = _catalog.where((entry) {
      final q = _query.trim();
      if (q.isEmpty) {
        return false;
      }
      return entry.nameZh.contains(q) || entry.id.toString() == q;
    }).toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '媒体资源管理',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('已缓存媒体', style: SecondaryTypography.onCard.h15),
          const SizedBox(height: 8),
          Text(
            _cached.isEmpty
                ? '暂无缓存'
                : '共 ${_cached.length} 个文件 · ${_sizeLabel(totalBytes)}',
            style: SecondaryTypography.onCard.body14,
          ),
          const SizedBox(height: 8),
          for (final file in _cached)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(file.name, style: SecondaryTypography.onCard.body14),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _sizeLabel(file.sizeBytes),
                    style: SecondaryTypography.onCard.small12,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    onPressed: () async {
                      await companionMediaCache.deleteCached(file.name);
                      _refresh();
                    },
                  ),
                ],
              ),
            ),
          if (_cached.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  for (final file in _cached) {
                    await companionMediaCache.deleteCached(file.name);
                  }
                  _refresh();
                },
                child: const Text('全部清理'),
              ),
            ),
          const Divider(height: 32),
          Text('按宝可梦下载', style: SecondaryTypography.onCard.h15),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              hintText: '搜索宝可梦名称或编号',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 8),
          if (_query.trim().isNotEmpty && matches.isEmpty)
            Text(
              '未找到（媒体目录为空时请先更新数据包）',
              style: SecondaryTypography.onCard.small12,
            ),
          for (final entry in matches.take(40))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                '#${entry.id} ${entry.nameZh}',
                style: SecondaryTypography.onCard.body14,
              ),
              subtitle: Text(
                '${entry.cries.length} 条叫声 · ${entry.forms.length} 张形态图',
                style: SecondaryTypography.onCard.small12,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => _downloadCry(entry),
                    child: const Text('叫声'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _downloadGif(entry),
                    child: const Text('动图'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

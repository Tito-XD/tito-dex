import 'package:flutter/material.dart';

import '../features/companion/companion_media.dart';
import '../features/companion/companion_animation_catalog.dart';
import '../features/dex/online_media_catalog.dart';
import '../l10n/app_zh.dart';
import '../theme/secondary_typography.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';
import '../widgets/tito_loading_panel.dart';

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
  Map<String, CompanionAnimationAsset> _animations = const {};
  var _query = '';
  var _busy = false;
  var _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh({bool reloadCatalog = false}) async {
    if (mounted) {
      setState(() => _loading = true);
    }
    try {
      final (cached, entries, animations) = await (
        companionMediaCache.listCached(),
        (reloadCatalog
                ? onlineMediaCatalog.reload()
                : onlineMediaCatalog.load())
            .catchError((Object error) {
              _loadError = AppZh.mediaResourceLoadFailed;
              return <int, OnlineMediaEntry>{};
            }),
        CompanionAnimationCatalog.load().catchError(
          (Object _) => CompanionAnimationCatalog(const []),
        ),
      ).wait;
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (entries.isNotEmpty) _loadError = null;
        _cached = cached;
        _animations = {
          for (final asset in animations.assets) asset.cacheFileName: asset,
        };
        _catalog = entries.values.toList()
          ..sort((a, b) => a.id.compareTo(b.id));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = AppZh.mediaResourceLoadFailed;
      });
    }
  }

  String _sizeLabel(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  String _cachedLabel(CachedMediaFile file) {
    final asset = _animations[file.name];
    if (asset == null) return file.name;
    return '${asset.displayName} · ${asset.label}${asset.shiny ? ' · ${AppZh.companionPickerShiny}' : ''}';
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
    _snack(
      path == null
          ? AppZh.mediaResourceCryFailed
          : AppZh.mediaResourceCryCached(entry.nameZh),
    );
    _refresh();
  }

  Future<void> _downloadGif(OnlineMediaEntry entry) async {
    setState(() => _busy = true);
    final path = await companionMediaCache.ensureGif(entry.id);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    _snack(
      path == null
          ? AppZh.mediaResourceGifFailed
          : AppZh.mediaResourceGifCached(entry.nameZh),
    );
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
    }).toList()..sort((a, b) => a.id.compareTo(b.id));

    // Both sections sit on sticker cards so their ink text, list tiles and
    // search field read the same way as every other secondary page — the
    // page background differs per theme, the card surface does not.
    return SecondaryPageScaffold(
      title: AppZh.mediaResourceTitle,
      children: [
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppZh.mediaResourceCachedTitle,
                style: SecondaryTypography.onCard.h15,
              ),
              const SizedBox(height: 8),
              Text(
                _cached.isEmpty
                    ? AppZh.mediaResourceCachedEmpty
                    : AppZh.mediaResourceCachedSummary(
                        _cached.length,
                        _sizeLabel(totalBytes),
                      ),
                style: SecondaryTypography.onCard.body14,
              ),
              if (_cached.isNotEmpty) const SizedBox(height: 8),
              for (final file in _cached)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _cachedLabel(file),
                    style: SecondaryTypography.onCard.body14,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _sizeLabel(file.sizeBytes),
                        style: SecondaryTypography.onCard.small12,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
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
                    child: Text(AppZh.mediaResourceClearAll),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          TitoLoadingPanel(
            message: AppZh.mediaResourceDownloadTitle,
            compact: true,
          )
        else
          StickerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppZh.mediaResourceDownloadTitle,
                  style: SecondaryTypography.onCard.h15,
                ),
                const SizedBox(height: 8),
                if (_loadError != null || _catalog.isEmpty) ...[
                  Text(
                    _loadError ?? AppZh.mediaResourceCatalogUnavailable,
                    style: SecondaryTypography.onCard.body14,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _refresh(reloadCatalog: true),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(AppZh.mediaResourceReload),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  decoration: InputDecoration(
                    hintText: AppZh.mediaResourceSearchHint,
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 8),
                if (_catalog.isNotEmpty &&
                    _query.trim().isNotEmpty &&
                    matches.isEmpty)
                  Text(
                    AppZh.mediaResourceNoMatch,
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
                      AppZh.mediaResourceEntryMeta(
                        entry.cries.length,
                        entry.forms.length,
                      ),
                      style: SecondaryTypography.onCard.small12,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: _busy ? null : () => _downloadCry(entry),
                          child: Text(AppZh.mediaResourceCry),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => _downloadGif(entry),
                          child: Text(AppZh.mediaResourceGif),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

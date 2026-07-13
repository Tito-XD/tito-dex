import 'package:shared_preferences/shared_preferences.dart';

/// User-selectable offline cache slices (stored in SharedPreferences).
class DexCachePreferences {
  const DexCachePreferences({
    this.cacheJsonData = true,
    this.cacheSprites = true,
    this.cacheSpritesAllVersions = false,
    this.cacheArtwork = true,
    this.cacheAnimatedSprites = false,
    this.cacheL10n = true,
    this.cacheTypeIcons = true,
    this.cacheConfig = true,
  });

  final bool cacheJsonData;
  final bool cacheSprites;
  final bool cacheSpritesAllVersions;
  final bool cacheArtwork;
  final bool cacheAnimatedSprites;
  final bool cacheL10n;
  final bool cacheTypeIcons;
  final bool cacheConfig;

  static const _prefix = 'titodex.dex.cache.';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_prefix}json', cacheJsonData);
    await prefs.setBool('${_prefix}sprites', cacheSprites);
    await prefs.setBool('${_prefix}sprites_all', cacheSpritesAllVersions);
    await prefs.setBool('${_prefix}artwork', cacheArtwork);
    await prefs.setBool('${_prefix}animated', cacheAnimatedSprites);
    await prefs.setBool('${_prefix}l10n', cacheL10n);
    await prefs.setBool('${_prefix}type_icons', cacheTypeIcons);
    await prefs.setBool('${_prefix}config', cacheConfig);
  }

  static Future<DexCachePreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return DexCachePreferences(
      cacheJsonData: prefs.getBool('${_prefix}json') ?? true,
      cacheSprites: prefs.getBool('${_prefix}sprites') ?? true,
      cacheSpritesAllVersions:
          prefs.getBool('${_prefix}sprites_all') ?? false,
      cacheArtwork: prefs.getBool('${_prefix}artwork') ?? true,
      cacheAnimatedSprites: prefs.getBool('${_prefix}animated') ?? false,
      cacheL10n: prefs.getBool('${_prefix}l10n') ?? true,
      cacheTypeIcons: prefs.getBool('${_prefix}type_icons') ?? true,
      cacheConfig: prefs.getBool('${_prefix}config') ?? true,
    );
  }

  DexCachePreferences copyWith({
    bool? cacheJsonData,
    bool? cacheSprites,
    bool? cacheSpritesAllVersions,
    bool? cacheArtwork,
    bool? cacheAnimatedSprites,
    bool? cacheL10n,
    bool? cacheTypeIcons,
    bool? cacheConfig,
  }) {
    return DexCachePreferences(
      cacheJsonData: cacheJsonData ?? this.cacheJsonData,
      cacheSprites: cacheSprites ?? this.cacheSprites,
      cacheSpritesAllVersions:
          cacheSpritesAllVersions ?? this.cacheSpritesAllVersions,
      cacheArtwork: cacheArtwork ?? this.cacheArtwork,
      cacheAnimatedSprites: cacheAnimatedSprites ?? this.cacheAnimatedSprites,
      cacheL10n: cacheL10n ?? this.cacheL10n,
      cacheTypeIcons: cacheTypeIcons ?? this.cacheTypeIcons,
      cacheConfig: cacheConfig ?? this.cacheConfig,
    );
  }

  /// Rough size hint for settings UI (not exact).
  String estimateLabelZh() {
    final parts = <String>[];
    if (cacheJsonData) {
      parts.add('JSON ~15MB');
    }
    if (cacheSprites) {
      parts.add(cacheSpritesAllVersions ? '小图全版本 ~500MB' : '小图 ~25MB');
    }
    if (cacheArtwork) {
      parts.add('立绘 ~100MB');
    }
    if (cacheAnimatedSprites) {
      parts.add('动图 ~50MB');
    }
    if (cacheL10n) {
      parts.add('中文 ~2MB');
    }
    if (cacheTypeIcons) {
      parts.add('属性图标 <1MB');
    }
    if (cacheConfig) {
      parts.add('配置 <1MB');
    }
    return parts.isEmpty ? '未选择任何内容' : parts.join(' + ');
  }
}

final dexCachePreferences = DexCachePreferences();

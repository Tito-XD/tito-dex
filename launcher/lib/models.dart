import 'dart:convert';
import 'dart:typed_data';

const titoDexPackage = 'com.tito.titodex';

enum LauncherStyle { journal, plastic, flat }

enum Wallpaper { none, coast, dusk, forest, photo }

enum WallpaperEffect { clear, frost, dim, scanlines }

enum HomeLayout { roam, dashboard, quiet }

enum HomeModule { trainer, titodex, favorites, recent }

const moduleLabels = {
  HomeModule.trainer: '训练家卡片',
  HomeModule.titodex: 'TitoDex',
  HomeModule.favorites: '常玩收藏',
  HomeModule.recent: '最近打开',
};
const layoutLabels = ['漫游', '面板', '留白'];

class ModuleConfig {
  ModuleConfig(this.module, {this.visible = true, this.wide = false});
  final HomeModule module;
  bool visible, wide;
  Map<String, dynamic> toJson() => {
    'id': module.name,
    'visible': visible,
    'wide': wide,
  };
}

List<ModuleConfig> defaultModules() => [
  ModuleConfig(HomeModule.trainer),
  ModuleConfig(HomeModule.titodex),
  ModuleConfig(HomeModule.favorites, wide: true),
  ModuleConfig(HomeModule.recent, visible: false, wide: true),
];

class LaunchApp {
  const LaunchApp(this.package, this.activity, this.label, this.icon);
  final String package, activity, label;
  final Uint8List icon;
  String get id => '$package/$activity';
  factory LaunchApp.fromMap(Map<dynamic, dynamic> map) => LaunchApp(
    map['package'] as String,
    map['activity'] as String,
    map['label'] as String,
    map['icon'] as Uint8List? ?? Uint8List(0),
  );
}

class WeatherCity {
  const WeatherCity(this.name, this.latitude, this.longitude);
  final String name;
  final double latitude, longitude;
  Map<String, dynamic> toJson() => {
    'name': name,
    'lat': latitude,
    'lon': longitude,
  };
  static WeatherCity? parse(dynamic json) {
    if (json is! Map ||
        json['name'] is! String ||
        json['lat'] is! num ||
        json['lon'] is! num) {
      return null;
    }
    final lat = (json['lat'] as num).toDouble(),
        lon = (json['lon'] as num).toDouble();
    if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
      return null;
    }
    return WeatherCity(json['name'] as String, lat, lon);
  }
}

class LauncherSettings {
  LauncherStyle style = LauncherStyle.journal;
  Wallpaper wallpaper = Wallpaper.none;
  WallpaperEffect effect = WallpaperEffect.clear;
  String name = '训练家';
  String? photo;
  WeatherCity? city;
  Set<String> favorites = {};
  bool use24Hour = true;
  HomeLayout layout = HomeLayout.roam;
  List<ModuleConfig> modules = defaultModules();
  double opacity = .72;
  bool blurPanels = true,
      reduceMotion = false,
      showWeather = true,
      showKeyHints = false;
  int libraryColumns = 4;
  String motto = '今天，也有新的冒险。';
  List<String> recent = [];
  List<LaunchApp> orderedFavorites(List<LaunchApp> apps) => [
    for (final id in favorites) ...apps.where((a) => a.id == id),
  ];
  List<LaunchApp> recentApps(List<LaunchApp> apps) => [
    for (final id in recent) ...apps.where((a) => a.id == id),
  ];
  void recordLaunch(String id) {
    recent = [id, ...recent.where((v) => v != id)].take(12).toList();
  }

  void moveFavorite(String id, int direction) {
    final list = favorites.toList(), old = favorites.toList().indexOf(id);
    if (old < 0) return;
    final target = (old + direction).clamp(0, list.length - 1);
    list.removeAt(old);
    list.insert(target, id);
    favorites = list.toSet();
  }

  void applyLayout(HomeLayout value) {
    layout = value;
    modules = defaultModules();
    if (value == HomeLayout.dashboard) modules.last.visible = true;
    if (value == HomeLayout.quiet) modules[2].visible = false;
  }

  void moveModule(int from, int to) {
    if (to < 0 || to >= modules.length) return;
    modules.insert(to, modules.removeAt(from));
  }

  String encode() => jsonEncode({
    'style': style.name,
    'wallpaper': wallpaper.name,
    'effect': effect.name,
    'name': name,
    'photo': photo,
    'city': city?.toJson(),
    'favorites': favorites.toList(),
    'use24Hour': use24Hour,
    'schema': 2,
    'layout': layout.name,
    'modules': modules.map((m) => m.toJson()).toList(),
    'opacity': opacity,
    'blurPanels': blurPanels,
    'reduceMotion': reduceMotion,
    'showWeather': showWeather,
    'showKeyHints': showKeyHints,
    'libraryColumns': libraryColumns,
    'motto': motto,
    'recent': recent,
  });
  factory LauncherSettings.decode(String? raw) {
    final settings = LauncherSettings();
    try {
      final json = jsonDecode(raw ?? '{}');
      if (json is! Map) return settings;
      settings.style =
          LauncherStyle.values
              .where((v) => v.name == json['style'])
              .firstOrNull ??
          LauncherStyle.journal;
      settings.wallpaper =
          Wallpaper.values
              .where((v) => v.name == json['wallpaper'])
              .firstOrNull ??
          Wallpaper.none;
      settings.effect =
          WallpaperEffect.values
              .where((v) => v.name == json['effect'])
              .firstOrNull ??
          WallpaperEffect.clear;
      if (json['name'] is String &&
          (json['name'] as String).trim().isNotEmpty) {
        settings.name = (json['name'] as String).trim();
      }
      settings.photo = json['photo'] is String ? json['photo'] as String : null;
      if (settings.wallpaper == Wallpaper.photo && settings.photo == null) {
        settings.wallpaper = Wallpaper.none;
      }
      settings.city = WeatherCity.parse(json['city']);
      if (json['favorites'] is List) {
        settings.favorites = (json['favorites'] as List)
            .whereType<String>()
            .take(12)
            .toSet();
      }
      settings.use24Hour = json['use24Hour'] != false;
      settings.layout =
          HomeLayout.values
              .where((v) => v.name == json['layout'])
              .firstOrNull ??
          HomeLayout.roam;
      if (json['modules'] is List) {
        final parsed = <ModuleConfig>[];
        for (final row in json['modules'] as List) {
          if (row is! Map) continue;
          final id = HomeModule.values
              .where((v) => v.name == row['id'])
              .firstOrNull;
          if (id == null || parsed.any((m) => m.module == id)) continue;
          parsed.add(
            ModuleConfig(
              id,
              visible: id == HomeModule.titodex || row['visible'] != false,
              wide: row['wide'] == true,
            ),
          );
        }
        for (final m in defaultModules()) {
          if (!parsed.any((v) => v.module == m.module)) parsed.add(m);
        }
        settings.modules = parsed;
      }
      final opacity = json['opacity'];
      if (opacity is num && opacity.isFinite) {
        settings.opacity = opacity.toDouble().clamp(.7, 1);
      }
      settings.blurPanels = json['blurPanels'] != false;
      settings.reduceMotion = json['reduceMotion'] == true;
      settings.showWeather = json['showWeather'] != false;
      settings.showKeyHints = json['showKeyHints'] == true;
      if (json['libraryColumns'] is int) {
        settings.libraryColumns = (json['libraryColumns'] as int).clamp(3, 6);
      }
      if (json['motto'] is String) {
        settings.motto = String.fromCharCodes(
          (json['motto'] as String).runes.take(40),
        );
      }
      if (json['recent'] is List) {
        settings.recent = (json['recent'] as List)
            .whereType<String>()
            .toSet()
            .take(12)
            .toList();
      }
    } catch (_) {
      /* A corrupt preference cannot make the home screen unusable. */
    }
    return settings;
  }
  LauncherSettings();
  void resetWallpaper() {
    wallpaper = Wallpaper.none;
    effect = WallpaperEffect.clear;
    photo = null;
  }
}

String greeting(DateTime now) => switch (now.hour) {
  < 6 => '夜深了，休息一下',
  < 11 => '早上好',
  < 14 => '中午好',
  < 18 => '下午好',
  _ => '晚上好',
};
String clockLabel(DateTime now, bool use24Hour) {
  final hour = use24Hour ? now.hour : (now.hour % 12 == 0 ? 12 : now.hour % 12);
  return '${hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
}

String dateLabel(DateTime now) =>
    '${now.month}月${now.day}日 · 星期${'一二三四五六日'[now.weekday - 1]}';
List<LaunchApp> filterApps(
  List<LaunchApp> apps,
  String query,
  Set<String> favorites,
  bool favoritesOnly,
) {
  final needle = query.trim().toLowerCase();
  final result = apps
      .where(
        (app) =>
            (!favoritesOnly || favorites.contains(app.id)) &&
            (app.label.toLowerCase().contains(needle) ||
                app.package.toLowerCase().contains(needle)),
      )
      .toList();
  final ranks = {for (final entry in favorites.indexed) entry.$2: entry.$1};
  result.sort((a, b) {
    if (ranks.containsKey(a.id) && ranks.containsKey(b.id)) {
      return ranks[a.id]!.compareTo(ranks[b.id]!);
    }
    final favored =
        (favorites.contains(b.id) ? 1 : 0) - (favorites.contains(a.id) ? 1 : 0);
    return favored == 0
        ? a.label.toLowerCase().compareTo(b.label.toLowerCase())
        : favored;
  });
  return result;
}

import 'package:flutter/services.dart';
import 'models.dart';

class DeviceBridge {
  static const channel = MethodChannel('com.tito.titodex.launcher/device');
  Future<String?> readSettings() =>
      channel.invokeMethod<String>('readSettings');
  Future<void> save(LauncherSettings value) =>
      channel.invokeMethod('writeSettings', {'json': value.encode()});
  Future<List<LaunchApp>> apps() async =>
      (await channel.invokeListMethod<dynamic>('apps') ?? [])
          .map((v) => LaunchApp.fromMap(v as Map))
          .toList();
  Future<Map<dynamic, dynamic>> status() async =>
      await channel.invokeMapMethod<dynamic, dynamic>('status') ?? {};
  Future<bool> action(String method, [Map<String, dynamic>? args]) async =>
      await channel.invokeMethod<bool>(method, args) ?? false;
  Future<bool> launch(String package, [String? activity]) =>
      action('launch', {'package': package, 'activity': activity});
  Future<String?> pickWallpaper() =>
      channel.invokeMethod<String>('pickWallpaper');
}

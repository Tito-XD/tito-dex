import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_release.dart';

class AppUpdatePlatform {
  const AppUpdatePlatform();
  static const channel = MethodChannel('com.tito.titodex/app_update');
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<InstalledApp?> installed() async {
    if (!supported) return null;
    try {
      final info = await channel.invokeMapMethod<String, dynamic>('installed');
      if (info == null) return null;
      return InstalledApp(
        version: info['version'] as String,
        buildNumber: (info['buildNumber'] as num).toInt(),
        packageName: info['packageName'] as String,
        arm64: info['arm64'] == true,
      );
    } on MissingPluginException {
      return null;
    }
  }

  Future<String> install(
    File file,
    AppRelease release, {
    required bool offline,
  }) async =>
      await channel.invokeMethod<String>('install', {
        'path': file.path,
        'sha256': release.sha256,
        'version': '${release.version}${offline ? '-offline' : ''}',
      }) ??
      'failed';
}

enum AppUpdatePhase {
  idle,
  checking,
  available,
  downloading,
  verifying,
  ready,
  installing,
}

class AppUpdateService extends ChangeNotifier {
  AppUpdateService({
    AppUpdatePlatform? platform,
    http.Client Function()? clientFactory,
    Future<Directory> Function()? cacheDirectory,
    DateTime Function()? now,
  }) : _platform = platform ?? const AppUpdatePlatform(),
       _clientFactory = clientFactory ?? http.Client.new,
       _cacheDirectory = cacheDirectory ?? getTemporaryDirectory,
       _now = now ?? DateTime.now;

  static final latestUrl = Uri.parse(
    'https://api.github.com/repos/Tito-XD/tito-dex/releases/latest',
  );
  static const _autoKey = 'appUpdate.automatic';
  static const _lastKey = 'appUpdate.lastAttempt';
  final AppUpdatePlatform _platform;
  final http.Client Function() _clientFactory;
  final Future<Directory> Function() _cacheDirectory;
  final DateTime Function() _now;
  bool automatic = true;
  bool loaded = false;
  InstalledApp? installed;
  AppRelease? release;
  AppUpdatePhase phase = AppUpdatePhase.idle;
  String? error;
  bool permissionRequired = false;
  bool checked = false;
  int receivedBytes = 0;
  File? _apk;
  Future<void>? _loading;
  Future<void>? _checking;
  http.Client? _downloadClient;
  bool _cancelled = false;
  bool get supported => _platform.supported;
  bool get busy =>
      phase == AppUpdatePhase.checking ||
      phase == AppUpdatePhase.downloading ||
      phase == AppUpdatePhase.verifying ||
      phase == AppUpdatePhase.installing;
  double get progress =>
      release == null ? 0 : (receivedBytes / release!.bytes).clamp(0, 1);

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    automatic = prefs.getBool(_autoKey) ?? true;
    try {
      installed = await _platform.installed();
    } catch (_) {
      error = 'platform';
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> setAutomatic(bool value) async {
    automatic = value;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(_autoKey, value);
  }

  Future<void> check({bool automaticCheck = false}) => _checking ??= _check(
    automaticCheck: automaticCheck,
  ).whenComplete(() => _checking = null);

  Future<void> _check({required bool automaticCheck}) async {
    await load();
    if (busy || installed?.canUpdate != true) return;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastKey);
    if (automaticCheck &&
        (!automatic ||
            (last != null &&
                _now().difference(DateTime.fromMillisecondsSinceEpoch(last)) <
                    const Duration(hours: 24)))) {
      return;
    }
    phase = AppUpdatePhase.checking;
    error = null;
    notifyListeners();
    await prefs.setInt(_lastKey, _now().millisecondsSinceEpoch);
    final client = _clientFactory();
    try {
      final response = await client
          .send(
            http.Request('GET', latestUrl)
              ..headers.addAll({
                'Accept': 'application/vnd.github+json',
                'User-Agent': 'TitoDex/${installed!.version}',
                'X-GitHub-Api-Version': '2022-11-28',
              }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw HttpException('release_http_${response.statusCode}');
      }
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 15),
      )) {
        bytes.addAll(chunk);
        if (bytes.length > 1024 * 1024) {
          throw const FormatException('release_too_large');
        }
      }
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final next = AppRelease.newerThan(json, installed!);
      if (next?.sha256 != release?.sha256) {
        _apk = null;
        permissionRequired = false;
      }
      release = next;
      checked = true;
    } catch (_) {
      error = 'check';
    } finally {
      client.close();
      phase = _apk != null
          ? AppUpdatePhase.ready
          : release != null
          ? AppUpdatePhase.available
          : AppUpdatePhase.idle;
      notifyListeners();
    }
  }

  Future<void> download() async {
    final target = release;
    if (target == null || busy) return;
    phase = AppUpdatePhase.downloading;
    error = null;
    receivedBytes = 0;
    permissionRequired = false;
    _apk = null;
    _cancelled = false;
    notifyListeners();
    final client = _clientFactory();
    _downloadClient = client;
    File? part;
    IOSink? output;
    try {
      final dir = Directory('${(await _cacheDirectory()).path}/app_updates');
      await dir.create(recursive: true);
      // Only our two fixed cache filenames are touched; previous installs can
      // leave no unbounded collection of APKs behind.
      part = File('${dir.path}/update.part');
      final ready = File('${dir.path}/update.apk');
      if (await ready.exists()) await ready.delete();
      final response = await client
          .send(http.Request('GET', target.download))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200 ||
          (response.contentLength != null &&
              response.contentLength != target.bytes)) {
        throw const FormatException('apk_size');
      }
      output = part.openWrite();
      final digestSink = _DigestSink();
      final hasher = sha256.startChunkedConversion(digestSink);
      var lastNotice = 0;
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        if (_cancelled) throw const HttpException('cancelled');
        receivedBytes += chunk.length;
        if (receivedBytes > target.bytes) {
          throw const FormatException('apk_size');
        }
        hasher.add(chunk);
        output.add(chunk);
        await output.flush();
        if (receivedBytes - lastNotice >= 128 * 1024) {
          lastNotice = receivedBytes;
          notifyListeners();
        }
      }
      hasher.close();
      await output.close();
      output = null;
      if (_cancelled) throw const HttpException('cancelled');
      phase = AppUpdatePhase.verifying;
      notifyListeners();
      if (receivedBytes != target.bytes ||
          digestSink.value.toString() != target.sha256) {
        throw const FormatException('apk_digest');
      }
      _apk = await part.rename(ready.path);
      part = null;
      phase = AppUpdatePhase.ready;
    } catch (_) {
      error = _cancelled ? null : 'download';
      phase = AppUpdatePhase.available;
    } finally {
      client.close();
      _downloadClient = null;
      try {
        await output?.close();
      } catch (_) {
        /* Preserve the download error. */
      }
      try {
        if (part != null && await part.exists()) await part.delete();
      } catch (_) {
        /* A partial file is never offered to the installer. */
      }
      notifyListeners();
    }
  }

  void cancelDownload() {
    if (phase != AppUpdatePhase.downloading) return;
    _cancelled = true;
    _downloadClient?.close();
  }

  Future<void> install() async {
    if (_apk == null || release == null || installed == null || busy) return;
    error = null;
    permissionRequired = false;
    phase = AppUpdatePhase.installing;
    notifyListeners();
    try {
      final result = await _platform.install(
        _apk!,
        release!,
        offline: installed!.offline,
      );
      permissionRequired = result == 'permission_required';
      if (result != 'started' && !permissionRequired) error = 'install';
    } catch (_) {
      error = 'install';
    } finally {
      if (error != null) _apk = null;
      phase = error == null ? AppUpdatePhase.ready : AppUpdatePhase.available;
      notifyListeners();
    }
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

final appUpdateService = AppUpdateService();

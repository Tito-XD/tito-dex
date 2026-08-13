import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

abstract final class JourneyAssistantExtensionContract {
  static const protocolVersion = 1;
  static const extensionId = 'journey_assistant';
  static const packageId = 'com.tito.titodex.extension.journeyassistant';
  static const providerAuthority =
      'com.tito.titodex.extension.journeyassistant.provider';
  static const readPermission =
      'com.tito.titodex.permission.READ_EXTENSION_PACK';
}

abstract final class ExtensionCatalogConfig {
  static const catalogUrl = String.fromEnvironment(
    'TITODEX_EXTENSION_CATALOG_URL',
  );

  static bool get isConfigured {
    final uri = Uri.tryParse(catalogUrl.trim());
    return _isJourneyWorkerCatalogUri(uri);
  }
}

const _workerExtensionCatalogPath = '/v1/extensions/journey_assistant/catalog';

bool _isJourneyWorkerCatalogUri(Uri? uri) =>
    uri != null &&
    uri.scheme == 'https' &&
    uri.hasAuthority &&
    uri.userInfo.isEmpty &&
    uri.path == _workerExtensionCatalogPath &&
    !uri.hasQuery &&
    !uri.hasFragment;

class JourneyAssistantExtensionInfo {
  const JourneyAssistantExtensionInfo({
    required this.installed,
    this.versionName,
    this.versionCode,
    this.contentVersion,
    this.capabilities = const [],
  });

  final bool installed;
  final String? versionName;
  final int? versionCode;
  final int? contentVersion;
  final List<String> capabilities;

  static const notInstalled = JourneyAssistantExtensionInfo(installed: false);

  factory JourneyAssistantExtensionInfo.fromMap(Map<Object?, Object?> map) =>
      JourneyAssistantExtensionInfo(
        installed: map['installed'] == true,
        versionName: map['versionName'] as String?,
        versionCode: (map['versionCode'] as num?)?.toInt(),
        contentVersion: (map['contentVersion'] as num?)?.toInt(),
        capabilities: (map['capabilities'] as List<Object?>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );
}

class JourneyAssistantExtensionCatalog {
  const JourneyAssistantExtensionCatalog({
    required this.packageId,
    required this.providerAuthority,
    required this.apkUri,
    required this.sha256Hex,
    required this.sizeBytes,
    required this.versionCode,
    this.versionName,
    this.minHostVersion,
  });

  final String packageId;
  final String providerAuthority;
  final Uri apkUri;
  final String sha256Hex;
  final int sizeBytes;
  final int versionCode;
  final String? versionName;
  final String? minHostVersion;

  factory JourneyAssistantExtensionCatalog.fromJson(
    Map<String, dynamic> json, {
    required Uri catalogUri,
  }) {
    if (json['schemaVersion'] != 1 || json['entries'] is! List) {
      throw const FormatException('Unsupported extension catalog');
    }
    final entries = (json['entries'] as List).whereType<Map>();
    final rawEntry = entries.cast<Map>().firstWhere(
      (entry) =>
          entry['extensionId'] == JourneyAssistantExtensionContract.extensionId,
      orElse: () => const {},
    );
    final entry = Map<String, dynamic>.from(rawEntry);
    final packageId = entry['packageId'] as String? ?? '';
    const providerAuthority =
        JourneyAssistantExtensionContract.providerAuthority;
    final apkValue = entry['downloadPath'] as String? ?? '';
    final apkUri = catalogUri.resolve(apkValue);
    final digest = (entry['sha256'] as String? ?? '').trim().toLowerCase();
    final sizeBytes = (entry['sizeBytes'] as num?)?.toInt() ?? 0;
    final versionCode = (entry['versionCode'] as num?)?.toInt() ?? 0;
    if (packageId != JourneyAssistantExtensionContract.packageId ||
        providerAuthority !=
            JourneyAssistantExtensionContract.providerAuthority ||
        !RegExp(
          r'^objects/[A-Za-z0-9][A-Za-z0-9._-]{0,199}\.apk$',
        ).hasMatch(apkValue) ||
        apkUri.scheme != 'https' ||
        !apkUri.hasAuthority ||
        apkUri.origin != catalogUri.origin ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) ||
        sizeBytes <= 0 ||
        sizeBytes > 512 * 1024 * 1024 ||
        versionCode <= 0) {
      throw const FormatException('Invalid extension catalog');
    }
    return JourneyAssistantExtensionCatalog(
      packageId: packageId,
      providerAuthority: providerAuthority,
      apkUri: apkUri,
      sha256Hex: digest,
      sizeBytes: sizeBytes,
      versionCode: versionCode,
      versionName: entry['versionName'] as String?,
      minHostVersion: entry['minHostVersion'] as String?,
    );
  }
}

abstract class JourneyAssistantExtensionPlatform {
  Future<JourneyAssistantExtensionInfo> inspect();
  Future<String?> readTextFile(String path);
  Future<String> install(String apkPath);
  Future<void> uninstall();
  void setStatusChangedHandler(VoidCallback handler);
}

class MethodChannelJourneyAssistantExtensionPlatform
    implements JourneyAssistantExtensionPlatform {
  MethodChannelJourneyAssistantExtensionPlatform({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.tito.titodex/journey_assistant_extension';
  final MethodChannel _channel;

  @override
  Future<JourneyAssistantExtensionInfo> inspect() async {
    if (kIsWeb || !Platform.isAndroid) {
      return JourneyAssistantExtensionInfo.notInstalled;
    }
    final result = await _channel
        .invokeMapMethod<Object?, Object?>('inspect', const {
          'packageId': JourneyAssistantExtensionContract.packageId,
          'providerAuthority':
              JourneyAssistantExtensionContract.providerAuthority,
          'readPermission': JourneyAssistantExtensionContract.readPermission,
        });
    return JourneyAssistantExtensionInfo.fromMap(result ?? const {});
  }

  @override
  Future<String> install(String apkPath) async {
    final result = await _channel.invokeMethod<String>('install', {
      'apkPath': apkPath,
      'packageId': JourneyAssistantExtensionContract.packageId,
      'providerAuthority': JourneyAssistantExtensionContract.providerAuthority,
      'readPermission': JourneyAssistantExtensionContract.readPermission,
    });
    return result ?? 'started';
  }

  @override
  Future<String?> readTextFile(String path) =>
      _channel.invokeMethod<String>('readTextFile', {'path': path});

  @override
  Future<void> uninstall() => _channel.invokeMethod<void>('uninstall', {
    'packageId': JourneyAssistantExtensionContract.packageId,
  });

  @override
  void setStatusChangedHandler(VoidCallback handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'statusChanged') handler();
    });
  }
}

class JourneyAssistantExtensionController extends ChangeNotifier {
  JourneyAssistantExtensionController({
    JourneyAssistantExtensionPlatform? platform,
    http.Client? client,
    String catalogUrl = ExtensionCatalogConfig.catalogUrl,
    Duration installPollInterval = const Duration(seconds: 1),
    int installPollAttempts = 30,
  }) : _platform = platform ?? MethodChannelJourneyAssistantExtensionPlatform(),
       _client = client,
       _catalogUrl = catalogUrl.trim(),
       _installPollInterval = installPollInterval,
       _installPollAttempts = installPollAttempts {
    _platform.setStatusChangedHandler(() => unawaited(refresh()));
  }

  final JourneyAssistantExtensionPlatform _platform;
  final http.Client? _client;
  final String _catalogUrl;
  final Duration _installPollInterval;
  final int _installPollAttempts;
  Timer? _installRecognitionTimer;
  int _installPollsRemaining = 0;

  JourneyAssistantExtensionInfo _info =
      JourneyAssistantExtensionInfo.notInstalled;
  bool _busy = false;
  String? _errorCode;

  JourneyAssistantExtensionInfo get info => _info;
  bool get installed => _info.installed;
  bool get busy => _busy;
  String? get errorCode => _errorCode;

  bool get catalogConfigured {
    final uri = Uri.tryParse(_catalogUrl);
    return _isJourneyWorkerCatalogUri(uri);
  }

  Future<void> refresh() async {
    try {
      _info = await _platform.inspect();
      _errorCode = null;
    } on MissingPluginException {
      _info = JourneyAssistantExtensionInfo.notInstalled;
    } on PlatformException {
      _info = JourneyAssistantExtensionInfo.notInstalled;
      _errorCode = 'inspect_failed';
    }
    if (_info.installed) {
      _stopInstallRecognitionPolling();
    }
    notifyListeners();
  }

  void _startInstallRecognitionPolling() {
    _stopInstallRecognitionPolling();
    if (_installPollAttempts <= 0) return;
    _installPollsRemaining = _installPollAttempts;
    _installRecognitionTimer = Timer.periodic(_installPollInterval, (timer) {
      if (installed || _installPollsRemaining <= 0) {
        _stopInstallRecognitionPolling();
        return;
      }
      _installPollsRemaining -= 1;
      unawaited(refresh());
    });
  }

  void _stopInstallRecognitionPolling() {
    _installRecognitionTimer?.cancel();
    _installRecognitionTimer = null;
    _installPollsRemaining = 0;
  }

  Future<String> installFromCatalog() async {
    if (_busy) return 'busy';
    if (!catalogConfigured) {
      _errorCode = 'catalog_not_configured';
      notifyListeners();
      return _errorCode!;
    }
    _busy = true;
    _errorCode = null;
    notifyListeners();
    File? apk;
    final client = _client ?? http.Client();
    final ownsClient = _client == null;
    try {
      final catalogUri = Uri.parse(_catalogUrl);
      final catalogResponse = await client
          .get(catalogUri)
          .timeout(const Duration(seconds: 12));
      if (catalogResponse.statusCode != 200) {
        throw const _ExtensionInstallException('catalog_http_error');
      }
      final decoded = jsonDecode(utf8.decode(catalogResponse.bodyBytes));
      if (decoded is! Map) {
        throw const _ExtensionInstallException('catalog_invalid');
      }
      final catalog = JourneyAssistantExtensionCatalog.fromJson(
        Map<String, dynamic>.from(decoded),
        catalogUri: catalogUri,
      );
      if (installed &&
          _info.versionCode != null &&
          catalog.versionCode <= _info.versionCode!) {
        return 'up_to_date';
      }
      final request = http.Request('GET', catalog.apkUri);
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const _ExtensionInstallException('apk_http_error');
      }
      final directory = await getTemporaryDirectory();
      apk = File('${directory.path}/titodex-journey-assistant.apk');
      final fileSink = apk.openWrite();
      late Digest digest;
      final digestSink = sha256.startChunkedConversion(
        ChunkedConversionSink<Digest>.withCallback(
          (digests) => digest = digests.single,
        ),
      );
      var downloaded = 0;
      try {
        await for (final chunk in response.stream) {
          downloaded += chunk.length;
          if (downloaded > catalog.sizeBytes) {
            throw const _ExtensionInstallException('apk_size_mismatch');
          }
          fileSink.add(chunk);
          digestSink.add(chunk);
        }
      } finally {
        await fileSink.close();
        digestSink.close();
      }
      if (downloaded != catalog.sizeBytes ||
          digest.toString() != catalog.sha256Hex) {
        throw const _ExtensionInstallException('apk_integrity_failed');
      }
      final result = await _platform.install(apk.path);
      await refresh();
      if (result == 'started' && !installed) {
        _startInstallRecognitionPolling();
      }
      return result;
    } on FormatException {
      _errorCode = 'catalog_invalid';
      return _errorCode!;
    } on TimeoutException {
      _errorCode = 'network_timeout';
      return _errorCode!;
    } on _ExtensionInstallException catch (error) {
      _errorCode = error.code;
      return error.code;
    } on PlatformException catch (error) {
      _errorCode = error.code;
      return error.code;
    } on Object {
      _errorCode = 'install_failed';
      return _errorCode!;
    } finally {
      try {
        if (apk != null && await apk.exists()) await apk.delete();
      } on FileSystemException {
        // The OS installer already owns its copied session; stale cache can be
        // cleaned by Android if immediate deletion is unavailable.
      }
      if (ownsClient) client.close();
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> uninstall() async {
    await _platform.uninstall();
  }

  @override
  void dispose() {
    _stopInstallRecognitionPolling();
    super.dispose();
  }

  Future<String?> readTextFile(String path) async {
    if (!installed || path.contains('..') || path.startsWith('/')) return null;
    try {
      return await _platform.readTextFile(path);
    } on PlatformException {
      return null;
    }
  }

  @visibleForTesting
  void setInfoForTest(JourneyAssistantExtensionInfo value) {
    _info = value;
    notifyListeners();
  }
}

class _ExtensionInstallException implements Exception {
  const _ExtensionInstallException(this.code);
  final String code;
}

final journeyAssistantExtension = JourneyAssistantExtensionController();

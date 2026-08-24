import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'ask_titodex_settings.dart';
import 'journey_pack_client.dart';
import 'journey_pack_models.dart';
import 'journey_pack_store.dart';

class JourneyPackRepository extends ChangeNotifier {
  JourneyPackRepository({
    JourneyPackClient? client,
    JourneyPackStore? store,
    bool Function()? enabledProvider,
  }) : _client = client,
       _store = store ?? FileJourneyPackStore(),
       _enabledProvider =
           enabledProvider ??
           (() =>
               askTitoDexSettings.noticeAcknowledged &&
               askTitoDexSettings.extensionEnabled);

  JourneyPackClient? _client;
  final JourneyPackStore _store;
  final bool Function() _enabledProvider;

  JourneyPackCatalog? _catalog;
  Map<String, InstalledJourneyPack> _installed = const {};
  Set<String> _corruptFamilies = const {};
  bool _loadingLocal = false;
  Future<void>? _localLoadFuture;
  bool _loadingCatalog = false;
  String? _busyFamily;
  int _downloadedBytes = 0;
  int _downloadTotalBytes = 0;
  String? _errorCode;
  JourneyPackCancelToken? _cancelToken;

  JourneyPackCatalog? get catalog => _catalog;
  Map<String, InstalledJourneyPack> get installed => _installed;
  Set<String> get corruptFamilies => _corruptFamilies;
  bool get loadingLocal => _loadingLocal;
  bool get loadingCatalog => _loadingCatalog;
  String? get busyFamily => _busyFamily;
  int get downloadedBytes => _downloadedBytes;
  int get downloadTotalBytes => _downloadTotalBytes;
  String? get errorCode => _errorCode;
  bool get featureEnabled => _enabledProvider();
  JourneyPackClient get _resolvedClient => _client ??= JourneyPackClient();

  bool get catalogConfigured => _resolvedClient.configured;

  double? get downloadProgress => _downloadTotalBytes <= 0
      ? null
      : (_downloadedBytes / _downloadTotalBytes).clamp(0, 1);

  Future<void> loadInstalled() {
    final active = _localLoadFuture;
    if (active != null) return active;
    final future = _loadInstalled();
    _localLoadFuture = future;
    return future.whenComplete(() => _localLoadFuture = null);
  }

  Future<void> _loadInstalled() async {
    _loadingLocal = true;
    notifyListeners();
    try {
      final snapshot = await _store.load();
      _installed = snapshot.installed;
      _corruptFamilies = snapshot.corruptFamilies;
    } on Object {
      _errorCode = 'storage_read_failed';
    } finally {
      _loadingLocal = false;
      notifyListeners();
    }
  }

  Future<String> refreshCatalog() async {
    if (!featureEnabled) return 'disabled';
    if (_loadingCatalog) return 'busy';
    _loadingCatalog = true;
    _errorCode = null;
    notifyListeners();
    try {
      _catalog = await _resolvedClient.fetchCatalog();
      return 'ok';
    } on TimeoutException {
      _errorCode = 'network_timeout';
      return _errorCode!;
    } on JourneyPackClientException catch (error) {
      _errorCode = error.code;
      return error.code;
    } on Object {
      _errorCode = 'catalog_failed';
      return _errorCode!;
    } finally {
      _loadingCatalog = false;
      notifyListeners();
    }
  }

  JourneyPackDescriptor? descriptorForGame(String? exactGame) {
    if (exactGame == null) return null;
    for (final descriptor in _catalog?.packs ?? const []) {
      if (descriptor.supportsGame(exactGame)) return descriptor;
    }
    return null;
  }

  JourneyPackAvailability availabilityFor(JourneyPackDescriptor descriptor) {
    if (!descriptor.isCompatible) return JourneyPackAvailability.incompatible;
    if (_corruptFamilies.contains(descriptor.gameFamily)) {
      return JourneyPackAvailability.corrupt;
    }
    final local = _installed[descriptor.gameFamily];
    if (local == null) return JourneyPackAvailability.notInstalled;
    if (local.descriptor.sha256Hex == descriptor.sha256Hex) {
      return JourneyPackAvailability.installed;
    }
    return JourneyPackAvailability.updateAvailable;
  }

  Future<String> install(JourneyPackDescriptor descriptor) async {
    if (!featureEnabled) return 'disabled';
    if (_busyFamily != null) return 'busy';
    if (!descriptor.isCompatible) return 'bundle_version_incompatible';
    _busyFamily = descriptor.gameFamily;
    _downloadedBytes = 0;
    _downloadTotalBytes = descriptor.sizeBytes;
    _errorCode = null;
    final token = JourneyPackCancelToken();
    _cancelToken = token;
    notifyListeners();
    try {
      final bytes = await _resolvedClient.download(
        descriptor,
        cancelToken: token,
        onProgress: (downloaded, total) {
          _downloadedBytes = downloaded;
          _downloadTotalBytes = total;
          notifyListeners();
        },
      );
      final document = JourneyPackDocument.fromBytes(
        bytes,
        descriptor: descriptor,
      );
      await _store.install(descriptor, bytes, document);
      await loadInstalled();
      return 'installed';
    } on FormatException {
      _errorCode = 'pack_invalid';
      return _errorCode!;
    } on TimeoutException {
      _errorCode = 'network_timeout';
      return _errorCode!;
    } on JourneyPackClientException catch (error) {
      _errorCode = error.code == 'cancelled' ? null : error.code;
      return error.code;
    } on Object {
      _errorCode = 'install_failed';
      return _errorCode!;
    } finally {
      _cancelToken = null;
      _busyFamily = null;
      _downloadedBytes = 0;
      _downloadTotalBytes = 0;
      notifyListeners();
    }
  }

  Future<void> cancelDownload() async => _cancelToken?.cancel();

  Future<String> delete(String gameFamily) async {
    if (_busyFamily != null) return 'busy';
    try {
      await _store.delete(gameFamily);
      await loadInstalled();
      return 'deleted';
    } on Object {
      _errorCode = 'delete_failed';
      notifyListeners();
      return _errorCode!;
    }
  }

  Future<List<JourneyPackReference>> referencesForGame(
    String? exactGame,
  ) async {
    if (exactGame == null || !featureEnabled) return const [];
    if (_installed.isEmpty) await loadInstalled();
    if (_catalog == null && await refreshCatalog() != 'ok') return const [];
    final catalogDescriptor = descriptorForGame(exactGame);
    if (catalogDescriptor == null || !catalogDescriptor.isCompatible) {
      return const [];
    }
    final installed = _installed[catalogDescriptor.gameFamily];
    if (installed == null ||
        installed.descriptor.sha256Hex != catalogDescriptor.sha256Hex ||
        installed.descriptor.id != catalogDescriptor.id ||
        installed.descriptor.version != catalogDescriptor.version ||
        installed.descriptor.sizeBytes != catalogDescriptor.sizeBytes ||
        installed.descriptor.entryCount != catalogDescriptor.entryCount ||
        !catalogDescriptor.supportsGame(exactGame)) {
      return const [];
    }
    return [catalogDescriptor.toRequestReference()];
  }

  Future<String?> progressionHintsJson() async {
    if (_installed.isEmpty) await loadInstalled();
    final entries = <Map<String, dynamic>>[];
    for (final pack in _installed.values) {
      if (!pack.descriptor.isCompatible) continue;
      for (final entry in pack.document.entries) {
        if (_looksLikeProgressionHint(entry)) entries.add(entry);
      }
    }
    if (entries.isEmpty) return null;
    return jsonEncode({'schemaVersion': 1, 'entries': entries});
  }

  @override
  void dispose() {
    unawaited(_cancelToken?.cancel());
    _client?.close();
    super.dispose();
  }
}

bool _looksLikeProgressionHint(Map<String, dynamic> entry) {
  if (entry['entryType'] == 'progression_hint') return true;
  return entry['id'] is String &&
      entry['games'] is List &&
      entry['subject'] is Map &&
      entry['steps'] is List &&
      entry['sources'] is List;
}

final journeyPackRepository = JourneyPackRepository();

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ask_titodex_settings.dart';
import 'progression_hints.dart';

class AskTitoDexConfig {
  static const workerUrl = String.fromEnvironment(
    'TITODEX_JOURNEY_ASSISTANT_URL',
  );
}

const _workerAskPath = '/v1/ask';
const _workerHealthPath = '/health';
const _maxHealthResponseBytes = 8192;

enum AskTitoDexProgress { checkingLocal, contactingWorker }

enum AskTitoDexAvailability { checking, online, disabled, unavailable }

class AskTitoDexWorkerStatus {
  const AskTitoDexWorkerStatus({
    required this.availability,
    this.qwenConfigured = false,
    this.aiSearchEnabled = false,
    this.curatedSourcesEnabled = false,
    this.sourceProviders = const [],
    bool webSearchEnabled = false,
    this.webSearchProviders = const [],
    bool? braveSearchEnabled,
    this.externalProviderEnabled = false,
    this.errorCode,
  }) : webSearchEnabled = braveSearchEnabled ?? webSearchEnabled;

  const AskTitoDexWorkerStatus.checking()
    : this(availability: AskTitoDexAvailability.checking);

  const AskTitoDexWorkerStatus.disabled()
    : this(availability: AskTitoDexAvailability.disabled);

  const AskTitoDexWorkerStatus.unavailable([String? errorCode])
    : this(
        availability: AskTitoDexAvailability.unavailable,
        errorCode: errorCode,
      );

  final AskTitoDexAvailability availability;
  final bool qwenConfigured;
  final bool aiSearchEnabled;
  final bool curatedSourcesEnabled;
  final List<String> sourceProviders;
  final bool webSearchEnabled;
  final List<String> webSearchProviders;

  /// Read-only compatibility for the v0.8.14 health schema and older tests.
  bool get braveSearchEnabled =>
      webSearchEnabled && webSearchProviders.contains('brave');

  final bool externalProviderEnabled;
  final String? errorCode;
}

bool _isJourneyWorkerAskEndpoint(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.hasAuthority &&
      uri.userInfo.isEmpty &&
      uri.path == _workerAskPath &&
      !uri.hasQuery &&
      !uri.hasFragment;
}

abstract class AskTitoDexOnlineClient {
  Future<AskTitoDexResult> ask(String question, AskTitoDexContext context);

  Future<AskTitoDexWorkerStatus> checkStatus();
}

class HttpAskTitoDexOnlineClient implements AskTitoDexOnlineClient {
  HttpAskTitoDexOnlineClient({
    http.Client? client,
    String endpoint = AskTitoDexConfig.workerUrl,
    this.timeout = const Duration(seconds: 20),
    Future<String> Function()? deviceKeyProvider,
  }) : _client = client ?? http.Client(),
       endpoint = endpoint.trim(),
       _deviceKeyProvider =
           deviceKeyProvider ?? askTitoDexSettings.anonymousDeviceKey;

  final http.Client _client;
  final String endpoint;
  final Duration timeout;
  final Future<String> Function() _deviceKeyProvider;

  bool get isConfigured => _isJourneyWorkerAskEndpoint(endpoint);

  @override
  Future<AskTitoDexWorkerStatus> checkStatus() async {
    if (!isConfigured) {
      throw const AskTitoDexOnlineException('worker_not_configured');
    }
    final uri = Uri.parse(endpoint).replace(path: _workerHealthPath);
    final response = await _client.get(uri).timeout(const Duration(seconds: 5));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AskTitoDexOnlineException('health_http_${response.statusCode}');
    }
    if (response.bodyBytes.length > _maxHealthResponseBytes) {
      throw const AskTitoDexOnlineException('health_response_too_large');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map ||
        decoded['ok'] != true ||
        decoded['capabilities'] is! Map) {
      throw const AskTitoDexOnlineException('invalid_health_response');
    }
    final capabilities = Map<String, dynamic>.from(
      decoded['capabilities'] as Map,
    );
    final providers =
        (capabilities['sourceProviders'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .where(
              (provider) => const {
                'pokeapi',
                'strategywiki',
                'wikidata',
              }.contains(provider),
            )
            .toList(growable: false);
    final webSearchProviders =
        (capabilities['webSearchProviders'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .where(
              (provider) => const {
                'tavily',
                'deepseek-native',
                'brave',
              }.contains(provider),
            )
            .toList(growable: false);
    final legacyBraveSearch = capabilities['braveSearch'] == true;
    return AskTitoDexWorkerStatus(
      availability: AskTitoDexAvailability.online,
      qwenConfigured: capabilities['publicModel'] == 'workers-ai-qwen',
      aiSearchEnabled: capabilities['aiSearch'] == true,
      curatedSourcesEnabled: capabilities['curatedSources'] == true,
      sourceProviders: providers,
      webSearchEnabled: capabilities['webSearch'] == true || legacyBraveSearch,
      webSearchProviders: webSearchProviders.isNotEmpty
          ? webSearchProviders
          : legacyBraveSearch
          ? const ['brave']
          : const [],
      externalProviderEnabled: capabilities['externalProvider'] == true,
    );
  }

  @override
  Future<AskTitoDexResult> ask(
    String question,
    AskTitoDexContext context,
  ) async {
    if (!isConfigured) {
      throw const AskTitoDexOnlineException('worker_not_configured');
    }
    final deviceKey = await _deviceKeyProvider();
    final response = await _client
        .post(
          Uri.parse(endpoint),
          headers: {
            'content-type': 'application/json',
            'x-titodex-device-key': deviceKey,
          },
          body: jsonEncode({
            'question': question,
            'context': context.toRequestJson(),
          }),
        )
        .timeout(timeout);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const AskTitoDexOnlineException('invalid_response');
    }
    final body = Map<String, dynamic>.from(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AskTitoDexOnlineException(
        body['errorCode'] as String? ?? 'http_${response.statusCode}',
      );
    }
    return AskTitoDexResult.fromJson(body);
  }
}

class AskTitoDexOnlineException implements Exception {
  const AskTitoDexOnlineException(this.code);

  final String code;
}

class AskTitoDexService {
  AskTitoDexService({
    ProgressionHintRepository? hints,
    AskTitoDexOnlineClient? online,
  }) : _hints = hints ?? progressionHintRepository,
       _online =
           online ??
           (_isJourneyWorkerAskEndpoint(AskTitoDexConfig.workerUrl)
               ? HttpAskTitoDexOnlineClient()
               : null);

  final ProgressionHintRepository _hints;
  final AskTitoDexOnlineClient? _online;

  Future<AskTitoDexWorkerStatus> checkConnection() async {
    if (!askTitoDexSettings.enabled) {
      return const AskTitoDexWorkerStatus.disabled();
    }
    final online = _online;
    if (online == null) {
      return const AskTitoDexWorkerStatus.unavailable('worker_not_configured');
    }
    try {
      return await online.checkStatus();
    } on TimeoutException {
      return const AskTitoDexWorkerStatus.unavailable('health_timeout');
    } on AskTitoDexOnlineException catch (error) {
      return AskTitoDexWorkerStatus.unavailable(error.code);
    } on Object {
      return const AskTitoDexWorkerStatus.unavailable('health_failed');
    }
  }

  Future<AskTitoDexContext> buildContext(AskTitoDexContext context) async =>
      context.copyWith(
        locationId: await _hints.resolveLocationId(context.locationLabel),
      );

  Future<AskTitoDexResult> ask(
    String question,
    AskTitoDexContext context, {
    void Function(AskTitoDexProgress progress)? onProgress,
  }) async {
    onProgress?.call(AskTitoDexProgress.checkingLocal);
    final local = await _hints.answer(question, context);
    if (local.status == AskTitoDexStatus.answered ||
        _online == null ||
        !askTitoDexSettings.enabled) {
      return local;
    }
    onProgress?.call(AskTitoDexProgress.contactingWorker);
    try {
      final online = await _online.ask(question, context);
      return online.withRuntimeTrace(onlineAttempted: true);
    } on TimeoutException {
      return local.withRuntimeTrace(
        onlineAttempted: true,
        errorCode: 'online_timeout_fallback',
      );
    } on AskTitoDexOnlineException catch (error) {
      return local.withRuntimeTrace(
        onlineAttempted: true,
        errorCode: 'online_${error.code}_fallback',
      );
    } on Object {
      return local.withRuntimeTrace(
        onlineAttempted: true,
        errorCode: 'online_failed_fallback',
      );
    }
  }
}

final askTitoDexService = AskTitoDexService();

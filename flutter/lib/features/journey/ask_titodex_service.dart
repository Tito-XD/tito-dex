import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ask_titodex_settings.dart';
import 'journey_pack_models.dart';
import 'journey_worker_config.dart';
import 'journey_pack_repository.dart';
import 'progression_hints.dart';

class AskTitoDexConfig {
  static const workerUrl = JourneyWorkerConfig.askUrl;
}

const _workerHealthPath = '/health';
const _maxHealthResponseBytes = 8192;
const _maxAskStreamResponseBytes = 64 * 1024;
const _maxAskRequestBytes = 10 * 1024;

String _encodeAskRequest(
  String question,
  AskTitoDexContext context,
  List<Map<String, String>> history,
) {
  final boundedHistory = <Map<String, String>>[];
  for (var index = 0; index + 1 < history.length; index += 2) {
    final user = history[index];
    final assistant = history[index + 1];
    if (user['role'] == 'user' &&
        assistant['role'] == 'assistant' &&
        user['content']?.isNotEmpty == true &&
        assistant['content']?.isNotEmpty == true) {
      boundedHistory.add(user);
      boundedHistory.add(assistant);
    }
  }
  String encode() => jsonEncode({
    'question': question,
    'context': context.toRequestJson(),
    if (boundedHistory.isNotEmpty) 'history': boundedHistory,
    if (context.journeyPacks.isNotEmpty)
      'journeyPacks': context.journeyPackRequestJson,
  });

  var body = encode();
  while (utf8.encode(body).length > _maxAskRequestBytes &&
      boundedHistory.length >= 2) {
    boundedHistory.removeRange(0, 2);
    body = encode();
  }
  if (utf8.encode(body).length > _maxAskRequestBytes) {
    throw const AskTitoDexOnlineException('request_too_large');
  }
  return body;
}

enum AskTitoDexProgress { checkingLocal, contactingWorker, revealingAnswer }

enum AskTitoDexAvailability { checking, online, disabled, unavailable }

class AskTitoDexWorkerStatus {
  const AskTitoDexWorkerStatus({
    required this.availability,
    this.qwenConfigured = false,
    this.aiSearchEnabled = false,
    this.dexBundleEnabled = false,
    this.curatedSourcesEnabled = false,
    this.experimentalAnswers = false,
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
  final bool dexBundleEnabled;
  final bool curatedSourcesEnabled;
  final bool experimentalAnswers;
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
  return JourneyWorkerConfig.askUri(value) != null;
}

abstract class AskTitoDexOnlineClient {
  Future<AskTitoDexResult> ask(
    String question,
    AskTitoDexContext context, {
    List<Map<String, String>> history = const [],
  });

  Future<AskTitoDexWorkerStatus> checkStatus();
}

class AskTitoDexOnlineStreamEvent {
  const AskTitoDexOnlineStreamEvent._({
    this.progress,
    this.answerDelta,
    this.result,
  });

  const AskTitoDexOnlineStreamEvent.progress(AskTitoDexProgress progress)
    : this._(progress: progress);

  const AskTitoDexOnlineStreamEvent.answerDelta(String delta)
    : this._(answerDelta: delta);

  const AskTitoDexOnlineStreamEvent.result(AskTitoDexResult result)
    : this._(result: result);

  final AskTitoDexProgress? progress;
  final String? answerDelta;
  final AskTitoDexResult? result;
}

abstract interface class AskTitoDexStreamingOnlineClient {
  Stream<AskTitoDexOnlineStreamEvent> askStream(
    String question,
    AskTitoDexContext context, {
    List<Map<String, String>> history = const [],
  });
}

class HttpAskTitoDexOnlineClient
    implements AskTitoDexOnlineClient, AskTitoDexStreamingOnlineClient {
  HttpAskTitoDexOnlineClient({
    http.Client? client,
    String endpoint = AskTitoDexConfig.workerUrl,
    this.timeout = const Duration(seconds: 35),
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
      dexBundleEnabled: capabilities['dexBundle'] == true,
      curatedSourcesEnabled: capabilities['curatedSources'] == true,
      experimentalAnswers: capabilities['experimentalAnswers'] == true,
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
    AskTitoDexContext context, {
    List<Map<String, String>> history = const [],
  }) async {
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
          body: _encodeAskRequest(question, context, history),
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

  @override
  Stream<AskTitoDexOnlineStreamEvent> askStream(
    String question,
    AskTitoDexContext context, {
    List<Map<String, String>> history = const [],
  }) async* {
    if (!isConfigured) {
      throw const AskTitoDexOnlineException('worker_not_configured');
    }
    final deviceKey = await _deviceKeyProvider();
    final request = http.Request('POST', Uri.parse(endpoint))
      ..headers.addAll({
        'content-type': 'application/json',
        'accept': 'application/x-ndjson, application/json',
        'x-titodex-device-key': deviceKey,
      })
      ..body = _encodeAskRequest(question, context, history);
    final response = await _client.send(request).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AskTitoDexOnlineException('http_${response.statusCode}');
    }

    var totalBytes = 0;
    var sawResult = false;
    final lines = response.stream
        .timeout(timeout)
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (line.trim().isEmpty) continue;
      totalBytes += utf8.encode(line).length + 1;
      if (totalBytes > _maxAskStreamResponseBytes) {
        throw const AskTitoDexOnlineException('stream_response_too_large');
      }
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        throw const AskTitoDexOnlineException('invalid_stream_event');
      }
      final body = Map<String, dynamic>.from(decoded);
      switch (body['type']) {
        case 'progress':
          if (body['stage'] == 'writing') {
            yield const AskTitoDexOnlineStreamEvent.progress(
              AskTitoDexProgress.revealingAnswer,
            );
          }
        case 'answer_delta':
          final delta = body['delta'];
          if (delta is! String || delta.isEmpty || delta.length > 80) {
            throw const AskTitoDexOnlineException('invalid_stream_delta');
          }
          yield AskTitoDexOnlineStreamEvent.answerDelta(delta);
        case 'result':
          if (body['result'] is! Map) {
            throw const AskTitoDexOnlineException('invalid_stream_result');
          }
          sawResult = true;
          yield AskTitoDexOnlineStreamEvent.result(
            AskTitoDexResult.fromJson(
              Map<String, dynamic>.from(body['result'] as Map),
            ),
          );
        default:
          // Older Workers ignore the Accept header and return the original
          // one-line JSON response. Treat it as the final event.
          if (body['status'] is! String) {
            throw const AskTitoDexOnlineException('invalid_stream_event');
          }
          sawResult = true;
          yield AskTitoDexOnlineStreamEvent.result(
            AskTitoDexResult.fromJson(body),
          );
      }
    }
    if (!sawResult) {
      throw const AskTitoDexOnlineException('stream_missing_result');
    }
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
    JourneyPackRepository? packs,
  }) : _hints = hints ?? progressionHintRepository,
       _packs = packs ?? journeyPackRepository,
       _online =
           online ??
           (_isJourneyWorkerAskEndpoint(AskTitoDexConfig.workerUrl)
               ? HttpAskTitoDexOnlineClient()
               : null);

  final ProgressionHintRepository _hints;
  final JourneyPackRepository _packs;
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

  Future<AskTitoDexContext> buildContext(AskTitoDexContext context) async {
    final values = await Future.wait<Object?>([
      _hints.resolveLocationId(context.locationLabel),
      _packs.referencesForGame(context.game),
    ]);
    return context.copyWith(
      locationId: values[0] as String?,
      journeyPacks: values[1] as List<JourneyPackReference>,
    );
  }

  Future<AskTitoDexResult> ask(
    String question,
    AskTitoDexContext context, {
    List<Map<String, String>> history = const [],
    void Function(AskTitoDexProgress progress)? onProgress,
    void Function(String delta)? onAnswerDelta,
  }) async {
    onProgress?.call(AskTitoDexProgress.checkingLocal);
    final local = await _hints.answer(question, context);
    final client = _online;
    if (local.status == AskTitoDexStatus.answered ||
        client == null ||
        !askTitoDexSettings.enabled) {
      return local;
    }
    onProgress?.call(AskTitoDexProgress.contactingWorker);
    try {
      if (client is AskTitoDexStreamingOnlineClient) {
        AskTitoDexResult? online;
        final streamedAnswer = StringBuffer();
        final streamingClient = client as AskTitoDexStreamingOnlineClient;
        await for (final event in streamingClient.askStream(
          question,
          context,
          history: history,
        )) {
          if (event.progress case final progress?) {
            onProgress?.call(progress);
          }
          if (event.answerDelta case final delta?) {
            if (streamedAnswer.length + delta.length > 1200) {
              throw const AskTitoDexOnlineException('stream_answer_too_large');
            }
            streamedAnswer.write(delta);
            onAnswerDelta?.call(delta);
          }
          if (event.result case final result?) online = result;
        }
        if (online == null) {
          throw const AskTitoDexOnlineException('stream_missing_result');
        }
        final streamed = streamedAnswer.toString();
        if (streamed.isNotEmpty && streamed != online.answer) {
          throw const AskTitoDexOnlineException('stream_answer_mismatch');
        }
        return online.withRuntimeTrace(onlineAttempted: true);
      }
      final online = await client.ask(question, context, history: history);
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

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
}

class HttpAskTitoDexOnlineClient implements AskTitoDexOnlineClient {
  HttpAskTitoDexOnlineClient({
    http.Client? client,
    String endpoint = AskTitoDexConfig.workerUrl,
    this.timeout = const Duration(seconds: 8),
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

  Future<AskTitoDexContext> buildContext(AskTitoDexContext context) async =>
      context.copyWith(
        locationId: await _hints.resolveLocationId(context.locationLabel),
      );

  Future<AskTitoDexResult> ask(
    String question,
    AskTitoDexContext context,
  ) async {
    final local = await _hints.answer(question, context);
    if (local.status == AskTitoDexStatus.answered ||
        _online == null ||
        !askTitoDexSettings.enabled) {
      return local;
    }
    try {
      return await _online.ask(question, context);
    } on TimeoutException {
      return local;
    } on AskTitoDexOnlineException {
      return local;
    } on Object {
      return local;
    }
  }
}

final askTitoDexService = AskTitoDexService();

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'journey_pack_models.dart';
import 'journey_worker_config.dart';

class JourneyPackClientException implements Exception {
  const JourneyPackClientException(this.code);

  final String code;
}

class JourneyPackCancelToken {
  bool _cancelled = false;
  Future<void> Function()? _cancelActive;

  bool get cancelled => _cancelled;

  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    await _cancelActive?.call();
  }

  void bind(Future<void> Function()? callback) {
    _cancelActive = callback;
    if (_cancelled) unawaited(callback?.call());
  }
}

class JourneyPackClient {
  JourneyPackClient({
    http.Client? client,
    String workerAskUrl = JourneyWorkerConfig.askUrl,
    this.catalogTimeout = const Duration(seconds: 12),
    this.downloadTimeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _catalogUri = JourneyWorkerConfig.packCatalogUri(workerAskUrl);

  final http.Client _client;
  final bool _ownsClient;
  final Uri? _catalogUri;
  final Duration catalogTimeout;
  final Duration downloadTimeout;

  bool get configured => _catalogUri != null;

  Future<JourneyPackCatalog> fetchCatalog() async {
    final uri = _catalogUri;
    if (uri == null) {
      throw const JourneyPackClientException('worker_not_configured');
    }
    final request = http.Request('GET', uri)..followRedirects = false;
    final response = await _client.send(request).timeout(catalogTimeout);
    if (response.request?.url != uri) {
      throw const JourneyPackClientException('catalog_redirect_rejected');
    }
    if (response.statusCode != 200) {
      throw JourneyPackClientException('catalog_http_${response.statusCode}');
    }
    final catalogLength = response.contentLength;
    if (catalogLength != null && catalogLength > 256 * 1024) {
      throw const JourneyPackClientException('catalog_too_large');
    }
    final bodyBytes = await _readBounded(
      response.stream,
      maxBytes: 256 * 1024,
      timeout: catalogTimeout,
      tooLargeCode: 'catalog_too_large',
    );
    try {
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      if (decoded is! Map) {
        throw const FormatException('Catalog must be an object');
      }
      return JourneyPackCatalog.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException {
      throw const JourneyPackClientException('catalog_invalid');
    }
  }

  Uri objectUri(JourneyPackDescriptor descriptor) {
    final catalogUri = _catalogUri;
    if (catalogUri == null) {
      throw const JourneyPackClientException('worker_not_configured');
    }
    final uri = catalogUri.replace(path: descriptor.contentPath);
    if (uri.origin != catalogUri.origin ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const JourneyPackClientException('object_path_invalid');
    }
    return uri;
  }

  Future<Uint8List> download(
    JourneyPackDescriptor descriptor, {
    JourneyPackCancelToken? cancelToken,
    void Function(int downloaded, int total)? onProgress,
  }) async {
    if (!descriptor.isCompatible) {
      throw const JourneyPackClientException('bundle_version_incompatible');
    }
    final uri = objectUri(descriptor);
    final request = http.Request('GET', uri)..followRedirects = false;
    final response = await _client.send(request).timeout(downloadTimeout);
    if (response.request?.url != uri) {
      throw const JourneyPackClientException('object_redirect_rejected');
    }
    if (response.statusCode != 200) {
      throw JourneyPackClientException('object_http_${response.statusCode}');
    }
    final contentLength = response.contentLength;
    if (contentLength != null &&
        contentLength >= 0 &&
        contentLength != descriptor.sizeBytes) {
      throw const JourneyPackClientException('pack_size_mismatch');
    }

    final bytes = BytesBuilder(copy: false);
    late Digest digest;
    final digestSink = sha256.startChunkedConversion(
      ChunkedConversionSink<Digest>.withCallback(
        (digests) => digest = digests.single,
      ),
    );
    final iterator = StreamIterator<List<int>>(
      response.stream.timeout(downloadTimeout),
    );
    cancelToken?.bind(iterator.cancel);
    var downloaded = 0;
    try {
      while (await iterator.moveNext()) {
        if (cancelToken?.cancelled == true) {
          throw const JourneyPackClientException('cancelled');
        }
        final chunk = iterator.current;
        downloaded += chunk.length;
        if (downloaded > descriptor.sizeBytes ||
            downloaded > journeyPackMaxBytes) {
          throw const JourneyPackClientException('pack_size_mismatch');
        }
        bytes.add(chunk);
        digestSink.add(chunk);
        onProgress?.call(downloaded, descriptor.sizeBytes);
      }
      if (cancelToken?.cancelled == true) {
        throw const JourneyPackClientException('cancelled');
      }
    } finally {
      cancelToken?.bind(null);
      await iterator.cancel();
      digestSink.close();
    }
    if (downloaded != descriptor.sizeBytes) {
      throw const JourneyPackClientException('pack_size_mismatch');
    }
    if (digest.toString() != descriptor.sha256Hex) {
      throw const JourneyPackClientException('pack_integrity_failed');
    }
    return bytes.takeBytes();
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

Future<Uint8List> _readBounded(
  Stream<List<int>> stream, {
  required int maxBytes,
  required Duration timeout,
  required String tooLargeCode,
}) async {
  final bytes = BytesBuilder(copy: false);
  var length = 0;
  await for (final chunk in stream.timeout(timeout)) {
    length += chunk.length;
    if (length > maxBytes) throw JourneyPackClientException(tooLargeCode);
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}

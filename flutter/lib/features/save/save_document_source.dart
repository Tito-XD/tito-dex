import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SaveDocument {
  const SaveDocument({
    required this.uri,
    required this.fileName,
    required this.bytes,
    this.modifiedMs,
  });

  final String uri;
  final String fileName;
  final Uint8List bytes;
  final int? modifiedMs;
}

abstract interface class SaveDocumentSource {
  Future<SaveDocument?> pick();

  Future<SaveDocument?> read(String uri);

  Future<void> release(String uri);
}

class PlatformSaveDocumentSource implements SaveDocumentSource {
  static const _channel = MethodChannel('com.tito.titodex/save_document');

  @override
  Future<SaveDocument?> pick() async {
    if (!kIsWeb && Platform.isAndroid) {
      final raw = await _channel.invokeMapMethod<Object?, Object?>(
        'pickSaveDocument',
      );
      return _decode(raw);
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['sav'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) {
      return null;
    }
    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) {
      return null;
    }
    return SaveDocument(
      uri: file.path ?? file.name,
      fileName: file.name,
      bytes: bytes,
      modifiedMs: file.path == null
          ? null
          : (await File(file.path!).stat()).modified.millisecondsSinceEpoch,
    );
  }

  @override
  Future<SaveDocument?> read(String uri) async {
    if (!kIsWeb && Platform.isAndroid) {
      final raw = await _channel.invokeMapMethod<Object?, Object?>(
        'readSaveDocument',
        {'uri': uri},
      );
      return _decode(raw);
    }
    if (kIsWeb) {
      return null;
    }
    final file = File(uri);
    if (!await file.exists()) {
      return null;
    }
    final stat = await file.stat();
    return SaveDocument(
      uri: uri,
      fileName: uri.split(Platform.pathSeparator).last,
      bytes: await file.readAsBytes(),
      modifiedMs: stat.modified.millisecondsSinceEpoch,
    );
  }

  @override
  Future<void> release(String uri) async {
    if (!kIsWeb && Platform.isAndroid) {
      await _channel.invokeMethod<void>('releaseSaveDocument', {'uri': uri});
    }
  }

  SaveDocument? _decode(Map<Object?, Object?>? raw) {
    if (raw == null) {
      return null;
    }
    final bytes = raw['bytes'];
    final uri = raw['uri'];
    final fileName = raw['fileName'];
    if (bytes is! Uint8List || uri is! String || fileName is! String) {
      return null;
    }
    return SaveDocument(
      uri: uri,
      fileName: fileName,
      bytes: bytes,
      modifiedMs: raw['modifiedMs'] as int?,
    );
  }
}

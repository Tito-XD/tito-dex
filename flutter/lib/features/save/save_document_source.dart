import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

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
    if (!kIsWeb && Platform.isIOS) {
      return _persistPickedCopy(file.name, bytes);
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
    if (!kIsWeb && Platform.isIOS) {
      // Only remove the copy this source persisted itself; never touch a
      // user-owned file outside the app container.
      if (uri.contains('/save_import/')) {
        final file = File(uri);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }

  /// iOS document picker hands out a short-lived temporary URL, so persist
  /// a copy inside the app container to keep the save readable across
  /// launches (mirrors the persistable-permission flow on Android).
  Future<SaveDocument> _persistPickedCopy(
    String fileName,
    Uint8List bytes,
  ) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/save_import');
    await dir.create(recursive: true);
    final dest = File('${dir.path}/$fileName');
    await dest.writeAsBytes(bytes, flush: true);
    final stat = await dest.stat();
    return SaveDocument(
      uri: dest.path,
      fileName: fileName,
      bytes: bytes,
      modifiedMs: stat.modified.millisecondsSinceEpoch,
    );
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

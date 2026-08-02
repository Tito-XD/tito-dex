import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps an Android Dex download alive after its progress dialog is minimized
/// and mirrors the same overall percentage into a foreground notification.
class DexDownloadNotification {
  static const _channel = MethodChannel(
    'com.tito.titodex/dex_download_notification',
  );

  bool _active = false;
  int _lastProgress = -1;
  String? _lastText;

  bool get active => _active;

  Future<bool> start({
    required int progress,
    required String title,
    required String text,
  }) async {
    if (!_supported) {
      return false;
    }
    _active = true;
    _lastProgress = progress;
    _lastText = text;
    try {
      return await _channel.invokeMethod<bool>('start', {
            'progress': progress,
            'title': title,
            'text': text,
          }) ??
          false;
    } on PlatformException catch (error) {
      _active = false;
      debugPrint('DexDownloadNotification.start failed: $error');
      return false;
    }
  }

  Future<void> update({required int progress, required String text}) async {
    if (!_active || !_supported) {
      return;
    }
    if (_lastProgress == progress && _lastText == text) {
      return;
    }
    _lastProgress = progress;
    _lastText = text;
    try {
      await _channel.invokeMethod<void>('update', {
        'progress': progress,
        'text': text,
      });
    } on PlatformException catch (error) {
      debugPrint('DexDownloadNotification.update failed: $error');
    }
  }

  Future<void> complete({required String title, required String text}) =>
      _finish('complete', title: title, text: text);

  Future<void> fail({required String title, required String text}) =>
      _finish('fail', title: title, text: text);

  Future<void> cancel() async {
    if (!_active || !_supported) {
      return;
    }
    _active = false;
    try {
      await _channel.invokeMethod<void>('cancel');
    } on PlatformException catch (error) {
      debugPrint('DexDownloadNotification.cancel failed: $error');
    }
  }

  Future<void> _finish(
    String method, {
    required String title,
    required String text,
  }) async {
    if (!_active || !_supported) {
      return;
    }
    _active = false;
    try {
      await _channel.invokeMethod<void>(method, {'title': title, 'text': text});
    } on PlatformException catch (error) {
      debugPrint('DexDownloadNotification.$method failed: $error');
    }
  }

  bool get _supported => !kIsWeb && Platform.isAndroid;
}

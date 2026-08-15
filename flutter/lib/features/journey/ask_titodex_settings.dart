import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _enabledKey = 'titodex.ask_titodex.enabled';
const _noticeAcknowledgedKey = 'titodex.ask_titodex.notice_acknowledged_v3';
const _consentVersionKey = 'titodex.ask_titodex.consent_version';
const _currentConsentVersion = 1;
const _anonymousDeviceKey = 'titodex.ask_titodex.anonymous_device_key';
const _extensionEnabledKey = 'titodex.extension.journey_assistant.enabled';
const _searchDisplayModeKey =
    'titodex.extension.journey_assistant.search_display_mode';

enum SearchAssistantDisplayMode {
  prominent('prominent'),
  compact('compact'),
  hidden('hidden');

  const SearchAssistantDisplayMode(this.storageValue);
  final String storageValue;

  static SearchAssistantDisplayMode fromStorage(String? value) {
    for (final mode in values) {
      if (mode.storageValue == value) return mode;
    }
    return SearchAssistantDisplayMode.compact;
  }
}

class AskTitoDexSettings extends ChangeNotifier {
  bool _enabled = false;
  bool _noticeAcknowledged = false;
  bool _extensionEnabled = false;
  SearchAssistantDisplayMode _searchDisplayMode =
      SearchAssistantDisplayMode.compact;
  bool _loaded = false;

  bool get enabled => _enabled;
  bool get noticeAcknowledged => _noticeAcknowledged;
  bool get extensionEnabled => _extensionEnabled;
  SearchAssistantDisplayMode get searchDisplayMode => _searchDisplayMode;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final hasCurrentConsent =
        (preferences.getInt(_consentVersionKey) ?? 0) >=
            _currentConsentVersion &&
        (preferences.getBool(_noticeAcknowledgedKey) ?? false);
    _noticeAcknowledged = hasCurrentConsent;
    // Older builds briefly defaulted the built-in entry to enabled. Do not
    // carry that state across the consent boundary: an upgraded install must
    // explicitly accept the current disclosure before any entry or online
    // capability is enabled.
    _extensionEnabled =
        hasCurrentConsent &&
        (preferences.getBool(_extensionEnabledKey) ?? false);
    _enabled =
        hasCurrentConsent &&
        _extensionEnabled &&
        (preferences.getBool(_enabledKey) ?? false);
    _searchDisplayMode = SearchAssistantDisplayMode.fromStorage(
      preferences.getString(_searchDisplayModeKey),
    );
    _loaded = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (value && (!_noticeAcknowledged || !_extensionEnabled)) return;
    _enabled = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, value);
    notifyListeners();
  }

  Future<void> acknowledgeNotice() async {
    _noticeAcknowledged = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_noticeAcknowledgedKey, true);
    await preferences.setInt(_consentVersionKey, _currentConsentVersion);
    notifyListeners();
  }

  /// Accepts the first-use disclosure and enables both the assistant entry
  /// and its online fallback. This is the only first-use activation path.
  Future<void> enableWithConsent() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_noticeAcknowledgedKey, true);
    await preferences.setInt(_consentVersionKey, _currentConsentVersion);
    await preferences.setBool(_extensionEnabledKey, true);
    await preferences.setBool(_enabledKey, true);
    _noticeAcknowledged = true;
    _extensionEnabled = true;
    _enabled = true;
    notifyListeners();
  }

  Future<void> setExtensionEnabled(bool value) async {
    if (value && !_noticeAcknowledged) return;
    _extensionEnabled = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_extensionEnabledKey, value);
    if (!value) {
      _enabled = false;
      await preferences.setBool(_enabledKey, false);
    }
    notifyListeners();
  }

  Future<void> setSearchDisplayMode(SearchAssistantDisplayMode value) async {
    _searchDisplayMode = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_searchDisplayModeKey, value.storageValue);
    notifyListeners();
  }

  /// Returns an app-local random key used only for Worker abuse protection.
  /// It is not derived from the user, device hardware, or save file.
  Future<String> anonymousDeviceKey() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_anonymousDeviceKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    final value = base64UrlEncode(bytes).replaceAll('=', '');
    await preferences.setString(_anonymousDeviceKey, value);
    return value;
  }

  @visibleForTesting
  void resetForTest() {
    _enabled = false;
    _noticeAcknowledged = false;
    _extensionEnabled = false;
    _searchDisplayMode = SearchAssistantDisplayMode.compact;
    _loaded = false;
  }
}

final askTitoDexSettings = AskTitoDexSettings();

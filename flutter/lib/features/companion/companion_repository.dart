import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-chosen standby companion; [formKey] selects a non-default form and
/// [isShiny] forces the shiny variant. A null [formKey] keeps the species
/// default form.
class CompanionChoice {
  const CompanionChoice({
    required this.pokemonId,
    required this.nameZh,
    this.formKey,
    this.isShiny = false,
    this.animationSourceUrl,
    this.animationLabel,
    this.crySourceUrl,
    this.cryLabel,
  });

  final int pokemonId;
  final String nameZh;
  final String? formKey;
  final bool isShiny;
  final String? animationSourceUrl;
  final String? animationLabel;
  final String? crySourceUrl;
  final String? cryLabel;

  CompanionChoice copyWith({
    String? formKey,
    bool? isShiny,
    String? animationSourceUrl,
    String? animationLabel,
    String? crySourceUrl,
    String? cryLabel,
  }) => CompanionChoice(
    pokemonId: pokemonId,
    nameZh: nameZh,
    formKey: formKey ?? this.formKey,
    isShiny: isShiny ?? this.isShiny,
    animationSourceUrl: animationSourceUrl ?? this.animationSourceUrl,
    animationLabel: animationLabel ?? this.animationLabel,
    crySourceUrl: crySourceUrl ?? this.crySourceUrl,
    cryLabel: cryLabel ?? this.cryLabel,
  );
}

/// Persists the standby companion selection (Settings → 同行宝可梦).
/// Only the id and display name are stored — the animated sprite itself is
/// fetched on demand, never bundled.
class CompanionRepository extends ChangeNotifier {
  static const _idKey = 'companion.pokemonId';
  static const _nameKey = 'companion.nameZh';
  static const _formKey = 'companion.formKey';
  static const _shinyKey = 'companion.isShiny';
  static const _animationSourceKey = 'companion.animationSourceUrl';
  static const _animationLabelKey = 'companion.animationLabel';
  static const _crySourceKey = 'companion.crySourceUrl';
  static const _cryLabelKey = 'companion.cryLabel';
  static const _enabledKey = 'companion.enabled';
  static const _sizeScaleKey = 'companion.sizeScale';
  static const _offsetXKey = 'companion.offsetX';
  static const _offsetYKey = 'companion.offsetY';

  /// Slider bounds — 0.75 lets the companion shrink below the default,
  /// 1.5 is a hard ceiling per product decision. Default stays 1.0.
  static const double minSizeScale = 0.75;
  static const double maxSizeScale = 1.5;
  static const double defaultSizeScale = 1.0;

  /// Alignment-like position on the home screen (-1..1). Default keeps the
  /// companion anchored at the bottom-right corner.
  static const double defaultOffsetX = 1.0;
  static const double defaultOffsetY = 1.0;

  CompanionChoice? _choice;
  bool _enabled = true;
  double _sizeScale = defaultSizeScale;
  double _offsetX = defaultOffsetX;
  double _offsetY = defaultOffsetY;
  bool _loaded = false;

  CompanionChoice? get choice => _choice;

  /// Whether the standby companion shows on the home dashboard (default on).
  bool get enabled => _enabled;

  /// User size multiplier applied on top of the height-based sprite size.
  double get sizeScale => _sizeScale;

  /// Horizontal alignment on the home screen (-1 left, 1 right).
  double get offsetX => _offsetX;

  /// Vertical alignment on the home screen (-1 top, 1 bottom).
  double get offsetY => _offsetY;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_idKey);
    final name = prefs.getString(_nameKey);
    final formKey = prefs.getString(_formKey);
    final isShiny = prefs.getBool(_shinyKey) ?? false;
    final animationSourceUrl = prefs.getString(_animationSourceKey);
    final animationLabel = prefs.getString(_animationLabelKey);
    final crySourceUrl = prefs.getString(_crySourceKey);
    final cryLabel = prefs.getString(_cryLabelKey);
    final enabled = prefs.getBool(_enabledKey) ?? true;
    final sizeScale = prefs.getDouble(_sizeScaleKey) ?? defaultSizeScale;
    final offsetX = prefs.getDouble(_offsetXKey) ?? defaultOffsetX;
    final offsetY = prefs.getDouble(_offsetYKey) ?? defaultOffsetY;
    _loaded = true;
    _enabled = enabled;
    _sizeScale = sizeScale.clamp(minSizeScale, maxSizeScale);
    _offsetX = offsetX.clamp(-1.0, 1.0);
    _offsetY = offsetY.clamp(-1.0, 1.0);
    if (id != null && id > 0) {
      _choice = CompanionChoice(
        pokemonId: id,
        nameZh: name ?? '#$id',
        formKey: formKey,
        isShiny: isShiny,
        animationSourceUrl: animationSourceUrl,
        animationLabel: animationLabel,
        crySourceUrl: crySourceUrl,
        cryLabel: cryLabel,
      );
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<void> setSizeScale(double scale) async {
    _sizeScale = scale.clamp(minSizeScale, maxSizeScale);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_sizeScaleKey, _sizeScale);
  }

  /// Update the in-memory offset and notify listeners without writing to disk.
  /// Use this while a drag is in progress to avoid spamming the platform
  /// channel with SharedPreferences writes on every frame.
  void setOffsetLocal(double x, double y) {
    _offsetX = x.clamp(-1.0, 1.0);
    _offsetY = y.clamp(-1.0, 1.0);
    notifyListeners();
  }

  Future<void> setOffset(double x, double y) async {
    _offsetX = x.clamp(-1.0, 1.0);
    _offsetY = y.clamp(-1.0, 1.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_offsetXKey, _offsetX);
    await prefs.setDouble(_offsetYKey, _offsetY);
  }

  Future<void> resetOffset() => setOffset(defaultOffsetX, defaultOffsetY);

  Future<void> save(CompanionChoice choice) async {
    _choice = choice;
    _loaded = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_idKey, choice.pokemonId);
    await prefs.setString(_nameKey, choice.nameZh);
    if (choice.formKey != null && choice.formKey!.isNotEmpty) {
      await prefs.setString(_formKey, choice.formKey!);
    } else {
      await prefs.remove(_formKey);
    }
    await prefs.setBool(_shinyKey, choice.isShiny);
    await _setOptionalString(
      prefs,
      _animationSourceKey,
      choice.animationSourceUrl,
    );
    await _setOptionalString(prefs, _animationLabelKey, choice.animationLabel);
    await _setOptionalString(prefs, _crySourceKey, choice.crySourceUrl);
    await _setOptionalString(prefs, _cryLabelKey, choice.cryLabel);
  }

  static Future<void> _setOptionalString(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value != null && value.isNotEmpty) {
      await prefs.setString(key, value);
    } else {
      await prefs.remove(key);
    }
  }

  static String _patsKey(int pokemonId) => 'companion.pats.$pokemonId';

  /// Lifetime pat count for a species — drives the friendship badge and the
  /// intimacy quote tiers across restarts.
  Future<int> patCountFor(int pokemonId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_patsKey(pokemonId)) ?? 0;
  }

  Future<int> incrementPats(int pokemonId) async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt(_patsKey(pokemonId)) ?? 0) + 1;
    await prefs.setInt(_patsKey(pokemonId), next);
    return next;
  }

  Future<void> clear() async {
    _choice = null;
    _loaded = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_idKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_formKey);
    await prefs.remove(_shinyKey);
    await prefs.remove(_animationSourceKey);
    await prefs.remove(_animationLabelKey);
    await prefs.remove(_crySourceKey);
    await prefs.remove(_cryLabelKey);
  }
}

final companionRepository = CompanionRepository();

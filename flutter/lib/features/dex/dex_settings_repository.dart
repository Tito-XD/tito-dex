import 'package:shared_preferences/shared_preferences.dart';

import 'dex_scope.dart';

const _gameVersionKey = 'titodex.dex.default_game_version';
const _regionalScopeKey = 'titodex.dex.default_regional_scope';

class DexSettingsRepository {
  Future<DexScope> loadDefaultScope() async {
    final prefs = await SharedPreferences.getInstance();
    final gameVersion = DexGameVersion.fromStorageKey(
          prefs.getString(_gameVersionKey),
        ) ??
        DexGameVersion.hgss;
    final regionalScope = DexRegionalPokedex.fromStorageKey(
          prefs.getString(_regionalScopeKey),
        ) ??
        DexRegionalPokedex.national;
    return DexScope(
      gameVersion: gameVersion,
      regionalScope: regionalScope,
    );
  }

  Future<DexGameVersion> loadDefaultGameVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return DexGameVersion.fromStorageKey(prefs.getString(_gameVersionKey)) ??
        DexGameVersion.hgss;
  }

  Future<void> saveDefaultGameVersion(DexGameVersion version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gameVersionKey, version.name);
  }

  Future<void> saveDefaultScope(DexScope scope) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gameVersionKey, scope.gameVersion.name);
    await prefs.setString(_regionalScopeKey, scope.regionalScope.name);
  }
}

final dexSettingsRepository = DexSettingsRepository();

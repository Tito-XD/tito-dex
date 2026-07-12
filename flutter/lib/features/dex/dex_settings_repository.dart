import 'package:shared_preferences/shared_preferences.dart';

import '../game/game_edition.dart';
import 'dex_scope.dart';

const _gameVersionKey = 'titodex.dex.default_game_version';
const _regionalScopeKey = 'titodex.dex.default_regional_scope';
// v0.4.0: Single global game edition (B2) — shared by home/dex/settings.
const _globalEditionKey = 'titodex.game.global_edition';

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

  /// v0.4.0: Load persisted global [GameEdition] (falls back to HGSS).
  Future<GameEdition> loadGlobalEdition() async {
    final prefs = await SharedPreferences.getInstance();
    return GameEdition.fromStorageKey(prefs.getString(_globalEditionKey)) ??
        GameEdition.hgss;
  }

  /// v0.4.0: Persist global [GameEdition] for router refresh + dex bar.
  Future<void> saveGlobalEdition(GameEdition edition) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_globalEditionKey, edition.name);
  }
}

final dexSettingsRepository = DexSettingsRepository();

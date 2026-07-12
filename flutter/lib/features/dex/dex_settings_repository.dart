import 'package:shared_preferences/shared_preferences.dart';

import '../game/game_edition.dart';
import '../game/game_edition_repository.dart';
import 'dex_game_scope.dart';
import 'dex_scope.dart';

const _regionalScopeKey = 'titodex.dex.default_regional_scope';

class DexSettingsRepository {
  Future<DexScope> loadDefaultScope() async {
    final gameEdition = await gameEditionRepository.loadEdition();
    final prefs = await SharedPreferences.getInstance();
    final regionalScope = DexRegionalPokedex.fromStorageKey(
          prefs.getString(_regionalScopeKey),
        ) ??
        gameEdition.defaultRegionalPokedex;
    return DexScope(
      gameEdition: gameEdition,
      regionalScope: regionalScope,
    );
  }

  Future<GameEdition> loadDefaultGameEdition() async {
    return gameEditionRepository.loadEdition();
  }

  @Deprecated('Use loadDefaultGameEdition')
  Future<DexGameVersion> loadDefaultGameVersion() async {
    final edition = await loadDefaultGameEdition();
    return DexGameVersion.fromGameEdition(edition);
  }

  Future<void> saveDefaultGameEdition(GameEdition edition) async {
    await gameEditionRepository.save(edition);
  }

  @Deprecated('Use saveDefaultGameEdition')
  Future<void> saveDefaultGameVersion(DexGameVersion version) async {
    await saveDefaultGameEdition(version.edition);
  }

  Future<void> saveDefaultScope(DexScope scope) async {
    await gameEditionRepository.save(scope.gameEdition);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_regionalScopeKey, scope.regionalScope.name);
  }
}

final dexSettingsRepository = DexSettingsRepository();

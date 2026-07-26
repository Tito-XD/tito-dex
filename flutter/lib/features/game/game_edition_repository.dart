import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_edition.dart';

const _globalGameEditionKey = 'titodex.global_game_edition';
const _globalGameFlavorKey = 'titodex.global_game_flavor';
const _autoSourceSaveGameKey = 'titodex.global_game_edition_auto_source';

class GameEditionRepository extends ChangeNotifier {
  GameEdition _edition = defaultGameEdition;
  bool _loaded = false;

  GameEdition get edition => _edition;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final slug = prefs.getString(_globalGameEditionKey);
    final base = gameEditionFromSlug(slug) ?? defaultGameEdition;
    final flavor = prefs.getString(_globalGameFlavorKey);
    _edition = base.withFlavor(flavor);
    _loaded = true;
    notifyListeners();
  }

  Future<GameEdition> loadEdition() async {
    if (!_loaded) {
      await load();
    }
    return _edition;
  }

  Future<void> save(GameEdition edition) async {
    _edition = edition;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_globalGameEditionKey, edition.slug);
    if (edition.selectedFlavor == null) {
      await prefs.remove(_globalGameFlavorKey);
    } else {
      await prefs.setString(_globalGameFlavorKey, edition.selectedFlavor!);
    }
    notifyListeners();
  }

  Future<void> saveSlug(String slug) async {
    final edition = gameEditionFromSlug(slug) ?? defaultGameEdition;
    await save(edition);
  }

  /// Auto-selects the edition matching a freshly parsed save.
  ///
  /// With [force] (explicit user import) the edition is applied
  /// unconditionally; otherwise it only switches when the save's game differs
  /// from the last one auto-applied, so a background startup re-sync never
  /// fights a manual edition pick made afterwards. Returns whether the global
  /// edition changed.
  Future<bool> applyForSaveGame(String? saveGame, {bool force = false}) async {
    final target = gameEditionForSaveGame(saveGame);
    if (target == null) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final lastApplied = prefs.getString(_autoSourceSaveGameKey);
    if (!force && lastApplied == saveGame) {
      return false;
    }
    await prefs.setString(_autoSourceSaveGameKey, saveGame!);
    await save(target);
    return true;
  }
}

final gameEditionRepository = GameEditionRepository();

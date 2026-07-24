import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_edition.dart';

const _globalGameEditionKey = 'titodex.global_game_edition';
const _globalGameFlavorKey = 'titodex.global_game_flavor';

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
}

final gameEditionRepository = GameEditionRepository();

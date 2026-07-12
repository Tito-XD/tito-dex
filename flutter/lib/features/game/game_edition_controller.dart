/// v0.4.0 — App-wide [GameEdition] state (B2 single global version).
///
/// Wired into GoRouter [refreshListenable] so home/dex/detail/search refresh
/// immediately after picker selection (fixes B1 stale UI).
library;

import 'package:flutter/foundation.dart';

import '../dex/dex_settings_repository.dart';
import 'game_edition.dart';

class GameEditionController extends ChangeNotifier {
  GameEditionController({GameEdition initial = GameEdition.hgss})
      : _edition = initial;

  GameEdition _edition;

  GameEdition get edition => _edition;

  /// Load persisted edition; call once during app bootstrap.
  Future<void> loadFromSettings() async {
    _edition = await dexSettingsRepository.loadGlobalEdition();
    notifyListeners();
  }

  /// Persist and notify — used by home picker, dex bar, settings.
  Future<void> setEdition(GameEdition edition) async {
    if (_edition == edition) {
      return;
    }
    _edition = edition;
    await dexSettingsRepository.saveGlobalEdition(edition);
    notifyListeners();
  }
}

/// Process-wide singleton for router refresh + InheritedWidget-less access.
final gameEditionController = GameEditionController();

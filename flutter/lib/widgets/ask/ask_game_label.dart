import '../../features/dex/dex_game_scope.dart';
import '../../features/game/game_edition.dart';

String askGameLabel(String game) => game == 'general'
    ? GameEdition.general.selectedLabel
    : flavorVersionLabelZh(game);

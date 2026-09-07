import '../features/dex/dex_models.dart';
import 'app_locale.dart';

String localizedName({required String nameEn, required String nameZh}) {
  if (AppLocale.instance.isEnglish && nameEn.trim().isNotEmpty) {
    return nameEn;
  }
  return nameZh;
}

extension LocalizedPokemonSummary on PokemonSummary {
  String get displayName => localizedName(nameEn: nameEn, nameZh: nameZh);
}

extension LocalizedEvolutionNode on EvolutionNode {
  String get displayName => localizedName(nameEn: nameEn, nameZh: nameZh);
}

extension LocalizedCachedAbility on CachedAbility {
  String get displayName => localizedName(nameEn: nameEn, nameZh: nameZh);
}

extension LocalizedCachedMove on CachedMove {
  String get displayName => localizedName(nameEn: nameEn, nameZh: nameZh);
}

extension LocalizedPokemonAbility on PokemonAbility {
  String get displayName {
    final name = localizedName(nameEn: nameEn, nameZh: nameZh);
    if (gameLabelsZh.isEmpty) {
      return name;
    }
    return AppLocale.pick(
      zh: '$name（${gameLabelsZh.join('、')}）',
      en: '$name (${gameLabelsZh.join(', ')})',
    );
  }
}

extension LocalizedPokemonFormDetail on PokemonFormDetail {
  String get displayName => localizedName(nameEn: nameEn, nameZh: nameZh);
}

extension LocalizedPokemonFormKind on PokemonFormKind {
  String get label => AppLocale.pick(
    zh: labelZh,
    en: switch (this) {
      PokemonFormKind.regional => 'Regional form',
      PokemonFormKind.mega => 'Mega Evolution',
      PokemonFormKind.gigantamax => 'Gigantamax',
      PokemonFormKind.battle => 'Battle form',
      PokemonFormKind.form => 'Form',
      PokemonFormKind.cosmetic => 'Cosmetic form',
    },
  );
}

/// Which evolution branch each Pokémon *form* actually takes.
///
/// PokeAPI's evolution chain is species-level: 喵喵 lists 猫老大 and 喵头目 as
/// siblings, 卡蒂狗 lists a single 风速狗, and nothing in the payload says that
/// the first pair is a regional split or that Hisuian Growlithe becomes the
/// Hisuian Arcanine rather than the ordinary one. That mapping is curated
/// knowledge, so it lives here.
///
/// Keys are form keys as they appear in the bundle (`forms[].key`); values are
/// the children reachable *from that form*, in display order. An empty list
/// means the form is a dead end (default 直冲熊 never becomes 堵拦熊).
/// A form key that is absent from the table is not filtered at all — the full
/// species chain is shown, which is the right answer for Mega/G-Max/cosmetic
/// forms that share their species' evolution.
///
/// Kept structural on purpose: `formSuffix` is a slug, and the Chinese variant
/// label is composed from [formVariantLabelZh] below. Bundles ship slugs, the
/// app ships labels.
///
/// Bundle v13+ carries a per-form `evolutionChain` built from the mirror of
/// this table in `tools/form_evolution_chains.py`, with real form sprites.
/// This table stays as the fallback for installs still on an older bundle;
/// `tools/test_form_evolution_targets.py` fails if the two drift apart.
library;

/// One reachable evolution, as a species plus an optional form of that species.
class FormEvolutionTarget {
  const FormEvolutionTarget(this.speciesId, [this.formSuffix]);

  /// National dex id of the child species.
  final int speciesId;

  /// Slug appended to the child's own slug to name the target form
  /// (`59` + `hisui` → `arcanine-hisui`). Null means the species' default form.
  final String? formSuffix;
}

/// Chinese label for a form suffix, matching the wording the bundle already
/// uses for `forms[].nameZh` (`风速狗（洗翠的样子）`) so a chain node and the
/// form selector never disagree about what the same form is called.
String? formVariantLabelZh(String suffix) => _variantLabelsZh[suffix];

const _variantLabelsZh = <String, String>{
  'alola': '阿罗拉的样子',
  'galar': '伽勒尔的样子',
  'galar-standard': '伽勒尔的样子',
  'hisui': '洗翠的样子',
  'paldea': '帕底亚的样子',
  'sandy': '砂土蓑衣',
  'trash': '垃圾蓑衣',
};

/// Form key → the evolutions that form can actually reach.
const kFormEvolutionTargets = <String, List<FormEvolutionTarget>>{
  // ── Alolan lines: same child species, different form of it ──────────────
  'rattata': [FormEvolutionTarget(20)],
  'rattata-alola': [FormEvolutionTarget(20, 'alola')],
  'sandshrew': [FormEvolutionTarget(28)],
  'sandshrew-alola': [FormEvolutionTarget(28, 'alola')],
  'vulpix': [FormEvolutionTarget(38)],
  'vulpix-alola': [FormEvolutionTarget(38, 'alola')],
  'diglett': [FormEvolutionTarget(51)],
  'diglett-alola': [FormEvolutionTarget(51, 'alola')],
  'geodude': [FormEvolutionTarget(75)],
  'geodude-alola': [FormEvolutionTarget(75, 'alola')],
  'graveler': [FormEvolutionTarget(76)],
  'graveler-alola': [FormEvolutionTarget(76, 'alola')],
  'grimer': [FormEvolutionTarget(89)],
  'grimer-alola': [FormEvolutionTarget(89, 'alola')],

  // 喵喵 is the awkward one: three forms, three different results.
  'meowth': [FormEvolutionTarget(53)],
  'meowth-gmax': [FormEvolutionTarget(53)],
  'meowth-alola': [FormEvolutionTarget(53, 'alola')],
  'meowth-galar': [FormEvolutionTarget(863)],

  // ── Galarian lines ──────────────────────────────────────────────────────
  'ponyta': [FormEvolutionTarget(78)],
  'ponyta-galar': [FormEvolutionTarget(78, 'galar')],
  'slowpoke': [FormEvolutionTarget(80), FormEvolutionTarget(199)],
  'slowpoke-galar': [
    FormEvolutionTarget(80, 'galar'),
    FormEvolutionTarget(199, 'galar'),
  ],
  'farfetchd': [],
  'farfetchd-galar': [FormEvolutionTarget(865)],
  'corsola': [],
  'corsola-galar': [FormEvolutionTarget(864)],
  'zigzagoon': [FormEvolutionTarget(264)],
  'zigzagoon-galar': [FormEvolutionTarget(264, 'galar')],
  'linoone': [],
  'linoone-galar': [FormEvolutionTarget(862)],
  'yamask': [FormEvolutionTarget(563)],
  'yamask-galar': [FormEvolutionTarget(867)],
  'darumaka': [FormEvolutionTarget(555)],
  'darumaka-galar': [FormEvolutionTarget(555, 'galar-standard')],

  // ── Hisuian lines ───────────────────────────────────────────────────────
  'growlithe': [FormEvolutionTarget(59)],
  'growlithe-hisui': [FormEvolutionTarget(59, 'hisui')],
  'voltorb': [FormEvolutionTarget(101)],
  'voltorb-hisui': [FormEvolutionTarget(101, 'hisui')],
  'qwilfish': [],
  'qwilfish-hisui': [FormEvolutionTarget(904)],
  'sneasel': [FormEvolutionTarget(461)],
  'sneasel-hisui': [FormEvolutionTarget(903)],
  'zorua': [FormEvolutionTarget(571)],
  'zorua-hisui': [FormEvolutionTarget(571, 'hisui')],
  // 野蛮鲈鱼: only the white-striped school produces 幽尾玄鱼.
  'basculin-red-striped': [],
  'basculin-blue-striped': [],
  'basculin-white-striped': [FormEvolutionTarget(902)],

  // ── Paldean lines ───────────────────────────────────────────────────────
  'wooper': [FormEvolutionTarget(195)],
  'wooper-paldea': [FormEvolutionTarget(980)],

  // ── Burmy: the cloak carries over to 结草贵妇, 绅士蛾 ignores it ─────────
  'burmy-plant': [FormEvolutionTarget(413), FormEvolutionTarget(414)],
  'burmy-sandy': [
    FormEvolutionTarget(413, 'sandy'),
    FormEvolutionTarget(414),
  ],
  'burmy-trash': [
    FormEvolutionTarget(413, 'trash'),
    FormEvolutionTarget(414),
  ],
};

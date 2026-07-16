import 'dart:math';
import 'dart:ui' show lerpDouble;

/// Height→sprite-size rule for the standby companion.
///
/// PokeAPI heights run 0.1m (绵绵泡芙…) to 20m (无极汰那); mapping that full
/// range linearly would flatten every ordinary partner onto the minimum, so
/// the proportional band covers the practical companion range and giants
/// simply pin to the maximum.
const int companionHeightFloorDm = 2; // 0.2m → minimum size
const int companionHeightCeilDm = 25; // 2.5m+ → maximum size

/// Linear size interpolation between [minSize] and [maxSize] px over the
/// clamped height band. Unknown height falls back to the band midpoint.
double companionSpriteSizeFor(
  int? heightDm, {
  required double minSize,
  required double maxSize,
}) {
  if (heightDm == null || heightDm <= 0) {
    return (minSize + maxSize) / 2;
  }
  final clamped = heightDm
      .clamp(companionHeightFloorDm, companionHeightCeilDm)
      .toDouble();
  final t =
      (clamped - companionHeightFloorDm) /
      (companionHeightCeilDm - companionHeightFloorDm);
  return lerpDouble(minSize, maxSize, t)!;
}

/// Lines shown in the pat speech bubble. `{name}` is replaced with the
/// companion's display name. The pool is assembled per game edition via
/// [companionQuotePoolFor]: shared lines + follower narration (only for
/// games that actually have on-screen followers) + generation flavor.
const List<String> companionSharedQuotes = [
  // 动画 / 游戏名台词
  '就决定是你了！',
  '好讨厌的感觉～',
  '效果拔群！',
  '{name}使用了撒娇！',
  '遇到了野生的{name}！…才怪。',
  // 亲密度 / 日常
  '{name}好像想被摸摸头。',
  '{name}打了个大大的哈欠。',
  '{name}高兴地跳了起来！',
  '{name}蹭了蹭你的脸颊！',
  '肚子饿得咕咕叫了…',
  '想吃树果！',
  '今天也要去冒险吗？',
  '呼…呼…（打瞌睡中）',
  '和你在一起很安心。',
];

/// Follower-Pokémon narration — only games with on-screen followers.
const List<String> companionFollowerQuotes = [
  '{name}精神十足地看着你！',
  '{name}高兴得叫了起来！',
  '{name}紧紧跟在你身后。',
  '{name}闻了闻地面的味道。',
  '{name}摇摇晃晃地跳着舞。',
  '{name}目不转睛地盯着你看。',
];

/// Editions whose games feature walking follower Pokémon.
const Set<String> companionFollowerEditionSlugs = {
  'yellow', 'gs', 'crystal', 'hgss', 'lgpe', 'swsh', 'pla', 'sv', //
};

/// Two flavor lines per generation, keyed by [GameEdition.generation].
const Map<int, List<String>> companionGenerationQuotes = {
  1: ['从真新镇出发的旅程。', '石英高原在等着你。'],
  2: ['妈妈帮你把零花钱存起来了。', '电话响了…是妈妈的购物汇报。'],
  3: ['天气好像在悄悄变化。', '附近似乎藏着秘密基地。'],
  4: ['宝可表滴滴响了两声。', '地下通道里好像埋着宝物。'],
  5: ['合众的季节又换了一轮。', '有人想听听宝可梦的心声…'],
  6: ['和{name}的羁绊闪闪发光。', '口袋里的进化石微微发热。'],
  7: ['阿罗拉～！', 'Z 手环微微震动了一下。'],
  8: ['旷野地带的风吹了过来。', '{name}好像想试试极巨化。'],
  9: ['太晶宝石闪闪发光。', '要不要来一顿野餐三明治？'],
};

/// Partner-game hug line (皮卡丘版 / LGPE).
const String companionPartnerQuote = '搭档想要抱抱！';

/// Assemble the pat-quote pool for the selected game edition.
List<String> companionQuotePoolFor({
  required int generation,
  String? editionSlug,
}) {
  return [
    ...companionSharedQuotes,
    if (editionSlug == null ||
        companionFollowerEditionSlugs.contains(editionSlug))
      ...companionFollowerQuotes,
    ...?companionGenerationQuotes[generation],
    if (editionSlug == 'yellow' || editionSlug == 'lgpe')
      companionPartnerQuote,
  ];
}

/// Shown when friendship maxes out (10 pats).
const String companionFriendshipQuote = '{name}最喜欢你了！❤';

/// Substitute the companion display name into a quote template.
String formatCompanionQuote(String template, String name) =>
    template.replaceAll('{name}', name);

/// Pick a pat quote template from [pool], avoiding an immediate repeat of
/// [previous].
String pickCompanionQuote(
  List<String> pool,
  Random random, {
  String? previous,
}) {
  if (pool.length == 1) {
    return pool.first;
  }
  while (true) {
    final quote = pool[random.nextInt(pool.length)];
    if (quote != previous) {
      return quote;
    }
  }
}

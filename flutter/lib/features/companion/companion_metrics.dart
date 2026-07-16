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

/// Classic lines shown in the pat speech bubble. `{name}` is replaced with
/// the companion's display name; HGSS follower-style narration mixes with
/// anime/game meme lines.
const List<String> companionPatQuotes = [
  // 动画 / 游戏名台词
  '就决定是你了！',
  '好讨厌的感觉～',
  '效果拔群！',
  '{name}使用了撒娇！',
  '遇到了野生的{name}！…才怪。',
  // HGSS 跟随宝可梦风格
  '{name}精神十足地看着你！',
  '{name}高兴得叫了起来！',
  '{name}紧紧跟在你身后。',
  '{name}闻了闻地面的味道。',
  '{name}摇摇晃晃地跳着舞。',
  '{name}目不转睛地盯着你看。',
  '{name}好像想被摸摸头。',
  '{name}打了个大大的哈欠。',
  // 亲密度 / 日常
  '{name}高兴地跳了起来！',
  '{name}蹭了蹭你的脸颊！',
  '肚子饿得咕咕叫了…',
  '想吃树果！',
  '今天也要去冒险吗？',
  '呼…呼…（打瞌睡中）',
  '和你在一起很安心。',
];

/// Shown when friendship maxes out (10 pats).
const String companionFriendshipQuote = '{name}最喜欢你了！❤';

/// Substitute the companion display name into a quote template.
String formatCompanionQuote(String template, String name) =>
    template.replaceAll('{name}', name);

/// Pick a pat quote template, avoiding an immediate repeat of [previous].
String pickCompanionQuote(Random random, {String? previous}) {
  if (companionPatQuotes.length == 1) {
    return companionPatQuotes.first;
  }
  while (true) {
    final quote =
        companionPatQuotes[random.nextInt(companionPatQuotes.length)];
    if (quote != previous) {
      return quote;
    }
  }
}

import speciesLabels from '../../../flutter/assets/l10n/zh/species_labels.json';
import { isGeneralPokemonFranchiseQuestion } from './pokemon_question_scope';

// The legacy catalog contains mixed Hans/Hant spellings (e.g. 铁轍迹).
// Match character variants without rewriting the user's or model's spelling.
const variantPairs = ['铁鐵', '辙轍', '迹跡', '头頭', '龙龍', '顿頓', '剑劍', '鱼魚',
  '鸟鳥', '鸭鴨', '龟龜', '兽獸', '马馬', '虫蟲', '叶葉', '电電', '梦夢', '宝寶',
  '绿綠', '红紅', '蓝藍', '银銀', '钢鋼', '铝鋁', '盐鹽', '发髮', '灵靈', '轰轟',
  '鸣鳴', '团團', '贪貪', '颚顎', '风風', '云雲', '陆陸', '狮獅', '长長', '鸭鴨'];
const characterVariants = new Map(variantPairs.flatMap((pair) => [...pair].map((char) => [char, `[${pair}]`] as const)));
const names = Object.entries(speciesLabels).filter(([id]) => id !== '201').flatMap(([, label]) => [label.zh, label.en])
  .filter((name): name is string => typeof name === 'string' && name.length >= 2)
  .sort((left, right) => right.length - left.length)
  .map((name) => [...name].map((char) => characterVariants.get(char) ?? char.replace(/[.*+?^${}()|[\]\\]/gu, '\\$&')).join(''));
const speciesVersionMarker = new RegExp(`(?<![A-Za-z])(${names.join('|')})([SV])(?=$|[^A-Za-z])`, 'gu');

/** Wiki S/V edition footnotes are not part of a species name. Card questions
 * and explicitly requested suffixed names retain their original spelling. */
export function normalizeGameSpeciesVersionMarkers(
  answer: string,
  question: string,
  game?: 'scarlet' | 'violet',
): string {
  if (!game || isGeneralPokemonFranchiseQuestion(question)) return answer;
  return answer.replace(speciesVersionMarker, (match, name: string) =>
    question.includes(match) ? match : name);
}

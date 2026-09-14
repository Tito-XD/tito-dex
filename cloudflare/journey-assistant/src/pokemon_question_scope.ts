import type { AssistantRequest } from './contract';
import { isExplicitFollowUpQuestion, recentConversationForQuestion } from './conversation_context';

/**
 * Questions about the wider Pokémon franchise must not inherit the selected
 * save/game as a factual constraint. The vocabulary stays deliberately narrow:
 * it covers animation, characters, voices and quotations, while the existing
 * server-owned Pokémon-domain allowlist remains the final research boundary.
 */
const generalFranchiseIntent = /(?:动画|動畫|动漫|動漫|漫画|漫畫|剧场版|电影|特别篇|特別篇|台词|口头禅|口号|开场白|谁说的|谁讲的|谁的(?:台词|口头禅)|哪一集|第几集|角色|配音|声优)/u;
const cardIntent = /(?:\b(?:ptcg|tcg|tcgp)\b|\btc[g]?\s*pocket\b|\bpok[eé]mon\s+(?:tcg|cards?|trading card game)|卡牌|卡片|集换式)/iu;
const otherCardFranchise = /(?:游戏王|遊戯王|万智牌|萬智牌|炉石|爐石|数码宝贝|航海王|海贼王|\b(?:yu-?gi-?oh|magic the gathering|hearthstone|digimon|one piece)\b)/iu;
const englishFranchiseIntent = /(?:\bpok[eé]mon\b.*\b(?:anime|cartoon|movie|film|episode|voice|actor|quote|manga)\b|\b(?:ash ketchum|team rocket|jessie|james and meowth)\b)/iu;

export function isGeneralPokemonFranchiseQuestion(question: string): boolean {
  return generalFranchiseIntent.test(question.trim()) ||
    isPokemonCardQuestion(question) || englishFranchiseIntent.test(question);
}

export function isPokemonCardQuestion(question: string): boolean {
  return cardIntent.test(question) && !otherCardFranchise.test(question);
}

/** An entity name alone cannot turn reference questions into a story blocker. */
export function isPokemonReferenceQuestion(question: string): boolean {
  return /(?:种族值|属性|特性|招式|技能|配招|进化|弱点|身高|体重|蛋组|性别|努力值|个体值|\b(?:base stats?|typing|abilities|learnset|moveset|evolutions?)\b)/iu.test(question);
}

/** Use history only when the current wording explicitly continues that topic. */
export function isGeneralPokemonFranchiseRequest(request: AssistantRequest): boolean {
  return isGeneralPokemonFranchiseQuestion(franchiseContextQuestion(request));
}

export function isPokemonCardRequest(request: AssistantRequest): boolean {
  return isPokemonCardQuestion(franchiseContextQuestion(request));
}

function franchiseContextQuestion(request: AssistantRequest): string {
  if (isGeneralPokemonFranchiseQuestion(request.question)) return request.question;
  for (const message of recentConversationForQuestion(request).slice().reverse()) {
    if (message.role !== 'user') continue;
    if (isGeneralPokemonFranchiseQuestion(message.content) ||
        !isExplicitFollowUpQuestion(message.content)) return message.content;
  }
  return request.question;
}

/** Missing a game selection does not imply an anime/card question. */
export function isVersionIndependentPokemonRequest(request: AssistantRequest): boolean {
  return request.context.game === 'general' || isGeneralPokemonFranchiseRequest(request);
}

/** Keep Mega Evolution separate from an ordinary species evolution chain. */
export function isMegaEvolutionQuestion(question: string): boolean {
  const normalized = question.trim();
  return /(?:超级|超級)进化|(?:超级|超級)進化/iu.test(normalized) ||
    /(?:\bmega\b|メガ)/iu.test(normalized) && /(?:进化|進化|evol)/iu.test(normalized);
}

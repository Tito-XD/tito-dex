import type { AssistantRequest } from './contract';
import { isExplicitFollowUpQuestion, recentConversationForQuestion } from './conversation_context';
import { isGeneralPokemonFranchiseQuestion, isPokemonCardQuestion } from './pokemon_question_scope';
import { mentionedEntities } from './structured_entities';

export type QuestionEvidenceDomain = 'gameplay' | 'mechanics' | 'anime' | 'manga' | 'cards' | 'pocket';
export const mangaIdentity = /(?:漫画|漫畫|特别篇|特別篇|欢乐祭|歡樂祭|\bmanga\b|\bAdventures\b|Pocket Monsters Special)/iu;
export const pocketIdentity = /(?:\bpocket\b(?!\s+monsters)|口袋版|袖珍版|口袋集换|口袋集換)/iu;
const animeIdentity = /(?:动画|動畫|动漫|動漫|剧场版|電影|电影|台词|台詞|配音|声优|聲優|\b(?:anime|cartoon|movie|episode|voice|actor|quote)\b)/iu;

/** A missing save selects no edition; it does not merge the canon of all works. */
export function questionEvidenceDomain(request: AssistantRequest): QuestionEvidenceDomain {
  const direct = explicitDomain(request.question);
  if (direct) return direct;
  if (isExplicitFollowUpQuestion(request.question) && mentionedEntities(request.question).length === 0) {
    for (const prior of recentConversationForQuestion(request).slice().reverse()) {
      if (prior.role !== 'user') continue;
      const domain = explicitDomain(prior.content);
      if (domain) return domain;
      if (!isExplicitFollowUpQuestion(prior.content)) break;
    }
  }
  return request.context.game === 'general'
    ? 'mechanics' : 'gameplay';
}

function explicitDomain(question: string): QuestionEvidenceDomain | null {
  if (isPokemonCardQuestion(question)) return pocketIdentity.test(question) ? 'pocket' : 'cards';
  if (mangaIdentity.test(question)) return 'manga';
  if (animeIdentity.test(question) || isGeneralPokemonFranchiseQuestion(question)) return 'anime';
  return null;
}

export function needsClaimGrounding(request: AssistantRequest): boolean {
  return questionEvidenceDomain(request) !== 'gameplay';
}

export function evidenceScopeInstruction(request: AssistantRequest): string {
  const domain = questionEvidenceDomain(request);
  const scope = {
    gameplay: '用户指定的主系列游戏流程', mechanics: '主系列宝可梦机制与物种资料',
    anime: '宝可梦动画人物与剧情', manga: '用户所指漫画作品',
    cards: '实体宝可梦集换式卡牌游戏', pocket: 'Pokémon TCG Pocket',
  }[domain];
  return `本题事实范围是${scope}。同名人物、物种或道具在其他作品中的情节不是此范围的证据。保留资料的条件、适用对象、默认规则和例外；不得把局部或有条件的陈述改成无条件规则。` +
    '问题包含多个子问或要求举例时，逐项覆盖来源能支持的部分，保留已获支持的例子；未获支持的部分明确说明，不留下“例如：”这类悬空句。百科、社区站与数据库不是官方资料，不得将它们统称“官方”；依据来源实际身份表述。' +
    (domain === 'manga' ? '漫画问题可以正常回答。正文明确所依据的漫画作品名与人物版本，引用应能识别该作品；仅当未指定作品且同名对象在不同漫画中的事实有歧义时澄清，不要一律拒答或套用动画/游戏。' : '正文有必要时说明依据的作品或规则范围，让用户知道资料适用于哪里。');
}

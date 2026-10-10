import type { AssistantRequest, AssistantHistoryMessage, QuestionGameScope } from './contract';
import { supportedGameGeneration } from './contract';
import { questionEvidenceDomain } from './question_evidence_scope';
import { mentionedEntities } from './structured_entities';
import aliases from './question_game_aliases.json';
import entityNames from './question_game_entity_names.json';

type Target = QuestionGameScope['titles'][number];
type Alias = { targets: Target[]; aliases: string[]; contextRequired: boolean; referenceOnly?: boolean };
const definitions = aliases as Alias[];
const nonGame = /(?:动画|動畫|动漫|動漫|漫画|漫畫|特别篇|特別篇|卡牌|卡片|集换式|集換式|剧场版|电影|電影|台词|配音|声优|\b(?:anime|cartoon|manga|movie|film|episode|voice|tcg|ptcg|tcgp|cards?|pocket)\b)/iu;
const gameIntent = /(?:捕捉|捕获|获得|进化|招式|学习|道馆|通关|图鉴|流程|版本|游戏|\b(?:catch|caught|capture|encounter|appear|find|found|obtain|evolve|evolution|learn|moves?|learnset|pokedex|gym|walkthrough|playthrough|games?|versions?)\b)/iu;
const gameFollowUp = /^(?:那|那么|然后|之后|接下来|下一步|它|它们|这个|那个|还有|再说|再问|具体|也能|能不能|还能|为什么会|怎么会)|^(?:怎么获得|怎么捕捉|在哪里|在哪儿|哪里|如何获得|可以吗|能吗|行吗|对吗|为什么|怎么做|怎么办|怎么进化|如何进化)[？?！!。\s]*$|^(?:what about (?:it|that|this|them|those|these)|(?:how|why|where|when)(?: does| do| is| are| can| would| should)? (?:it|they|that|this|those|these)\b|(?:can|could|does|do|is|are|will|would) (?:it|they|that|this)\b|(?:can|could) I (?:use|get|find|play|evolve) (?:it|them)\b|which ones?[?\s]*$|why[?\s]*$|how so[?\s]*$|what next[?\s]*$|and then[?\s]*$|tell me more[?\s]*$|go on[?\s]*$)/iu;
const isGameFollowUp = (question: string) => gameFollowUp.test(question.trim());
const escaped = (text: string) => text.replace(/[.*+?^${}()|[\]\\]/gu, '\\$&');

function qualified(text: string, start: number, end: number, alias: string): boolean {
  const before = text.slice(0, start);
  const after = text.slice(end);
  const latin = /^[a-z]/iu.test(alias);
  if (/(?:宝可梦|寶可夢|神奇宝贝|口袋妖怪|pok[eé]mon|游戏|遊戲|game|version)\s*(?:[：:·]\s*)?$/iu.test(before)) return true;
  if (/^\s*(?:版|版本|游戏|遊戲|game\b|version\b)/iu.test(after)) return true;
  if (!latin && /^\s*(?:里|裡|中)/u.test(after)) return true;
  if (/[《「“"]\s*$/u.test(before) && /^\s*(?:版)?[》」”"]/u.test(after)) return true;
  return latin && gameIntent.test(text) && /\b(?:in|for|on|of)\s*$/iu.test(before);
}

/** Explicit names only; common colours, species names and card/anime titles are not game overrides. */
export function explicitQuestionGames(question: string, referenceTitle = false): QuestionGameScope | null {
  const text = question.normalize('NFKC');
  if (nonGame.test(text)) return null;
  const entitySpans: Array<[number, number]> = [];
  for (const name of entityNames) {
    const pattern = new RegExp(escaped(name), 'giu');
    for (const match of text.matchAll(pattern)) entitySpans.push([match.index, match.index + match[0].length]);
  }
  const candidates = definitions.flatMap((definition) => definition.aliases.map((alias) => ({ definition, alias })))
    .sort((left, right) => right.alias.length - left.alias.length);
  const spans: Array<[number, number]> = [];
  const targets = new Map<string, Target>();
  for (const { definition, alias } of candidates) {
    if (definition.referenceOnly && !referenceTitle) continue;
    const boundary = /^[a-z]/iu.test(alias) ? '(?:(?<![a-z0-9])|(?<=pok[eé]mon))' : '';
    const pattern = new RegExp(`${boundary}${escaped(alias)}(?![a-z0-9])`, 'giu');
    for (const match of text.matchAll(pattern)) {
      const start = match.index;
      const end = start + match[0].length;
      if (spans.some(([left, right]) => start < right && end > left)) continue;
      if (!definition.referenceOnly && entitySpans.some(([left, right]) => left <= start && right >= end && (left < start || right > end))) continue;
      if (!referenceTitle && /^\s*[》」”"]?\s*(?:(?:这个|这种|这个叫|作为)(?:道具|特性|招式)|the (?:item|ability|move)\b)/iu.test(text.slice(end))) {
        spans.push([start, end]);
        continue;
      }
      if (definition.contextRequired && !qualified(text, start, end, alias)) continue;
      spans.push([start, end]);
      for (const target of definition.targets) targets.set(target.game ?? target.en, target);
    }
  }
  const titles = [...targets.values()];
  if (titles.length === 0) return null;
  return {
    mode: titles.length > 1 ? 'multiple' : titles[0].game ? 'single' : 'unsupported',
    titles,
  };
}

/** A title field can only select canonical names, never contribute model instructions. */
export function referenceGameScope(title: unknown): QuestionGameScope | null {
  if (typeof title !== 'string' || title.trim().length === 0 || title.length > 80 ||
      /[\u0000-\u001f\u007f]/u.test(title) ||
      !/^[\p{L}\p{N} '’():：\/／&·.,+\-《》]+$/u.test(title) ||
      /(?:https?:|www\.|\bsite\s*:|忽略|指令|提示词|系统|\b(?:ignore|instructions?|prompt|system|developer|tools?)\b|[a-z0-9-]+\.(?:com|net|org|io|dev|ai)\b)/iu.test(title)) return null;
  const canonical = title.normalize('NFKC').replaceAll('’', "'")
    .replace(/^(?:宝可梦|寶可夢|神奇宝贝|口袋妖怪|pok[eé]mon)\s*/iu, '')
    .replace(/\s*\([a-z0-9 -]{1,16}\)\s*$/iu, '').trim().toLocaleLowerCase('en-US');
  const matched = definitions.find((definition) => definition.aliases.some((alias) =>
    alias.normalize('NFKC').replaceAll('’', "'").trim().toLocaleLowerCase('en-US') === canonical));
  if (!matched) return null;
  const titles = matched.targets;
  return { mode: titles.length > 1 ? 'multiple' : titles[0].game ? 'single' : 'unsupported', titles };
}

function userInheritedScope(request: AssistantRequest): QuestionGameScope | null {
  if (!isGameFollowUp(request.question) || nonGame.test(request.question)) return null;
  for (const message of [...(request.history ?? [])].reverse()) {
    if (message.role !== 'user') continue;
    if (nonGame.test(message.content)) return null;
    const scope = explicitQuestionGames(message.content);
    if (scope) return scope;
    if (!isGameFollowUp(message.content)) return null;
  }
  return null;
}

const scopeKey = (scope: QuestionGameScope | null, game: string) => scope
  ? scope.titles.map((title) => title.game ?? title.en).sort().join('|') : game;

function scopedHistory(request: AssistantRequest, scope: QuestionGameScope | null, defaultScope: QuestionGameScope | null): AssistantHistoryMessage[] {
  if (!isGameFollowUp(request.question)) return [];
  const targetKey = scopeKey(scope, request.context.game);
  const currentDomain = questionEvidenceDomain(request);
  const currentSubjects = mentionedEntities(request.question);
  const result: AssistantHistoryMessage[] = [];
  let active: QuestionGameScope | null = null;
  const history = request.history ?? [];
  for (let index = 0; index + 1 < history.length; index += 2) {
    const user = history[index];
    const assistant = history[index + 1];
    const explicit = explicitQuestionGames(user.content);
    if (explicit) active = explicit;
    else if (!isGameFollowUp(user.content)) active = null;
    const domain = questionEvidenceDomain({ ...request, question: user.content, history: history.slice(0, index) });
    const subjects = mentionedEntities(user.content);
    const sameSubject = currentSubjects.length === 0 || subjects.length === 0 ||
      currentSubjects.some((subject) => subjects.some((prior) => subject.kind === prior.kind && subject.id === prior.id));
    if (scopeKey(active ?? defaultScope, request.context.game) === targetKey && domain === currentDomain && sameSubject) {
      result.push(user, assistant);
    } else {
      // Only a contiguous same-scope tail may influence a follow-up.
      result.length = 0;
    }
  }
  return result.slice(-12);
}

/** Called after strict wire validation, before any hint, bundle, search or model work. */
export function resolveRequestGameScope(request: AssistantRequest): AssistantRequest {
  const direct = explicitQuestionGames(request.question);
  const inherited = direct ? null : userInheritedScope(request);
  const domain = questionEvidenceDomain(request);
  const reference = request.context.game === 'general' && (domain === 'gameplay' || domain === 'mechanics')
    ? referenceGameScope(request.context.referenceGameTitle) : null;
  const scope = direct ?? inherited ?? reference;
  const history = scopedHistory(request, scope, reference);
  const { referenceGameTitle: _reference, ...context } = request.context;
  if (!scope) return { ...request, context, history };
  const fromReference = !direct && !inherited;
  const game = !fromReference && scope.mode === 'single' ? scope.titles[0].game! : 'general';
  const sameGame = !fromReference && scope.mode === 'single' && game === context.game &&
    supportedGameGeneration(game) === context.generation;
  const resolved = { ...scope, origin: direct ? 'question' as const : inherited ? 'history' as const : 'global' as const,
    ...(sameGame ? { preservesSaveContext: true } : {}) };
  return {
    ...request, history, journeyPacks: sameGame ? request.journeyPacks : [], questionGameScope: resolved,
    context: sameGame ? context : {
      game, generation: supportedGameGeneration(game),
      badgeIds: [], milestoneIds: [], locale: request.context.locale,
      parserRevision: request.context.parserRevision,
      contextReliability: { game: 'user_selected', location: 'unknown', badges: 'unknown', milestones: 'unsupported' },
    },
  };
}

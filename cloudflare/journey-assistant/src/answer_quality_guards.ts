import {
  moveAdviceGuardFailure,
  type MoveAdviceGuardFailure,
  type MoveAnswerStructuredSource,
} from './move_answer_quality_guard';

export type GuardedGame = 'scarlet' | 'violet';

export type GeneratedAnswerGuardFailure =
  | MoveAdviceGuardFailure
  | 'excessive_move_candidates'
  | 'internal_source_reference'
  | 'selected_game_conflict';

export type GeneratedAnswerGuardInput = {
  answer: string;
  question: string;
  game?: GuardedGame;
  knownMoveNames?: readonly string[];
  structuredSources?: readonly MoveAnswerStructuredSource[];
};

const adviceIntentPattern =
  /(?:培养|适合|推荐|配招|值不值得|怎么练|练什么|练吗|好不好用|好用吗|强不强|厉不厉害|打法|队伍|搭配)/u;

const internalSourceReferencePatterns = [
  /\b(?:tavily|dex-bundle|strategywiki|wikidata)-[a-z0-9][a-z0-9-]*\b/iu,
  /\bpokeapi-(?:pokemon-species|pokemon|move|item|ability|location|location-area)-[a-z0-9-]+\b/iu,
  /\bTitoDex\s+Dex\s+bundle(?:\s+v\d+)?\b/iu,
  /\b(?:usedSourceIds|sourceKinds|versionScope|exactGame|moveSet|verifiedFacts|matchedHintIds|answerMode)\b/u,
];

const oppositeVersionTerms: Record<GuardedGame, readonly RegExp[]> = {
  violet: [
    /故勒顿/u,
    /橘子学院/u,
    /奥琳/u,
    /\bKoraidon\b/iu,
    /\bNaranja(?:\s+Academy)?\b/iu,
    /\b(?:Professor\s+)?Sada\b/iu,
  ],
  scarlet: [
    /密勒顿/u,
    /葡萄学院/u,
    /弗图/u,
    /\bMiraidon\b/iu,
    /\bUva(?:\s+Academy)?\b/iu,
    /\b(?:Professor\s+)?Turo\b/iu,
  ],
};

/**
 * Rejects unsafe model-written bodies without trying to invent a replacement.
 * The caller keeps ownership of the deterministic/local fallback path.
 */
export function generatedAnswerGuardFailure(
  input: GeneratedAnswerGuardInput,
): GeneratedAnswerGuardFailure | null {
  const answer = input.answer.trim();
  if (internalSourceReferencePatterns.some((pattern) => pattern.test(answer))) {
    return 'internal_source_reference';
  }

  if (input.game && hasOppositeVersionLeak(answer, input.question, input.game)) {
    return 'selected_game_conflict';
  }

  const mentionedMoves = mentionedMoveNames(answer, input.knownMoveNames ?? []);
  if (adviceIntentPattern.test(input.question) && mentionedMoves.length > 6) {
    return 'excessive_move_candidates';
  }
  if (input.structuredSources !== undefined && mentionedMoves.length > 0) {
    const moveFailure = moveAdviceGuardFailure({
      answer,
      question: input.question,
      mentionedMoves,
      sources: input.structuredSources,
    });
    if (moveFailure) return moveFailure;
  }

  return null;
}

function hasOppositeVersionLeak(
  answer: string,
  question: string,
  game: GuardedGame,
): boolean {
  const forbidden = oppositeVersionTerms[game];
  if (!forbidden.some((pattern) => pattern.test(answer))) return false;

  // A comparison or an explicit request for the other edition/content is
  // intentional, so it must not be mistaken for context contamination.
  if (/(?:朱紫|紫朱|版本.{0,6}(?:差异|区别|对比|相比|比较)|(?:差异|区别|对比|相比|比较).{0,6}版本|两(?:个|种|版)?版本|另一版|另一个版本)/u
    .test(question)) {
    return false;
  }
  if (forbidden.some((pattern) => pattern.test(question))) return false;
  if (game === 'violet' &&
      /(?:宝可梦\s*朱|《朱》|朱(?:版|版本)|\bScarlet\b)/iu.test(question)) {
    return false;
  }
  if (game === 'scarlet' &&
      /(?:宝可梦\s*紫|《紫》|紫(?:版|版本)|\bViolet\b)/iu.test(question)) {
    return false;
  }
  return true;
}

function mentionedMoveNames(
  answer: string,
  knownMoveNames: readonly string[],
): string[] {
  const lowerAnswer = answer.toLocaleLowerCase('en-US');
  const distinctNames = new Map<string, string>();
  for (const rawName of [...knownMoveNames].sort(
    (left, right) => right.length - left.length,
  )) {
    const name = rawName.trim();
    if (name.length < 2) continue;
    const normalized = name.toLocaleLowerCase('en-US');
    if (distinctNames.has(normalized)) continue;
    if (containsEntityName(lowerAnswer, normalized)) {
      distinctNames.set(normalized, name);
    }
  }
  return [...distinctNames.values()];
}

function containsEntityName(haystack: string, needle: string): boolean {
  if (!/^[a-z0-9 -]+$/u.test(needle)) return haystack.includes(needle);
  const escaped = needle.replace(/[.*+?^$(){}|[\]\\]/gu, '\\$&');
  return new RegExp(
    '(?:^|[^a-z0-9])' + escaped + '(?:$|[^a-z0-9])',
    'u',
  ).test(haystack);
}

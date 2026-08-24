export type MoveAdviceGuardFailure =
  | 'move_advice_missing_rationale'
  | 'move_advice_missing_source'
  | 'move_advice_not_structured'
  | 'move_candidate_not_learnable'
  | 'move_fact_conflict'
  | 'move_fact_unverified';

export type MoveAnswerStructuredSource = {
  id: string;
  title?: string;
  url?: string;
  text: string;
};

export type MoveAdviceGuardInput = {
  answer: string;
  question: string;
  mentionedMoves: readonly string[];
  sources: readonly MoveAnswerStructuredSource[];
};

const moveAdviceIntentPattern =
  /(?:配招|(?:招式|技能).{0,16}(?:适合|推荐|选择|哪些|什么|怎么|搭配|好用)|(?:适合|推荐|选择|哪些|什么|怎么|搭配).{0,16}(?:招式|技能))/u;

const implicitMoveAdvicePattern =
  /(?:适合|推荐|应该|该|要不要|值不值得).{0,6}学/u;

const moveRationalePattern =
  /(?:用途|作用|负责|用来|用于|选择|取舍|路线|打法|输出|强化|提升|先手|补盲|覆盖|本系|稳定|收割|回复|控场|干扰|条件|如果|若|根据|配合|搭配|替换|二选一|物攻|特攻|通关|对战|清场|续航|优先度|破盾|消耗)/u;

type MoveFacts = {
  type: Set<string>;
  category: Set<string>;
  power: Set<number>;
  accuracy: Set<number>;
  pp: Set<number>;
};

type StructuredMoveEvidence = {
  learnableNames: Set<string>;
  factsByName: Map<string, MoveFacts>;
};

type MoveFactClaims = {
  type: string[];
  category: string[];
  power: number[];
  accuracy: number[];
  pp: number[];
  hasUnsupportedAccuracyClaim: boolean;
  hasUnsupportedPowerClaim: boolean;
};

/**
 * Treats selected-game moveSet rows only as learnability evidence. Concrete
 * move attributes and numbers require an independent structured move record.
 * The caller owns fallback behavior; this guard never guesses a repair.
 */
export function moveAdviceGuardFailure(
  input: MoveAdviceGuardInput,
): MoveAdviceGuardFailure | null {
  if (!isMoveAdviceQuestion(input.question, input.mentionedMoves)) return null;
  const candidateMoves = input.mentionedMoves.filter((move) =>
    isPresentedMoveCandidate(input.answer, move));
  if (candidateMoves.length === 0) return 'move_advice_missing_rationale';
  if (!input.sources.some((source) => Boolean(source.url))) {
    return 'move_advice_missing_source';
  }
  if (
    candidateMoves.length > 1 &&
    candidateMoves.some((move) => !isStructuredMoveLine(input.answer, move))
  ) {
    return 'move_advice_not_structured';
  }
  const evidence = structuredMoveEvidence(input.sources);
  for (const move of candidateMoves) {
    if (!evidence.learnableNames.has(normalizeMoveName(move))) {
      return 'move_candidate_not_learnable';
    }
    if (!moveHasRationale(input.answer, move)) {
      return 'move_advice_missing_rationale';
    }
  }

  for (const occurrence of moveOccurrences(input.answer, candidateMoves)) {
    const claims = moveFactClaims(occurrence.context);
    const facts = evidence.factsByName.get(normalizeMoveName(occurrence.name));
    const failure = compareMoveClaims(claims, facts);
    if (failure) return failure;
  }
  return null;
}

function isStructuredMoveLine(answer: string, move: string): boolean {
  const escaped = move.replace(/[.*+?^$(){}|[\]\\]/gu, '\\$&');
  return new RegExp(
    '(?:^|\\n)\\s*(?:(?:[-*+•]|\\d+[.)、])\\s*)' +
      escaped +
      '(?=\\s*[：:（(、，,])',
    /[a-z]/iu.test(move) ? 'imu' : 'mu',
  ).test(answer);
}

function isPresentedMoveCandidate(answer: string, move: string): boolean {
  const lowerAnswer = answer.toLocaleLowerCase('en-US');
  const lowerMove = move.toLocaleLowerCase('en-US');
  let offset = 0;
  while (offset < lowerAnswer.length) {
    const index = lowerAnswer.indexOf(lowerMove, offset);
    if (index < 0) return false;
    const prefix = answer.slice(Math.max(0, index - 24), index);
    const suffix = answer.slice(index + move.length, index + move.length + 16);
    const linePrefix = answer.slice(answer.lastIndexOf('\n', index - 1) + 1, index);
    const listStart = /^\s*(?:(?:[-*•]|\d+[.)、])\s*)?$/u.test(linePrefix);
    const inlinePseudoListStart = /(?:^|[。！？；])\s*[-*+•]\s*$/u.test(prefix);
    const introduced = /(?:推荐|选择|考虑|使用|学习|采用|带上|换成|包括|候选)(?:的)?(?:招式|技能)?\s*[:：]?\s*$/u
      .test(prefix);
    const listed = /(?:^|[、，,；;])\s*$/u.test(prefix);
    const hasCandidateSuffix =
      /^(?:\s|[（(:：、，,。；;)）]|和|与|或|作为|用于|用来|负责|提供|提升|强化|补盲|覆盖|输出|收割|回复|控场|干扰|是|能|可|适合)/u
        .test(suffix);
    if ((listStart || inlinePseudoListStart || introduced || listed) && hasCandidateSuffix) {
      return true;
    }
    offset = index + Math.max(1, lowerMove.length);
  }
  return false;
}

function isMoveAdviceQuestion(question: string, mentionedMoves: readonly string[]): boolean {
  return moveAdviceIntentPattern.test(question) ||
    (implicitMoveAdvicePattern.test(question) && mentionedMoves.some((move) =>
      containsEntityName(
        question.toLocaleLowerCase('en-US'),
        move.toLocaleLowerCase('en-US'),
      )));
}

function structuredMoveEvidence(
  sources: readonly MoveAnswerStructuredSource[],
): StructuredMoveEvidence {
  const evidence: StructuredMoveEvidence = {
    learnableNames: new Set<string>(),
    factsByName: new Map<string, MoveFacts>(),
  };
  for (const source of sources) {
    let value: unknown;
    try {
      value = JSON.parse(source.text);
    } catch {
      continue;
    }
    if (!isRecord(value)) continue;
    if (/^dex-bundle-v\d+$/u.test(source.id) && !source.url) {
      collectDexBundleMoveEvidence(value, evidence);
    } else if (/^pokeapi-move-\d+$/u.test(source.id)) {
      collectPokeApiMoveEvidence(value, source.title, evidence);
    }
  }
  return evidence;
}

function collectDexBundleMoveEvidence(
  value: Record<string, unknown>,
  evidence: StructuredMoveEvidence,
): void {
  if (isRecord(value.species) && isRecord(value.species.moveSet)) {
    for (const method of ['levelUp', 'machine', 'egg', 'tutor', 'learnable']) {
      const rows = value.species.moveSet[method];
      if (!Array.isArray(rows)) continue;
      for (const row of rows) {
        if (!isRecord(row) || typeof row.nameZh !== 'string') continue;
        addLearnableName(evidence, row.nameZh);
      }
    }
  }
  if (isRecord(value.move) && typeof value.move.nameZh === 'string') {
    const name = value.move.nameZh;
    addMoveFacts(evidence, name, {
      type: firstString(value.move.type, value.move.typeZh),
      category: firstString(value.move.category, value.move.categoryZh),
      power: finiteNumber(value.move.power),
      accuracy: finiteNumber(value.move.accuracy),
      pp: finiteNumber(value.move.pp),
    });
  }
}

function collectPokeApiMoveEvidence(
  value: Record<string, unknown>,
  title: string | undefined,
  evidence: StructuredMoveEvidence,
): void {
  if (!isRecord(value.versionScope) || value.versionScope.exactGame !== true ||
      !isRecord(value.gameValues)) return;
  const titleName = title?.replace(/^PokéAPI\s*·\s*/u, '').trim();
  const name = titleName || (typeof value.name === 'string' ? value.name : '');
  if (!name) return;
  addMoveFacts(evidence, name, {
    type: firstString(value.gameValues.type),
    category: firstString(value.gameValues.damageClass),
    power: finiteNumber(value.gameValues.power),
    accuracy: finiteNumber(value.gameValues.accuracy),
    pp: finiteNumber(value.gameValues.pp),
  });
}

function addLearnableName(evidence: StructuredMoveEvidence, name: string): void {
  const normalized = normalizeMoveName(name);
  if (normalized) evidence.learnableNames.add(normalized);
}

function addMoveFacts(
  evidence: StructuredMoveEvidence,
  name: string,
  facts: {
    type?: string;
    category?: string;
    power?: number;
    accuracy?: number;
    pp?: number;
  },
): void {
  const normalizedName = normalizeMoveName(name);
  if (!normalizedName) return;
  const target = evidence.factsByName.get(normalizedName) ?? {
    type: new Set<string>(),
    category: new Set<string>(),
    power: new Set<number>(),
    accuracy: new Set<number>(),
    pp: new Set<number>(),
  };
  if (facts.type) target.type.add(normalizeMoveType(facts.type));
  if (facts.category) target.category.add(normalizeMoveCategory(facts.category));
  if (facts.power !== undefined) target.power.add(facts.power);
  if (facts.accuracy !== undefined) target.accuracy.add(facts.accuracy);
  if (facts.pp !== undefined) target.pp.add(facts.pp);
  evidence.factsByName.set(normalizedName, target);
}

function moveHasRationale(answer: string, move: string): boolean {
  const lowerMove = move.toLocaleLowerCase('en-US');
  return answer.split(/[\n。！？；]/u).some((fragment) =>
    containsEntityName(fragment.toLocaleLowerCase('en-US'), lowerMove) &&
    moveRationalePattern.test(fragment));
}

function moveOccurrences(
  answer: string,
  mentionedMoves: readonly string[],
): Array<{ name: string; context: string }> {
  const lowerAnswer = answer.toLocaleLowerCase('en-US');
  const occurrences: Array<{ name: string; index: number; end: number }> = [];
  for (const name of mentionedMoves) {
    const lowerName = name.toLocaleLowerCase('en-US');
    let offset = 0;
    while (offset < lowerAnswer.length) {
      const index = lowerAnswer.indexOf(lowerName, offset);
      if (index < 0) break;
      occurrences.push({ name, index, end: index + lowerName.length });
      offset = index + Math.max(1, lowerName.length);
    }
  }
  occurrences.sort((left, right) => left.index - right.index || right.end - left.end);
  return occurrences.map((occurrence, index) => {
    const next = occurrences[index + 1];
    const hardEnd = next?.index ?? answer.length;
    const suffix = answer.slice(occurrence.index, hardEnd);
    const delimiter = suffix.search(/[\n。！？；]/u);
    return {
      name: occurrence.name,
      context: suffix.slice(0, delimiter < 0 ? suffix.length : delimiter),
    };
  });
}

function moveFactClaims(context: string): MoveFactClaims {
  const leadingDetails = leadingMoveDetails(context);
  return {
    type: claimedMoveTypes(leadingDetails),
    category: claimedMoveCategories(leadingDetails),
    power: claimedNumbers(
      context,
      /威力\s*(?:为|是|[:：])?\s*(\d{1,5})|(\d{1,5})\s*威力/giu,
    ),
    accuracy: claimedNumbers(
      context,
      /命中(?:率)?\s*(?:为|是|[:：])?\s*(\d{1,5})\s*%?|\b(\d{1,5})\s*%?\s*命中率?/giu,
    ),
    pp: claimedNumbers(
      context,
      /\bPP\s*(?:为|是|[:：])?\s*(\d{1,4})|(\d{1,4})\s*PP\b/giu,
    ),
    hasUnsupportedAccuracyClaim: /(?:必中|必定命中|一定命中)/u.test(context),
    hasUnsupportedPowerClaim:
      /(?:威力\s*(?:很|较|非常|相当)?(?:高|低)|(?:高|低)威力)/u.test(context),
  };
}

function leadingMoveDetails(context: string): string {
  const parenthetical =
    context.match(/^[^（(\n]{1,40}[（(]([^）)\n]{1,100})[）)]/u)?.[1] ?? '';
  const explicit =
    context.match(/^(?:.{0,30}?)(?:属性|类型|分类)(?:为|是|[:：])?.{0,30}/u)?.[0] ?? '';
  const moveDescription =
    context.match(/^.{0,50}?(?:系|属性)(?:的)?(?:物理|特殊|变化)?招式/u)?.[0] ?? '';
  const labelledDescription =
    context.match(/^[^\n：:]{1,40}[：:]\s*[^\n。！？；]{1,100}/u)?.[0] ?? '';
  return [parenthetical, explicit, moveDescription, labelledDescription].join('\n');
}

const moveTypeAliases: ReadonlyArray<readonly [string, string]> = [
  ['normal', '一般'], ['fire', '火'], ['water', '水'], ['electric', '电'],
  ['grass', '草'], ['ice', '冰'], ['fighting', '格斗'], ['poison', '毒'],
  ['ground', '地面'], ['flying', '飞行'], ['psychic', '超能力'], ['bug', '虫'],
  ['rock', '岩石'], ['ghost', '幽灵'], ['dragon', '龙'], ['dark', '恶'],
  ['steel', '钢'], ['fairy', '妖精'],
];

function claimedMoveTypes(value: string): string[] {
  const types = new Set<string>();
  for (const [canonical, zh] of moveTypeAliases) {
    const chinesePattern = new RegExp(
      '(?:' + zh + ')(?:系|属性)|(?:属性|类型)(?:为|是|[:：])?\\s*(?:' + zh + ')',
      'u',
    );
    const englishPattern = new RegExp('\\b' + canonical + '(?:-type)?\\b', 'iu');
    if (chinesePattern.test(value) || englishPattern.test(value)) {
      types.add(canonical);
    }
  }
  return [...types];
}

function claimedMoveCategories(value: string): string[] {
  const categories = new Set<string>();
  for (const [canonical, zh] of [
    ['physical', '物理'], ['special', '特殊'], ['status', '变化'],
  ] as const) {
    const chinesePattern = new RegExp(
      '分类(?:为|是|[:：])?\\s*' + zh + '|' + zh +
        '(?=\\s*(?:类|分类|招式|攻击|一般|火|水|电|草|冰|格斗|毒|地面|飞行|超能力|虫|岩石|幽灵|龙|恶|钢|妖精|[,，、）)]))',
      'u',
    );
    const englishPattern = new RegExp('\\b' + canonical + '\\b', 'iu');
    if (chinesePattern.test(value) || englishPattern.test(value)) {
      categories.add(canonical);
    }
  }
  return [...categories];
}

function claimedNumbers(value: string, pattern: RegExp): number[] {
  const values = new Set<number>();
  for (const match of value.matchAll(pattern)) {
    const raw = match.slice(1).find((entry) => entry !== undefined);
    if (raw !== undefined) values.add(Number(raw));
  }
  return [...values];
}

function compareMoveClaims(
  claims: MoveFactClaims,
  facts: MoveFacts | undefined,
): 'move_fact_conflict' | 'move_fact_unverified' | null {
  if (claims.hasUnsupportedAccuracyClaim || claims.hasUnsupportedPowerClaim) {
    return 'move_fact_unverified';
  }
  for (const [field, claimedValues] of [
    ['type', claims.type],
    ['category', claims.category],
    ['power', claims.power],
    ['accuracy', claims.accuracy],
    ['pp', claims.pp],
  ] as const) {
    if (claimedValues.length === 0) continue;
    const verifiedValues = facts?.[field];
    if (!verifiedValues || verifiedValues.size !== 1) return 'move_fact_unverified';
    const verified = [...verifiedValues][0];
    if (claimedValues.some((claimed) => claimed !== verified)) {
      return 'move_fact_conflict';
    }
  }
  return null;
}

function firstString(...values: unknown[]): string | undefined {
  return values.find(
    (value): value is string => typeof value === 'string' && value.length > 0,
  );
}

function finiteNumber(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined;
}

function normalizeMoveName(value: string): string {
  return value
    .normalize('NFKC')
    .toLocaleLowerCase('en-US')
    .replace(/[\s·・_-]+/gu, '');
}

function normalizeMoveType(value: string): string {
  const normalized = value
    .trim()
    .toLocaleLowerCase('en-US')
    .replace(/(?:系|属性)$/u, '');
  return moveTypeAliases.find(
    ([canonical, zh]) => normalized === canonical || normalized === zh,
  )?.[0] ?? normalized;
}

function normalizeMoveCategory(value: string): string {
  const normalized = value.trim().toLocaleLowerCase('en-US');
  const aliases: Record<string, string> = {
    physical: 'physical',
    物理: 'physical',
    special: 'special',
    特殊: 'special',
    status: 'status',
    变化: 'status',
  };
  return aliases[normalized] ?? normalized;
}

function containsEntityName(haystack: string, needle: string): boolean {
  if (!/^[a-z0-9 -]+$/u.test(needle)) return haystack.includes(needle);
  const escaped = needle.replace(/[.*+?^$(){}|[\]\\]/gu, '\\$&');
  return new RegExp(
    '(?:^|[^a-z0-9])' + escaped + '(?:$|[^a-z0-9])',
    'u',
  ).test(haystack);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

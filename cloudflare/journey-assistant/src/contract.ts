export const MAX_QUESTION_LENGTH = 240;
export const MAX_REQUEST_BYTES = 4096;
export const MAX_CONTEXT_IDS = 16;
export const MAX_ANSWER_LENGTH = 1200;

export type AssistantContext = {
  game: 'heartgold' | 'soulsilver';
  generation: 4;
  locationId?: string;
  badgeIds: string[];
  badgeCount?: number;
  milestoneIds: string[];
  locale: 'zh-Hans';
  parserRevision: number;
  /**
   * Optional for schema-v1 callers. When omitted, the current HGSS parser's
   * capabilities are used as a backwards-compatible default.
   */
  contextReliability?: ContextReliability;
};

export type ContextReliability = {
  game: 'save_verified' | 'user_selected';
  location: 'save_verified' | 'unknown';
  badges: 'save_verified' | 'count_only' | 'unknown';
  milestones: 'save_verified' | 'unsupported';
};

export type AssistantRequest = {
  question: string;
  context: AssistantContext;
};

export type AssistantResponse = {
  status: 'answered' | 'needs_clarification' | 'no_match' | 'failed';
  answer: string | null;
  contextUsed?: Record<string, unknown>;
  matchedHintIds?: string[];
  verifiedFacts?: string[];
  unknowns?: string[];
  confidence: 'high' | 'medium' | 'low';
  sources?: { title: string; url: string; accessedAt: string }[];
  followUp: string | null;
  errorCode?: string;
  onlineComposed?: boolean;
};

const allowedRequestKeys = new Set(['question', 'context']);
const allowedContextKeys = new Set([
  'game',
  'generation',
  'locationId',
  'badgeIds',
  'badgeCount',
  'milestoneIds',
  'locale',
  'parserRevision',
  'contextReliability',
]);
const allowedReliabilityKeys = new Set(['game', 'location', 'badges', 'milestones']);
const allowedBadges = new Set([
  'zephyr_badge',
  'hive_badge',
  'plain_badge',
  'fog_badge',
  'storm_badge',
  'mineral_badge',
  'glacier_badge',
  'rising_badge',
  'boulder_badge',
  'cascade_badge',
  'thunder_badge',
  'rainbow_badge',
  'soul_badge',
  'marsh_badge',
  'volcano_badge',
  'earth_badge',
]);

export function parseAssistantRequest(value: unknown): AssistantRequest | null {
  if (!isPlainObject(value) || hasUnexpectedKeys(value, allowedRequestKeys)) return null;
  if (typeof value.question !== 'string') return null;
  const question = value.question.trim();
  if (question.length < 1 || question.length > MAX_QUESTION_LENGTH) return null;
  if (!isPlainObject(value.context) || hasUnexpectedKeys(value.context, allowedContextKeys)) return null;
  const context = value.context;
  if (context.game !== 'heartgold' && context.game !== 'soulsilver') return null;
  if (context.generation !== 4 || context.locale !== 'zh-Hans') return null;
  if (!Number.isInteger(context.parserRevision) || (context.parserRevision as number) < 0) return null;
  if (context.locationId !== undefined && (typeof context.locationId !== 'string' || context.locationId.length > 80)) return null;
  if (!validIds(context.badgeIds, allowedBadges) || !validIds(context.milestoneIds)) return null;
  if (
    context.badgeCount !== undefined &&
    (!Number.isInteger(context.badgeCount) || (context.badgeCount as number) < 0 || (context.badgeCount as number) > 16)
  ) return null;
  const reliability = parseReliability(context.contextReliability, {
    hasLocation: context.locationId !== undefined,
  });
  if (!reliability) return null;
  if (reliability.location === 'save_verified' && context.locationId === undefined) return null;
  if (reliability.location === 'unknown' && context.locationId !== undefined) return null;
  if (reliability.badges === 'save_verified' && context.badgeCount !== undefined) return null;
  if (reliability.badges === 'count_only') {
    if (context.badgeIds.length !== 0 || context.badgeCount === undefined) return null;
  }
  if (reliability.badges === 'unknown' && (context.badgeIds.length !== 0 || context.badgeCount !== undefined)) return null;
  if (reliability.milestones === 'unsupported' && context.milestoneIds.length !== 0) return null;
  return {
    question,
    context: {
      game: context.game,
      generation: 4,
      ...(context.locationId === undefined ? {} : { locationId: context.locationId }),
      badgeIds: context.badgeIds as string[],
      ...(context.badgeCount === undefined ? {} : { badgeCount: context.badgeCount as number }),
      milestoneIds: context.milestoneIds as string[],
      locale: 'zh-Hans',
      parserRevision: context.parserRevision as number,
      contextReliability: reliability,
    },
  };
}

export function effectiveContextReliability(context: AssistantContext): ContextReliability {
  return context.contextReliability ?? {
    game: 'save_verified',
    location: context.locationId === undefined ? 'unknown' : 'save_verified',
    badges: 'save_verified',
    milestones: 'unsupported',
  };
}

function parseReliability(
  value: unknown,
  legacy: { hasLocation: boolean },
): ContextReliability | null {
  if (value === undefined) {
    return {
      game: 'save_verified',
      location: legacy.hasLocation ? 'save_verified' : 'unknown',
      badges: 'save_verified',
      milestones: 'unsupported',
    };
  }
  if (!isPlainObject(value) || hasUnexpectedKeys(value, allowedReliabilityKeys)) return null;
  if (value.game !== 'save_verified' && value.game !== 'user_selected') return null;
  if (value.location !== 'save_verified' && value.location !== 'unknown') return null;
  if (value.badges !== 'save_verified' && value.badges !== 'count_only' && value.badges !== 'unknown') return null;
  if (value.milestones !== 'save_verified' && value.milestones !== 'unsupported') return null;
  return {
    game: value.game,
    location: value.location,
    badges: value.badges,
    milestones: value.milestones,
  };
}

function validIds(value: unknown, allowed?: Set<string>): value is string[] {
  return Array.isArray(value) &&
    value.length <= MAX_CONTEXT_IDS &&
    value.every((item) =>
      typeof item === 'string' &&
      item.length <= 80 &&
      /^[a-z0-9_-]+$/.test(item) &&
      (allowed === undefined || allowed.has(item)),
    );
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function hasUnexpectedKeys(value: Record<string, unknown>, allowed: Set<string>): boolean {
  return Object.keys(value).some((key) => !allowed.has(key));
}

export function validateModelSectionOrder(
  value: unknown,
  allowedSectionIds: string[],
): string[] | null {
  if (!isPlainObject(value) || Object.keys(value).some((key) => key !== 'sectionOrder')) return null;
  if (!Array.isArray(value.sectionOrder) || value.sectionOrder.length !== allowedSectionIds.length) return null;
  if (!value.sectionOrder.every((item) => typeof item === 'string')) return null;
  const order = value.sectionOrder as string[];
  if (new Set(order).size !== order.length) return null;
  const allowed = new Set(allowedSectionIds);
  if (!order.every((item) => allowed.has(item))) return null;
  return order;
}

export function validateModelHintSelection(
  value: unknown,
  allowedHintIds: ReadonlySet<string>,
): { hintId: string } | null {
  if (!isPlainObject(value) || Object.keys(value).some((key) => key !== 'hintId')) return null;
  if (typeof value.hintId !== 'string' || !allowedHintIds.has(value.hintId)) return null;
  return { hintId: value.hintId };
}

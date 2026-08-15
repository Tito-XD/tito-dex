import type { AssistantRequest, AssistantResponse } from './contract';
import {
  effectiveContextReliability,
  validateModelHintSelection,
  validateModelSectionOrder,
} from './contract';
import { progressionHints, type ProgressionHint } from './progression_hints';

export type AiRunner = (
  hint: ProgressionHint,
  request: AssistantRequest,
  deterministic: AssistantResponse,
) => Promise<unknown>;

export type AiHintResolver = (
  hints: ProgressionHint[],
  request: AssistantRequest,
) => Promise<unknown>;

export async function answerQuestion(
  request: AssistantRequest,
  runAi?: AiRunner,
  resolveWithAi?: AiHintResolver,
): Promise<AssistantResponse> {
  const gameHints = progressionHints
    .filter((hint) => hint.games.includes(request.context.game));
  const candidates = gameHints
    .map((hint) => ({ hint, score: scoreHint(hint, request) }))
    .filter((candidate) => candidate.score > 0)
    .sort((left, right) => right.score - left.score);

  let hint: ProgressionHint | undefined;
  let selectedByAi = false;
  if (
    candidates.length === 0 ||
    (candidates.length > 1 && candidates[0].score === candidates[1].score)
  ) {
    if (resolveWithAi && gameHints.length > 0) {
      try {
        const selection = validateModelHintSelection(
          await resolveWithAi(gameHints, request),
          new Set(gameHints.map((candidate) => candidate.id)),
        );
        hint = selection === null
          ? undefined
          : gameHints.find((candidate) => candidate.id === selection.hintId);
        selectedByAi = hint !== undefined;
      } catch {
        hint = undefined;
      }
    }
  } else {
    hint = candidates[0].hint;
  }
  if (!hint && candidates.length === 0) {
    return {
      status: 'no_match',
      answer: null,
      confidence: 'low',
      followUp: '目前只收录少量主线阻塞点。请补充游戏版本、地点、挡路角色或所需道具。',
    };
  }
  if (!hint) {
    return {
      status: 'needs_clarification',
      answer: null,
      confidence: 'low',
      followUp: '我找到多个可能的阻塞点。请补充你所在地点或挡路的角色／物体。',
    };
  }

  const deterministic = deterministicAnswer(hint, request);
  // A unique local rule is already final. Model calls are reserved for hints
  // selected from an unresolved miss/tie, preserving offline-first behavior
  // and the public Workers AI quota.
  if (!selectedByAi) return deterministic;
  // A retrieval/model-selected hint is already an online result. When the
  // optional composer is omitted, return the exact audited answer directly;
  // this avoids spending a second model call merely to reorder its sections.
  if (!runAi) return { ...deterministic, onlineComposed: true };
  try {
    const modelValue = await runAi(hint, request, deterministic);
    const sections = (deterministic.answer ?? '').split('\n\n');
    const sectionIds = sections.map((_, index) => `section-${index}`);
    const order = validateModelSectionOrder(modelValue, sectionIds);
    if (!order) {
      return { ...deterministic, errorCode: 'invalid_model_json' };
    }
    const byId = new Map(sectionIds.map((id, index) => [id, sections[index]]));
    return {
      ...deterministic,
      answer: order.map((id) => byId.get(id)).join('\n\n'),
      onlineComposed: true,
    };
  } catch (error) {
    const errorCode = error instanceof DOMException && error.name === 'AbortError'
      ? 'upstream_timeout'
      : 'upstream_failed';
    return { ...deterministic, errorCode };
  }
}

function scoreHint(hint: ProgressionHint, request: AssistantRequest): number {
  const question = normalize(request.question);
  const reliability = effectiveContextReliability(request.context);
  let score = 0;
  if (hint.subject.aliases.some((alias) => question.includes(normalize(alias)))) score += 5;
  if (hint.locationAliases.some((alias) => question.includes(normalize(alias)))) score += 3;
  if (hint.destinationAliases.some((alias) => question.includes(normalize(alias)))) score += 2;
  // Save location is supporting context, never a question by itself. Without
  // lexical evidence, every unrelated question asked on Route 36 used to be
  // hijacked by the Sudowoodo rule and never reached online retrieval.
  if (score === 0) return 0;
  if (
    reliability.location === 'save_verified' &&
    request.context.locationId &&
    hint.locations.includes(request.context.locationId)
  ) score += 4;
  return score;
}

function deterministicAnswer(hint: ProgressionHint, request: AssistantRequest): AssistantResponse {
  const reliability = effectiveContextReliability(request.context);
  const verifiedFacts = [hint.overviewZh];
  const unknowns: string[] = [];
  const progress: string[] = [];
  for (const requirement of hint.requirements) {
    if (requirement.type === 'badge') {
      if (
        reliability.badges === 'save_verified' &&
        request.context.badgeIds.includes(requirement.id)
      ) {
        progress.push(`你的存档可以确认已取得${requirement.labelZh}。`);
        verifiedFacts.push(`存档已确认${requirement.labelZh}`);
      } else if (reliability.badges === 'save_verified' && request.context.parserRevision > 0) {
        progress.push(`你的存档尚未显示${requirement.labelZh}。`);
      }
    }
    if (requirement.type === 'milestone' && reliability.milestones === 'save_verified') {
      if (request.context.milestoneIds.includes(requirement.id)) {
        progress.push(`你的存档可以确认已完成${requirement.labelZh}。`);
        verifiedFacts.push(`存档已确认${requirement.labelZh}`);
      } else if (request.context.parserRevision > 0) {
        progress.push(`你的存档尚未显示${requirement.labelZh}。`);
      }
    } else if (requirement.reliability === 'not_currently_parsed') {
      unknowns.push(`当前解析器无法确认是否已完成／取得${requirement.labelZh}`);
    }
  }
  return {
    status: 'answered',
    answer: [
      hint.overviewZh,
      hint.steps.map((step) => step.instructionZh).join('\n'),
      progress.join(''),
      unknowns.length === 0 ? '' : `注意：${unknowns.join('；')}。`,
    ].filter(Boolean).join('\n\n'),
    contextUsed: {
      game: request.context.game,
      gameReliability: reliability.game,
      ...(reliability.location === 'save_verified' && request.context.locationId
        ? { locationId: request.context.locationId }
        : {}),
      ...(reliability.badges === 'save_verified'
        ? { badgeIds: request.context.badgeIds }
        : {}),
      ...(reliability.badges === 'count_only' && request.context.badgeCount !== undefined
        ? { badgeCount: request.context.badgeCount }
        : {}),
      contextReliability: reliability,
    },
    matchedHintIds: [hint.id],
    verifiedFacts,
    unknowns,
    confidence: 'high',
    sources: hint.sources,
    followUp: null,
    onlineComposed: false,
  };
}

function normalize(value: string): string {
  return value.trim().toLowerCase().replace(/[\s·・,，.。!?！？()（）\-_/]/g, '');
}

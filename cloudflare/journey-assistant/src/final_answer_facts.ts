import type { AssistantResponse } from './contract';
import { entityNameMismatch, evolutionClaimMismatch } from './structured_entities';

/** Run after every composer/verifier/reconciler and before semantic streaming. */
export function enforceFinalFacts(
  candidate: AssistantResponse,
  structured: AssistantResponse | null,
  sources: readonly { id: string; text: string }[] = [],
): AssistantResponse {
  if (structured?.answer && structured.evidence?.basis === 'structured') {
    // Sources supporting a different generated body cannot be attached as proof
    // of this result. Keep only the executed query's facts, IDs and data scope.
    return { ...structured, answerBlocks: undefined,
      unknowns: candidate.answer === structured.answer ? candidate.unknowns : structured.unknowns,
    };
  }
  if (candidate.answer && (entityNameMismatch(candidate.answer) || evolutionClaimMismatch(candidate.answer, sources))) {
    return {
      status: 'no_match', answer: null, confidence: 'low',
      followUp: '回答中的名称或进化关系未通过资料核对。请改查具体宝可梦或资料条目。',
      errorCode: 'entity_identity_conflict',
      evidence: { basis: 'unverified', scope: 'general', complete: false, entityIds: [] },
    };
  }
  return {
    ...candidate,
    evidence: candidate.evidence ?? {
      basis: candidate.sources?.length ? 'sources' : 'unverified',
      scope: 'general', complete: false, entityIds: [],
    },
  };
}

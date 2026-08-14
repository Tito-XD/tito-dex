import type { AssistantRequest, AssistantResponse } from './contract';

export function buildLogRecord(
  response: AssistantResponse,
  request: AssistantRequest,
): Record<string, unknown> {
  return {
    event: 'assistant_result',
    status: response.status,
    matchedHintIds: response.matchedHintIds ?? [],
    game: request.context.game,
    hasLocation: request.context.locationId !== undefined,
    badgeCount: request.context.badgeCount ?? request.context.badgeIds.length,
    errorCode: response.errorCode ?? null,
    answerMode: response.answerMode ?? null,
    modelUsed: response.modelUsed ?? false,
    aiSearchUsed: response.aiSearchUsed ?? false,
  };
}

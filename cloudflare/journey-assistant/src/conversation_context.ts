import type {
  AssistantHistoryMessage,
  AssistantRequest,
} from './contract';

const followUpPrefix = /^(?:那|那么|然后|之后|接下来|下一步|它|它们|这个|这个呢|那个|那这个|还有|再说|再问|具体|可以|能不能|还能|也能|为什么会|怎么会)/u;
const followUpSuffix = /(?:呢|那呢|这个呢|怎么样|怎么做|怎么办|在哪里|在哪儿|可以吗|能吗|行吗|对吗)$/u;

/**
 * Conversation history is context only for a visibly elliptical follow-up.
 * A selected game and an old Pokemon answer must not turn an unrelated new
 * question into a continuation of the previous topic.
 */
export function isExplicitFollowUpQuestion(question: string): boolean {
  const normalized = question
    .trim()
    .replace(/[，。！？!?、\s]+$/gu, '');
  if (normalized.length === 0 || normalized.length > 48) return false;
  return followUpPrefix.test(normalized) || followUpSuffix.test(normalized);
}

export function recentConversationForQuestion(
  request: AssistantRequest,
  maximumMessages = 6,
): AssistantHistoryMessage[] {
  if (!isExplicitFollowUpQuestion(request.question)) return [];
  return (request.history ?? []).slice(-maximumMessages);
}

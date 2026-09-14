import type {
  AssistantHistoryMessage,
  AssistantRequest,
} from './contract';
import { mentionedEntities } from './structured_entities';

const followUpPrefix = /^(?:那|那么|然后|之后|接下来|下一步|它|它们|这个|这个呢|那个|那这个|还有|再说|再问|具体|可以|能不能|还能|也能|为什么会|怎么会)/u;
const followUpSuffix = /(?:呢|那呢|这个呢|怎么样|怎么做|怎么办|在哪里|在哪儿|可以吗|能吗|行吗|对吗)$/u;
const englishFollowUp = /^(?:what about (?:it|that|this|them|those|these)|(?:how|why|where|when)(?: does| do| is| are| can| would| should)? (?:it|they|that|this|those|these)\b.*|(?:can|could|does|do|is|are|will|would) (?:it|they|that|this|those|these)\b.*|(?:can|could) I (?:use|get|find|play|evolve) (?:it|them)|which ones?|why|how so|what next|and then|tell me more|go on)$/iu;
const englishObjectFollowUp = /^(?:what|which|how|where|when|why)\b.{0,55}\b(?:it|them|that|this)$/iu;
const englishReferenceFollowUp = /^(?:can|could|may|should|would) I\b.{0,35}\b(?:it|them|that|this)\b.{0,35}$|^(?:how many|how much|which)\b.{0,20}\b(?:those|these|that|this)\b.{0,55}$/iu;
const explicitGameTopic = /(?:《[^》]+》|魂银|心金|朱紫|剑盾|晶灿钻石|明亮珍珠|究极之日|究极之月|\b(?:SoulSilver|HeartGold|Scarlet|Violet|Brilliant Diamond|Shining Pearl|Sword|Shield)\b)/iu;

/**
 * Conversation history is context only for a visibly elliptical follow-up.
 * A selected game and an old Pokemon answer must not turn an unrelated new
 * question into a continuation of the previous topic.
 */
export function isExplicitFollowUpQuestion(question: string): boolean {
  const normalized = question
    .trim()
    .replace(/[，。！？!?、\s]+$/gu, '');
  if (normalized.length === 0 || normalized.length > 96) return false;
  if (explicitGameTopic.test(normalized)) return false;
  return followUpPrefix.test(normalized) || followUpSuffix.test(normalized) ||
    englishFollowUp.test(normalized) || englishObjectFollowUp.test(normalized) ||
    englishReferenceFollowUp.test(normalized);
}

export function recentConversationForQuestion(
  request: AssistantRequest,
  maximumMessages = 6,
): AssistantHistoryMessage[] {
  if (!isExplicitFollowUpQuestion(request.question)) return [];
  return (request.history ?? []).slice(-maximumMessages);
}

const retrievalTopicChange = /(?:换(?:个|一个|话题)|另(?:一个|一件)|新问题|动画|动漫|电影|台词|口号|配音|声优|卡牌|卡片|集换式|天气预报|今天天气|明天天气|股价|股票|新闻|代码|编程|\b(?:instead|unrelated|new (?:topic|question)|anime|movie|quote|tcg|ptcg|cards?|weather forecast|stocks?|programming|python|javascript)\b)/iu;
const additionalGameTopic = /(?:白金|钻石|珍珠|黑[２2]?版|白[２2]?版|日月|太阳|月亮|阿尔宙斯|红宝石|蓝宝石|绿宝石|火红|叶绿|水晶|朱版|紫版|\b(?:Platinum|Diamond|Pearl|Black(?: 2)?|White(?: 2)?|Sun|Moon|Ruby|Sapphire|Emerald|FireRed|LeafGreen|Crystal|Legends Arceus)\b)/iu;
const encounterTopic = /(?:捕捉|捕获|抓|捉|遭遇|遇到|出没|栖息|\b(?:catch|capture|encounter)\b)/iu;

/**
 * Resolves only the retrieval subject of an explicitly elliptical follow-up.
 * Keep the original request for answer focus, display and evidence verification.
 * Previous assistant text is never promoted into a retrieval fact or subject.
 */
export function conversationRetrievalRequest(request: AssistantRequest): AssistantRequest {
  if (!isExplicitFollowUpQuestion(request.question) ||
      retrievalTopicChange.test(request.question) ||
      additionalGameTopic.test(request.question) ||
      mentionedEntities(request.question).length > 0) return request;

  const previousUsers = recentConversationForQuestion(request, 12)
    .filter((message) => message.role === 'user').reverse();
  for (const previous of previousUsers) {
    if (retrievalTopicChange.test(previous.content)) return request;
    const subjects = mentionedEntities(previous.content);
    if (subjects.length > 1) return request;
    if (subjects.length === 0) {
      // Skip only other elliptical turns, never an intervening new topic.
      if (isExplicitFollowUpQuestion(previous.content)) continue;
      return request;
    }
    const subject = subjects[0];
    const intent = subject.kind === 'pokemon' && encounterTopic.test(previous.content)
      ? '捕捉条件'
      : '原问题';
    // Put the latest focus first so the bounded search query keeps questions
    // such as weekday/time, rather than only repeating an earlier location ask.
    const prefix = `${subject.zh}（${subject.en}） ${request.question}；${intent}：`;
    return {
      ...request,
      question: prefix + previous.content.slice(0, Math.max(0, 240 - prefix.length)),
    };
  }
  return request;
}

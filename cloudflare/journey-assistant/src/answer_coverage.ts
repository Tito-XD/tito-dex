/** A single factual projection cannot also satisfy an explicit explanation,
 * example, comparison or additional subquestion. Keep those on the research path. */
export function needsExpandedAnswer(question: string): boolean {
  return /(?:为什么|为何|原因|原理|举例|例子|举.{0,5}例|区别|比较|对比|分别|以及|另外|还需要|需要先|\bwhy\b|\bexamples?\b|\bcompare\b|\bdifference\b|\balso\b|\band (?:how|what|where|when|why|which|do|does|can)\b)/iu.test(question) ||
    (question.match(/[?？]/gu)?.length ?? 0) > 1;
}

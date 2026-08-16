/**
 * Questions about the wider Pokémon franchise must not inherit the selected
 * save/game as a factual constraint. The vocabulary stays deliberately narrow:
 * it covers animation, characters, voices and quotations, while the existing
 * server-owned Pokémon-domain allowlist remains the final research boundary.
 */
const generalFranchiseIntent = /(?:动画|动漫|剧场版|电影|特别篇|台词|口头禅|开场白|谁说的|谁讲的|谁的(?:台词|口头禅)|哪一集|第几集|火箭队|武藏|小次郎|喵喵|角色|配音|声优)/u;

export function isGeneralPokemonFranchiseQuestion(question: string): boolean {
  return generalFranchiseIntent.test(question.trim());
}

/** Keep Mega Evolution separate from an ordinary species evolution chain. */
export function isMegaEvolutionQuestion(question: string): boolean {
  const normalized = question.trim();
  return /(?:超级|超級)进化|(?:超级|超級)進化/iu.test(normalized) ||
    /(?:\bmega\b|メガ)/iu.test(normalized) && /(?:进化|進化|evol)/iu.test(normalized);
}

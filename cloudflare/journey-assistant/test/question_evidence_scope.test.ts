import { describe, expect, it } from 'vitest';
import { sourceMatchesPokemonQuestion } from '../src/pokemon_source_scope';
import type { AssistantRequest } from '../src/contract';
import { evidenceScopeInstruction, questionEvidenceDomain } from '../src/question_evidence_scope';
import { isGeneralPokemonFranchiseQuestion } from '../src/pokemon_question_scope';

const request = (question: string): AssistantRequest => ({ question, context: {
  game: 'general', generation: 0, badgeIds: [], milestoneIds: [], locale: 'zh-Hans', parserRevision: 0,
  contextReliability: { game: 'user_selected', location: 'unknown', badges: 'unknown', milestones: 'unsupported' },
} });

describe('evidence belongs to the requested work and fact domain', () => {
  it('answers explicit manga scope with work and character attribution rather than blanket clarification', () => {
    const manga = request('《宝可梦特别篇》漫画里的小黄是谁？');
    expect(questionEvidenceDomain(manga)).toBe('manga');
    expect(isGeneralPokemonFranchiseQuestion('宝可梦漫画里的小黄是谁？')).toBe(true);
    expect(evidenceScopeInstruction(manga)).toContain('漫画问题可以正常回答');
    expect(evidenceScopeInstruction(manga)).toContain('漫画作品名与人物版本');
    expect(evidenceScopeInstruction(manga)).toContain('仅当未指定作品');
    expect(sourceMatchesPokemonQuestion(manga, { title: 'Yellow (Adventures)',
      url: 'https://bulbapedia.bulbagarden.net/wiki/Yellow_(Adventures)' })).toBe(true);
  });
  it.each([
    ['皮卡丘为什么进化成雷丘？', '赤红的皮卡丘（欢乐祭）', 'https://wiki.52poke.com/wiki/赤红的皮卡丘（欢乐祭）'],
    ['How does Pikachu evolve?', "Ash's Pikachu", 'https://bulbapedia.bulbagarden.net/wiki/Ash%27s_Pikachu'],
    ['动画里的小智是谁？', 'Red (Adventures)', 'https://bulbapedia.bulbagarden.net/wiki/Red_(Adventures)'],
    ['PTCG每回合可以附加几张能量？', 'Energy Zone - Pokémon TCG Pocket', 'https://www.pokemon.com/us/pokemon-tcg-pocket/energy-zone'],
    ['TCG Pocket能量区怎么用？', 'Pokémon Trading Card Game rulebook', 'https://www.pokemon.com/rulebook.pdf'],
  ])('rejects cross-domain evidence for %s', (question, title, url) => {
    expect(sourceMatchesPokemonQuestion(request(question), { title, url })).toBe(false);
  });
  it.each([
    ['皮卡丘怎么进化？', 'Pikachu (Pokémon)', 'https://bulbapedia.bulbagarden.net/wiki/Pikachu_(Pok%C3%A9mon)'],
    ['《欢乐祭》中赤红的皮卡丘发生过什么？', '赤红的皮卡丘（欢乐祭）', 'https://wiki.52poke.com/wiki/赤红的皮卡丘（欢乐祭）'],
    ['Pokémon manga 中 Yellow 是谁？', 'Yellow - Pocket Monsters Special manga', 'https://bulbapedia.bulbagarden.net/wiki/Yellow_(Adventures)'],
    ['Who are Jessie and James in the Pokemon anime?', 'Jessie', 'https://bulbapedia.bulbagarden.net/wiki/Jessie'],
    ['PTCG能量规则是什么？', 'Official rulebook', 'https://assets.pokemon.com/assets/rulebook.pdf'],
    ['TCG Pocket能量区怎么用？', 'Energy Zone - Pokémon TCG Pocket', 'https://www.pokemon.com/us/pokemon-tcg-pocket/energy-zone'],
  ])('retains matching evidence for %s', (question, title, url) => {
    expect(sourceMatchesPokemonQuestion(request(question), { title, url })).toBe(true);
  });
});

import type { AssistantRequest } from './contract';
import { mangaIdentity, pocketIdentity, questionEvidenceDomain } from './question_evidence_scope';
import { mentionedEntities } from './structured_entities';

/** Reject known mismatched evidence before either strict or relaxed verification. */
export function sourceMatchesPokemonQuestion(
  request: AssistantRequest,
  source: { title: string; url?: string | null },
): boolean {
  let identity = source.title;
  if (source.url) {
    try {
      const url = new URL(source.url);
      if (url.searchParams.has('diff') || url.searchParams.get('action') === 'history') {
        return false;
      }
      identity += ' ' + decodeURIComponent(url.pathname + url.hash);
    } catch {
      return false;
    }
  }
  identity = identity.replaceAll('_', ' ');
  const domain = questionEvidenceDomain(request);
  const mangaSource = mangaIdentity.test(identity);
  const pocketSource = pocketIdentity.test(identity);
  const characterSpeciesSource = mentionedEntities(source.title, 'pokemon').some((entity) =>
    identity.includes(`的${entity.zh}`) || identity.toLowerCase().includes(`'s ${entity.en.toLowerCase()}`));
  if (mangaSource && domain !== 'manga') return false;
  if (characterSpeciesSource && (domain === 'mechanics' || domain === 'gameplay')) return false;
  if (pocketSource && domain !== 'pocket') return false;
  const cardSource = /(?:\bTCG\b|Trading Card Game|集换式|卡牌|卡片|\([^)]*[A-Za-z][^)]* \d{1,3}(?:\/\d{1,3})?\))/iu.test(identity);
  const cardQuestion = domain === 'cards' || domain === 'pocket';
  if (domain === 'pocket' && !pocketSource && /(?:rulebook|规则|規則|manual)/iu.test(identity)) return false;
  if (cardQuestion) {
    // Species game pages and walkthroughs do not establish card rules or text.
    const gameOnlySource = /(?:\(Pok[eé]mon\)|\/pokedex(?:-[a-z0-9]+)?\/|#(?:Game locations|Learnset|By leveling up|By HM)|walkthrough|游戏攻略|游戏流程)/iu.test(identity);
    return cardSource || !gameOnlySource;
  }
  if (cardSource) return false;
  return true;
}

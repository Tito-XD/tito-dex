import pokemon from '../../../flutter/assets/l10n/zh/species_labels.json';
import move from '../../../flutter/assets/l10n/zh/moves_labels.json';
import ability from '../../../flutter/assets/l10n/zh/abilities_labels.json';
import item from '../../../flutter/assets/l10n/zh/items_labels.json';

export type EntityKind = 'pokemon' | 'move' | 'ability' | 'item';
export type StructuredEntity = { id: number; kind: EntityKind; zh: string; en: string };
const catalogs = { pokemon, move, ability, item };
export const entities: StructuredEntity[] = Object.entries(catalogs).flatMap(([kind, rows]) =>
  Object.entries(rows).map(([id, row]) => ({
    id: Number(id), kind: kind as EntityKind, zh: row.zh, en: row.en,
  })),
);
const byId = new Map(entities.map((entity) => [`${entity.kind}:${entity.id}`, entity]));
export function entityName(kind: EntityKind, id: number): string | null {
  return byId.get(`${kind}:${id}`)?.zh ?? null;
}
export function mentionedEntities(text: string, kind?: EntityKind): StructuredEntity[] {
  const lower = text.toLowerCase();
  const occupied: [number, number][] = [];
  return entities.filter((entity) => !kind || entity.kind === kind)
    .sort((a, b) => b.zh.length - a.zh.length || b.en.length - a.en.length)
    .filter((entity) => [entity.zh, entity.en].some((name) => {
      if (!name || name.length < 2) return false;
      const at = lower.indexOf(name.toLowerCase());
      if (at < 0 || occupied.some(([start, end]) => at >= start && at < end)) return false;
      if (/^[a-z]/iu.test(name) && (/[a-z]/iu.test(lower[at - 1] ?? '') ||
          /[a-z]/iu.test(lower[at + name.length] ?? ''))) return false;
      occupied.push([at, at + name.length]);
      return true;
    })).slice(0, 12);
}

/** A model's supported=true cannot make two different entity IDs equivalent. */
export function entityNameMismatch(answer: string): boolean {
  for (const match of answer.matchAll(/([\u3400-\u9fff·]{2,24})\s*[（(]\s*([A-Za-z][A-Za-z .:'’-]{1,40})\s*[）)]/gu)) {
    const english = entities.filter((entity) => entity.en.toLowerCase() === match[2].toLowerCase());
    if (!english.length) continue;
    // Chinese prose may run directly into the name; use the longest suffix.
    const chinese = entities.filter((entity) => match[1].endsWith(entity.zh))
      .sort((a, b) => b.zh.length - a.zh.length);
    if (chinese.length && !english.some((entity) =>
      entity.kind === chinese[0].kind && entity.id === chinese[0].id)) return true;
  }
  return false;
}

/** Check affirmative evolution claims against complete, locally supplied graphs. */
export function evolutionClaimMismatch(answer: string, sources: readonly { id: string; text: string }[]): boolean {
  for (const source of sources) {
    if (!source.id.startsWith('dex-bundle-') || source.text.length > 24_000) continue;
    let parsed: unknown;
    try { parsed = JSON.parse(source.text); } catch { continue; }
    if (!record(parsed) || !record(parsed.species) || !record(parsed.species.evolutionChain)) continue;
    const chain = parsed.species.evolutionChain;
    if (chain.truncated !== false || !Array.isArray(chain.edges) || chain.edges.length > 40) continue;
    const graph = new Map<number, number[]>();
    for (const edge of chain.edges) {
      if (!record(edge) || typeof edge.fromStableId !== 'string' || typeof edge.toStableId !== 'string') continue;
      const from = Number(edge.fromStableId.replace(/^pokemon:/u, ''));
      const to = Number(edge.toStableId.replace(/^pokemon:/u, ''));
      if (!entityName('pokemon', from) || !entityName('pokemon', to)) continue;
      graph.set(from, [...(graph.get(from) ?? []), to]);
      if (!graph.has(to)) graph.set(to, []);
    }
    for (const [from] of graph) {
      const name = entityName('pokemon', from)!;
      const pattern = new RegExp(`${name}([^。；！？\\n]{0,12}?)(?:进化成|进化为|进化到)([\\u3400-\\u9fff]{2,16})`, 'gu');
      for (const match of answer.matchAll(pattern)) {
        if (/(?:不|无法|未能)/u.test(match[1])) continue;
        const target = entities.filter((entity) => entity.kind === 'pokemon' && match[2].startsWith(entity.zh))
          .sort((a, b) => b.zh.length - a.zh.length)[0];
        if (!target) continue;
        const visited = new Set<number>();
        const pending = [...(graph.get(from) ?? [])];
        while (pending.length) {
          const id = pending.pop()!;
          if (visited.has(id)) continue;
          visited.add(id); pending.push(...(graph.get(id) ?? []));
        }
        if (!visited.has(target.id)) return true;
      }
    }
  }
  return false;
}

function record(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

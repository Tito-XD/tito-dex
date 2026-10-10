import type { AssistantRequest, AssistantResponse, QuestionGameScope } from './contract';
import type { CuratedSource } from './curated_web';
import { isBasicOutlineRequest } from './basic_web_outline';
import { conversationRetrievalRequest } from './conversation_context';
import { mentionedEntities } from './structured_entities';
import { referenceGameScope } from './request_game_scope';
import definitions from './question_game_aliases.json';
import { publicHttpsUrl } from './web_search_common';

type ProjectionCounts = { lineCount: number; pipeRows: number; matchedHeadings: number; mismatchedHeadings: number; headerTables: number; gameHeaderCells: number; locationHeaderCells: number; compactGameCells: number; knownPrefixUnknownGameCells: number; twoColumnRows: number; outsideLocationRows: number; unknownGameCells: number; qualifierRejected: number; invalidLocation: number; weatherRejected: number; quoteRejected: number; acceptedRows: number };
const newCounts = (): ProjectionCounts => ({ lineCount: 0, pipeRows: 0, matchedHeadings: 0, mismatchedHeadings: 0, headerTables: 0, gameHeaderCells: 0, locationHeaderCells: 0, compactGameCells: 0, knownPrefixUnknownGameCells: 0, twoColumnRows: 0, outsideLocationRows: 0, unknownGameCells: 0, qualifierRejected: 0, invalidLocation: 0, weatherRejected: 0, quoteRejected: 0, acceptedRows: 0 });
type CaptureRow = { games: QuestionGameScope['titles']; location: string; condition?: string; method?: string; quote: string; source: CuratedSource };
const compactName = (value: string) => value.normalize('NFKC').replace(/\s+/gu, '').toLocaleLowerCase('en-US');
const gameTokens = definitions.flatMap((definition) => definition.aliases.flatMap((alias) => {
  if (/[()（）]/u.test(alias)) return [];
  const scope = referenceGameScope(alias);
  return scope ? [{ token: compactName(alias), titles: scope.titles }] : [];
}))
  .sort((a, b) => b.token.length - a.token.length);
const locationHeading = /^(?:#{1,6}\s*)?(?:where to (?:find|catch|get)|how to (?:obtain|get|catch)|game locations?|encounter locations?|locations?|捕捉地点|获得地点|出现地点|分布地点)(?:\s+(.+?))?\s*[:：]?$/iu;
const otherHeading = /^(?:#{1,6}\s*)?(?:evolution(?: chart)?|type (?:defenses|effectiveness)|base stats|moves|abilities|进化|属性|招式|种族值|特性)\s*[:：]?$/iu;
const gameHeaders = /^(?:game(?:s|\(s\))?(?:\s+version(?:s|\(s\))?)?|version(?:s|\(s\))?|games?\s*\/\s*versions?|游戏|版本|游戏版本)$/iu;
const locationHeaders = /^(?:location(?:s|\(s\))?|where to (?:find|get|catch)|how to (?:obtain|get|catch)|obtain method|encounter location(?:s|\(s\))?|地点|捕捉地点|获得地点|出现地点|获得方式|取得方式)(?:\s+(.+?))?$/iu;
const conditionHeaders = /^(?:weather|conditions?|天气|条件)$/iu;
const methodHeaders = /^(?:methods?|obtain method|方式|获得方式)$/iu;

/** A conservative source projection, not model memory: complete edition cells
 * and explicit location rows only. No inference from URL slugs or loose prose. */
export function extractBasicCaptureOutline(request: AssistantRequest, sources: CuratedSource[], now: () => Date): AssistantResponse | null {
  if (!isBasicOutlineRequest(request) || !/(?:捕捉|捕获|抓|获得|哪里|在哪|catch|obtain|where)/iu.test(request.question)) return null;
  const subjects = mentionedEntities(conversationRetrievalRequest(request).question, 'pokemon');
  if (subjects.length !== 1) { console.log(JSON.stringify({ event: 'assistant_capture_projection', reason: 'request_subject_count', subjectCount: subjects.length })); return null; }
  const selected: CaptureRow[] = [];
  const seen = new Set<string>();
  for (const [sourcePosition, source] of sources.entries()) {
    const counts = newCounts();
    const titleSubjects = mentionedEntities(source.title, 'pokemon');
    const titleMatches = titleSubjects.length === 1 && titleSubjects[0].id === subjects[0].id;
    const publicSource = Boolean(source.url && publicHttpsUrl(source.url));
    const diagnostic = (reason: string) => console.log(JSON.stringify({ event: 'assistant_capture_projection', reason,
      sourcePosition, publicSource, titleSubjectCount: titleSubjects.length, titleMatches, ...counts }));
    if (!publicSource || !titleMatches) { diagnostic(!publicSource ? 'nonpublic_source' : 'title_subject_mismatch'); continue; }
    const parsed = readRows(source, subjects[0], counts);
    diagnostic(parsed.length ? 'rows_found' : 'no_clear_rows');
    for (const row of parsed) {
      const key = `${row.games.map((game) => game.en).join('|')}|${row.location}|${row.condition ?? ''}|${row.method ?? ''}`;
      if (seen.has(key)) continue;
      seen.add(key); selected.push(row);
      if (selected.length === 2) break;
    }
    if (selected.length === 2) break;
  }
  if (!selected.length) return null;
  const used = [...new Map(selected.map((row) => [row.source.url!, row.source])).values()];
  const sourceKinds = [...new Set(used.flatMap((source) => source.searchProviders ??
    (source.id.startsWith('exa-') ? ['exa' as const] : source.id.startsWith('tavily-') ? ['tavily' as const] : [])))];
  return {
    status: 'answered', confidence: 'low', followUp: null, outlineMode: 'basic_web_outline', onlineComposed: false,
    contextUsed: { game: 'general', scope: 'general_mechanics' }, matchedHintIds: [], verifiedFacts: [],
    answer: '部分游戏里的获得地点/途径：\n' + selected.map((row) => `- 《${row.games.map((game) => game.zh).join('／')}》：${row.location}${row.condition ? `；原文条件：${row.condition}` : ''}${row.method ? `；原文方式：${row.method}` : ''}。`).join('\n') +
      '\n\n这里只保留原文列出的地点或途径；未标明的获得方式尚未确认，不代表各版本共有。',
    unknowns: ['这是本次检索资料的基础参考，部分地点保留来源名称；资料未说明的获取步骤尚未确认，来源尚未经人工审核。'],
    sources: used.map((source) => ({ title: source.title, url: source.url!, accessedAt: now().toISOString().slice(0, 10) })),
    sourceKinds, evidence: { basis: 'sources', scope: 'general', complete: false, entityIds: [`pokemon:${subjects[0].id}`] },
  };
}

function readRows(source: CuratedSource, subject: { en: string; zh: string }, counts: ProjectionCounts): CaptureRow[] {
  const isLocationHeading = (value: string) => {
    const match = locationHeading.exec(cleanCell(value));
    if (!match) return false;
    const tail = match[1]?.trim().toLocaleLowerCase('en-US');
    return !tail || tail === subject.en.toLocaleLowerCase('en-US') || tail === subject.zh;
  };
  const isLocationColumn = (value: string) => {
    const match = locationHeaders.exec(value);
    if (!match) return false;
    const tail = match[1]?.trim().toLocaleLowerCase('en-US');
    return !tail || tail === subject.en.toLocaleLowerCase('en-US') || tail === subject.zh;
  };
  const lines = [...source.text.matchAll(/[^\r\n]+(?:\r?\n|$)/gu)].map((match) => ({ line: match[0].trim(), offset: match.index, raw: match[0] }));
  counts.lineCount = lines.length;
  counts.pipeRows = lines.filter((entry) => entry.line.includes('|')).length;
  const validLocation = (value: string, metadata = false) => {
    if (usableValue(value, metadata)) return true;
    counts.invalidLocation++;
    if (!metadata && value.split(/[,、，]/u).some((part) => weatherOnly(part.trim()))) counts.weatherRejected++;
    return false;
  };
  const rows: CaptureRow[] = [];
  let inLocations = false;
  let unscopedTableAllowed = true;
  let columns: { game: number; location: number; condition: number; method: number } | null = null;
  for (let index = 0; index < lines.length && rows.length < 8; index++) {
    const line = lines[index].line;
    const normalizedLine = cleanCell(line);
    if (isLocationHeading(normalizedLine)) { counts.matchedHeadings++; inLocations = true; unscopedTableAllowed = false; columns = null; continue; }
    if (locationHeading.test(normalizedLine)) { counts.mismatchedHeadings++; inLocations = false; unscopedTableAllowed = false; columns = null; continue; }
    if (otherHeading.test(normalizedLine)) { inLocations = false; unscopedTableAllowed = false; columns = null; continue; }
    const cells = normalizedLine.includes('|') ? normalizedLine.replace(/^\||\|$/gu, '').split('|').map(cleanCell) : [];
    if (cells.length >= 2) {
      const game = cells.findIndex((cell) => gameHeaders.test(cell));
      const location = cells.findIndex(isLocationColumn);
      counts.gameHeaderCells += cells.filter((cell) => gameHeaders.test(cell)).length;
      counts.locationHeaderCells += cells.filter(isLocationColumn).length;
      if ((inLocations || unscopedTableAllowed) && game >= 0 && location >= 0) { counts.headerTables++; columns = { game, location, condition: cells.findIndex((cell) => conditionHeaders.test(cell)), method: cells.findIndex((cell, position) => position !== location && methodHeaders.test(cell)) }; continue; }
      if (!columns && cells.length === 2 && !inLocations) counts.outsideLocationRows++;
      if (!columns && inLocations && cells.length === 2) {
        counts.twoColumnRows++;
        const games = gameCell(cells[0], counts);
        if (games && validLocation(cells[1])) addRow(rows, source, games, cells[1], line, counts);
      }
      if (columns && !cells.every((cell) => /^[-: ]*$/u.test(cell))) {
        const games = gameCell(cells[columns.game] ?? '', counts);
        const locationCell = cells[columns.location] ?? '';
        const condition = columns.condition >= 0 ? cells[columns.condition] : '';
        const method = columns.method >= 0 ? cells[columns.method] : '';
        if (games && validLocation(locationCell) && (!condition || validLocation(condition, true)) && (!method || validLocation(method, true))) {
          addRow(rows, source, games, locationCell, line, counts, condition, method);
        }
      }
      continue;
    }
    if (!inLocations) continue;
    const labelled = /^(.{1,80}?)\s*[:：]\s*(.{3,180})$/u.exec(line);
    if (labelled) {
      const games = gameCell(cleanCell(labelled[1]), counts);
      const location = cleanCell(labelled[2]);
      if (games && validLocation(location)) addRow(rows, source, games, location, line, counts);
      continue;
    }
    const games = gameCell(cleanCell(line), counts);
    if (!games) continue;
    let next = index + 1;
    const combined = [...games];
    while (next < lines.length) {
      const additional = gameCell(cleanCell(lines[next].line));
      if (!additional) break;
      combined.push(...additional); next++;
    }
    if (next >= lines.length || isLocationHeading(lines[next].line) || otherHeading.test(cleanCell(lines[next].line))) continue;
    const location = cleanCell(lines[next].line);
    const after = lines[next + 1]?.line ?? '';
    // Unlabelled weather below a location is ambiguous: never discard it and
    // promote the remaining location to an unconditional encounter.
    if (weatherOnly(after)) { counts.weatherRejected++; index = next; continue; }
    const labelledCondition = /^(?:weather|conditions?|天气|条件)\s*[:：]\s*(.+)$/iu.exec(after);
    const condition = labelledCondition ? cleanCell(labelledCondition[1]) : '';
    const end = next + (labelledCondition ? 1 : 0);
    const quote = source.text.slice(lines[index].offset, lines[end].offset + lines[end].raw.trimEnd().length);
    if (validLocation(location) && (!condition || validLocation(condition, true))) addRow(rows, source,
      [...new Map(combined.map((game) => [game.en, game])).values()], location, quote, counts, condition);
    index = end;
  }
  return rows;
}

function addRow(rows: CaptureRow[], source: CuratedSource, games: QuestionGameScope['titles'], location: string, quote: string, counts: ProjectionCounts, condition?: string, method?: string) {
  // This is exact original contiguous evidence, not reconstructed nearby cells.
  if (quote.length < 12 || quote.length > 600 || !source.text.includes(quote)) { counts.quoteRejected++; return; }
  counts.acceptedRows++;
  rows.push({ games, location, quote, source, ...(condition ? { condition } : {}), ...(method ? { method } : {}) });
}
function gameCell(cell: string, counts?: ProjectionCounts): QuestionGameScope['titles'] | null {
  const unknown = () => { if (counts) counts.unknownGameCells++; return null; };
  // A parenthesized qualifier may be a required DLC/scope condition, not a
  // harmless game code. Do not use the global selector's suffix stripping.
  if (/[()（）]/u.test(cell)) { if (counts) counts.qualifierRejected++; return unknown(); }
  const direct = referenceGameScope(cell);
  if (direct) return direct.titles;
  const compact = compactName(cell.trim().replace(/^(?:宝可梦|寶可夢|pok[eé]mon)\s*/iu, ''));
  let remaining = compact;
  const titles: QuestionGameScope['titles'] = [];
  // Browser extraction can concatenate adjacent version badges. Every byte
  // must belong to a known title or an explicit separator; no leftover text
  // becomes a guessed place or a partially recognized edition.
  while (remaining && titles.length < 8) {
    remaining = remaining.replace(/^(?:[\/,&+]+|and)/iu, '');
    if (!remaining) break;
    const entry = gameTokens.find((candidate) => candidate.token && remaining.startsWith(candidate.token));
    if (!entry) {
      if (counts && gameTokens.some((candidate) => compact.startsWith(candidate.token))) counts.knownPrefixUnknownGameCells++;
      return unknown();
    }
    titles.push(...entry.titles); remaining = remaining.slice(entry.token.length);
  }
  if (remaining || !titles.length) return unknown();
  if (counts) counts.compactGameCells++;
  return [...new Map(titles.map((title) => [title.en, title])).values()];
}
function cleanCell(text: string): string {
  return text.replace(/<br\s*\/?>/giu, ' / ').replace(/\[([^\]]+)\]\([^)]*\)/gu, '$1').replace(/[*`]/gu, '').trim();
}
function weatherOnly(value: string): boolean {
  return /^(?:hail|snow|rain|sandstorm|sun(?:ny)?|fog|thunderstorm|overcast|雹|冰雹|雪|沙暴|晴天|雨天|暴风雪)$/iu.test(value);
}
function usableValue(value: string, metadata = false): boolean {
  return value.length >= (metadata ? 1 : 3) && value.length <= 180 &&
    (metadata || !value.split(/[,、，]/u).some((part) => weatherOnly(part.trim()))) &&
    !/^(?:none|unknown|n\/a|not available|unavailable|no data|(?:location )?data not (?:yet )?available|暂无|未知|未提供|没有)/iu.test(value) &&
    !/[<>\u0000-\u001f\u007f]|https?:|www\.|(?:\b(?:ignore|instructions?|prompt|system|developer)\b|忽略指令|系统提示)/iu.test(value);
}

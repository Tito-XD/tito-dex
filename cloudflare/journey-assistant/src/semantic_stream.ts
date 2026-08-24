import {
  MAX_ANSWER_LENGTH,
  MAX_ANSWER_BLOCKS,
  type AnswerBlockKind,
  type AssistantAnswerBlock,
  type AssistantResponse,
} from './contract';

const MAX_BLOCK_ITEMS = 12;
const MAX_ITEM_LENGTH = 240;
const MAX_TABLE_ROWS = 12;
const MAX_TABLE_COLUMNS = 6;
const MAX_CELL_LENGTH = 120;
// Considerably below the App's 512-code-unit per-event ceiling. Together
// with MAX_ANSWER_LENGTH this keeps the semantic-event envelope small enough
// for the App's bounded 64 KiB NDJSON decoder, even for multi-block answers.
const MAX_STREAM_DELTA_LENGTH = 256;
const MAX_STREAM_DELTAS_PER_BLOCK = 8;

/**
 * Converts a completed, verified answer into bounded semantic blocks.
 * This is deliberately provider-independent: no unverified provider token is
 * exposed, and callers can later replace the composer with a verified async
 * source without changing the wire protocol.
 */
export function attachSemanticAnswer(
  response: AssistantResponse,
): AssistantResponse {
  if (response.status !== 'answered' || !response.answer) {
    return response.answerBlocks?.length
      ? { ...response, answerBlocks: [] }
      : response;
  }
  const answerBlocks = composeAnswerBlocks(response.answer);
  const answer = answerBlocks.map((block) => block.text).join('\n\n');
  if (answer.length > MAX_ANSWER_LENGTH) {
    const canonical = response.answer.slice(0, MAX_ANSWER_LENGTH);
    return {
      ...response,
      answer: canonical,
      answerBlocks: [buildBlock(canonical, 0)],
    };
  }
  return { ...response, answer, answerBlocks };
}

export function composeAnswerBlocks(answer: string): AssistantAnswerBlock[] {
  const normalized = normalizeInlineEnumerations(
    answer.replace(/\r\n?/gu, '\n').trim(),
  );
  if (!normalized) return [];

  const rawGroups = normalized.split(/\n{2,}/gu).flatMap(splitMixedGroup);
  const boundedGroups = rawGroups.length <= MAX_ANSWER_BLOCKS
    ? rawGroups
    : [
        ...rawGroups.slice(0, MAX_ANSWER_BLOCKS - 1),
        rawGroups.slice(MAX_ANSWER_BLOCKS - 1).join('\n\n'),
      ];

  return boundedGroups.map((text, index) => buildBlock(text, index));
}

/** Natural reveal units, packed into protocol-safe bounded deltas. */
export function semanticBlockDeltas(block: AssistantAnswerBlock): string[] {
  let naturalDeltas: string[];
  if (block.kind === 'bullets' || block.kind === 'table') {
    const lines = block.text.split('\n');
    naturalDeltas = lines.map((line, index) =>
      index < lines.length - 1 ? `${line}\n` : line,
    );
  } else {
    naturalDeltas = sentenceDeltas(block.text);
  }
  return packStreamDeltas(naturalDeltas);
}

function splitMixedGroup(group: string): string[] {
  const text = group.trim();
  if (!text) return [];
  const lines = text.split('\n');
  if (lines.every(isBulletLine)) return [text];
  if (lines.length < 2) return [text];

  const firstStructured = lines.findIndex((line, index) =>
    index > 0 && (isBulletLine(line) || isTableStart(lines, index)),
  );
  if (firstStructured < 1) return [text];
  const prefix = lines.slice(0, firstStructured).join('\n').trim();
  const suffix = lines.slice(firstStructured).join('\n').trim();
  return [prefix, suffix].filter(Boolean);
}

function buildBlock(text: string, index: number): AssistantAnswerBlock {
  const lines = text.split('\n');
  const title = headingTitle(lines[0]);
  const body = title ? lines.slice(1).join('\n').trimStart() : text;
  let kind: AnswerBlockKind;
  let items: string[] | undefined;
  let rows: string[][] | undefined;

  if (isMarkdownTable(lines)) {
    kind = 'table';
    rows = parseTableRows(lines);
  } else if (isWarning(body)) {
    kind = 'warning';
  } else if (lines.length > 1 && lines.every(isBulletLine)) {
    kind = 'bullets';
    const parsedItems = lines.map(stripBullet).filter(Boolean);
    // `text` is canonical. Only expose the structured projection when it is
    // complete; otherwise Flutter intentionally reparses the canonical text.
    if (
      parsedItems.length <= MAX_BLOCK_ITEMS &&
      parsedItems.every((item) => item.length <= MAX_ITEM_LENGTH)
    ) {
      items = parsedItems;
    }
  } else {
    kind = index === 0 ? 'summary' : 'paragraph';
  }

  return {
    id: `answer-${String(index + 1).padStart(2, '0')}`,
    kind,
    ...(title ? { title } : {}),
    text,
    ...(items && items.length > 0 ? { items } : {}),
    ...(rows && rows.length > 0 ? { rows } : {}),
  };
}

function sentenceDeltas(text: string): string[] {
  const deltas = text.match(/[^。！？；\n]+[。！？；]?|\n/gu) ?? [];
  return deltas.length > 0 && deltas.join('') === text ? deltas : [text];
}

function packStreamDeltas(naturalDeltas: string[]): string[] {
  const canonical = naturalDeltas.join('');
  if (!canonical) return [];
  // All answer blocks originate from the bounded response contract. Keeping
  // this explicit makes any future contract drift fail closed in tests rather
  // than silently producing an event the App cannot accept.
  if (canonical.length > MAX_ANSWER_LENGTH) {
    throw new RangeError('semantic block exceeds answer contract');
  }

  const bounded = naturalDeltas.flatMap((delta) => {
    const chunks: string[] = [];
    let offset = 0;
    while (offset < delta.length) {
      const end = safeUtf16SliceEnd(
        delta,
        offset,
        MAX_STREAM_DELTA_LENGTH,
      );
      chunks.push(delta.slice(offset, end));
      offset = end;
    }
    return chunks;
  }).filter(Boolean);
  if (bounded.length <= MAX_STREAM_DELTAS_PER_BLOCK) return bounded;

  // Pathological punctuation/newline-heavy text can otherwise create one
  // event per code unit. Repartition only that exceptional case into a small
  // fixed number of exact, contiguous chunks; never merge a tail past the
  // per-event ceiling.
  const packed: string[] = [];
  let offset = 0;
  while (offset < canonical.length) {
    const remainingSlots = MAX_STREAM_DELTAS_PER_BLOCK - packed.length;
    const targetLength = Math.ceil(
      (canonical.length - offset) / remainingSlots,
    );
    const end = safeUtf16SliceEnd(
      canonical,
      offset,
      Math.min(MAX_STREAM_DELTA_LENGTH, targetLength),
    );
    packed.push(canonical.slice(offset, end));
    offset = end;
  }
  return packed;
}

function safeUtf16SliceEnd(
  text: string,
  start: number,
  capacity: number,
): number {
  if (capacity <= 0) return start;
  let end = Math.min(text.length, start + capacity);
  if (
    end < text.length &&
    isHighSurrogate(text.charCodeAt(end - 1)) &&
    isLowSurrogate(text.charCodeAt(end))
  ) {
    end -= 1;
  }
  if (
    end === start &&
    start + 1 < text.length &&
    isHighSurrogate(text.charCodeAt(start)) &&
    isLowSurrogate(text.charCodeAt(start + 1))
  ) {
    return start + 2;
  }
  return end;
}

function isHighSurrogate(codeUnit: number): boolean {
  return codeUnit >= 0xd800 && codeUnit <= 0xdbff;
}

function isLowSurrogate(codeUnit: number): boolean {
  return codeUnit >= 0xdc00 && codeUnit <= 0xdfff;
}

/**
 * Some providers return compact Chinese lists as one paragraph:
 * `1. … 2. …`. Insert line breaks only when a real 1→2 enumeration exists.
 * Decimal numbers, versions and `Lv.40` do not match the boundary rule.
 */
function normalizeInlineEnumerations(text: string): string {
  const marker = /(^|\s)([1-9]|1\d|20)[.、)](?=\s*[^\d\s])/gu;
  const matches = [...text.matchAll(marker)].map((match) => ({
    number: Number(match[2]),
    index: match.index ?? 0,
  }));
  const start = matches.findIndex((match, index) =>
    match.number === 1 && matches[index + 1]?.number === 2
  );
  if (start < 0) return text;
  const sequence = [matches[start]];
  for (let index = start + 1; index < matches.length; index += 1) {
    if (matches[index].number !== sequence.at(-1)!.number + 1) break;
    sequence.push(matches[index]);
  }
  if (sequence.length < 2) return text;
  let result = text;
  for (const entry of sequence.toReversed()) {
    if (entry.index > 0 && result[entry.index] !== '\n') {
      result = `${result.slice(0, entry.index)}\n${result.slice(entry.index + 1)}`;
    }
  }
  return result;
}

function isBulletLine(line: string): boolean {
  return /^\s*(?:[-*+]\s+|\d+[.)、]\s*)\S/u.test(line);
}

function stripBullet(line: string): string {
  return line.replace(/^\s*(?:[-*+]\s+|\d+[.)、]\s*)/u, '').trim();
}

function isTableStart(lines: string[], index: number): boolean {
  return index + 1 < lines.length && lines[index].includes('|') &&
    /^\s*\|?\s*:?-{3,}:?\s*(?:\|\s*:?-{3,}:?\s*)+\|?\s*$/u.test(lines[index + 1]);
}

function isMarkdownTable(lines: string[]): boolean {
  return lines.length >= 2 && isTableStart(lines, 0);
}

function parseTableRows(lines: string[]): string[][] | undefined {
  const dataLines = lines.filter((_, index) => index !== 1);
  if (dataLines.length > MAX_TABLE_ROWS) return undefined;
  const rows = dataLines.map((line) => line
    .replace(/^\s*\|/u, '')
    .replace(/\|\s*$/u, '')
    .split('|')
    .map((cell) => cell.trim()));
  if (
    rows.some(
      (row) =>
        row.length > MAX_TABLE_COLUMNS ||
        row.some((cell) => cell.length > MAX_CELL_LENGTH),
    )
  ) {
    return undefined;
  }
  return rows;
}

function isWarning(text: string): boolean {
  return /^(?:>\s*)?(?:注意|警告|提醒|未知|无法|未能|请注意|请确认)[：:]/u.test(
    text,
  );
}

function headingTitle(line: string): string | undefined {
  const match = /^#{1,6}\s+(.+)$/u.exec(line.trim());
  return match?.[1].trim().slice(0, 80) || undefined;
}

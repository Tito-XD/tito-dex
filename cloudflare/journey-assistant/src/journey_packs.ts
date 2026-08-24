import type { AssistantRequest, JourneyPackReference } from './contract';
import { progressionHints, type ProgressionHint } from './progression_hints';

export const MAX_JOURNEY_PACK_CATALOG_BYTES = 256 * 1024;
export const MAX_JOURNEY_PACK_BYTES = 4 * 1024 * 1024;
export const MAX_JOURNEY_PACK_ENTRIES = 1000;
export const JOURNEY_PACK_CATALOG_KEY = 'journey-packs/catalog.json';

const supportedGameGenerations: Readonly<Record<string, number>> = {
  diamond: 4,
  pearl: 4,
  platinum: 4,
  heartgold: 4,
  soulsilver: 4,
  black: 5,
  white: 5,
  'black-2': 5,
  'white-2': 5,
  x: 6,
  y: 6,
  'omega-ruby': 6,
  'alpha-sapphire': 6,
  sun: 7,
  moon: 7,
  'ultra-sun': 7,
  'ultra-moon': 7,
  sword: 8,
  shield: 8,
  'brilliant-diamond': 8,
  'shining-pearl': 8,
  'legends-arceus': 8,
  scarlet: 9,
  violet: 9,
};

const packIdPattern = /^[a-z0-9][a-z0-9._-]{0,79}$/;
const familyPattern = /^[a-z0-9][a-z0-9._-]{0,39}$/;
const versionPattern = /^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/;
const hintIdPattern = /^[a-z0-9_-]+$/;
const actionPattern = /^[a-z0-9_]+$/;
const isoDatePattern = /^\d{4}-\d{2}-\d{2}$/;
const isoDateTimePattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/;

export type JourneyPackDescriptor = {
  id: string;
  gameFamily: string;
  games: string[];
  version: string;
  contentPath: string;
  sizeBytes: number;
  sha256: string;
  titleZh: string;
  descriptionZh?: string;
  entryCount: number;
  bundleVersionRequired: number;
  minAppVersion?: string;
};

export type LoadedJourneyPackCatalog = {
  descriptors: JourneyPackDescriptor[];
  body: Uint8Array;
};

export async function loadJourneyPackCatalog(
  bucket: R2Bucket | undefined,
): Promise<LoadedJourneyPackCatalog | null> {
  if (!bucket) return null;
  try {
    const object = await bucket.get(JOURNEY_PACK_CATALOG_KEY);
    if (!object || object.size < 2 || object.size > MAX_JOURNEY_PACK_CATALOG_BYTES) {
      return null;
    }
    const body = new Uint8Array(await object.arrayBuffer());
    if (body.byteLength !== object.size) return null;
    const value: unknown = JSON.parse(new TextDecoder().decode(body));
    const descriptors = parseCatalog(value);
    return descriptors ? { descriptors, body } : null;
  } catch {
    return null;
  }
}

export function descriptorForPath(
  descriptors: readonly JourneyPackDescriptor[],
  path: string,
): JourneyPackDescriptor | undefined {
  return descriptors.find((descriptor) => descriptor.contentPath === path);
}

export function descriptorObjectKey(descriptor: JourneyPackDescriptor): string {
  return `journey-packs/objects/${descriptor.id}/${descriptor.version}.json`;
}

export async function readJourneyPackBody(
  descriptor: JourneyPackDescriptor,
  bucket: R2Bucket,
): Promise<Uint8Array | null> {
  try {
    const object = await bucket.get(descriptorObjectKey(descriptor));
    if (
      !object ||
      object.size !== descriptor.sizeBytes ||
      object.size < 2 ||
      object.size > MAX_JOURNEY_PACK_BYTES
    ) return null;
    const body = new Uint8Array(await object.arrayBuffer());
    if (body.byteLength !== descriptor.sizeBytes) return null;
    if (await sha256Hex(body) !== descriptor.sha256) return null;
    return body;
  } catch {
    return null;
  }
}

export async function loadJourneyPackHints(
  request: AssistantRequest,
  bucket: R2Bucket | undefined,
): Promise<ProgressionHint[]> {
  const reference = request.journeyPacks?.[0];
  if (!bucket || !reference) return progressionHints;
  const catalog = await loadJourneyPackCatalog(bucket);
  if (!catalog) return progressionHints;
  const descriptor = catalog.descriptors.find((candidate) =>
    candidate.games.includes(request.context.game)
  );
  if (!descriptor || !referenceMatchesDescriptor(reference, descriptor)) {
    return progressionHints;
  }
  const body = await readJourneyPackBody(descriptor, bucket);
  if (!body) return progressionHints;
  const hints = parsePack(body, descriptor);
  if (!hints) return progressionHints;

  const builtInById = new Map(progressionHints.map((hint) => [hint.id, hint]));
  const merged = [...progressionHints];
  for (const hint of hints) {
    const builtIn = builtInById.get(hint.id);
    if (builtIn) {
      // A downloaded pack may repeat an inherited audited hint, but it cannot
      // silently replace it. Any divergence rejects the complete pack.
      if (canonicalJson(builtIn) !== canonicalJson(hint)) return progressionHints;
      continue;
    }
    merged.push(hint);
  }
  return merged;
}

function parseCatalog(value: unknown): JourneyPackDescriptor[] | null {
  if (!isPlainObject(value) || !hasExactKeys(value, ['schemaVersion', 'generatedAt', 'packs'])) {
    return null;
  }
  if (
    value.schemaVersion !== 1 ||
    typeof value.generatedAt !== 'string' ||
    !isoDateTimePattern.test(value.generatedAt) ||
    Number.isNaN(Date.parse(value.generatedAt)) ||
    !Array.isArray(value.packs)
  ) return null;

  const descriptors: JourneyPackDescriptor[] = [];
  const ids = new Set<string>();
  const paths = new Set<string>();
  const assignedGames = new Set<string>();
  for (const valueDescriptor of value.packs) {
    const descriptor = parseDescriptor(valueDescriptor);
    if (
      !descriptor ||
      ids.has(descriptor.id) ||
      paths.has(descriptor.contentPath) ||
      descriptor.games.some((game) => assignedGames.has(game))
    ) return null;
    ids.add(descriptor.id);
    paths.add(descriptor.contentPath);
    descriptor.games.forEach((game) => assignedGames.add(game));
    descriptors.push(descriptor);
  }
  return descriptors;
}

function parseDescriptor(value: unknown): JourneyPackDescriptor | null {
  if (!isPlainObject(value)) return null;
  const requiredKeys = [
    'id',
    'gameFamily',
    'games',
    'version',
    'contentPath',
    'sizeBytes',
    'sha256',
    'titleZh',
    'entryCount',
    'bundleVersionRequired',
  ];
  if (!hasOnlyKeys(value, [...requiredKeys, 'descriptionZh', 'minAppVersion'])) return null;
  if (requiredKeys.some((key) => !(key in value))) return null;
  if (
    typeof value.id !== 'string' ||
    !safeSegment(value.id, packIdPattern) ||
    typeof value.gameFamily !== 'string' ||
    !safeSegment(value.gameFamily, familyPattern) ||
    typeof value.version !== 'string' ||
    !safeSegment(value.version, versionPattern) ||
    !validGames(value.games) ||
    typeof value.contentPath !== 'string' ||
    value.contentPath !== `/v1/journey-packs/objects/${value.id}/${value.version}.json` ||
    !Number.isInteger(value.sizeBytes) ||
    (value.sizeBytes as number) < 2 ||
    (value.sizeBytes as number) > MAX_JOURNEY_PACK_BYTES ||
    typeof value.sha256 !== 'string' ||
    !/^[a-f0-9]{64}$/.test(value.sha256) ||
    !boundedString(value.titleZh, 1, 80) ||
    !Number.isInteger(value.entryCount) ||
    (value.entryCount as number) < 1 ||
    (value.entryCount as number) > MAX_JOURNEY_PACK_ENTRIES ||
    !Number.isInteger(value.bundleVersionRequired) ||
    (value.bundleVersionRequired as number) < 20 ||
    (value.descriptionZh !== undefined && !boundedString(value.descriptionZh, 1, 180)) ||
    (value.minAppVersion !== undefined &&
      (typeof value.minAppVersion !== 'string' || !/^\d+\.\d+\.\d+$/.test(value.minAppVersion)))
  ) return null;
  return value as JourneyPackDescriptor;
}

function parsePack(
  body: Uint8Array,
  descriptor: JourneyPackDescriptor,
): ProgressionHint[] | null {
  try {
    const value: unknown = JSON.parse(new TextDecoder().decode(body));
    if (!isPlainObject(value)) return null;
    if (!hasOnlyKeys(value, [
      'schemaVersion', 'id', 'gameFamily', 'games', 'version', 'sourceAsOf', 'entries',
    ])) return null;
    for (const key of ['schemaVersion', 'id', 'gameFamily', 'games', 'version', 'entries']) {
      if (!(key in value)) return null;
    }
    if (
      value.schemaVersion !== 1 ||
      value.id !== descriptor.id ||
      value.gameFamily !== descriptor.gameFamily ||
      value.version !== descriptor.version ||
      !sameStringArray(value.games, descriptor.games) ||
      (value.sourceAsOf !== undefined &&
        (typeof value.sourceAsOf !== 'string' || !validIsoDate(value.sourceAsOf))) ||
      !Array.isArray(value.entries) ||
      value.entries.length !== descriptor.entryCount ||
      value.entries.length > MAX_JOURNEY_PACK_ENTRIES
    ) return null;

    const hints: ProgressionHint[] = [];
    const ids = new Set<string>();
    const packGames = new Set(descriptor.games);
    for (const entry of value.entries) {
      const hint = parseProgressionHint(entry, packGames);
      if (!hint || ids.has(hint.id)) return null;
      ids.add(hint.id);
      hints.push(hint);
    }
    return hints;
  } catch {
    return null;
  }
}

function parseProgressionHint(
  value: unknown,
  packGames: ReadonlySet<string>,
): ProgressionHint | null {
  if (!isPlainObject(value) || !hasExactKeys(value, [
    'id',
    'games',
    'generation',
    'locations',
    'locationAliases',
    'destinationAliases',
    'subject',
    'requirements',
    'steps',
    'overviewZh',
    'sources',
  ])) return null;
  if (
    typeof value.id !== 'string' ||
    !hintIdPattern.test(value.id) ||
    !validGames(value.games) ||
    !(value.games as string[]).every((game) => packGames.has(game)) ||
    !Number.isInteger(value.generation) ||
    !(value.games as string[]).every((game) => supportedGameGenerations[game] === value.generation) ||
    !boundedStringArray(value.locations, 0, 80, true) ||
    !boundedStringArray(value.locationAliases, 0, 80) ||
    !boundedStringArray(value.destinationAliases, 0, 80) ||
    !validSubject(value.subject) ||
    !Array.isArray(value.requirements) ||
    !value.requirements.every(validRequirement) ||
    !Array.isArray(value.steps) ||
    value.steps.length < 1 ||
    !value.steps.every(validStep) ||
    !boundedString(value.overviewZh, 1, 180) ||
    !Array.isArray(value.sources) ||
    value.sources.length < 1 ||
    !value.sources.every(validSource)
  ) return null;
  return value as unknown as ProgressionHint;
}

function validSubject(value: unknown): boolean {
  return isPlainObject(value) &&
    hasExactKeys(value, ['type', 'id', 'labelZh', 'aliases']) &&
    ['overworld_blocker', 'story_blocker', 'reference_topic'].includes(String(value.type)) &&
    typeof value.id === 'string' && hintIdPattern.test(value.id) &&
    boundedString(value.labelZh, 1, 80) &&
    boundedStringArray(value.aliases, 1, 80);
}

function validRequirement(value: unknown): boolean {
  if (!isPlainObject(value) || !hasOnlyKeys(value, [
    'type', 'id', 'labelZh', 'itemId', 'reliability',
  ])) return false;
  for (const key of ['type', 'id', 'labelZh', 'reliability']) {
    if (!(key in value)) return false;
  }
  return ['badge', 'key_item', 'milestone'].includes(String(value.type)) &&
    typeof value.id === 'string' && hintIdPattern.test(value.id) &&
    boundedString(value.labelZh, 1, 80) &&
    ['save_verified', 'not_currently_parsed'].includes(String(value.reliability)) &&
    (value.itemId === undefined || (Number.isInteger(value.itemId) && (value.itemId as number) >= 1));
}

function validStep(value: unknown): boolean {
  return isPlainObject(value) &&
    hasExactKeys(value, ['order', 'action', 'targetId', 'locationId', 'instructionZh']) &&
    Number.isInteger(value.order) && (value.order as number) >= 1 &&
    typeof value.action === 'string' && actionPattern.test(value.action) &&
    typeof value.targetId === 'string' && hintIdPattern.test(value.targetId) &&
    boundedString(value.locationId, 1, 120) &&
    boundedString(value.instructionZh, 1, 120);
}

function validSource(value: unknown): boolean {
  if (!isPlainObject(value) || !hasExactKeys(value, ['title', 'url', 'accessedAt'])) return false;
  if (!boundedString(value.title, 1, 180) || !boundedString(value.url, 1, 600)) return false;
  if (typeof value.accessedAt !== 'string' || !validIsoDate(value.accessedAt)) return false;
  try {
    const url = new URL(value.url as string);
    return url.protocol === 'https:' || url.protocol === 'http:';
  } catch {
    return false;
  }
}

function referenceMatchesDescriptor(
  reference: JourneyPackReference,
  descriptor: JourneyPackDescriptor,
): boolean {
  return reference.id === descriptor.id &&
    reference.gameFamily === descriptor.gameFamily &&
    reference.version === descriptor.version &&
    reference.sha256 === descriptor.sha256;
}

async function sha256Hex(value: BufferSource): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', value);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function validGames(value: unknown): value is string[] {
  return Array.isArray(value) &&
    value.length >= 1 &&
    new Set(value).size === value.length &&
    value.every((game) => typeof game === 'string' && game in supportedGameGenerations);
}

function safeSegment(value: string, pattern: RegExp): boolean {
  return pattern.test(value) && !value.includes('..');
}

function boundedString(value: unknown, min: number, max: number): value is string {
  return typeof value === 'string' && value.length >= min && value.length <= max;
}

function boundedStringArray(
  value: unknown,
  minItems: number,
  maxStringLength: number,
  unique = false,
): value is string[] {
  return Array.isArray(value) &&
    value.length >= minItems &&
    (!unique || new Set(value).size === value.length) &&
    value.every((item) => boundedString(item, 1, maxStringLength));
}

function sameStringArray(value: unknown, expected: readonly string[]): boolean {
  return Array.isArray(value) &&
    value.length === expected.length &&
    value.every((item, index) => item === expected[index]);
}

function validIsoDate(value: string): boolean {
  if (!isoDatePattern.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(parsed.getTime()) && parsed.toISOString().startsWith(value);
}

function canonicalJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  if (isPlainObject(value)) {
    return `{${Object.keys(value).sort().map((key) =>
      `${JSON.stringify(key)}:${canonicalJson(value[key])}`
    ).join(',')}}`;
  }
  return JSON.stringify(value);
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function hasExactKeys(value: Record<string, unknown>, expected: readonly string[]): boolean {
  const keys = Object.keys(value);
  return keys.length === expected.length && expected.every((key) => key in value);
}

function hasOnlyKeys(value: Record<string, unknown>, allowed: readonly string[]): boolean {
  const allowedSet = new Set(allowed);
  return Object.keys(value).every((key) => allowedSet.has(key));
}

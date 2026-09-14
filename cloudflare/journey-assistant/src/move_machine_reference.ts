type JsonReader = (url: URL, maximumBytes: number) => Promise<unknown>;

const object = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === 'object' && !Array.isArray(value);

/** Resolve a selected-version machine only from the move's own API links.
 * An item name establishes its number, never where the player obtains it. */
export async function readMoveMachineReference(
  move: Record<string, unknown>,
  versionGroupId: number,
  read: JsonReader,
): Promise<{ number: string; versionGroup: string; sourceUrl: string; acquisition: 'unknown' } | null> {
  if (!versionGroupId || !Number.isInteger(move.id) || !Array.isArray(move.machines)) return null;
  const groupUrl = `https://pokeapi.co/api/v2/version-group/${versionGroupId}/`;
  const row = move.machines.find((entry: unknown) => object(entry) &&
    object(entry.version_group) && entry.version_group.url === groupUrl);
  if (!object(row) || !object(row.machine) || typeof row.machine.url !== 'string' ||
      !/^https:\/\/pokeapi\.co\/api\/v2\/machine\/[1-9]\d*\/$/u.test(row.machine.url)) return null;
  try {
    const value = await read(new URL(row.machine.url), 16_384);
    if (!object(value) || !object(value.move) || !object(value.version_group) ||
        !object(value.item) || value.move.url !== `https://pokeapi.co/api/v2/move/${move.id}/` ||
        value.version_group.url !== groupUrl || typeof value.version_group.name !== 'string' ||
        typeof value.item.name !== 'string' || !/^(?:tm|hm|tr)\d{2,3}$/u.test(value.item.name)) return null;
    return { number: value.item.name.toUpperCase(), versionGroup: value.version_group.name,
      sourceUrl: row.machine.url, acquisition: 'unknown' };
  } catch {
    return null; // Optional enrichment must not discard existing move facts.
  }
}

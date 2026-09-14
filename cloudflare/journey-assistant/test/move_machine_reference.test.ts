import { describe, expect, it, vi } from 'vitest';
import { readMoveMachineReference } from '../src/move_machine_reference';

const group = (id: number) => ({ name: id === 9 ? 'platinum' : 'scarlet-violet', url: `https://pokeapi.co/api/v2/version-group/${id}/` });
const move = { id: 89, machines: [
  { version_group: group(25), machine: { url: 'https://pokeapi.co/api/v2/machine/2000/' } },
  { version_group: group(9), machine: { url: 'https://pokeapi.co/api/v2/machine/500/' } },
] };
const response = { move: { url: 'https://pokeapi.co/api/v2/move/89/' }, version_group: group(9), item: { name: 'tm26' } };

describe('selected-version machine metadata', () => {
  it('also retains technical-record numbers where the selected group supplies them', async () => {
    expect((await readMoveMachineReference(move, 9, async () => ({ ...response, item: { name: 'tr10' } })))?.number).toBe('TR10');
  });
  it('uses the selected group and does not manufacture an acquisition location', async () => {
    const read = vi.fn(async () => response);
    expect(await readMoveMachineReference(move, 9, read)).toEqual({ number: 'TM26', versionGroup: 'platinum',
      sourceUrl: 'https://pokeapi.co/api/v2/machine/500/', acquisition: 'unknown' });
    expect(read).toHaveBeenCalledExactlyOnceWith(new URL('https://pokeapi.co/api/v2/machine/500/'), 16_384);
  });
  it('rejects cross-version, wrong-move, malformed and failed references', async () => {
    for (const value of [{ ...response, version_group: group(25) }, { ...response, move: { url: 'https://pokeapi.co/api/v2/move/1/' } },
      { ...response, item: { name: 'master-ball' } }, null]) {
      expect(await readMoveMachineReference(move, 9, async () => value)).toBeNull();
    }
    expect(await readMoveMachineReference(move, 9, async () => { throw Error('offline'); })).toBeNull();
  });
  it('does not fetch for general, absent group, or a substituted host', async () => {
    const read = vi.fn();
    expect(await readMoveMachineReference(move, 0, read)).toBeNull();
    expect(await readMoveMachineReference(move, 10, read)).toBeNull();
    expect(await readMoveMachineReference({ ...move, machines: [{ version_group: group(9), machine: { url: 'https://example.com/machine/500/' } }] }, 9, read)).toBeNull();
    expect(read).not.toHaveBeenCalled();
  });
});

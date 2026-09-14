import { describe, expect, it } from 'vitest';
import { normalizeGameSpeciesVersionMarkers } from '../src/pokemon_version_markers';

describe('species edition footnotes', () => {
  it('recognizes mixed simplified/traditional catalog spellings', () => {
    expect(normalizeGameSpeciesVersionMarkers('铁辙迹V、鐵轍跡V、铁轍迹V与密勒頓V。',
      '紫的悖谬宝可梦有哪些？', 'violet')).toBe('铁辙迹、鐵轍跡、铁轍迹与密勒頓。');
  });
  it('normalizes catalog species S/V suffixes only for main-series context', () => {
    expect(normalizeGameSpeciesVersionMarkers('密勒顿V和铁包袱V在紫中出现；故勒顿S在朱中出现。',
      '《紫》中有哪些悖谬宝可梦？', 'violet')).toBe('密勒顿和铁包袱在紫中出现；故勒顿在朱中出现。');
  });
  it.each([
    ['皮卡丘V有攻击招式。', 'PTCG皮卡丘V怎么用？', 'violet'],
    ['密勒顿V是卡名。', '密勒顿V是什么？', 'violet'],
    ['密勒顿V', '宝可梦卡牌有哪些？', undefined],
    ['未知名称V和代码SV', '《紫》有什么？', 'violet'],
    ['EeveeVSTAR and EeveeVMAX', '《紫》有什么？', 'violet'],
    ['NotPikachuV，未知图腾S和UnownV', '有哪些字母形态？', 'violet'],
  ] as const)('preserves explicit card names and unrelated text: %s', (answer, question, game) => {
    expect(normalizeGameSpeciesVersionMarkers(answer, question, game)).toBe(answer);
  });
});

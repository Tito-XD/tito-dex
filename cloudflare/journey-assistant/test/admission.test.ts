import { env, SELF, runInDurableObject } from 'cloudflare:test';
import { describe, expect, it, vi } from 'vitest';
import worker from '../src/index';
import { DAILY_QUESTION_LIMIT, MINUTE_QUESTION_LIMIT } from '../src/question_budget';

const payload = JSON.stringify({ question: '挡路的树怎么过？', context: {
  game: 'soulsilver', generation: 4, locationId: 'johto-route-36-area',
  badgeIds: ['plain_badge'], milestoneIds: [], locale: 'zh-Hans', parserRevision: 2,
} });
function request(key: string, ip?: string) {
  return new Request<unknown, IncomingRequestCfProperties>('https://assistant.test/v1/ask', { method: 'POST', body: payload,
    headers: { 'x-titodex-device-key': key, ...(ip ? { 'cf-connecting-ip': ip } : {}),
      'x-forwarded-for': key } });
}
describe('admission security regressions', () => {
  it('rejects excess requests even when every device key is fresh', async () => {
    const responses = [];
    for (let i = 0; i < 21; i++) {
      responses.push(await SELF.fetch(request(`integration-rotated-${i}`, '192.0.2.99')));
    }
    expect(responses.slice(0, 20).every(response => response.status === 200)).toBe(true);
    expect(responses[20].status).toBe(429);
  });

  it('rotating device keys and forwarded headers cannot rotate the edge bucket', async () => {
    const keys: string[] = [];
    const aiRun = vi.spyOn(env.AI ?? { run: async () => null }, 'run');
    const limitedEnv = { ...env, QUESTION_RATE_LIMITER: {
      limit: vi.fn(async ({ key }: { key: string }) => { keys.push(key); return { success: false }; }),
    } } as Env;
    for (let i = 0; i < 21; i++) {
      expect((await worker.fetch(request(`rotated-device-${i}`, '192.0.2.1'), limitedEnv)).status).toBe(429);
    }
    expect(new Set(keys)).toEqual(new Set(['edge:192.0.2.1']));
    expect(aiRun).not.toHaveBeenCalled();
  });
  it('missing edge identity shares a bucket and limiter failures fail closed', async () => {
    const limit = vi.fn(async () => ({ success: false }));
    await worker.fetch(request('rotated-device-1'), { ...env, QUESTION_RATE_LIMITER: { limit } });
    expect(limit).toHaveBeenCalledWith({ key: 'edge:unknown' });
    const broken = { ...env, QUESTION_RATE_LIMITER: { limit: async () => { throw Error('offline'); } } };
    expect((await worker.fetch(request('rotated-device-2'), broken)).status).toBe(503);
  });
  it('global denial happens before any R2, model, or search work', async () => {
    const stub = env.QUESTION_BUDGET.getByName('journey-questions-v1');
    await runInDurableObject(stub, async (_instance, state) => {
      await state.storage.put('counters', { day: Math.floor(Date.now() / 86400000), daily: DAILY_QUESTION_LIMIT, minute: 0, burst: 0 });
    });
    const get = vi.spyOn(env.JOURNEY_CONTENT, 'get');
    const guarded = { ...env, QUESTION_RATE_LIMITER: { limit: async () => ({ success: true }) },
      } satisfies Env;
    expect((await worker.fetch(request('fresh-device-key'), guarded)).status).toBe(429);
    expect(get).not.toHaveBeenCalled();
  });
  it('atomically limits concurrent admissions across clients', async () => {
    const stub = env.QUESTION_BUDGET.getByName(crypto.randomUUID());
    const results = await Promise.all(Array.from({ length: 80 }, () => stub.admit()));
    expect(results.filter(Boolean)).toHaveLength(MINUTE_QUESTION_LIMIT);
  });
  it('daily exhaustion survives minute rollover and resets on a new UTC day', async () => {
    const stub = env.QUESTION_BUDGET.getByName(crypto.randomUUID());
    await runInDurableObject(stub, async (instance, state) => {
      const day = Math.floor(Date.now() / 86400000);
      await state.storage.put('counters', { day, daily: DAILY_QUESTION_LIMIT, minute: 0, burst: 0 });
      expect(await instance.admit()).toBe(false);
      await state.storage.put('counters', { day: day - 1, daily: DAILY_QUESTION_LIMIT, minute: 0, burst: 0 });
      expect(await instance.admit()).toBe(true);
    });
  });
});

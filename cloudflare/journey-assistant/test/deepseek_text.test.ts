import { env } from 'cloudflare:test';
import { afterEach, describe, expect, it, vi } from 'vitest';
import worker, { runTextModel } from '../src/index';
import { runDeepSeekText } from '../src/deepseek_text';
import type { DeepSeekNativeSearchConfig } from '../src/deepseek_native_search';
import type { AssistantResponse } from '../src/contract';

const config: DeepSeekNativeSearchConfig = {
  enabled: true, accountId: 'a'.repeat(32), authToken: 'test-only-gateway-token-12345',
  gatewayId: 'titodex-journey-assistant', provider: 'custom-deepseek-anthropic',
  keyAlias: 'TitoDex', endpoint: 'anthropic/v1/messages', model: 'deepseek-v4-flash',
};
const messages = [{ role: 'system' as const, content: 'Only supplied evidence.' }, { role: 'user' as const, content: '{"sources":[]}' }];
const schema = { type: 'object', properties: { allowed: { type: 'boolean' } } };
function payload(value: unknown) {
  return new Response(JSON.stringify({ stop_reason: 'end_turn', content: [{ type: 'text', text: JSON.stringify(value) }] }));
}
function fakeEnv() {
  return Object.assign({}, env, {
    AI_GATEWAY_ID: config.gatewayId,
    CF_ACCOUNT_ID: config.accountId, CF_AIG_TOKEN: config.authToken,
    CURATED_WEB_ENABLED: 'true', EXA_WEB_ENABLED: 'true', EXA_API_KEY: 'exa-test-key-only-123456789',
    TAVILY_WEB_ENABLED: 'false', TAVILY_API_KEY: '', WEB_SEARCH_PRIMARY: 'exa',
    DEEPSEEK_NATIVE_SEARCH_ENABLED: 'false', DEEPSEEK_TEXT_ENABLED: 'true',
    DEEPSEEK_NATIVE_PROVIDER: config.provider, DEEPSEEK_NATIVE_KEY_ALIAS: config.keyAlias,
  }) as Env;
}
afterEach(() => vi.restoreAllMocks());

describe('DeepSeek text model', () => {
  it('uses the fixed Gateway and explicit BYOK alias with no search tools', async () => {
    const fetcher = vi.fn<typeof fetch>(async (input, init) => {
      expect(input.toString()).toBe(`https://gateway.ai.cloudflare.com/v1/${config.accountId}/titodex-journey-assistant/custom-deepseek-anthropic/anthropic/v1/messages`);
      expect(new Headers(init?.headers).get('cf-aig-byok-alias')).toBe('TitoDex');
      const body = JSON.parse(init?.body as string);
      expect(body.model).toBe('deepseek-v4-flash');
      expect(body).not.toHaveProperty('tools');
      expect(body).not.toHaveProperty('tool_choice');
      expect(body.system).toContain('不得联网');
      return payload({ allowed: true });
    });
    expect(await runDeepSeekText(config, 'curated-web-queries', messages, schema, 250, 0, fetcher)).toEqual({ allowed: true });
    expect(fetcher).toHaveBeenCalledTimes(1);
  });


  it('reports DeepSeek text as the provider after a successful call', async () => {
    const fetcher = vi.spyOn(globalThis, 'fetch').mockResolvedValue(payload({ allowed: true }));
    const trace: { modelUsed: boolean; aiSearchUsed: boolean; modelProviders?: AssistantResponse['modelProviders'] } = { modelUsed: true, aiSearchUsed: false };
    expect(await runTextModel(fakeEnv(), 'curated-web-compose', messages, schema, 250, 0, trace)).toEqual({ allowed: true });
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(trace.modelProviders).toEqual(['deepseek-text']);
    expect(JSON.parse(fetcher.mock.calls[0][1]?.body as string)).not.toHaveProperty('tools');
  });

  it('keeps the shorter Gateway timeout for curated-web phases', async () => {
    const fetcher = vi.spyOn(globalThis, 'fetch').mockImplementation(async () => payload({ allowed: true }));
    await runTextModel(fakeEnv(), 'curated-web-compose', messages, schema, 250, 0);
    await runTextModel(fakeEnv(), 'local-hint-compose', messages, schema, 250, 0);
    const timeouts = fetcher.mock.calls.map((call) => new Headers(call[1]?.headers).get('cf-aig-request-timeout'));
    expect(timeouts).toEqual(['6000', '10000']);
  });

  it('fails fast after one failure within a request and retries in a new request', async () => {
    const fetcher = vi.spyOn(globalThis, 'fetch').mockImplementation(async () => new Response('busy', { status: 503 }));
    const trace = { modelUsed: true, aiSearchUsed: false };
    const configured = fakeEnv();
    await expect(runTextModel(configured, 'curated-web-queries', messages, schema, 250, 0, trace)).rejects.toThrow('deepseek_text_unavailable');
    await expect(runTextModel(configured, 'curated-web-compose', messages, schema, 250, 0, trace)).rejects.toThrow('text_model_unavailable_this_request');
    expect(fetcher).toHaveBeenCalledTimes(1);
    await expect(runTextModel(configured, 'curated-web-queries', messages, schema, 250, 0, { modelUsed: true, aiSearchUsed: false })).rejects.toThrow('deepseek_text_unavailable');
    expect(fetcher).toHaveBeenCalledTimes(2);
  });

  it('refuses to call a model when DeepSeek text is disabled', async () => {
    const fetcher = vi.spyOn(globalThis, 'fetch');
    const disabled = Object.assign(fakeEnv(), { DEEPSEEK_TEXT_ENABLED: 'false' }) as Env;
    await expect(runTextModel(disabled, 'curated-web-queries', messages, schema, 250, 0)).rejects.toThrow('text_model_unconfigured');
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('rejects a response that attempts a tool call instead of JSON text', async () => {
    const fetcher = vi.fn<typeof fetch>(async () => new Response(JSON.stringify({ stop_reason: 'end_turn', content: [
      { type: 'server_tool_use', name: 'web_search' }, { type: 'text', text: '{"allowed":true}' },
    ] })));
    await expect(runDeepSeekText(config, 'curated-web-queries', messages, schema, 250, 0, fetcher)).rejects.toThrow('invalid_deepseek_text');
  });

  it('health reports DeepSeek text as the model without advertising a native search route', async () => {
    const response = await worker.fetch(new Request('https://worker.test/health'), fakeEnv());
    const value = await response.json();
    expect(value).toMatchObject({ capabilities: {
      publicModel: 'deepseek-text', publicModelFallback: 'deepseek-text',
      sourceProviders: [], webSearchProviders: ['exa'],
    } });
    expect(JSON.stringify(value)).not.toContain('deepseek-native');
    expect(JSON.stringify(value)).not.toContain(config.authToken);
  });

  it('health reports no model when DeepSeek text is disabled', async () => {
    const disabled = Object.assign(fakeEnv(), { DEEPSEEK_TEXT_ENABLED: 'false' }) as Env;
    const value = await (await worker.fetch(new Request('https://worker.test/health'), disabled)).json();
    expect(value).toMatchObject({ capabilities: { publicModel: 'unavailable', publicModelFallback: 'unavailable' } });
  });
});

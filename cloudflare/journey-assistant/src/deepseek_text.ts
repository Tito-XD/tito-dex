import type { DeepSeekNativeSearchConfig } from './deepseek_native_search';
import { DEEPSEEK_NATIVE_ENDPOINT, DEEPSEEK_NATIVE_MODEL, isDeepSeekNativeSearchConfigured } from './deepseek_native_search';
import { isPlainObject, readSearchResponse } from './web_search_common';

type ModelMessage = { role: 'system' | 'user'; content: string };

/** Shares the explicit Gateway/BYOK identity, never the native-search tools. */
export function isDeepSeekTextConfigured(config: DeepSeekNativeSearchConfig): boolean {
  return config.enabled && config.provider === 'custom-deepseek-anthropic' &&
    isDeepSeekNativeSearchConfigured(config);
}

export async function runDeepSeekText(
  config: DeepSeekNativeSearchConfig,
  phase: string,
  messages: ModelMessage[],
  schema: Record<string, unknown>,
  maxTokens: number,
  temperature: number,
  fetcher: typeof fetch = fetch,
): Promise<unknown> {
  if (!isDeepSeekTextConfigured(config)) throw new Error('deepseek_text_unconfigured');
  const endpoint = new URL('https://gateway.ai.cloudflare.com');
  endpoint.pathname = ['v1', config.accountId!.trim(), config.gatewayId.trim(),
    config.provider.trim(), ...DEEPSEEK_NATIVE_ENDPOINT.split('/')]
    .map((segment) => encodeURIComponent(segment)).join('/');
  const response = await fetcher(endpoint, {
    method: 'POST', redirect: 'manual',
    headers: {
      'content-type': 'application/json', 'anthropic-version': '2023-06-01',
      'cf-aig-authorization': `Bearer ${config.authToken!.trim()}`,
      'cf-aig-byok-alias': config.keyAlias!.trim(),
      'cf-aig-skip-cache': 'true', 'cf-aig-collect-log': 'false',
      'cf-aig-request-timeout': '6000', 'cf-aig-max-attempts': '1',
      'cf-aig-metadata': JSON.stringify({ feature: 'journey-assistant', phase: `deepseek-text:${phase}` }),
    },
    body: JSON.stringify({
      model: DEEPSEEK_NATIVE_MODEL,
      max_tokens: maxTokens, temperature, stream: false,
      thinking: { type: 'disabled' },
      system: messages.filter((message) => message.role === 'system').map((message) => message.content).join('\n') +
        '\n你是文本模型备用，只能使用本次提供的 sources，不得联网、调用工具或凭记忆新增事实。只输出符合此 schema 的 JSON：' + JSON.stringify(schema),
      messages: messages.filter((message) => message.role === 'user'),
      // Intentionally no tools, tool_choice or native-search continuation.
    }),
    signal: AbortSignal.timeout(6_000),
  });
  if (!response.ok) {
    await response.body?.cancel();
    throw new Error('deepseek_text_unavailable');
  }
  const value = await readSearchResponse(response);
  if (!isPlainObject(value) || !Array.isArray(value.content) || value.stop_reason !== 'end_turn' ||
      value.content.some((block) => !isPlainObject(block) || block.type !== 'text' || typeof block.text !== 'string')) {
    throw new Error('invalid_deepseek_text');
  }
  const text = value.content.map((block) => (block as { text: string }).text).join('\n').trim();
  if (!text || text.length > 32_768) throw new Error('invalid_deepseek_text');
  const parsed: unknown = JSON.parse(text.replace(/^```(?:json)?\s*([\s\S]*?)\s*```$/u, '$1'));
  if (!isPlainObject(parsed)) throw new Error('invalid_deepseek_text');
  return parsed;
}

import { vi } from 'vitest';

export type StubModelMessage = { role: 'system' | 'user'; content: string };
export type TextModelHandler = (phase: string, messages: StubModelMessage[]) => unknown;

/** Server configuration that makes DeepSeek text the Worker's text model. */
export const TEXT_MODEL_ENV = {
  CF_ACCOUNT_ID: 'a'.repeat(32),
  CF_AIG_TOKEN: 'test-gateway-run-token-123456',
  AI_GATEWAY_ID: 'titodex-journey-assistant',
  DEEPSEEK_TEXT_ENABLED: 'true',
  DEEPSEEK_NATIVE_PROVIDER: 'custom-deepseek-anthropic',
  DEEPSEEK_NATIVE_KEY_ALIAS: 'TitoDex',
} as const;

const TEXT_PHASE_PREFIX = 'deepseek-text:';

/**
 * Wraps the current global fetch so DeepSeek text calls reach `handler` and
 * every other request (Exa, PokeAPI, DeepSeek native search) keeps its stub.
 * A thrown handler error becomes a Gateway 503, i.e. a failed model call.
 */
export function stubTextModel(handler: TextModelHandler): void {
  const passthrough = globalThis.fetch;
  vi.stubGlobal('fetch', async (input: RequestInfo | URL, init?: RequestInit) => {
    const metadata = new Headers(init?.headers).get('cf-aig-metadata');
    const phase = metadata ? (JSON.parse(metadata) as { phase?: unknown }).phase : undefined;
    if (typeof phase !== 'string' || !phase.startsWith(TEXT_PHASE_PREFIX)) {
      return passthrough(input, init);
    }
    const body = JSON.parse(init?.body as string) as {
      system: string;
      messages: StubModelMessage[];
    };
    try {
      const value = await handler(phase.slice(TEXT_PHASE_PREFIX.length), [
        { role: 'system', content: body.system },
        ...body.messages,
      ]);
      return new Response(JSON.stringify({
        stop_reason: 'end_turn',
        content: [{ type: 'text', text: JSON.stringify(value) }],
      }), { headers: { 'content-type': 'application/json' } });
    } catch {
      return new Response('{}', { status: 503 });
    }
  });
}

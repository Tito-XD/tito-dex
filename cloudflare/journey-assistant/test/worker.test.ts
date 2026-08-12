import { env, SELF } from 'cloudflare:test';
import { beforeEach, describe, expect, it } from 'vitest';

function body(overrides: Record<string, unknown> = {}): string {
  return JSON.stringify({
    question: '挡路的树怎么过？',
    context: {
      game: 'soulsilver',
      generation: 4,
      locationId: 'johto-route-36-area',
      badgeIds: ['plain_badge'],
      milestoneIds: [],
      locale: 'zh-Hans',
      parserRevision: 2,
    },
    ...overrides,
  });
}

async function post(payload: string, deviceKey = 'test-device-key-12345'): Promise<Response> {
  return SELF.fetch('https://assistant.test/v1/ask', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-titodex-device-key': deviceKey,
    },
    body: payload,
  });
}

describe('journey assistant Worker contract', () => {
  beforeEach(async () => {
    const listed = await env.JOURNEY_CONTENT.list();
    await Promise.all(listed.objects.map((object) => env.JOURNEY_CONTENT.delete(object.key)));
  });

  it('serves local HGSS answers without an AI binding', async () => {
    const response = await post(body(), 'local-answer-key-123');
    expect(response.status).toBe(200);
    const value = await response.json() as { status: string; onlineComposed: boolean };
    expect(value.status).toBe('answered');
    expect(value.onlineComposed).toBe(false);
    expect(response.headers.get('cache-control')).toBe('no-store');
  });

  it('rejects unexpected save or identity fields', async () => {
    const response = await post(body({ trainerName: '不要发送', rawSave: 'AA==' }), 'schema-key-123456');
    expect(response.status).toBe(400);
    expect(await response.json()).toMatchObject({ errorCode: 'invalid_request' });
  });

  it('rejects the wrong game version instead of returning HGSS facts', async () => {
    const value = JSON.parse(body()) as { context: Record<string, unknown> };
    value.context.game = 'platinum';
    const response = await post(JSON.stringify(value), 'wrong-game-key-123');
    expect(response.status).toBe(400);
  });

  it('rejects oversized requests before inference', async () => {
    const response = await post(JSON.stringify({ padding: 'x'.repeat(5000) }), 'oversize-key-12345');
    expect(response.status).toBe(413);
    expect(await response.json()).toMatchObject({ errorCode: 'payload_too_large' });
  });

  it('returns a safe no-match response for unknown requests without AI', async () => {
    const value = JSON.parse(body()) as {
      question: string;
      context: Record<string, unknown>;
    };
    value.question = '这里完全没有可识别的信息';
    delete value.context.locationId;
    const response = await post(JSON.stringify(value), 'no-match-key-12345');
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ status: 'no_match', answer: null });
  });

  it('enforces the configured per-key cost guard', async () => {
    const deviceKey = 'rate-limit-key-unique-12345';
    const responses = await Promise.all(
      Array.from({ length: 21 }, () => post(body(), deviceKey)),
    );
    expect(responses.some((response) => response.status === 429)).toBe(true);
  });

  it('serves only the fixed extension catalog and immutable APK namespace', async () => {
    await env.JOURNEY_CONTENT.put(
      'extensions/journey-assistant/extension-catalog.json',
      '{"schemaVersion":1,"entries":[]}',
    );
    await env.JOURNEY_CONTENT.put(
      'extensions/journey-assistant/objects/titodex-journey-assistant-1.apk',
      new Uint8Array([0x50, 0x4b, 0x03, 0x04]),
    );
    const catalog = await SELF.fetch(
      'https://assistant.test/v1/extensions/journey_assistant/catalog',
    );
    expect(catalog.status).toBe(200);
    expect(catalog.headers.get('content-type')).toContain('application/json');
    expect(catalog.headers.get('cache-control')).toBe('no-store');

    const apk = await SELF.fetch(
      'https://assistant.test/v1/extensions/journey_assistant/objects/titodex-journey-assistant-1.apk',
    );
    expect(apk.status).toBe(200);
    expect([...new Uint8Array(await apk.arrayBuffer())]).toEqual([0x50, 0x4b, 0x03, 0x04]);
    expect(apk.headers.get('cache-control')).toContain('immutable');
    expect(apk.headers.get('content-type')).toBe('application/vnd.android.package-archive');
  });

  it('rejects traversal and does not expose other R2 prefixes', async () => {
    await env.JOURNEY_CONTENT.put('journey-search/private.md', 'private');
    const traversal = await SELF.fetch(
      'https://assistant.test/v1/extensions/journey_assistant/objects/%2e%2e%2fprivate.apk',
    );
    expect(traversal.status).toBe(404);
    const searchDocument = await SELF.fetch(
      'https://assistant.test/journey-search/private.md',
    );
    expect(searchDocument.status).toBe(404);
  });

  it('fails safely when the extension bucket is empty', async () => {
    const response = await SELF.fetch(
      'https://assistant.test/v1/extensions/journey_assistant/catalog',
    );
    expect(response.status).toBe(404);
    expect(await response.json()).toMatchObject({ errorCode: 'not_found' });
  });
});

import { answerQuestion } from './assistant';
import {
  effectiveContextReliability,
  MAX_REQUEST_BYTES,
  parseAssistantRequest,
  type AssistantRequest,
  type AssistantResponse,
} from './contract';
import type { ProgressionHint } from './progression_hints';
import { buildLogRecord } from './logging';
import { getJourneySearch, retrieveAuditedHintIds } from './retrieval';

const MODEL_TIMEOUT_MS = 5_000;
const MAX_PROVIDER_RESPONSE_BYTES = 16_384;
const EXTENSION_CATALOG_PATH = '/v1/extensions/journey_assistant/catalog';
const EXTENSION_OBJECT_PATH_PREFIX = '/v1/extensions/journey_assistant/objects/';
const EXTENSION_CATALOG_KEY = 'extensions/journey-assistant/extension-catalog.json';
const EXTENSION_OBJECT_KEY_PREFIX = 'extensions/journey-assistant/objects/';
const IMMUTABLE_APK_NAME = /^[A-Za-z0-9][A-Za-z0-9._-]{0,199}\.apk$/;

const JSON_HEADERS = {
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
  'x-content-type-options': 'nosniff',
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'content-type, x-titodex-device-key',
  'access-control-allow-methods': 'POST, OPTIONS',
};

type ModelMessage = { role: 'system' | 'user'; content: string };

export default {
  async fetch(request, env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === '/v1/ask' && request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: JSON_HEADERS });
    }
    if (url.pathname === '/health' && request.method === 'GET') {
      return json({ ok: true, schemaVersion: 1 }, 200);
    }
    const extensionContent = await serveExtensionContent(request, url, env);
    if (extensionContent) return extensionContent;
    if (url.pathname !== '/v1/ask') return jsonError('not_found', 404);
    if (request.method !== 'POST') return jsonError('method_not_allowed', 405);
    const contentLength = Number(request.headers.get('content-length') ?? '0');
    if (contentLength > MAX_REQUEST_BYTES) return jsonError('payload_too_large', 413);

    const deviceKey = request.headers.get('x-titodex-device-key')?.trim();
    if (env.QUESTION_RATE_LIMITER) {
      const rateKey = deviceKey && /^[A-Za-z0-9_-]{12,80}$/.test(deviceKey)
        ? deviceKey
        : 'anonymous-missing-key';
      const outcome = await env.QUESTION_RATE_LIMITER.limit({ key: rateKey });
      if (!outcome.success) return jsonError('rate_limited', 429);
    }

    let value: unknown;
    try {
      if (!request.body) return jsonError('invalid_json', 400);
      const body = new TextDecoder().decode(
        await readStreamBounded(request.body, MAX_REQUEST_BYTES, 'request_body_too_large'),
      );
      value = JSON.parse(body);
    } catch (error) {
      if (error instanceof Error && error.message === 'request_body_too_large') {
        return jsonError('payload_too_large', 413);
      }
      return jsonError('invalid_json', 400);
    }
    const parsed = parseAssistantRequest(value);
    if (!parsed) return jsonError('invalid_request', 400);

    const response = await answerQuestion(
      parsed,
      env.AI ? (hint, assistantRequest, fallback) =>
        runComposer(env, hint, assistantRequest, fallback) : undefined,
      env.AI ? (hints, assistantRequest) =>
        resolveHint(env, hints, assistantRequest) : undefined,
    );
    console.log(JSON.stringify(buildLogRecord(response, parsed)));
    return json(response, 200);
  },
} satisfies ExportedHandler<Env>;

async function serveExtensionContent(
  request: Request,
  url: URL,
  env: Env,
): Promise<Response | null> {
  const isCatalog = url.pathname === EXTENSION_CATALOG_PATH;
  const objectName = url.pathname.startsWith(EXTENSION_OBJECT_PATH_PREFIX)
    ? url.pathname.slice(EXTENSION_OBJECT_PATH_PREFIX.length)
    : null;
  if (!isCatalog && objectName === null) return null;
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    return jsonError('method_not_allowed', 405);
  }
  if (objectName !== null && !IMMUTABLE_APK_NAME.test(objectName)) {
    return jsonError('not_found', 404);
  }
  if (!env.JOURNEY_CONTENT) return jsonError('resource_unavailable', 503);

  const key = isCatalog
    ? EXTENSION_CATALOG_KEY
    : `${EXTENSION_OBJECT_KEY_PREFIX}${objectName}`;
  try {
    const object = request.method === 'HEAD'
      ? await env.JOURNEY_CONTENT.head(key)
      : await env.JOURNEY_CONTENT.get(key);
    if (!object) return jsonError('not_found', 404);

    const headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set('etag', object.httpEtag);
    headers.set('x-content-type-options', 'nosniff');
    headers.set(
      'content-type',
      isCatalog
        ? 'application/json; charset=utf-8'
        : 'application/vnd.android.package-archive',
    );
    headers.set(
      'cache-control',
      isCatalog ? 'no-store' : 'public, max-age=31536000, immutable',
    );
    return new Response(
      request.method === 'HEAD' ? null : (object as R2ObjectBody).body,
      { status: 200, headers },
    );
  } catch {
    return jsonError('resource_unavailable', 503);
  }
}

async function runComposer(
  env: Env,
  hint: ProgressionHint,
  request: AssistantRequest,
  fallback: AssistantResponse,
): Promise<unknown> {
  const prompt = {
    question: request.question,
    context: modelSafeContext(request),
    allowedAnswerSections: (fallback.answer ?? '')
      .split('\n\n')
      .map((text, index) => ({ id: `section-${index}`, text })),
  };
  const sectionIds = prompt.allowedAnswerSections.map((section) => section.id);
  return runJsonModel(env, `answer-composition:${hint.id}`, [
    {
      role: 'system',
      content: '你是 TitoDex 旅程卡关助手。只能为 allowedAnswerSections 排序，不得改写、删除或补充内容。只输出包含全部 ID 且不重复的 {"sectionOrder":["section-0"]}。',
    },
    { role: 'user', content: JSON.stringify(prompt) },
  ], {
    type: 'object',
    additionalProperties: false,
    required: ['sectionOrder'],
    properties: {
      sectionOrder: {
        type: 'array',
        minItems: sectionIds.length,
        maxItems: sectionIds.length,
        uniqueItems: true,
        items: { type: 'string', enum: sectionIds },
      },
    },
  }, 420, 0.1);
}

async function resolveHint(
  env: Env,
  hints: ProgressionHint[],
  request: AssistantRequest,
): Promise<unknown> {
  let candidates = hints;
  const search = getJourneySearch(
    env.AI_SEARCH_ENABLED,
    env.JOURNEY_SEARCH_NAMESPACE,
  );
  if (search) {
    try {
      const retrievedIds = await retrieveAuditedHintIds(search, hints, request);
      const retrieved = new Set(retrievedIds);
      const narrowed = hints.filter((hint) => retrieved.has(hint.id));
      if (narrowed.length === 1) return { hintId: narrowed[0].id };
      if (narrowed.length > 1) candidates = narrowed;
    } catch {
      // Retrieval is optional. The model remains restricted to local audited hints.
    }
  }
  return resolveHintWithModel(env, candidates, request);
}

async function resolveHintWithModel(
  env: Env,
  hints: ProgressionHint[],
  request: AssistantRequest,
): Promise<unknown> {
  const hintIds = hints.map((hint) => hint.id);
  return runJsonModel(env, 'intent-resolution', [
    {
      role: 'system',
      content: '你只做意图分类。根据问题从 candidates 选择唯一 hintId；不能确定时输出无效空字符串。不得回答游戏问题。只输出 {"hintId":"..."}。',
    },
    {
      role: 'user',
      content: JSON.stringify({
        question: request.question,
        context: modelSafeContext(request),
        candidates: hints.map((hint) => ({
          id: hint.id,
          subject: hint.subject,
          locationAliases: hint.locationAliases,
          destinationAliases: hint.destinationAliases,
          overviewZh: hint.overviewZh,
        })),
      }),
    },
  ], {
    type: 'object',
    additionalProperties: false,
    required: ['hintId'],
    properties: { hintId: { type: 'string', enum: hintIds } },
  }, 80, 0);
}

async function runJsonModel(
  env: Env,
  phase: string,
  messages: ModelMessage[],
  jsonSchema: Record<string, unknown>,
  maxTokens: number,
  temperature: number,
): Promise<unknown> {
  if (
    env.AI_EXTERNAL_PROVIDER_ENABLED === 'true' &&
    env.AI_PROVIDER !== 'workers-ai'
  ) {
    try {
      return await runGatewayProvider(env, phase, messages, maxTokens, temperature);
    } catch {
      // An optional provider must never make the audited Workers AI path unusable.
    }
  }
  return runWorkersAi(env, phase, messages, jsonSchema, maxTokens, temperature);
}

async function runWorkersAi(
  env: Env,
  phase: string,
  messages: ModelMessage[],
  jsonSchema: Record<string, unknown>,
  maxTokens: number,
  temperature: number,
): Promise<unknown> {
  const result = await env.AI.run(env.AI_MODEL, {
    messages,
    response_format: {
      type: 'json_schema',
      json_schema: jsonSchema,
    },
    max_tokens: maxTokens,
    temperature,
  }, gatewayOptions(env, phase));
  return unwrapModelResult(result);
}

async function runGatewayProvider(
  env: Env,
  phase: string,
  messages: ModelMessage[],
  maxTokens: number,
  temperature: number,
): Promise<unknown> {
  const provider = validateProvider(env.AI_PROVIDER);
  const endpoint = validateProviderEndpoint(env.AI_PROVIDER_ENDPOINT);
  const model = validateModelName(env.AI_PROVIDER_MODEL);
  const response = await env.AI.gateway(env.AI_GATEWAY_ID).run({
    provider,
    endpoint,
    headers: {
      'Content-Type': 'application/json',
      'cf-aig-skip-cache': true,
      'cf-aig-collect-log': false,
      'cf-aig-request-timeout': MODEL_TIMEOUT_MS,
      'cf-aig-max-attempts': 1,
      'cf-aig-metadata': JSON.stringify({ feature: 'journey-assistant', phase }),
    },
    query: {
      model,
      messages,
      response_format: { type: 'json_object' },
      max_tokens: maxTokens,
      temperature,
      stream: false,
    },
  }, { signal: AbortSignal.timeout(MODEL_TIMEOUT_MS) });
  return parseProviderJsonResponse(response);
}

function modelSafeContext(request: AssistantRequest): Record<string, unknown> {
  const reliability = effectiveContextReliability(request.context);
  return {
    game: request.context.game,
    generation: request.context.generation,
    reliability,
    ...(reliability.location === 'save_verified' && request.context.locationId
      ? { locationId: request.context.locationId }
      : {}),
    ...(reliability.badges === 'save_verified'
      ? { badgeIds: request.context.badgeIds }
      : {}),
    ...(reliability.badges === 'count_only' && request.context.badgeCount !== undefined
      ? { badgeCount: request.context.badgeCount }
      : {}),
    ...(reliability.milestones === 'save_verified'
      ? { milestoneIds: request.context.milestoneIds }
      : {}),
  };
}

function gatewayOptions(env: Env, phase: string): AiOptions {
  return {
    signal: AbortSignal.timeout(MODEL_TIMEOUT_MS),
    gateway: {
      id: env.AI_GATEWAY_ID,
      skipCache: true,
      collectLog: false,
      requestTimeoutMs: MODEL_TIMEOUT_MS,
      retries: { maxAttempts: 1 },
      metadata: { feature: 'journey-assistant', phase },
    },
  };
}

export async function parseProviderJsonResponse(response: Response): Promise<unknown> {
  if (!response.ok) throw new Error(`provider_status_${response.status}`);
  const declaredLength = Number(response.headers.get('content-length') ?? '0');
  if (declaredLength > MAX_PROVIDER_RESPONSE_BYTES) throw new Error('provider_response_too_large');
  if (!response.body) throw new Error('provider_empty_response');
  const bytes = await readStreamBounded(
    response.body,
    MAX_PROVIDER_RESPONSE_BYTES,
    'provider_response_too_large',
  );
  const payload: unknown = JSON.parse(new TextDecoder().decode(bytes));
  if (!isPlainObject(payload) || !Array.isArray(payload.choices) || payload.choices.length < 1) {
    throw new Error('invalid_provider_response');
  }
  const first = payload.choices[0];
  if (!isPlainObject(first) || !isPlainObject(first.message) || typeof first.message.content !== 'string') {
    throw new Error('invalid_provider_response');
  }
  return JSON.parse(first.message.content);
}

async function readStreamBounded(
  stream: ReadableStream<Uint8Array>,
  maxBytes: number,
  limitError: string,
): Promise<Uint8Array> {
  const reader = stream.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel(limitError);
      throw new Error(limitError);
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return bytes;
}

function validateProvider(value: string): string {
  if (value === 'deepseek' || /^custom-[a-z0-9][a-z0-9-]{0,62}$/.test(value)) return value;
  throw new Error('invalid_ai_provider');
}

function validateProviderEndpoint(value: string): string {
  if (/^(?:v1\/)?chat\/completions$/.test(value)) return value;
  throw new Error('invalid_ai_provider_endpoint');
}

function validateModelName(value: string): string {
  if (/^[A-Za-z0-9._:/-]{1,120}$/.test(value)) return value;
  throw new Error('invalid_ai_provider_model');
}

function unwrapModelResult(result: unknown): unknown {
  if (isPlainObject(result) && 'response' in result) {
    const response = result.response;
    if (typeof response === 'string') {
      try { return JSON.parse(response); } catch { return null; }
    }
    return response;
  }
  return result;
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function json(value: unknown, status: number): Response {
  return new Response(JSON.stringify(value), { status, headers: JSON_HEADERS });
}

function jsonError(errorCode: string, status: number): Response {
  return json({
    status: 'failed',
    answer: null,
    confidence: 'low',
    followUp: null,
    errorCode,
  }, status);
}

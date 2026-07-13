import { HOT_CACHE_KEYS, HOT_CACHE_TTL_SECONDS } from './constants.js';
import { cacheControlForKey, contentTypeForKey } from './cache.js';
import { spriteFallbackKeys } from './fallback.js';
import { CORS_HEADERS } from './constants.js';
import { notModified } from './http.js';

/**
 * @param {import('./types.js').Env} env
 * @param {string} key
 */
async function getCachedObject(env, key) {
  if (!env.MANIFEST_KV || !HOT_CACHE_KEYS.has(key)) {
    return null;
  }
  return env.MANIFEST_KV.get(`cache:obj:${key}`, 'json');
}

/**
 * @param {import('./types.js').Env} env
 * @param {string} key
 */
async function invalidateCachedObject(env, key) {
  if (env.MANIFEST_KV) {
    await env.MANIFEST_KV.delete(`cache:obj:${key}`);
  }
}

function buildObjectResponse(key, body, etag, extraHeaders = {}) {
  const headers = new Headers(CORS_HEADERS);
  headers.set('Content-Type', contentTypeForKey(key));
  headers.set('Cache-Control', cacheControlForKey(key));
  headers.set('ETag', etag);
  for (const [headerKey, value] of Object.entries(extraHeaders)) {
    headers.set(headerKey, value);
  }
  return { headers, body };
}

/**
 * Serve an R2 object with optional KV cache + If-None-Match.
 * @param {import('./types.js').Env} env
 * @param {Request} request
 * @param {string} key
 * @param {Record<string, string>} [extraHeaders]
 */
export async function serveR2Object(env, request, key, extraHeaders = {}) {
  const ifNoneMatch = request.headers.get('If-None-Match');

  const cached = await getCachedObject(env, key);
  if (cached) {
    if (ifNoneMatch && ifNoneMatch === cached.etag) {
      return notModified(cached.etag);
    }
    const headers = new Headers(CORS_HEADERS);
    headers.set('Content-Type', cached.contentType);
    headers.set('Cache-Control', cached.cacheControl);
    headers.set('ETag', cached.etag);
    headers.set('X-TitoDex-Cache', 'kv');
    for (const [headerKey, value] of Object.entries(extraHeaders)) {
      headers.set(headerKey, value);
    }
    if (request.method === 'HEAD') {
      return new Response(null, { status: 200, headers });
    }
    return new Response(cached.body, { status: 200, headers });
  }

  const object = await env.DEX_BUCKET.get(key);
  if (!object) {
    return null;
  }

  if (ifNoneMatch && ifNoneMatch === object.httpEtag) {
    return notModified(object.httpEtag);
  }

  if (HOT_CACHE_KEYS.has(key) && env.MANIFEST_KV) {
    const body = await object.text();
    await env.MANIFEST_KV.put(
      `cache:obj:${key}`,
      JSON.stringify({
        body,
        etag: object.httpEtag,
        contentType: contentTypeForKey(key),
        cacheControl: cacheControlForKey(key),
      }),
      { expirationTtl: HOT_CACHE_TTL_SECONDS },
    );
    const headers = new Headers(CORS_HEADERS);
    headers.set('Content-Type', contentTypeForKey(key));
    headers.set('Cache-Control', cacheControlForKey(key));
    headers.set('ETag', object.httpEtag);
    headers.set('X-TitoDex-Cache', 'r2');
    for (const [headerKey, value] of Object.entries(extraHeaders)) {
      headers.set(headerKey, value);
    }
    if (request.method === 'HEAD') {
      return new Response(null, { status: 200, headers });
    }
    return new Response(body, { status: 200, headers });
  }

  const { headers, body } = buildObjectResponse(key, object.body, object.httpEtag, extraHeaders);
  if (request.method === 'HEAD') {
    return new Response(null, { status: 200, headers });
  }
  return new Response(body, { status: 200, headers });
}

/**
 * Resolve sprite with version-group fallbacks.
 * @param {import('./types.js').Env} env
 * @param {Request} request
 * @param {string} key
 */
export async function serveWithFallbacks(env, request, key) {
  const direct = await serveR2Object(env, request, key);
  if (direct) {
    return direct;
  }

  const candidates = spriteFallbackKeys(key);
  if (!candidates) {
    return null;
  }

  for (const candidate of candidates) {
    if (candidate === key) {
      continue;
    }
    const object = await env.DEX_BUCKET.head(candidate);
    if (object) {
      const fallbackFrom = key.match(/by-version\/([^/]+)\//)?.[1] ?? 'unknown';
      const servedFrom = candidate.match(/by-version\/([^/]+)\//)?.[1] ?? candidate;
      return serveR2Object(env, request, candidate, {
        'X-TitoDex-Sprite-Fallback': `${fallbackFrom}→${servedFrom}`,
      });
    }
  }

  return null;
}

/**
 * Write JSON to R2 and bust KV cache.
 * @param {import('./types.js').Env} env
 * @param {string} key
 * @param {Record<string, unknown>} data
 */
export async function putJsonObject(env, key, data) {
  const body = `${JSON.stringify(data, null, 2)}\n`;
  await env.DEX_BUCKET.put(key, body, {
    httpMetadata: { contentType: 'application/json; charset=utf-8' },
  });
  await invalidateCachedObject(env, key);
  return body;
}

/**
 * @param {import('./types.js').Env} env
 * @param {string} key
 */
export async function readJsonObject(env, key) {
  const object = await env.DEX_BUCKET.get(key);
  if (!object) {
    return null;
  }
  return JSON.parse(await object.text());
}

export { invalidateCachedObject };

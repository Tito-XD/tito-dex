/**
 * TitoDex dex CDN Worker — R2 proxy with CORS and cache headers.
 *
 * Routes:
 *   GET /bundle/latest  → 302 to bundle-manifest.json archiveUrl
 *   GET /*              → R2 object from titodex-dex bucket
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

const LONG_CACHE = 'public, max-age=31536000, immutable';
const SHORT_CACHE = 'public, max-age=300';

function cacheControlForKey(key) {
  if (key === 'bundle-manifest.json') {
    return SHORT_CACHE;
  }
  if (
    key.startsWith('v2/sprites/') ||
    key.startsWith('v2/type_icons/') ||
    key.startsWith('v2/details/') ||
    key === 'v2/bundle.tar.zst'
  ) {
    return LONG_CACHE;
  }
  if (
    key.startsWith('v2/summaries.json') ||
    key.startsWith('v2/types.json') ||
    key.startsWith('v2/moves.json') ||
    key.startsWith('v2/manifest.json')
  ) {
    return LONG_CACHE;
  }
  return SHORT_CACHE;
}

function contentTypeForKey(key) {
  if (key.endsWith('.json')) return 'application/json; charset=utf-8';
  if (key.endsWith('.jpg')) return 'image/jpeg';
  if (key.endsWith('.png')) return 'image/png';
  if (key.endsWith('.tar.zst')) return 'application/octet-stream';
  return 'application/octet-stream';
}

function objectKeyFromPath(pathname) {
  const path = pathname.replace(/^\/+/, '');
  if (!path || path === '/') {
    return 'bundle-manifest.json';
  }
  return path;
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('Method Not Allowed', { status: 405, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);

    if (url.pathname === '/bundle/latest') {
      const manifestObj = await env.DEX_BUCKET.get('bundle-manifest.json');
      if (!manifestObj) {
        return new Response('bundle-manifest.json not found', {
          status: 404,
          headers: CORS_HEADERS,
        });
      }
      const manifest = JSON.parse(await manifestObj.text());
      return Response.redirect(manifest.archiveUrl, 302);
    }

    if (url.pathname === '/cdn-health') {
      const headers = new Headers(CORS_HEADERS);
      headers.set('Content-Type', 'application/json; charset=utf-8');
      headers.set('Cache-Control', 'no-store');
      return new Response(
        JSON.stringify({
          ok: true,
          service: 'tito-dex-cdn',
          rev: '2026-07-09b',
          bucket: 'titodex-dex',
        }),
        { status: 200, headers },
      );
    }

    const key = objectKeyFromPath(url.pathname);
    const object = await env.DEX_BUCKET.get(key);
    if (!object) {
      return new Response('Not Found', { status: 404, headers: CORS_HEADERS });
    }

    const headers = new Headers(CORS_HEADERS);
    headers.set('Content-Type', contentTypeForKey(key));
    headers.set('Cache-Control', cacheControlForKey(key));
    headers.set('ETag', object.httpEtag);

    if (request.method === 'HEAD') {
      return new Response(null, { status: 200, headers });
    }

    return new Response(object.body, { status: 200, headers });
  },
};

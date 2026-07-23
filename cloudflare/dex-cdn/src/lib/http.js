import { CORS_HEADERS } from './constants.js';

export function jsonResponse(data, status = 200, extraHeaders = {}) {
  const headers = new Headers(CORS_HEADERS);
  headers.set('Content-Type', 'application/json; charset=utf-8');
  headers.set('Cache-Control', 'no-store');
  for (const [key, value] of Object.entries(extraHeaders)) {
    headers.set(key, value);
  }
  return new Response(JSON.stringify(data), { status, headers });
}

export function textResponse(body, status = 200, extraHeaders = {}) {
  const headers = new Headers(CORS_HEADERS);
  for (const [key, value] of Object.entries(extraHeaders)) {
    headers.set(key, value);
  }
  return new Response(body, { status, headers });
}

export function notModified(etag) {
  const headers = new Headers(CORS_HEADERS);
  headers.set('ETag', etag);
  headers.set('Cache-Control', 'no-cache');
  return new Response(null, { status: 304, headers });
}

export function unauthorized() {
  return textResponse('Unauthorized', 401);
}

export function methodNotAllowed() {
  return textResponse('Method Not Allowed', 405);
}

export function parseBearerToken(request) {
  const header = request.headers.get('Authorization') || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : null;
}

export function requireAdmin(request, env) {
  const secret = env.ADMIN_SECRET;
  if (!secret) {
    return { ok: false, response: textResponse('Admin API disabled (ADMIN_SECRET not set)', 503) };
  }
  const token = parseBearerToken(request);
  if (!token || token !== secret) {
    return { ok: false, response: unauthorized() };
  }
  return { ok: true };
}

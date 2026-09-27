const PAGES_ORIGIN = 'https://titodex.pages.dev';

// These paths belong to the published Android clients and CDN maintenance.
// A missing CDN object must never fall through to Pages' HTML fallback.
export function isCdnPath(pathname) {
  let path;
  try {
    path = decodeURIComponent(pathname).replace(/^\/+/, '/');
  } catch {
    return true;
  }
  return /^\/(?:v\d+|bundle|admin)(?:\/|$)/.test(path) ||
    path === '/bundle-manifest.json' || path === '/cdn-health';
}

export async function handleRequest(request, env, fetchPages = fetch) {
  const incoming = new URL(request.url);
  if (isCdnPath(incoming.pathname)) {
    return env.CDN.fetch(request);
  }

  // Keep the host fixed; the entry is not a general-purpose HTTP proxy.
  const upstream = new URL(PAGES_ORIGIN);
  upstream.pathname = incoming.pathname;
  upstream.search = incoming.search;
  const headers = new Headers(request.headers);
  // CDN administration credentials and browser cookies do not belong to Pages.
  headers.delete('authorization');
  headers.delete('cookie');
  headers.delete('host');
  const forwarded = new Request(upstream, {
    method: request.method,
    headers,
    body: ['GET', 'HEAD'].includes(request.method) ? undefined : request.body,
    redirect: 'manual',
  });
  const response = await fetchPages(forwarded);
  const location = response.headers.get('location');
  if (!location) return response;

  const redirect = new URL(location, upstream);
  if (redirect.origin !== PAGES_ORIGIN) return response;
  redirect.protocol = incoming.protocol;
  redirect.host = incoming.host;
  const rewritten = new Response(response.body, response);
  rewritten.headers.set('location', redirect.href);
  return rewritten;
}

export default {
  fetch(request, env) {
    return handleRequest(request, env);
  },
};

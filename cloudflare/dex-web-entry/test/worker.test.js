import test from 'node:test';
import assert from 'node:assert/strict';
import worker, { handleRequest, isCdnPath } from '../src/worker.js';

const origin = 'https://dex.tito.cafe';

test('CDN namespaces, encoded paths and unknown versions stay reserved', () => {
  for (const path of ['/v2/a', '/v4/a', '/v5/a', '/v20/a', '/v5', '/bundle/latest',
    '/bundle-manifest.json', '/cdn-health', '/admin/status', '/%76%35/missing', '//v5/a', '/%ZZ']) {
    assert.equal(isCdnPath(path), true, path);
  }
  for (const path of ['/', '/app', '/1025', '/151', '/pokedex/johto', '/_astro/a.js',
    '/data/dex/details/1.json', '/pokemon/artwork/1.png', '/sw.js', '/manifest.webmanifest']) {
    assert.equal(isCdnPath(path), false, path);
  }
});

test('CDN requests and responses pass through unchanged, including errors and auth', async () => {
  for (const status of [200, 206, 304, 401, 404, 503]) {
    const request = new Request(origin + '/v5/details/missing.json', {
      headers: { authorization: 'test-only', range: 'bytes=0-99', 'if-none-match': 'abc' },
    });
    const response = new Response(status === 304 ? null : 'data', {
      status, headers: { etag: 'abc', 'cache-control': 'public, max-age=300' },
    });
    const result = await handleRequest(request, { CDN: { fetch: async (actual) => {
      assert.equal(actual, request); return response;
    } } }, () => assert.fail('CDN must not fall back to Pages'));
    assert.equal(result, response);
  }
});

test('admin POST body and authentication are forwarded only to CDN', async () => {
  const request = new Request(origin + '/admin/example', {
    method: 'POST', headers: { authorization: 'test-only' }, body: '{"example":true}',
  });
  await handleRequest(request, { CDN: { fetch: async (actual) => {
    assert.equal(actual.headers.get('authorization'), 'test-only');
    assert.equal(await actual.text(), '{"example":true}'); return new Response('ok');
  } } }, () => assert.fail('admin must not reach Pages'));
});

test('Pages receives the path and query without credentials', async () => {
  const request = new Request(origin + '/pokedex/johto?name=abc', {
    headers: { cookie: 'private=1', authorization: 'private', accept: 'text/html' },
  });
  await handleRequest(request, {}, async (actual) => {
    assert.equal(actual.url, 'https://titodex.pages.dev/pokedex/johto?name=abc');
    assert.equal(actual.redirect, 'manual');
    assert.equal(actual.headers.get('authorization'), null);
    assert.equal(actual.headers.get('cookie'), null);
    assert.equal(actual.headers.get('accept'), 'text/html');
    return new Response('html');
  });
});

test('Pages requests cannot change the fixed upstream hostname', async () => {
  await handleRequest(new Request(origin + '//other.example/test'), {}, async (actual) => {
    assert.equal(new URL(actual.url).hostname, 'titodex.pages.dev'); return new Response('ok');
  });
});

test('Pages redirects remain on the public host; external links stay external', async () => {
  for (const [location, expected] of [
    ['/app', origin + '/app'],
    ['https://titodex.pages.dev/pokedex?x=1', origin + '/pokedex?x=1'],
    ['https://github.com/Tito-XD/tito-dex', 'https://github.com/Tito-XD/tito-dex'],
  ]) {
    const response = await handleRequest(new Request(origin + '/app.html'), {}, async () =>
      new Response(null, { status: 301, headers: { location } }));
    assert.equal(response.status, 301);
    assert.equal(response.headers.get('location'), expected);
  }
});


test('Worker execution context is not mistaken for a fetch implementation', async () => {
  const original = globalThis.fetch;
  globalThis.fetch = async () => new Response('page');
  try {
    const response = await worker.fetch(new Request(origin + '/app'), {}, { waitUntil() {} });
    assert.equal(await response.text(), 'page');
  } finally { globalThis.fetch = original; }
});

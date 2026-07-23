import assert from 'node:assert/strict';
import test from 'node:test';

import { cacheControlForKey } from '../src/lib/cache.js';
import { LONG_CACHE, SHORT_CACHE } from '../src/lib/constants.js';

test('all immutable version prefixes, including v5, use long cache', () => {
  assert.equal(cacheControlForKey('v5/details/25.json'), LONG_CACHE);
  assert.equal(cacheControlForKey('v3/sprites/25.png'), LONG_CACHE);
  assert.equal(cacheControlForKey('v2/bundle.tar.zst'), LONG_CACHE);
});

test('root manifest and hot-update slices keep a short cache', () => {
  assert.equal(cacheControlForKey('bundle-manifest.json'), SHORT_CACHE);
  assert.equal(cacheControlForKey('v5/l10n/zh/manifest.json'), SHORT_CACHE);
  assert.equal(cacheControlForKey('v5/maps/hgss_map_list.json'), SHORT_CACHE);
  assert.equal(cacheControlForKey('v5/config/app_config.json'), SHORT_CACHE);
});

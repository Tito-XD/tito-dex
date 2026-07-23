import { LONG_CACHE, SHORT_CACHE } from './constants.js';

export function cacheControlForKey(key) {
  if (key === 'bundle-manifest.json') {
    return SHORT_CACHE;
  }
  if (/^v\d+\/(l10n|maps|config)\//.test(key)) {
    return SHORT_CACHE;
  }
  if (/^v\d+\//.test(key)) {
    return LONG_CACHE;
  }
  return SHORT_CACHE;
}

export function contentTypeForKey(key) {
  if (key.endsWith('.json')) return 'application/json; charset=utf-8';
  if (key.endsWith('.jpg')) return 'image/jpeg';
  if (key.endsWith('.png')) return 'image/png';
  if (key.endsWith('.gif')) return 'image/gif';
  if (key.endsWith('.tar.zst')) return 'application/octet-stream';
  return 'application/octet-stream';
}

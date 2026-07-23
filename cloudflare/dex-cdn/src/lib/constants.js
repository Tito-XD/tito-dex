/** @typedef {import('./types.js').Env} Env */

export const DEPLOY_REV = '2026-07-23-v5';

export const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS, POST, PUT',
  'Access-Control-Max-Age': '86400',
};

export const LONG_CACHE = 'public, max-age=31536000, immutable';
export const SHORT_CACHE = 'public, max-age=300';

/** Keys cached in KV with SHORT_CACHE TTL (seconds). */
export const HOT_CACHE_KEYS = new Set(['bundle-manifest.json']);

/** Version groups tried when a by-version sprite is missing (after the requested group). */
export const SPRITE_VERSION_FALLBACKS = [
  'scarlet-violet',
  'red-blue',
  'heartgold-soulsilver',
  'gold-silver',
  'ruby-sapphire',
];

export const BY_VERSION_SPRITE_RE =
  /^(v\d+)\/sprites\/by-version\/([^/]+)\/(\d+)\.png$/;

export const DEFAULT_GITHUB_REPO = 'Tito-XD/tito-dex';

/** KV TTL for hot manifest cache (matches SHORT_CACHE max-age). */
export const HOT_CACHE_TTL_SECONDS = 300;

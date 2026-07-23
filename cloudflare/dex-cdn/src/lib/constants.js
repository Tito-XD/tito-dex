/** @typedef {import('./types.js').Env} Env */

export const DEPLOY_REV = '2026-07-13a';

export const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS, POST, PUT',
  'Access-Control-Max-Age': '86400',
};

export const LONG_CACHE = 'public, max-age=31536000, immutable';
export const SHORT_CACHE = 'public, max-age=300';

/** Keys cached in KV with SHORT_CACHE TTL (seconds). */
export const HOT_CACHE_KEYS = new Set(['bundle-manifest.json']);

/** R2 keys probed by /cdn-health?probe=1 and the 6-hour cron. */
export const PROBE_KEYS = [
  'bundle-manifest.json',
  'v3/manifest.json',
  'v3/summaries.json',
  'v3/l10n/zh/manifest.json',
  'v3/config/app_config.json',
  'v3/sprites/by-version/scarlet-violet/25.png',
  'v3/sprites/25.png',
  'v3/artwork/25.png',
  'v3/type_icons/fire.png',
];

/** Version groups tried when a by-version sprite is missing (after the requested group). */
export const SPRITE_VERSION_FALLBACKS = [
  'scarlet-violet',
  'red-blue',
  'heartgold-soulsilver',
  'gold-silver',
  'ruby-sapphire',
];

export const BY_VERSION_SPRITE_RE =
  /^(v[23])\/sprites\/by-version\/([^/]+)\/(\d+)\.png$/;

export const DEFAULT_GITHUB_REPO = 'Tito-XD/tito-dex';

/** KV TTL for hot manifest cache (matches SHORT_CACHE max-age). */
export const HOT_CACHE_TTL_SECONDS = 300;

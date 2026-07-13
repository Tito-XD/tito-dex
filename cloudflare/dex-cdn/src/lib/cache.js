import { LONG_CACHE, SHORT_CACHE } from './constants.js';

export function cacheControlForKey(key) {
  if (key === 'bundle-manifest.json') {
    return SHORT_CACHE;
  }
  if (
    key.startsWith('v2/sprites/') ||
    key.startsWith('v2/artwork/') ||
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
  if (
    key.startsWith('v3/sprites/') ||
    key.startsWith('v3/artwork/') ||
    key.startsWith('v3/type_icons/') ||
    key.startsWith('v3/game_icons/') ||
    key.startsWith('v3/details/') ||
    key.startsWith('v3/l10n/') ||
    key.startsWith('v3/maps/') ||
    key.startsWith('v3/config/') ||
    key === 'v3/bundle.tar.zst'
  ) {
    return LONG_CACHE;
  }
  if (
    key.startsWith('v3/summaries.json') ||
    key.startsWith('v3/types.json') ||
    key.startsWith('v3/moves.json') ||
    key.startsWith('v3/manifest.json') ||
    key.startsWith('v3/abilities.json') ||
    key.startsWith('v3/games.json') ||
    key.startsWith('v3/natures.json') ||
    key.startsWith('v3/egg_groups.json') ||
    key.startsWith('v3/status_conditions.json') ||
    key.startsWith('v3/weather.json') ||
    key.startsWith('v3/terrains.json') ||
    key.startsWith('v3/items.json')
  ) {
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

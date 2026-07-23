import { BY_VERSION_SPRITE_RE, SPRITE_VERSION_FALLBACKS } from './constants.js';

/**
 * Build ordered R2 keys to try when a by-version sprite is missing.
 * @returns {string[] | null}
 */
export function spriteFallbackKeys(key) {
  const match = key.match(BY_VERSION_SPRITE_RE);
  if (!match) {
    return genericSpriteFallbackKeys(key);
  }

  const [, prefix, requestedGroup, id] = match;
  const candidates = [];
  const seen = new Set();

  const add = (candidate) => {
    if (!seen.has(candidate)) {
      seen.add(candidate);
      candidates.push(candidate);
    }
  };

  add(`${prefix}/sprites/by-version/${requestedGroup}/${id}.png`);
  for (const group of SPRITE_VERSION_FALLBACKS) {
    if (group !== requestedGroup) {
      add(`${prefix}/sprites/by-version/${group}/${id}.png`);
    }
  }

  add(`${prefix}/sprites/${id}.png`);
  add(`${prefix}/artwork/${id}.png`);

  return candidates;
}

/**
 * @returns {string[] | null}
 */
export function genericSpriteFallbackKeys(key) {
  const match = key.match(/^(v\d+)\/sprites\/(\d+)\.png$/);
  if (!match) {
    return null;
  }
  const [, prefix, id] = match;
  return [`${prefix}/sprites/${id}.png`, `${prefix}/artwork/${id}.png`];
}

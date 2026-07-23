import assert from 'node:assert/strict';
import test from 'node:test';

import { buildHealthReport } from '../src/lib/health.js';

function envForManifest(manifest, seen) {
  return {
    DEX_BUCKET: {
      async get(key) {
        if (key !== 'bundle-manifest.json') return null;
        return { text: async () => JSON.stringify(manifest) };
      },
      async head(key) {
        seen.push(key);
        return { size: 1, uploaded: new Date('2026-07-23T00:00:00Z') };
      },
    },
  };
}

test('deep health derives v4 keys and accepts the default sprite probe', async () => {
  const seen = [];
  const report = await buildHealthReport(
    envForManifest(
      {
        bundleVersion: 6,
        cdnPrefix: 'v4',
        archiveUrl: 'https://example.invalid/v4/bundle.tar.zst',
      },
      seen,
    ),
    { deep: true },
  );

  assert.equal(report.ok, true);
  assert.equal(report.manifest.activePrefix, 'v4');
  assert.ok(seen.includes('v4/sprites/25.png'));
  assert.ok(!seen.some((key) => key.includes('/sprites/by-version/')));
});

test('deep health still derives v3 for an old manifest without cdnPrefix', async () => {
  const seen = [];
  const report = await buildHealthReport(
    envForManifest(
      {
        bundleVersion: 5,
        archiveUrl: 'https://example.invalid/v3/bundle.tar.zst',
      },
      seen,
    ),
    { deep: true },
  );

  assert.equal(report.ok, true);
  assert.equal(report.manifest.activePrefix, 'v3');
  assert.ok(seen.includes('v3/manifest.json'));
});

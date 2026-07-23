import { DEPLOY_REV } from './constants.js';
import { sendAlert } from './alerts.js';

function activePrefixForManifest(manifest) {
  if (typeof manifest?.cdnPrefix === 'string' && /^v\d+$/.test(manifest.cdnPrefix)) {
    return manifest.cdnPrefix;
  }
  const archiveMatch = String(manifest?.archiveUrl ?? '').match(/\/(v\d+)\/bundle\.tar\.zst(?:\?|$)/);
  if (archiveMatch) return archiveMatch[1];
  const bundleVersion = Number(manifest?.bundleVersion);
  if (Number.isInteger(bundleVersion) && bundleVersion >= 2) {
    return `v${bundleVersion - 2}`;
  }
  return null;
}

function probeKeysForPrefix(prefix) {
  return [
    'bundle-manifest.json',
    `${prefix}/manifest.json`,
    `${prefix}/summaries.json`,
    `${prefix}/l10n/zh/manifest.json`,
    `${prefix}/config/app_config.json`,
    `${prefix}/sprites/25.png`,
    `${prefix}/artwork/25.png`,
    `${prefix}/type_icons/fire.png`,
    `${prefix}/bundle.tar.zst`,
  ];
}

/**
 * HEAD-check a list of R2 keys.
 * @param {import('./types.js').Env} env
 * @param {string[]} keys
 */
export async function probeR2Keys(env, keys) {
  const results = await Promise.all(
    keys.map(async (key) => {
      const head = await env.DEX_BUCKET.head(key);
      return {
        key,
        ok: head !== null,
        size: head?.size ?? null,
        uploaded: head?.uploaded?.toISOString?.() ?? null,
      };
    }),
  );

  const missing = results.filter((entry) => !entry.ok).map((entry) => entry.key);
  return {
    ok: missing.length === 0,
    checked: results.length,
    missing,
    keys: results,
  };
}

/**
 * @param {import('./types.js').Env} env
 * @param {{ deep?: boolean }} [options]
 */
export async function buildHealthReport(env, options = {}) {
  const checkedAt = new Date().toISOString();
  const report = {
    ok: true,
    service: 'tito-dex-cdn',
    rev: env.DEPLOY_REV || DEPLOY_REV,
    bucket: 'titodex-dex',
    checkedAt,
  };

  if (options.deep) {
    const manifestObj = await env.DEX_BUCKET.get('bundle-manifest.json');
    if (manifestObj) {
      try {
        const manifest = JSON.parse(await manifestObj.text());
        const activePrefix = activePrefixForManifest(manifest);
        report.manifest = {
          bundleVersion: manifest.bundleVersion,
          activePrefix,
          l10nVersion: manifest.l10nVersion,
          publishedAt: manifest.publishedAt,
          archiveUrl: manifest.archiveUrl,
        };
        if (!activePrefix) {
          report.probe = { ok: false, checked: 0, missing: ['active-prefix'], keys: [] };
          report.ok = false;
        } else {
          const probe = await probeR2Keys(env, probeKeysForPrefix(activePrefix));
          report.probe = probe;
          report.ok = probe.ok;
        }
      } catch {
        report.manifest = { parseError: true };
        report.probe = { ok: false, checked: 0, missing: ['manifest-parse'], keys: [] };
        report.ok = false;
      }
    } else {
      report.manifest = null;
      report.probe = { ok: false, checked: 0, missing: ['bundle-manifest.json'], keys: [] };
      report.ok = false;
    }
  }

  if (env.MANIFEST_KV) {
    const lastProbe = await env.MANIFEST_KV.get('health:last_probe', 'json');
    if (lastProbe) {
      report.lastScheduledProbe = lastProbe;
    }
    const lastDispatch = await env.MANIFEST_KV.get('cron:last_dispatch', 'json');
    if (lastDispatch) {
      report.lastScheduledDispatch = lastDispatch;
    }
  }

  return report;
}

/**
 * @param {import('./types.js').Env} env
 * @param {Record<string, unknown>} report
 */
export async function sendHealthAlert(env, report) {
  const missing = report.probe?.missing ?? [];
  const text = missing.length
    ? `TitoDex CDN probe failed — missing: ${missing.join(', ')}`
    : 'TitoDex CDN probe reported not ok';

  await sendAlert(env, text, {
    title: 'dex.tito.cafe health alert',
    fields: {
      checkedAt: String(report.checkedAt),
      rev: String(report.rev),
    },
  });
}

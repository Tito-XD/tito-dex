import { DEPLOY_REV, PROBE_KEYS } from './constants.js';

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
    const probe = await probeR2Keys(env, PROBE_KEYS);
    report.probe = probe;
    report.ok = probe.ok;

    const manifestObj = await env.DEX_BUCKET.get('bundle-manifest.json');
    if (manifestObj) {
      try {
        const manifest = JSON.parse(await manifestObj.text());
        report.manifest = {
          bundleVersion: manifest.bundleVersion,
          l10nVersion: manifest.l10nVersion,
          publishedAt: manifest.publishedAt,
          archiveUrl: manifest.archiveUrl,
        };
      } catch {
        report.manifest = { parseError: true };
        report.ok = false;
      }
    } else {
      report.manifest = null;
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
  const webhook = env.ALERT_WEBHOOK_URL;
  if (!webhook) {
    return;
  }

  const missing = report.probe?.missing ?? [];
  const text = missing.length
    ? `TitoDex CDN probe failed — missing: ${missing.join(', ')}`
    : 'TitoDex CDN probe reported not ok';

  await fetch(webhook, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      content: text,
      embeds: [
        {
          title: 'dex.tito.cafe health alert',
          description: text,
          color: 0xff4444,
          fields: [
            { name: 'checkedAt', value: String(report.checkedAt), inline: true },
            { name: 'rev', value: String(report.rev), inline: true },
          ],
        },
      ],
    }),
  });
}

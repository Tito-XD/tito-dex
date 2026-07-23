import { buildHealthReport, sendHealthAlert } from './health.js';
import { triggerGitHubWorkflow } from './github-dispatch.js';

/** Sunday 04:00 UTC — weekly l10n sync. */
export const CRON_L10N_SYNC = '0 4 * * SUN';

/** Every 6 hours — deep CDN probe + optional alert. */
export const CRON_HEALTH_PROBE = '0 */6 * * *';

/**
 * @param {import('./types.js').Env} env
 * @param {string} cron
 */
export async function handleScheduledCron(env, cron) {
  if (cron === CRON_L10N_SYNC) {
    const result = await triggerGitHubWorkflow(env, 'sync-l10n', {
      force_full: false,
      source: 'worker-cron',
    });
    if (env.MANIFEST_KV) {
      await env.MANIFEST_KV.put(
        'cron:last_dispatch',
        JSON.stringify({ ...result, cron, at: new Date().toISOString() }),
        { expirationTtl: 86400 * 30 },
      );
    }
    return { action: 'sync-l10n', ...result };
  }

  if (cron === CRON_HEALTH_PROBE) {
    const report = await buildHealthReport(env, { deep: true });
    if (env.MANIFEST_KV) {
      await env.MANIFEST_KV.put('health:last_probe', JSON.stringify(report), {
        expirationTtl: 86400 * 7,
      });
    }
    if (!report.ok) {
      await sendHealthAlert(env, report);
    }
    return { action: 'health-probe', ok: report.ok, missing: report.probe?.missing ?? [] };
  }

  return { action: 'unknown', cron };
}

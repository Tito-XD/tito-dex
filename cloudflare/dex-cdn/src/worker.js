/**
 * TitoDex dex CDN Worker — R2 proxy, cron scheduler, health probes, admin API.
 *
 * Public routes:
 *   GET /bundle/latest       → 302 to bundle-manifest.json archiveUrl
 *   GET /cdn-health          → liveness (+ ?probe=1 for deep R2 checks)
 *   GET /*                   → R2 object (sprites use version-group fallbacks)
 *
 * Admin routes (Authorization: Bearer ADMIN_SECRET):
 *   GET  /admin/status       → deep health + manifest summary
 *   POST /admin/trigger-sync → repository_dispatch to GitHub Actions
 *   PUT  /admin/manifest     → merge-update bundle-manifest.json in R2
 */

import { CORS_HEADERS, DEPLOY_REV } from './lib/constants.js';
import { jsonResponse, methodNotAllowed, textResponse } from './lib/http.js';
import { buildHealthReport } from './lib/health.js';
import { handleAdminRequest } from './lib/admin.js';
import { handleScheduledCron } from './lib/cron.js';
import { serveR2Object, serveWithFallbacks } from './lib/r2-serve.js';

function objectKeyFromPath(pathname) {
  const path = pathname.replace(/^\/+/, '');
  if (!path || path === '/') {
    return 'bundle-manifest.json';
  }
  return path;
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);

    if (url.pathname.startsWith('/admin/')) {
      if (request.method !== 'GET' && request.method !== 'POST' && request.method !== 'PUT') {
        return methodNotAllowed();
      }
      return handleAdminRequest(request, env);
    }

    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return methodNotAllowed();
    }

    if (url.pathname === '/bundle/latest') {
      const manifestObj = await env.DEX_BUCKET.get('bundle-manifest.json');
      if (!manifestObj) {
        return textResponse('bundle-manifest.json not found', 404);
      }
      const manifest = JSON.parse(await manifestObj.text());
      return Response.redirect(manifest.archiveUrl, 302);
    }

    if (url.pathname === '/cdn-health') {
      const deep = url.searchParams.get('probe') === '1';
      const report = await buildHealthReport(env, { deep });
      return jsonResponse(report, report.ok ? 200 : 503);
    }

    const key = objectKeyFromPath(url.pathname);
    const response =
      key.includes('/sprites/by-version/') || key.match(/^v[23]\/sprites\/\d+\.png$/)
        ? await serveWithFallbacks(env, request, key)
        : await serveR2Object(env, request, key);

    if (!response) {
      return textResponse('Not Found', 404);
    }

    return response;
  },

  async scheduled(event, env) {
    try {
      await handleScheduledCron(env, event.cron);
    } catch (error) {
      console.error('scheduled handler failed', event.cron, error);
      if (env.ALERT_WEBHOOK_URL) {
        await fetch(env.ALERT_WEBHOOK_URL, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            content: `TitoDex Worker cron failed (${event.cron}): ${
              error instanceof Error ? error.message : String(error)
            }`,
          }),
        }).catch(() => {});
      }
    }
  },
};

export { DEPLOY_REV };

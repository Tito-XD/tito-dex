import { jsonResponse, requireAdmin, textResponse } from './http.js';
import { buildHealthReport } from './health.js';
import { triggerGitHubWorkflow } from './github-dispatch.js';
import { putJsonObject, readJsonObject } from './r2-serve.js';

/**
 * @param {Request} request
 * @param {import('./types.js').Env} env
 */
export async function handleAdminRequest(request, env) {
  const auth = requireAdmin(request, env);
  if (!auth.ok) {
    return auth.response;
  }

  const url = new URL(request.url);
  const path = url.pathname;

  if (path === '/admin/status' && request.method === 'GET') {
    const report = await buildHealthReport(env, { deep: true });
    return jsonResponse(report);
  }

  if (path === '/admin/trigger-sync' && request.method === 'POST') {
    let body = {};
    try {
      body = await request.json();
    } catch {
      return textResponse('Invalid JSON body', 400);
    }

    const workflow = typeof body.workflow === 'string' ? body.workflow : 'sync-l10n';
    const inputs = typeof body.inputs === 'object' && body.inputs ? body.inputs : {};

    try {
      const result = await triggerGitHubWorkflow(env, workflow, inputs);
      if (env.MANIFEST_KV) {
        await env.MANIFEST_KV.put(
          'admin:last_dispatch',
          JSON.stringify({
            ...result,
            workflow,
            inputs,
            at: new Date().toISOString(),
          }),
          { expirationTtl: 86400 * 30 },
        );
      }
      return jsonResponse({ ok: true, ...result, workflow, inputs });
    } catch (error) {
      return jsonResponse(
        { ok: false, error: error instanceof Error ? error.message : String(error) },
        502,
      );
    }
  }

  if (path === '/admin/manifest' && request.method === 'PUT') {
    let patch = {};
    try {
      patch = await request.json();
    } catch {
      return textResponse('Invalid JSON body', 400);
    }

    const existing = (await readJsonObject(env, 'bundle-manifest.json')) ?? {};
    const merged = { ...existing, ...patch, publishedAt: new Date().toISOString() };

    await putJsonObject(env, 'bundle-manifest.json', merged);
    return jsonResponse({ ok: true, manifest: merged });
  }

  return textResponse('Not Found', 404);
}

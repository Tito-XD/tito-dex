import { DEFAULT_GITHUB_REPO } from './constants.js';

const WORKFLOW_EVENT_TYPES = {
  'sync-l10n': 'sync-l10n',
  'pokeapi-assets': 'build-pokeapi-assets',
};

/**
 * Trigger a GitHub Actions workflow via repository_dispatch.
 * @param {import('./types.js').Env} env
 * @param {string} workflowKey
 * @param {Record<string, unknown>} clientPayload
 */
export async function triggerGitHubWorkflow(env, workflowKey, clientPayload = {}) {
  const token = env.GITHUB_DISPATCH_TOKEN;
  if (!token) {
    throw new Error('GITHUB_DISPATCH_TOKEN is not configured');
  }

  const eventType = WORKFLOW_EVENT_TYPES[workflowKey];
  if (!eventType) {
    throw new Error(`Unknown workflow: ${workflowKey}`);
  }

  const repo = env.GITHUB_REPO || DEFAULT_GITHUB_REPO;
  const response = await fetch(`https://api.github.com/repos/${repo}/dispatches`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/vnd.github+json',
      'Content-Type': 'application/json',
      'User-Agent': 'tito-dex-cdn-worker',
      'X-GitHub-Api-Version': '2022-11-28',
    },
    body: JSON.stringify({
      event_type: eventType,
      client_payload: {
        source: 'worker',
        triggeredAt: new Date().toISOString(),
        ...clientPayload,
      },
    }),
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`GitHub dispatch failed (${response.status}): ${detail}`);
  }

  return { repo, eventType, status: response.status };
}

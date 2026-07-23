/**
 * @param {import('./types.js').Env} env
 */
export function hasAlertConfigured(env) {
  return Boolean(
    (env.TELEGRAM_BOT_TOKEN && env.TELEGRAM_CHAT_ID) || env.ALERT_WEBHOOK_URL,
  );
}

/**
 * @param {import('./types.js').Env} env
 * @param {string} text
 * @param {{ title?: string, fields?: Record<string, string> }} [options]
 */
export async function sendAlert(env, text, options = {}) {
  await Promise.all([
    sendTelegramAlert(env, text, options).catch((error) => {
      console.error('telegram alert failed', error);
    }),
    sendWebhookAlert(env, text, options).catch((error) => {
      console.error('webhook alert failed', error);
    }),
  ]);
}

/**
 * @param {import('./types.js').Env} env
 * @param {string} text
 * @param {{ title?: string, fields?: Record<string, string> }} [options]
 */
async function sendTelegramAlert(env, text, options = {}) {
  const token = env.TELEGRAM_BOT_TOKEN;
  const chatId = env.TELEGRAM_CHAT_ID;
  if (!token || !chatId) {
    return;
  }

  const lines = [];
  if (options.title) {
    lines.push(`🚨 ${options.title}`);
    lines.push('');
  }
  lines.push(text);
  if (options.fields) {
    lines.push('');
    for (const [key, value] of Object.entries(options.fields)) {
      lines.push(`${key}: ${value}`);
    }
  }

  const response = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      chat_id: chatId,
      text: lines.join('\n'),
      disable_web_page_preview: true,
    }),
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`Telegram sendMessage failed (${response.status}): ${detail}`);
  }
}

/**
 * @param {import('./types.js').Env} env
 * @param {string} text
 * @param {{ title?: string, fields?: Record<string, string> }} [options]
 */
async function sendWebhookAlert(env, text, options = {}) {
  const webhook = env.ALERT_WEBHOOK_URL;
  if (!webhook) {
    return;
  }

  await fetch(webhook, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      content: text,
      embeds: options.title
        ? [
            {
              title: options.title,
              description: text,
              color: 0xff4444,
              fields: options.fields
                ? Object.entries(options.fields).map(([name, value]) => ({
                    name,
                    value,
                    inline: true,
                  }))
                : [],
            },
          ]
        : undefined,
    }),
  });
}

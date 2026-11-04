import { renderEmail } from './messages.mjs';

export function createEmailWorker({ client, getEnv, fetchImpl = fetch,
  waitUntil, logger = console }) {
  async function rpc(name, args = {}) {
    const result = await client.rpc(`accommodation_email_${name}`, args);
    if (result.error) throw new Error(`Email queue ${name} failed`);
    return result.data;
  }

  async function checkProvider(config, diagnostics = false) {
    const apiKey = getEnv('BREVO_API_KEY');
    if (!apiKey) return { ready: false, api_key_configured: false };
    const results = await Promise.all(['senders', 'account'].map(async (path) => {
      const response = await fetchImpl(`https://api.brevo.com/v3/${path}`, {
        method: 'GET', headers: { Accept: 'application/json', 'api-key': apiKey },
        signal: AbortSignal.timeout(12000),
      });
      return { ok: response.ok, status: response.status, contentType: response.headers.get('content-type'),
        data: await response.json().catch(() => ({})) };
    }));
    const [senders, account] = results;
    const valid = senders.ok && account.ok;
    const verified = valid && (senders.data.senders ?? []).some((sender) =>
      sender.email?.toLowerCase() === config.sender_email.toLowerCase() && sender.active === true);
    const enabled = valid && account.data.relay?.enabled === true;
    const providerErrors = results.map(({ ok, status, data }) => {
      if (ok) return null;
      const message = typeof data.message === 'string' ? data.message : '';
      if (/\bip\b/i.test(message) && /unrecogni[sz]ed|unauthori[sz]ed|not.*authori[sz]ed|whitelist|allowlist/i.test(message)) {
        return 'ip_not_authorized';
      }
      if (status === 401) return 'authentication_rejected';
      if (status === 403) return 'access_forbidden';
      return 'provider_request_failed';
    });
    // Return only readiness flags, never the key or other account/profile data.
    return { ready: verified && enabled, api_key_configured: true, api_key_valid: valid,
      sender_verified: verified, transactional_enabled: enabled,
      sender_email: config.sender_email, provider_status: results.map(r => r.status),
      provider_errors: providerErrors,
      ...(diagnostics ? { provider_diagnostics: results.map(r => r.ok ? null : {
        code: typeof r.data.code === 'string' && /^[a-z_]{1,64}$/i.test(r.data.code) ? r.data.code : null,
        content_type: r.contentType,
        message: typeof r.data.message === 'string' ? r.data.message
          .split(apiKey).join('[redacted]')
          .replace(/[\w.+-]+@[\w.-]+\.[a-z]{2,}/gi, '[email]')
          .replace(/https?:\/\/\S+/gi, '[url]')
          .replace(/\b(?:\d{1,3}\.){3}\d{1,3}\b/g, '[ip]')
          .slice(0, 300) : 'No JSON error message returned',
      }) } : {}) };
  }

  async function processEvent(event, config, apiKey) {
    let failure = null;
    try {
      const recipients = await rpc('prepare', { p_event: event.id, p_lease: event.lease_token });
      for (const recipient of recipients ?? []) {
        const content = renderEmail(event, recipient, config);
        const response = await fetchImpl('https://api.brevo.com/v3/smtp/email', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'api-key': apiKey },
          body: JSON.stringify({
            sender: { name: config.sender_name, email: config.sender_email },
            replyTo: { name: config.sender_name, email: config.sender_email },
            to: [{ email: recipient.email, name: recipient.display_name || 'Administrator' }],
            ...content,
            // The database retains this UUID across retries. Recipient addresses
            // are sent separately, and successful deliveries are not resent.
            headers: { idempotencyKey: recipient.id },
            tags: ['staff-accommodation', event.kind],
          }),
          signal: AbortSignal.timeout(12000),
        });
        const result = await response.json().catch(() => ({}));
        if (!response.ok && result.code !== 'duplicate_parameter') {
          throw new Error(`Brevo returned HTTP ${response.status}`);
        }
        await rpc('ack', { p_delivery: recipient.id, p_event: event.id,
          p_lease: event.lease_token, p_provider_id: result.messageId ?? null });
      }
    } catch (error) {
      // Never log provider credentials or email bodies.
      failure = error instanceof Error && /^Brevo returned HTTP \d+$/.test(error.message)
        ? error.message : 'Email processing failed; retry scheduled';
      logger.error('Accommodation email processing failed', { event_id: event.id, error: failure });
    } finally {
      try {
        await rpc('finish', { p_event: event.id, p_lease: event.lease_token, p_error: failure });
      } catch {
        logger.error('Accommodation email lease will be recovered automatically', { event_id: event.id });
      }
    }
  }

  return async function handler(request) {
    if (request.method === 'OPTIONS') return new Response(null, { status: 204 });
    if (request.method !== 'POST') return Response.json({ error: 'Method not allowed' }, { status: 405 });
    const match = /^Bearer ([a-f0-9]{64})$/i.exec(request.headers.get('Authorization') ?? '');
    if (!match) return Response.json({ error: 'Unauthorized' }, { status: 401 });
    try {
      if (!await rpc('worker_authorized', { p_token: match[1] })) {
        return Response.json({ error: 'Unauthorized' }, { status: 401 });
      }
      const config = await rpc('config');
      const input = await request.json().catch(() => ({}));
      if (input?.check_only === true) return Response.json(await checkProvider(config, input.diagnostics === true));
      if (!config?.enabled) return Response.json({ enabled: false, accepted: 0 });
      const apiKey = getEnv('BREVO_API_KEY');
      if (!apiKey) return Response.json({ error: 'Brevo API key not configured' }, { status: 503 });
      const events = await rpc('claim', { p_limit: 3 });
      if (!events?.length) return Response.json({ accepted: 0 });
      waitUntil(Promise.all(events.map((event) => processEvent(event, config, apiKey))));
      return Response.json({ accepted: events.length }, { status: 202 });
    } catch {
      logger.error('Accommodation email worker could not access its queue');
      return Response.json({ error: 'Email queue unavailable' }, { status: 503 });
    }
  };
}

import assert from 'node:assert/strict';
import test from 'node:test';
import { renderEmail } from './messages.mjs';
import { createEmailWorker } from './worker.mjs';

const config = { enabled: true, sender_name: 'Accommodation Notifications',
  sender_email: 'sgsit2024@gmail.com', site_url: 'https://accomodation-app-seven.vercel.app/' };
const event = { id: 'event-1', lease_token: 'lease-1', kind: 'staff_created',
  payload: { staff_name: 'John Smith', staff_id: 'S123' }, created_at: '2026-11-04T07:00:00Z' };
const recipients = [
  { id: 'ef6d7be1-6b4e-4167-b8e1-532fba2d6a6a', email: 'admin1@example.test', display_name: 'First admin' },
  { id: 'a15d6419-902a-40e9-a2b4-e340641299ce', email: 'admin2@example.test', display_name: 'Second admin' },
];

function harness(options = {}) {
  const calls = [], sends = [], reads = [], tasks = [], errors = [], acknowledged = new Set();
  const client = { async rpc(name, args) {
    calls.push({ name, args });
    if (options.failRpc === name) return { data: null, error: { message: 'Database error' } };
    let data;
    switch (name) {
      case 'accommodation_email_worker_authorized': data = args.p_token === 'a'.repeat(64); break;
      case 'accommodation_email_config': data = { ...config, ...options.config }; break;
      case 'accommodation_email_claim': data = options.events ?? [event]; break;
      case 'accommodation_email_prepare': data = recipients.filter(r => !acknowledged.has(r.id)); break;
      case 'accommodation_email_ack': acknowledged.add(args.p_delivery); data = null; break;
      case 'accommodation_email_finish': data = null; break;
      default: throw new Error(`Unexpected RPC: ${name}`);
    }
    return { data, error: null };
  } };
  const handler = createEmailWorker({ client,
    getEnv: () => options.missingKey ? undefined : 'test-brevo-key',
    waitUntil: task => tasks.push(task),
    logger: { error: (...args) => errors.push(args) },
    fetchImpl: async (url, init) => {
      if (init.method === 'GET') {
        reads.push(url);
        if (options.readStatus) return Response.json({ message: options.readMessage ?? 'Private account data' }, { status: options.readStatus });
        return Response.json(url.endsWith('/senders')
          ? { senders: [{ email: config.sender_email, active: options.senderVerified !== false }] }
          : { relay: { enabled: options.relayEnabled !== false }, email: 'not-returned@example.test' });
      }
      sends.push({ url, init, message: JSON.parse(init.body) });
      if (options.fetchError) throw new Error('Private provider response test-brevo-key');
      if (options.respond) return options.respond(sends.length);
      return Response.json({ messageId: `message-${sends.length}` }, { status: 201 });
    },
  });
  return { handler, calls, sends, reads, tasks, errors, acknowledged };
}
const request = (token = 'a'.repeat(64)) => new Request('https://worker.example.test', {
  method: 'POST', headers: { Authorization: `Bearer ${token}` }, body: '{}',
});

for (const kind of ['admin_welcome', 'staff_created', 'staff_deleted', 'room_shift_request',
  'leave_request', 'room_shift_logged', 'leave_started']) {
  test(`${kind} has readable HTML and text without exposing passwords`, () => {
    const message = renderEmail({ ...event, kind, payload: {
      ...event.payload, staff_name: 'A <script>alert(1)</script> & B',
      reason: '<b>Personal</b>', password: 'NEVER_EMAIL_A_PASSWORD',
    } }, recipients[0], config);
    assert.ok(message.subject.length > 0);
    assert.ok(message.textContent.includes('https://accomodation-app-seven.vercel.app/'));
    assert.ok(!message.htmlContent.includes('<script>'));
    assert.ok(!JSON.stringify(message).includes('NEVER_EMAIL_A_PASSWORD'));
  });
}

test('welcome message identifies the new admin rather than broadcasting their login', () => {
  const message = renderEmail({ ...event, kind: 'admin_welcome' }, recipients[0], config);
  assert.ok(message.textContent.includes(recipients[0].email));
  assert.ok(message.textContent.includes(recipients[0].display_name));
  assert.ok(!message.textContent.includes(recipients[1].email));
});

test('contract reminders identify the location, room, expiry and both thresholds safely', () => {
  for (const days of [10, 5]) {
    const message = renderEmail({ ...event, kind: 'contract_expiry_reminder', payload: {
      days_before: days, location_name: 'East <script>alert(1)</script> & West',
      room_number: 'R001', contract_number: 'C123', expiry_date: '2026-12-01',
    } }, recipients[0], config);
    assert.ok(message.subject.includes(`in ${days} days`));
    for (const detail of ['R001', 'C123', '2026-12-01']) assert.ok(message.textContent.includes(detail));
    assert.ok(!message.htmlContent.includes('<script>'));
  }
  assert.throws(() => renderEmail({ ...event, kind: 'contract_expiry_reminder',
    payload: { days_before: 3 } }, recipients[0], config));
});

test('rejects unknown templates and unsafe login URLs', () => {
  assert.throws(() => renderEmail({ ...event, kind: 'unknown' }, recipients[0], config));
  assert.throws(() => renderEmail(event, recipients[0], { ...config, site_url: 'javascript:alert(1)' }));
});

test('rejects missing and incorrect worker credentials without claiming jobs', async () => {
  const h = harness();
  const missing = await h.handler(new Request('https://worker.example.test', { method: 'POST' }));
  assert.equal(missing.status, 401);
  const incorrect = await h.handler(request('b'.repeat(64)));
  assert.equal(incorrect.status, 401);
  assert.equal(h.calls.length, 1);
  assert.equal(h.sends.length, 0);
});

test('disabled setup and missing credentials do not consume job attempts', async () => {
  const disabled = harness({ config: { enabled: false } });
  assert.deepEqual(await (await disabled.handler(request())).json(), { enabled: false, accepted: 0 });
  const missingKey = harness({ missingKey: true });
  assert.equal((await missingKey.handler(request())).status, 503);
  for (const h of [disabled, missingKey]) {
    assert.ok(!h.calls.some(c => c.name === 'accommodation_email_claim'));
    assert.equal(h.sends.length, 0);
  }
});

test('delivers separately to each resolved admin and acknowledges successful emails', async () => {
  const h = harness();
  assert.equal((await h.handler(request())).status, 202);
  await Promise.all(h.tasks);
  assert.equal(h.sends.length, 2);
  for (const [i, send] of h.sends.entries()) {
    assert.equal(send.url, 'https://api.brevo.com/v3/smtp/email');
    assert.equal(send.init.headers['api-key'], 'test-brevo-key');
    assert.equal(send.message.to.length, 1);
    assert.equal(send.message.to[0].email, recipients[i].email);
    assert.equal(send.message.headers.idempotencyKey, recipients[i].id);
    assert.equal(send.message.sender.email, config.sender_email);
  }
  assert.equal(h.acknowledged.size, 2);
  assert.equal(h.calls.find(c => c.name === 'accommodation_email_finish').args.p_error, null);
});

test('partial failure retries only remaining recipients with the same delivery UUID', async () => {
  const h = harness({ respond: count => count === 2
    ? Response.json({ code: 'service_unavailable' }, { status: 503 })
    : Response.json({ messageId: `id-${count}` }, { status: 201 }) });
  await h.handler(request());
  await Promise.all(h.tasks);
  assert.equal(h.acknowledged.size, 1);
  assert.equal(h.calls.find(c => c.name === 'accommodation_email_finish').args.p_error, 'Brevo returned HTTP 503');
  await h.handler(request());
  await Promise.all(h.tasks);
  assert.equal(h.sends.length, 3);
  assert.equal(h.sends[2].message.to[0].email, recipients[1].email);
  assert.equal(h.sends[2].message.headers.idempotencyKey, h.sends[1].message.headers.idempotencyKey);
  assert.equal(h.acknowledged.size, 2);
});

test('Brevo duplicate-key response is acknowledged instead of repeatedly retried', async () => {
  const h = harness({ respond: () => Response.json({ code: 'duplicate_parameter' }, { status: 400 }) });
  await h.handler(request());
  await Promise.all(h.tasks);
  assert.equal(h.acknowledged.size, 2);
});

test('transport and database errors do not expose credentials in logs', async () => {
  for (const options of [{ fetchError: true }, { failRpc: 'accommodation_email_prepare' }]) {
    const h = harness(options);
    await h.handler(request());
    await Promise.all(h.tasks);
    assert.ok(h.calls.some(c => c.name === 'accommodation_email_finish' && c.args.p_error));
    assert.ok(!JSON.stringify(h.errors).includes('test-brevo-key'));
  }
});

test('preflight and unsupported methods send no emails', async () => {
  const h = harness();
  assert.equal((await h.handler(new Request('https://worker.example.test', { method: 'OPTIONS' }))).status, 204);
  assert.equal((await h.handler(new Request('https://worker.example.test'))).status, 405);
  assert.equal(h.calls.length, 0);
  assert.equal(h.sends.length, 0);
});

const checkRequest = (diagnostics = false) => new Request('https://worker.example.test', {
  method: 'POST', headers: { Authorization: `Bearer ${'a'.repeat(64)}` },
  body: JSON.stringify({ check_only: true, diagnostics }),
});

test('readiness check validates Brevo while delivery is disabled and sends nothing', async () => {
  const h = harness({ config: { enabled: false } });
  const status = await (await h.handler(checkRequest())).json();
  assert.equal(status.ready, true);
  assert.equal(status.sender_verified, true);
  assert.equal(status.transactional_enabled, true);
  assert.equal(h.reads.length, 2);
  assert.equal(h.sends.length, 0);
  assert.ok(!h.calls.some(c => c.name === 'accommodation_email_claim'));
  assert.ok(!JSON.stringify(status).includes('test-brevo-key'));
  assert.ok(!JSON.stringify(status).includes('not-returned@example.test'));
});

test('readiness identifies missing keys, invalid keys, unverified senders and disabled email service', async () => {
  for (const options of [{ missingKey: true }, { readStatus: 401 },
    { senderVerified: false }, { relayEnabled: false }]) {
    const h = harness(options);
    const status = await (await h.handler(checkRequest())).json();
    assert.equal(status.ready, false);
    assert.equal(h.sends.length, 0);
    assert.ok(!JSON.stringify(status).includes('Private account data'));
  }
});

test('readiness identifies IP restrictions without exposing provider response data', async () => {
  const h = harness({ readStatus: 403,
    readMessage: 'We have detected you are using an unrecognised IP address 192.0.2.1. Private account data' });
  const status = await (await h.handler(checkRequest())).json();
  assert.deepEqual(status.provider_errors, ['ip_not_authorized', 'ip_not_authorized']);
  assert.ok(!JSON.stringify(status).includes('192.0.2.1'));
  assert.ok(!JSON.stringify(status).includes('Private account data'));
  assert.equal(h.sends.length, 0);
});

test('explicit authenticated diagnostics redact the key and identifying error details', async () => {
  const h = harness({ readStatus: 403,
    readMessage: 'Access denied test-brevo-key account@example.test 192.0.2.1 https://private.example.test' });
  const status = await (await h.handler(checkRequest(true))).json();
  assert.ok(status.provider_diagnostics[0].message.startsWith('Access denied'));
  for (const value of ['test-brevo-key', 'account@example.test', '192.0.2.1', 'https://private.example.test']) {
    assert.ok(!JSON.stringify(status).includes(value));
  }
  assert.equal(h.sends.length, 0);
});

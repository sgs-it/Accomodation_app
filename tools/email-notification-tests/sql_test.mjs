import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

// A real, isolated Postgres engine. Vault/net/cron are local no-network stubs.
// These tests never connect to Supabase or modify production accommodation data.
const db = new PGlite();
const uuid = n => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const one = async (sql, params = []) => (await db.query(sql, params)).rows[0];
const count = async table => Number((await one(`select count(*) as n from ${table}`)).n);
let checks = 0;
function check(condition, description) {
  assert.ok(condition, description);
  checks++;
  console.log(`PASS ${description}`);
}

try {
  await db.exec(`
    create role anon; create role authenticated; create role service_role;
    create schema auth;
    create function auth.jwt() returns jsonb language sql as $$
      select coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb)
    $$;
    create table auth.users(id uuid primary key, email text, raw_user_meta_data jsonb default '{}');
    create table public.user_roles(id uuid default gen_random_uuid(), user_id uuid primary key
      references auth.users on delete cascade, role text, created_at timestamptz default now());
    create table public.staff(id uuid primary key, name text, staff_id text, status text,
      auth_user_id uuid references auth.users on delete cascade);
    create table public.beds(id uuid primary key, bed_code text);
    create table public.shift_history(id uuid primary key, staff_id uuid references public.staff on delete cascade,
      shift_date date, from_bed_id uuid, to_bed_id uuid, reason text);
    create table public.pending_changes(id uuid primary key, change_type text, staff_name text, payload jsonb);
    create table public.legacy_email_calls(id uuid default gen_random_uuid());
    create function public.fn_send_request_email() returns trigger language plpgsql security definer as $$
    BEGIN
      insert into public.legacy_email_calls default values; return new;
    END $$;
    create trigger tr_send_request_email after insert on public.pending_changes for each row
      execute function public.fn_send_request_email();
    create schema vault;
    create table vault.secrets(id uuid default gen_random_uuid(), name text unique, secret text);
    create view vault.decrypted_secrets as select id, name, secret as decrypted_secret from vault.secrets;
    create function vault.create_secret(new_secret text, new_name text, description text) returns uuid
      language sql as $$ insert into vault.secrets(name,secret) values(new_name,new_secret) returning id $$;
    create schema net;
    create table net.test_requests(id bigserial primary key, url text, headers jsonb, body jsonb);
    create function net.http_post(url text, headers jsonb, body jsonb, timeout_milliseconds integer)
      returns bigint language sql as $$ insert into net.test_requests(url,headers,body)
      values(url,headers,body) returning id $$;
    create schema cron;
    create table cron.test_jobs(id bigserial primary key, name text, schedule text, command text);
    create function cron.schedule(name text, schedule text, command text) returns bigint language sql as $$
      insert into cron.test_jobs(name,schedule,command) values(name,schedule,command) returning id $$;
  `);
  await db.query('insert into auth.users values($1,$2,$3)', [uuid(1), 'first@example.test', { display_name: 'First admin' }]);
  await db.query('insert into public.user_roles(user_id,role) values($1,\'admin\')', [uuid(1)]);
  let migration = await readFile(new URL('../../supabase/migrations/20261104071851_automated_admin_email_notifications.sql', import.meta.url), 'utf8');
  // The hosted extension itself is tested against Supabase's documented APIs;
  // this local engine substitutes the scheduler but executes all application SQL.
  migration = migration.replace(/^create extension if not exists pg_cron with schema pg_catalog;\r?\n/gm, '');
  await db.exec(migration);
  check((await one('select enabled from email_notifications.config')).enabled === false, 'delivery is disabled by default');
  check(await count('email_notifications.events') === 0, 'existing admins are not backfilled or sent welcome emails');
  check(await count('public.user_roles') === 1, 'migration leaves existing account records unchanged');
  await db.query('insert into public.staff values($1,\'Disabled\',\'S0\',\'Active\',null)', [uuid(10)]);
  await db.query('insert into public.pending_changes values($1,\'leave_request\',\'Disabled\',\'{}\')', [uuid(20)]);
  check(await count('email_notifications.events') === 0, 'events do not accumulate before activation');
  check(await count('public.legacy_email_calls') === 1, 'legacy request emails remain active while disabled');

  await db.exec(`update email_notifications.config set enabled = true;
    select set_config('request.jwt.claims','{"role":"service_role"}',false);`);
  for (const n of [2, 3]) {
    await db.query('insert into auth.users values($1,$2,$3)', [uuid(n), `admin${n}@example.test`, { display_name: `Admin ${n}` }]);
    await db.query('insert into public.user_roles(user_id,role) values($1,$2)', [uuid(n), n === 2 ? 'admin' : 'staff']);
  }
  await db.query('update public.user_roles set role=\'admin\' where user_id=$1', [uuid(3)]);
  await db.query('update public.user_roles set role=\'admin\' where user_id=$1', [uuid(2)]);
  check(await count('email_notifications.events') === 2, 'first admin creation/promotion queues one welcome; repeated upsert does not');
  await db.query('insert into public.staff values($1,\'Jane Snapshot\',\'S100\',\'Active\',null)', [uuid(100)]);
  await db.query('insert into public.shift_history values($1,$2,\'2026-11-04\',null,null,\'Move\')', [uuid(300), uuid(100)]);
  await db.query('update public.staff set status=\'On Leave\' where id=$1', [uuid(100)]);
  await db.query('update public.staff set status=\'On Leave\' where id=$1', [uuid(100)]);
  await db.query('delete from public.staff where id=$1', [uuid(100)]);
  await db.query('insert into public.pending_changes values($1,\'shift_request\',\'John\',$2)', [uuid(200),
    { reason: '<b>Transfer</b>', password: 'DO_NOT_COPY', target_location_id: 'location-1' }]);
  await db.query('insert into public.pending_changes values($1,\'leave_request\',\'John\',$2)', [uuid(201),
    { from_date: '2026-11-01', to_date: '2026-11-05', reason: 'Annual' }]);
  check(await count('email_notifications.events') === 8, 'all seven requested event categories are captured without duplicate status alerts');
  const deleted = await one("select payload from email_notifications.events where kind='staff_deleted'");
  check(deleted.payload.staff_name === 'Jane Snapshot', 'deletion snapshot survives removal of the staff row');
  const snapshot = await one("select payload from email_notifications.events where kind='room_shift_request'");
  check(!('password' in snapshot.payload), 'queue copies only selected notification fields');
  check(await count('public.legacy_email_calls') === 1, 'legacy request email is suppressed only after activation');

  const beforeRollback = await count('email_notifications.events');
  await db.exec(`begin; insert into public.staff values('${uuid(110)}','Rollback','S110','Active',null); rollback;`);
  check(await count('email_notifications.events') === beforeRollback, 'rolled-back business actions never leave email events');
  check(await count('net.test_requests') === 0, 'business writes perform no HTTP or SMTP calls');

  const key = (await one("select decrypted_secret from vault.decrypted_secrets where name='accommodation_email_worker_key'")).decrypted_secret;
  check((await one('select public.accommodation_email_worker_authorized($1) as ok', [key])).ok, 'worker authenticates its private Vault credential');
  check(!(await one("select public.accommodation_email_worker_authorized('wrong') as ok")).ok, 'invalid worker credentials are rejected');
  const claims = (await db.query('select * from public.accommodation_email_claim(10)')).rows;
  check(claims.length === 8, 'worker claims a bounded batch of due events');
  check((await db.query('select * from public.accommodation_email_claim(10)')).rows.length === 0, 'overlapping workers cannot claim leased events');

  const welcome = claims.find(e => e.kind === 'admin_welcome' && e.target_user_id === uuid(2));
  const welcomeRecipients = (await db.query('select * from public.accommodation_email_prepare($1,$2)', [welcome.id, welcome.lease_token])).rows;
  check(welcomeRecipients.length === 1 && welcomeRecipients[0].user_id === uuid(2), 'welcome email goes only to its new admin');
  const created = claims.find(e => e.kind === 'staff_created');
  let targets = (await db.query('select * from public.accommodation_email_prepare($1,$2)', [created.id, created.lease_token])).rows;
  check(targets.length === 3, 'event alerts resolve all current admins from Auth and roles');
  const first = targets.find(r => r.user_id === uuid(1));
  await db.query('select public.accommodation_email_ack($1,$2,$3,$4)', [first.id, created.id, created.lease_token, 'provider-id']);
  await db.query('select public.accommodation_email_finish($1,$2,$3)', [created.id, created.lease_token, 'Provider unavailable']);
  check((await one('select state from email_notifications.events where id=$1', [created.id])).state === 'pending', 'partial failures are retained for retry');
  await db.query('update public.user_roles set role=\'staff\' where user_id=$1', [uuid(2)]);
  await db.query('insert into auth.users values($1,$2,$3)', [uuid(4), 'admin4@example.test', {}]);
  await db.query('insert into public.user_roles(user_id,role) values($1,\'admin\')', [uuid(4)]);
  await db.query('update email_notifications.events set available_at=now() where id=$1', [created.id]);
  const retry = (await db.query('select * from public.accommodation_email_claim(10)')).rows.find(e => e.id === created.id);
  targets = (await db.query('select * from public.accommodation_email_prepare($1,$2)', [retry.id, retry.lease_token])).rows;
  check(targets.length === 2 && targets.some(r => r.user_id === uuid(4)), 'new admins are resolved on retry without resending acknowledged deliveries');
  check(!targets.some(r => r.user_id === uuid(2)), 'demoted admins are excluded from retry delivery');
  await db.query('update public.user_roles set role=\'admin\' where user_id=$1', [uuid(2)]);
  targets = (await db.query('select * from public.accommodation_email_prepare($1,$2)', [retry.id, retry.lease_token])).rows;
  check(targets.some(r => r.user_id === uuid(2)), 'restored current admins become eligible again before an unsent event completes');
  await db.query('update public.user_roles set role=\'staff\' where user_id=$1', [uuid(2)]);
  await db.query('delete from auth.users where id=$1', [uuid(3)]);
  targets = (await db.query('select * from public.accommodation_email_prepare($1,$2)', [retry.id, retry.lease_token])).rows;
  check(targets.length === 1 && targets[0].user_id === uuid(4), 'deleted admins are excluded from pending deliveries');
  await db.query('select public.accommodation_email_ack($1,$2,$3,$4)', [targets[0].id, retry.id, retry.lease_token, 'next-provider-id']);
  await db.query('select public.accommodation_email_finish($1,$2,null)', [retry.id, retry.lease_token]);
  check((await one('select state from email_notifications.events where id=$1', [retry.id])).state === 'sent', 'successful event completes after its remaining recipients are handled');
  const expired = claims.find(e => e.kind === 'room_shift_logged');
  await db.query("update email_notifications.events set attempts=8,leased_until=now()-interval '1 minute' where id=$1", [expired.id]);
  await one('select email_notifications.dispatch()');
  check((await one('select state from email_notifications.events where id=$1', [expired.id])).state === 'failed', 'exhausted crashed leases are retained as failures instead of remaining stuck');
  await assert.rejects(db.query('select public.accommodation_email_ack($1,$2,$3,null)', [first.id, expired.id, expired.lease_token]), /Email lease expired/);
  checks++; console.log('PASS stale worker leases cannot acknowledge deliveries');

  check(!(await one("select has_schema_privilege('authenticated','email_notifications','usage') as ok")).ok, 'app users cannot access the private queue schema');
  check(!(await one("select has_function_privilege('anon','public.accommodation_email_claim(integer)','execute') as ok")).ok, 'anonymous callers cannot execute queue RPCs');
  check(!(await one("select has_function_privilege('authenticated','public.accommodation_email_prepare(uuid,uuid)','execute') as ok")).ok, 'signed-in clients cannot read admin email recipients');
  await db.exec(`select set_config('request.jwt.claims','{"role":"authenticated"}',false)`);
  await assert.rejects(db.query('select * from public.accommodation_email_claim(1)'), /Backend service role required/);
  checks++; console.log('PASS queue RPCs also validate the backend service-role claim');
  await db.exec(`select set_config('request.jwt.claims','{"role":"service_role"}',false)`);
  const rls = (await db.query("select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='email_notifications' and c.relkind='r'")).rows;
  check(rls.length === 3 && rls.every(r => r.relrowsecurity), 'RLS is enabled on every new queue table');

  await db.exec(`create or replace function email_notifications.enqueue(p_key text,p_kind text,p_payload jsonb,p_target uuid default null)
    returns void language plpgsql set search_path='' as $$ begin raise exception 'Simulated queue failure'; end $$;`);
  await db.query('insert into public.staff values($1,\'Still created\',\'S500\',\'Active\',null)', [uuid(500)]);
  check(Boolean(await one('select id from public.staff where id=$1', [uuid(500)])), 'queue failure does not break staff creation');
  console.log(`${checks} isolated PostgreSQL checks passed. No production database or email provider was contacted.`);
} finally {
  await db.close();
}

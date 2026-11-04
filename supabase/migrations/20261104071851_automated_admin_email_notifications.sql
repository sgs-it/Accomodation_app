-- Notification-only objects. Existing accommodation rows and approval logic are untouched.
-- Delivery stays OFF until the Brevo sender and server-side API key are configured.
create schema email_notifications;
revoke all on schema email_notifications from public, anon, authenticated;
grant usage on schema email_notifications to service_role;

create table email_notifications.config (
  singleton boolean primary key default true check (singleton),
  enabled boolean not null default false,
  sender_email text not null default 'sgsit2024@gmail.com',
  sender_name text not null default 'Accommodation Notifications',
  site_url text not null default 'https://accomodation-app-seven.vercel.app/'
);
insert into email_notifications.config(singleton) values (true);

create table email_notifications.events (
  id uuid primary key default gen_random_uuid(),
  event_key text not null unique,
  kind text not null check (kind in ('admin_welcome', 'staff_created', 'staff_deleted',
    'room_shift_request', 'leave_request', 'room_shift_logged', 'leave_started')),
  target_user_id uuid,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  state text not null default 'pending' check (state in ('pending','processing','sent','skipped','failed')),
  attempts integer not null default 0,
  available_at timestamptz not null default now(),
  leased_until timestamptz,
  lease_token uuid,
  last_error text
);
create index email_events_due_idx on email_notifications.events(available_at, created_at)
  where state in ('pending','processing');

create table email_notifications.deliveries (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references email_notifications.events(id) on delete cascade,
  user_id uuid not null,
  email text not null,
  display_name text not null default '',
  state text not null default 'pending' check (state in ('pending','sent','skipped')),
  provider_id text,
  sent_at timestamptz,
  unique(event_id, user_id)
);
alter table email_notifications.config enable row level security;
alter table email_notifications.events enable row level security;
alter table email_notifications.deliveries enable row level security;
revoke all on all tables in schema email_notifications from public, anon, authenticated;

-- Every public RPC below is executable only by the backend service role.
create function email_notifications.require_service_role() returns void
language plpgsql set search_path = '' as $$
begin
  if (select auth.jwt()->>'role') is distinct from 'service_role' then
    raise exception 'Backend service role required' using errcode = '42501';
  end if;
end $$;

create function public.accommodation_email_enabled() returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  perform email_notifications.require_service_role();
  return exists(select 1 from email_notifications.config where enabled);
end $$;

-- Vault stores a dedicated worker credential, never a frontend key or email API key.
select vault.create_secret(
  replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  'accommodation_email_worker_key', 'Private credential for the accommodation email worker'
);

create function public.accommodation_email_worker_authorized(p_token text) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  perform email_notifications.require_service_role();
  return coalesce(length(p_token) = 64 and p_token = (
    select decrypted_secret from vault.decrypted_secrets
    where name = 'accommodation_email_worker_key' limit 1
  ), false);
end $$;

create function email_notifications.enqueue(p_key text, p_kind text, p_payload jsonb,
  p_target uuid default null) returns void
language plpgsql set search_path = '' as $$
begin
  if not exists(select 1 from email_notifications.config where enabled) then return; end if;
  insert into email_notifications.events(event_key, kind, payload, target_user_id)
  values (p_key, p_kind, p_payload, p_target) on conflict (event_key) do nothing;
end $$;

-- Private trigger function: existing RLS/business checks govern the source operation.
-- No passwords, tokens, or unrestricted request payloads are copied into the queue.
create function email_notifications.capture_event() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_kind text; v_key text; v_payload jsonb; v_target uuid;
begin
  if not exists(select 1 from email_notifications.config where enabled) then return null; end if;
  if tg_table_name = 'user_roles' then
    if new.role <> 'admin' then return null; end if;
    if tg_op = 'UPDATE' then
      if old.role = 'admin' then return null; end if;
    end if;
    v_kind := 'admin_welcome'; v_target := new.user_id;
    v_key := v_kind || ':' || new.user_id::text;
    v_payload := '{}'::jsonb;
  elsif tg_table_name = 'staff' then
    if tg_op = 'DELETE' then
      v_kind := 'staff_deleted';
      v_key := v_kind || ':' || old.id::text;
      v_payload := jsonb_build_object('staff_name', old.name, 'staff_id', old.staff_id);
    else
      if tg_op = 'INSERT' then v_kind := 'staff_created';
      elsif new.status = 'On Leave' and old.status is distinct from new.status then
        v_kind := 'leave_started';
      else return null;
      end if;
      v_key := v_kind || ':' || new.id::text;
      if v_kind = 'leave_started' then v_key := v_key || ':' || pg_current_xact_id()::text; end if;
      v_payload := jsonb_build_object('staff_name', new.name, 'staff_id', new.staff_id);
    end if;
  elsif tg_table_name = 'pending_changes' then
    if new.change_type not in ('shift_request', 'leave_request') then return null; end if;
    v_kind := case when new.change_type = 'shift_request' then 'room_shift_request' else 'leave_request' end;
    v_key := v_kind || ':' || new.id::text;
    v_payload := jsonb_build_object('staff_name', new.staff_name,
      'reason', new.payload->>'reason', 'leave_type', new.payload->>'leave_type',
      'from_date', new.payload->>'from_date', 'to_date', new.payload->>'to_date',
      'requested_location', new.payload->>'target_location_id');
  elsif tg_table_name = 'shift_history' then
    v_kind := 'room_shift_logged'; v_key := v_kind || ':' || new.id::text;
    select jsonb_build_object('staff_name', s.name, 'staff_id', s.staff_id,
      'shift_date', new.shift_date, 'reason', new.reason,
      'from_bed', (select bed_code from public.beds where id = new.from_bed_id),
      'to_bed', (select bed_code from public.beds where id = new.to_bed_id))
      into v_payload from public.staff s where s.id = new.staff_id;
    v_payload := coalesce(v_payload, jsonb_build_object('shift_date', new.shift_date, 'reason', new.reason));
  else return null;
  end if;
  perform email_notifications.enqueue(v_key, v_kind, v_payload, v_target);
  return null;
exception when others then
  -- An email queue problem must never break account, bed, or approval operations.
  raise warning 'Accommodation email enqueue failed (SQLSTATE %)', sqlstate;
  return null;
end $$;

create trigger accommodation_email_admin_created after insert or update of role
  on public.user_roles for each row execute function email_notifications.capture_event();
create trigger accommodation_email_staff_changed after insert or delete or update of status
  on public.staff for each row execute function email_notifications.capture_event();
create trigger accommodation_email_request_created after insert
  on public.pending_changes for each row execute function email_notifications.capture_event();
create trigger accommodation_email_shift_logged after insert
  on public.shift_history for each row execute function email_notifications.capture_event();

create function public.accommodation_email_claim(p_limit integer default 3)
returns setof email_notifications.events
language plpgsql security definer set search_path = '' as $$
begin
  perform email_notifications.require_service_role();
  if not exists(select 1 from email_notifications.config where enabled) then return; end if;
  update email_notifications.events set state = 'failed', lease_token = null, leased_until = null,
    last_error = 'Worker lease expired after retry limit'
    where state = 'processing' and attempts >= 8 and leased_until < now();
  return query
    with due as (
      select id from email_notifications.events
      where state in ('pending','processing') and available_at <= now()
        and (leased_until is null or leased_until < now()) and attempts < 8
      order by available_at, created_at limit greatest(1, least(p_limit, 10))
      for update skip locked
    ) update email_notifications.events e set state = 'processing', attempts = attempts + 1,
      leased_until = now() + interval '5 minutes', lease_token = gen_random_uuid()
      from due where e.id = due.id returning e.*;
end $$;

create function public.accommodation_email_prepare(p_event uuid, p_lease uuid)
returns setof email_notifications.deliveries
language plpgsql security definer set search_path = '' as $$
declare v_event email_notifications.events;
begin
  perform email_notifications.require_service_role();
  select * into v_event from email_notifications.events
    where id = p_event and lease_token = p_lease and state = 'processing' and leased_until > now();
  if not found then raise exception 'Email lease expired'; end if;
  -- Resolve recipients at delivery time: new admins are included automatically;
  -- removed admins and deleted accounts are excluded, including on retries.
  insert into email_notifications.deliveries(event_id, user_id, email, display_name)
    select p_event, r.user_id, lower(trim(u.email)), coalesce(u.raw_user_meta_data->>'display_name', '')
    from public.user_roles r join auth.users u on u.id = r.user_id
    where r.role = 'admin' and nullif(trim(u.email),'') is not null
      and (v_event.kind <> 'admin_welcome' or r.user_id = v_event.target_user_id)
    on conflict (event_id, user_id) do update set email = excluded.email,
      display_name = excluded.display_name, state = 'pending'
      where email_notifications.deliveries.state <> 'sent';
  update email_notifications.deliveries d set state = 'skipped'
    where d.event_id = p_event and d.state = 'pending' and not exists (
      select 1 from public.user_roles r join auth.users u on u.id = r.user_id
      where r.user_id = d.user_id and r.role = 'admin' and nullif(trim(u.email),'') is not null
    );
  return query select * from email_notifications.deliveries where event_id = p_event and state = 'pending';
end $$;

create function public.accommodation_email_config() returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform email_notifications.require_service_role();
  return (select to_jsonb(c) from email_notifications.config c where singleton);
end $$;

create function public.accommodation_email_ack(p_delivery uuid, p_event uuid, p_lease uuid,
  p_provider_id text default null) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform email_notifications.require_service_role();
  if not exists(select 1 from email_notifications.events
      where id = p_event and lease_token = p_lease and state = 'processing' and leased_until > now()) then
    raise exception 'Email lease expired';
  end if;
  update email_notifications.deliveries set state = 'sent', sent_at = now(), provider_id = p_provider_id
    where id = p_delivery and event_id = p_event;
end $$;

create function public.accommodation_email_finish(p_event uuid, p_lease uuid,
  p_error text default null) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform email_notifications.require_service_role();
  update email_notifications.events e set
    state = case when p_error is not null or exists(select 1 from email_notifications.deliveries d
          where d.event_id = p_event and d.state = 'pending')
      then case when attempts >= 8 then 'failed' else 'pending' end
      when not exists(select 1 from email_notifications.deliveries d where d.event_id = p_event and d.state = 'sent')
      then 'skipped' else 'sent' end,
    last_error = left(p_error, 200), lease_token = null, leased_until = null,
    available_at = now() + least(60, power(2, attempts)::integer) * interval '1 minute'
    where e.id = p_event and e.lease_token = p_lease;
end $$;

-- Suppress the legacy request-email sender only AFTER queued delivery is activated.
-- All original notification code remains in place while enabled=false.
do $$
declare v_definition text;
begin
  select pg_get_functiondef(p.oid) into v_definition from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname='public' and p.proname='fn_send_request_email' and p.pronargs=0;
  if v_definition is not null then
    v_definition := regexp_replace(v_definition, '\mBEGIN\M',
      E'BEGIN\n  IF EXISTS (SELECT 1 FROM email_notifications.config WHERE enabled) THEN RETURN NEW; END IF;\n');
    execute v_definition;
  end if;
end $$;

-- The new function authenticates this private Vault credential itself.
-- No email API key, worker credential, or service-role key is placed in app code.
create function email_notifications.dispatch() returns bigint
language plpgsql security definer set search_path = '' as $$
declare v_key text; v_request bigint;
begin
  if not exists(select 1 from email_notifications.config where enabled) then return null; end if;
  update email_notifications.events set state = 'failed', lease_token = null, leased_until = null,
    last_error = 'Worker lease expired after retry limit'
    where state = 'processing' and attempts >= 8 and leased_until < now();
  if not exists (
    select 1 from email_notifications.events where state in ('pending','processing')
      and attempts < 8 and available_at <= now() and (leased_until is null or leased_until < now())
  ) then return null; end if;
  select decrypted_secret into v_key from vault.decrypted_secrets
    where name = 'accommodation_email_worker_key' limit 1;
  select net.http_post(
    url := 'https://bhmzebuvksntosaogzet.supabase.co/functions/v1/accommodation-email-worker',
    headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' || v_key),
    body := '{}'::jsonb, timeout_milliseconds := 10000
  ) into v_request;
  return v_request;
end $$;

revoke all on all functions in schema email_notifications from public, anon, authenticated;
do $$
declare r record;
begin
  for r in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and starts_with(p.proname, 'accommodation_email_')
  loop
    execute format('revoke all on function %s from public, anon, authenticated', r.signature);
    execute format('grant execute on function %s to service_role', r.signature);
  end loop;
end $$;

create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('accommodation-email-dispatch', '* * * * *', 'select email_notifications.dispatch()');
notify pgrst, 'reload schema';

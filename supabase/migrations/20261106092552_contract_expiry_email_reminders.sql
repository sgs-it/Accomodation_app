-- Notification-only extension. Does not update contracts, rooms or approval workflows.
alter table email_notifications.events drop constraint events_kind_check;
alter table email_notifications.events add constraint events_kind_check check (kind in (
  'admin_welcome','staff_created','staff_deleted','room_shift_request',
  'leave_request','room_shift_logged','leave_started','contract_expiry_reminder'));

create function email_notifications.queue_contract_reminders() returns integer
language plpgsql security definer set search_path = '' as $$
declare v_today date := (now() at time zone 'Asia/Kolkata')::date; v_count integer;
begin
  if not exists(select 1 from email_notifications.config where enabled) then return 0; end if;
  insert into email_notifications.events(event_key,kind,payload)
    select 'contract_expiry:' || md5(jsonb_build_array(r.id,r.contract_expiry,
        coalesce(r.contract_number,''))::text) || ':' || (r.contract_expiry-v_today)::text,
      'contract_expiry_reminder', jsonb_build_object(
        'room_id',r.id,'room_number',r.room_number,
        'location_name',coalesce(l.name,r.location_id),
        'contract_number',r.contract_number,'expiry_date',r.contract_expiry,
        'days_before',r.contract_expiry-v_today)
    from public.rooms r left join public.locations l on l.id=r.location_id
    where r.contract_expiry in (v_today+10,v_today+5)
    on conflict (event_key) do nothing;
  get diagnostics v_count = row_count;
  return v_count;
end $$;
revoke all on function email_notifications.queue_contract_reminders() from public,anon,authenticated;

-- A renewal or deletion must cancel stale reminders, including pending retries.
create function email_notifications.contract_reminder_current(p_payload jsonb) returns boolean
language sql stable set search_path = '' as $$
  select exists(select 1 from public.rooms r
    where r.id::text=p_payload->>'room_id'
      and r.contract_expiry::text=p_payload->>'expiry_date'
      and coalesce(r.contract_number,'')=coalesce(p_payload->>'contract_number','')
      and r.contract_expiry >= (now() at time zone 'Asia/Kolkata')::date)
$$;
revoke all on function email_notifications.contract_reminder_current(jsonb) from public,anon,authenticated;

-- Preserve the existing admin-recipient resolution and welcome-event handling.
do $$
declare v_definition text;
  v_marker text := 'if not found then raise exception ''Email lease expired''; end if;';
begin
  v_definition := pg_get_functiondef('public.accommodation_email_prepare(uuid,uuid)'::regprocedure);
  if position(v_marker in v_definition)=0 then raise exception 'Unexpected email prepare function; refusing replacement'; end if;
  v_definition := replace(v_definition,v_marker,v_marker || E'\n' || $guard$
  if v_event.kind='contract_expiry_reminder'
      and not email_notifications.contract_reminder_current(v_event.payload) then
    update email_notifications.deliveries set state='skipped'
      where event_id=p_event and state='pending';
    return;
  end if;
  $guard$);
  execute v_definition;
end $$;

-- Cron runs in UTC: 03:30 UTC = 09:00 Asia/Kolkata. Delivery uses the existing queue.
select cron.schedule('accommodation-contract-expiry-reminders','30 3 * * *',
  'select email_notifications.queue_contract_reminders()');
notify pgrst, 'reload schema';

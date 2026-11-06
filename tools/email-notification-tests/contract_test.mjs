import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

export async function contractChecks(db) {
  const id = n => `00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
  const query = async (sql, args=[]) => (await db.query(sql,args)).rows;
  await db.exec(`create table public.locations(id text primary key,name text);
    create table public.rooms(id uuid primary key,location_id text,room_number text,
      contract_number text,contract_expiry date);
    insert into public.locations values('EAST','East & West');
    update email_notifications.config set enabled=true;`);
  await db.exec(await readFile(new URL('../../supabase/migrations/20261106092552_contract_expiry_email_reminders.sql',import.meta.url),'utf8'));
  for (const [n,days] of [10,5,9,0,-1,null,15].entries()) {
    await query(`insert into public.rooms values($1,'EAST',$2,'C123',
      case when $3::integer is null then null else (now() at time zone 'Asia/Kolkata')::date+$3 end)`,[id(800+n),`R${n}`,days]);
  }
  const before = JSON.stringify(await query('select * from public.rooms order by id'));
  assert.equal((await query('select email_notifications.queue_contract_reminders() as n'))[0].n,2);
  assert.equal((await query('select email_notifications.queue_contract_reminders() as n'))[0].n,0);
  assert.equal(JSON.stringify(await query('select * from public.rooms order by id')),before);
  const events = await query("select * from email_notifications.events where kind='contract_expiry_reminder' order by (payload->>'days_before')::integer desc");
  assert.deepEqual(events.map(e=>e.payload.days_before),[10,5]);
  assert.equal(events[0].payload.location_name,'East & West');
  const job = (await query("select * from cron.test_jobs where name='accommodation-contract-expiry-reminders'"))[0];
  assert.equal(job.schedule,'30 3 * * *');
  await query('insert into auth.users(id,email) values($1,$2)',[id(900),'existing@example.test']);
  await query("insert into public.user_roles(user_id,role) values($1,'admin')",[id(900)]);
  const lease=id(950), event=events[0];
  await query("update email_notifications.events set state='processing',lease_token=$2,leased_until=now()+interval '5 minutes' where id=$1",[event.id,lease]);
  let recipients=await query('select * from public.accommodation_email_prepare($1,$2)',[event.id,lease]);
  assert.ok(recipients.some(r=>r.user_id===id(900)));
  await query('insert into auth.users(id,email) values($1,$2)',[id(901),'future@example.test']);
  await query("insert into public.user_roles(user_id,role) values($1,'admin')",[id(901)]);
  recipients=await query('select * from public.accommodation_email_prepare($1,$2)',[event.id,lease]);
  assert.ok(recipients.some(r=>r.user_id===id(901)));
  await query("update public.user_roles set role='staff' where user_id=$1",[id(900)]);
  recipients=await query('select * from public.accommodation_email_prepare($1,$2)',[event.id,lease]);
  assert.ok(!recipients.some(r=>r.user_id===id(900)));
  await query("update public.rooms set contract_expiry=contract_expiry+30 where id=$1",[id(800)]);
  assert.equal((await query('select * from public.accommodation_email_prepare($1,$2)',[event.id,lease])).length,0);
  await query('select public.accommodation_email_finish($1,$2,null)',[event.id,lease]);
  assert.equal((await query('select state from email_notifications.events where id=$1',[event.id]))[0].state,'skipped');
  await query("update public.rooms set contract_number='RENEWED' where id=$1",[id(801)]);
  assert.equal((await query('select email_notifications.contract_reminder_current($1) as ok',[events[1].payload]))[0].ok,false);
  assert.equal((await query('select email_notifications.queue_contract_reminders() as n'))[0].n,1);
  await query('delete from public.rooms where id=$1',[id(801)]);
  assert.equal((await query('select email_notifications.contract_reminder_current($1) as ok',[events[1].payload]))[0].ok,false);
  await db.exec('update email_notifications.config set enabled=false');
  assert.equal((await query('select email_notifications.queue_contract_reminders() as n'))[0].n,0);
  assert.equal((await query("select has_function_privilege('anon','email_notifications.queue_contract_reminders()','EXECUTE') as ok"))[0].ok,false);
  await db.exec('update email_notifications.config set enabled=true');
  console.log('PASS contract reminders: exact 10/5 days, deduplication, daily schedule, unchanged contracts, current/future admins, demotion, renewal, deletion, disabled queue and private access');
}

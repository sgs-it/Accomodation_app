# Automated admin email notifications

Email automation is **enabled** in production project `bhmzebuvksntosaogzet` as of 2026-11-04.
The notification migration, `accommodation-email-worker` version 3, and the queue-routing
patch in `notify_admins` version 6 are deployed. JWT verification on `notify_admins` remains enabled.

On 2026-11-06 the worker was updated to version 4 and migration
`20261106092552_contract_expiry_email_reminders.sql` was applied for contract reminders.
Cron job `accommodation-contract-expiry-reminders` runs at 09:00 Asia/Kolkata daily
(`30 3 * * *` UTC). It queues an email per room/contract exactly 10 and 5 calendar days
before `rooms.contract_expiry`. Existing and future admins are resolved at delivery time
through the existing admin-recipient logic; no static mailing list is needed.
Each email identifies location, room, contract number, expiry date and days remaining.
The deduplication key includes the room, contract number, expiry date and threshold.
Renewed, changed or deleted contracts invalidate queued reminders before delivery.
Dates without a contract expiry, already-expired dates and other day ranges are skipped;
past reminder dates are not backfilled. Existing contract records are never updated.
Deployment verification found zero contracts due today and sent no test emails.

Live checks passed: Brevo `/v3/senders` and `/v3/account` both returned HTTP 200,
`sgsit2024@gmail.com` is verified, and the transactional relay is enabled. The authenticated
worker returned HTTP 200 with `accepted:0` for the empty queue. The minutely dispatcher is active.
No test emails or accounts were created, so actual inbox delivery has not been tested.

Supabase Edge Functions do not have stable outbound IP addresses, so authorizing one observed
IP is not a reliable ongoing solution if IP blocking is reenabled. The account owner can use a static outbound
proxy (preserves IP restrictions, requires additional infrastructure) or disabling unknown-IP
blocking for API keys in Brevo Settings > Security > Authorized IPs. The latter affects the
account's API keys and removes an extra security check; API-key authentication still applies.
Do not change that security setting automatically. SMTP blocking can remain unchanged.
See https://supabase.com/kb/troubleshooting/why-supabase-edge-functions-cannot-provide-static-egress-ips-for-whitelisting
and https://help.brevo.com/hc/en-us/articles/5740111683858-Authorize-and-block-IP-addresses-for-API-and-SMTP-security.

The key needs **Account: Read** for readiness checks and **Transactional email: All** for sending.
Brevo does not offer a Read/write level for Transactional email. Keep unrelated resources at None.
See https://help.brevo.com/hc/en-us/articles/40158277171474-About-API-key-permissions.
Never paste API keys in chat or commit them to this repository.

At activation the queue had zero events; no historical records were backfilled.
The legacy fixed-recipient email routes are bypassed while the new queue is enabled.
Existing push behavior is preserved. Staff and bed counts remained 176 and 177; shift history
remained at 13 records and the current admin count was 1. Client access to private queue
objects and anonymous access to the notification RPCs remain denied.

## Included events

| Event | Email recipients |
| --- | --- |
| First creation/promotion of an administrator account | That administrator only |
| Room-shift request submitted | All current administrators |
| Room shift recorded, including an approved request recorded in shift history | All current administrators |
| Leave request submitted | All current administrators |
| Staff marked On Leave, including approval that changes their status | All current administrators |
| Staff/supervisor account or staff record created | All current administrators |
| Staff account or record deleted, including Auth cascade deletion | All current administrators |
| Contract expiry in 10 days or 5 days | All current administrators |

Request and completion messages are separate events. Welcome emails never contain passwords.
No historical records are backfilled. Account creation does not require adding each admin to a Brevo contact list.

## Sender setup reference

1. Create a free account at https://onboarding.brevo.com/ using `sgsit2024@gmail.com`.
2. Complete Brevo's account activation and verify that address under **Senders**.
3. Create a Brevo API key with Account: Read and Transactional email: All permissions,
   and store it as `BREVO_API_KEY` in the Supabase project's
   **Edge Functions > Secrets** page:
   https://supabase.com/dashboard/project/bhmzebuvksntosaogzet/functions/secrets
   Do not put the key in chat, Flutter code, repository files, or `app_settings`.

Brevo may replace a Gmail sender with a provider-managed sending address; replies still go to the configured Gmail address.
The free plan's recipient-based allowance applies. One event sent to five administrators uses five email sends.

Official documentation:
- https://help.brevo.com/hc/en-us/articles/208836149-Create-a-new-sender-From-name-and-From-email
- https://help.brevo.com/hc/en-us/articles/14925263522578-Comply-with-Gmail-Yahoo-and-Microsoft-s-requirements-for-email-senders
- https://developers.brevo.com/docs/send-a-transactional-email

## Deployment and activation sequence

The following sequence is completed in production; retain it as a deployment reference.

1. **Already applied to production; do not reapply.** Apply only `migrations/20261104071851_automated_admin_email_notifications.sql`
   using the connected Supabase migration tool. The migration initially creates a disabled queue.
2. **Already deployed as version 3.** Deploy `functions/accommodation-email-worker` with entrypoint `index.ts`.
   Set `verify_jwt=false` for **this new worker only**: it authenticates a dedicated,
   cryptographically random Vault credential on every POST. Never disable JWT verification
   for `notify_admins`. The worker's RPCs independently require the backend service role.
3. **Already deployed as version 6; do not reapply the patch.** Retrieve the current deployed `notify_admins` source and apply
   `functions/notify_admins/queued_email.patch`. Preserve its other files, FCM credentials,
   recipient logic, and `verify_jwt=true`. This directory intentionally contains a patch,
   rather than a copy of the deployed source containing legacy credentials.
4. Verify the deployed code and the private worker authentication. Use mocked tests for
   emails; do not create/delete real staff accounts or send test messages without authorization.
   An authenticated POST with `{"check_only":true}` checks provider access, sender verification,
   and transactional activation without claiming jobs or sending emails. Require `ready:true`
   before activation. By default this returns flags and fixed error categories only.
   With `diagnostics:true`, failed provider calls also return error codes and bounded messages
   with the API key, email addresses, URLs and IPv4 addresses redacted. Successful account
   profile data is never returned. Both modes require the private worker credential.
5. **Already enabled.** Activate future events with:

   ```sql
   update email_notifications.config set enabled = true where singleton;
   ```

The existing published web, Android, and iOS apps then generate these events through their
existing database writes. They do not need new client-side notification calls or a release
for this feature. Data capture is transactional, and the worker runs approximately every minute.
Existing push notification behavior is preserved. The legacy request-email trigger and Edge
Function fallback stop sending their fixed-recipient emails only after the new queue is enabled,
preventing duplicate old/new email routes.

## What changes in the backend

- A separate private `email_notifications` schema with configuration, events, and per-recipient delivery records.
- Four notification-only triggers attached to existing account/staff/request/shift tables.
- Service-role-only RPCs, an authenticated worker, a private Vault credential, and a minutely Cron dispatcher.
- A conditional guard in the existing request-email trigger; its original code remains active while delivery is disabled.

Existing accommodation records, schema columns, role assignments, RLS policies on business tables,
bed assignment operations, and approval functions are not changed. Deletion events retain a small
name/ID snapshot so removing a staff account does not erase its unsent notification.
Only notification display fields are copied; passwords, device tokens, and unrelated payload fields are excluded.

Each recipient gets a separate email. Recipients are rechecked before delivery, so removed/demoted
admins are excluded. Successful recipients are acknowledged individually and not normally resent
when another recipient fails. Brevo receives a stable delivery UUID for its 30-minute idempotency window.
This is retryable delivery, not an unlimited exactly-once guarantee if a provider accepted an email
but its database acknowledgement was lost beyond that window.

## Monitoring and stopping delivery

```sql
-- Delivery status; no email bodies or passwords are returned.
select kind, state, count(*) from email_notifications.events group by kind, state order by kind, state;

-- Failures are retained after eight processing attempts.
select id, kind, attempts, last_error, created_at
from email_notifications.events where state = 'failed' order by created_at desc;

-- Pause new captures/claims and revert the legacy mail routes to their previous behavior.
update email_notifications.config set enabled = false where singleton;
```

An already-running worker batch can finish after pausing. Review the cause and recipient count
before manually retrying failed events; do not replay old events indiscriminately.

## Validation

28 Node checks and 32 isolated database checks passed. The new private queue tables intentionally
have RLS without client policies: access is through service-role-only RPCs. The advisor's informational
`rls_enabled_no_policy` finding therefore reflects the intended denial of direct client access.
See https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy.

```powershell
node --test supabase/functions/accommodation-email-worker/worker.test.mjs supabase/functions/notify_admins/push_message.test.mjs
npm ci --prefix tools/email-notification-tests --ignore-scripts
npm test --prefix tools/email-notification-tests
```

The SQL suite runs the migration against an isolated Postgres engine. It substitutes only Vault,
pg_net, and pg_cron with no-network stubs. It does not connect to Supabase or change production data.

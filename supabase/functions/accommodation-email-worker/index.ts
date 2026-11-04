import { createClient } from 'npm:@supabase/supabase-js@2.118.0';
import { createEmailWorker } from './worker.mjs';

declare const EdgeRuntime: { waitUntil(task: Promise<unknown>): void };

// JWT verification is replaced ONLY for this new worker by a private,
// cryptographically random Vault credential checked on every POST.
// The existing notify_admins function retains its JWT verification.
Deno.serve(createEmailWorker({
  client: createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false, autoRefreshToken: false },
  }),
  getEnv: (name: string) => Deno.env.get(name),
  waitUntil: (task: Promise<unknown>) => EdgeRuntime.waitUntil(task),
}));

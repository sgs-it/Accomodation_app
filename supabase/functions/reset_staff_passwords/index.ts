import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Fetch all staff records that have an auth_user_id
    const { data: staffList, error: staffErr } = await supabaseAdmin
      .from('staff')
      .select('id, staff_id, name, auth_user_id')
      .not('auth_user_id', 'is', null);

    if (staffErr) throw staffErr;
    if (!staffList || staffList.length === 0) {
      return new Response(JSON.stringify({ message: 'No staff records found', updated: 0 }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }

    // 2. Verify each user actually has role='staff' in user_roles (safety check to skip admins)
    const results: { name: string; staffId: string; success: boolean; error?: string }[] = [];

    for (const staff of staffList) {
      // Only reset if user_roles says 'staff'
      const { data: roleRow } = await supabaseAdmin
        .from('user_roles')
        .select('role')
        .eq('user_id', staff.auth_user_id)
        .maybeSingle();

      if (!roleRow || roleRow.role !== 'staff') {
        // Skip admins or users with no role
        results.push({ name: staff.name, staffId: staff.staff_id, success: false, error: 'Skipped (not a staff role)' });
        continue;
      }

      // Password pattern: SGS + occupant id (staff_id)
      // This naturally meets the 6-character minimum (3 + 3/4 digits)
      const newPassword = 'SGS' + staff.staff_id;

      const { error: updateErr } = await supabaseAdmin.auth.admin.updateUserById(
        staff.auth_user_id,
        { password: newPassword }
      );

      if (updateErr) {
        results.push({ name: staff.name, staffId: staff.staff_id, success: false, error: updateErr.message });
      } else {
        results.push({ name: staff.name, staffId: staff.staff_id, success: true });
      }
    }

    const successCount = results.filter(r => r.success).length;
    const failCount = results.filter(r => !r.success).length;

    return new Response(JSON.stringify({
      message: `Password reset complete. ${successCount} updated, ${failCount} skipped/failed.`,
      updated: successCount,
      skipped: failCount,
      details: results,
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });

  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});

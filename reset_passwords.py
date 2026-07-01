"""
Reset all staff passwords to their bed_code (e.g. AJB-5029-B011)
so they match the credentials list given to staff.
"""
import requests

SUPABASE_URL = 'https://bhmzebuvksntosaogzet.supabase.co'
KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJobXplYnV2a3NudG9zYW9nemV0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjQ2NTEyNSwiZXhwIjoyMDk4MDQxMTI1fQ.OF7GhwCffvFWMn4TaV8TdIkRz2u6g3AVKP2xgZOxpBs'
AH = {'apikey': KEY, 'Authorization': 'Bearer ' + KEY, 'Content-Type': 'application/json'}

# Fetch all staff with their auth_user_id and bed_code via SQL
sql = """
SELECT s.staff_id, s.name, s.auth_user_id, b.bed_code
FROM staff s
JOIN bed_assignments ba ON ba.staff_id = s.id
JOIN beds b ON b.id = ba.bed_id
WHERE s.auth_user_id IS NOT NULL
ORDER BY s.staff_id
"""

r = requests.post(
    SUPABASE_URL + '/rest/v1/rpc/exec_sql',
    headers=AH,
    json={'query': sql}
)

# Use the REST approach with select instead
r = requests.get(
    SUPABASE_URL + '/rest/v1/staff',
    headers={**AH, 'Prefer': 'return=representation'},
    params={'select': 'staff_id,name,auth_user_id,bed_assignments(beds(bed_code))',
            'auth_user_id': 'not.is.null'}
)

staff_list = r.json() if r.ok else []
print(f"Fetched {len(staff_list)} staff with auth accounts")

ok = 0
fail = 0
for s in staff_list:
    uid      = s.get('auth_user_id')
    sid      = s.get('staff_id', '')
    name     = s.get('name', '')
    
    # Extract bed_code from nested join
    assignments = s.get('bed_assignments', [])
    bed_code = None
    if assignments:
        bed = assignments[0].get('beds', {})
        if isinstance(bed, dict):
            bed_code = bed.get('bed_code')

    if not uid or not bed_code:
        print(f"  SKIP {sid} ({name}): no uid or bed_code")
        continue

    # Reset password via Supabase Admin API
    r2 = requests.put(
        f'{SUPABASE_URL}/auth/v1/admin/users/{uid}',
        headers=AH,
        json={'password': bed_code}
    )

    if r2.ok:
        ok += 1
        print(f"  OK  {sid:15} | {bed_code}")
    else:
        fail += 1
        print(f"  FAIL {sid} ({name}): {r2.status_code} {r2.text[:100]}")

print(f"\nDone: {ok} updated, {fail} failed")
print(f"\nPassword format: bed_code  e.g.  AJB-5029-B011")

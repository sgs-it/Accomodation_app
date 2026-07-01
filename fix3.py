import re, requests

SUPABASE_URL = 'https://bhmzebuvksntosaogzet.supabase.co'
KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJobXplYnV2a3NudG9zYW9nemV0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjQ2NTEyNSwiZXhwIjoyMDk4MDQxMTI1fQ.OF7GhwCffvFWMn4TaV8TdIkRz2u6g3AVKP2xgZOxpBs'
AH = {'apikey': KEY, 'Authorization': 'Bearer ' + KEY, 'Content-Type': 'application/json'}

# Fetch staff with no auth_user_id
r = requests.get(
    SUPABASE_URL + '/rest/v1/staff',
    headers=dict(**AH, Prefer='return=representation'),
    params={'select': 'id,staff_id,name,auth_user_id', 'auth_user_id': 'is.null'}
)
missing = r.json()
print('Staff missing auth:', len(missing))

for s in missing:
    sid   = s['staff_id']
    name  = s['name']
    svid  = s['id']
    clean = re.sub(r'[^A-Za-z0-9]', '', sid)
    email = clean + '@staff.sgs.com'

    cr = requests.post(
        SUPABASE_URL + '/auth/v1/admin/users', headers=AH,
        json={'email': email, 'password': sid, 'email_confirm': True,
              'user_metadata': {'display_name': name}}
    )
    if cr.ok:
        uid = cr.json().get('id')
        requests.patch(
            SUPABASE_URL + '/rest/v1/staff',
            headers=dict(**AH, Prefer='return=representation'),
            params={'id': 'eq.' + svid},
            json={'auth_user_id': uid}
        )
        h2 = dict(**AH, Prefer='resolution=merge-duplicates,return=representation')
        requests.post(
            SUPABASE_URL + '/rest/v1/user_roles', headers=h2,
            json={'user_id': uid, 'role': 'staff'},
            params={'on_conflict': 'user_id'}
        )
        print('  Fixed:', sid, '->', email)
    else:
        print('  FAIL', email, cr.status_code, cr.text[:100])

# Final tally
r2 = requests.get(
    SUPABASE_URL + '/rest/v1/user_roles',
    headers=dict(**AH, Prefer='return=representation'),
    params={'role': 'eq.staff', 'select': 'user_id'}
)
print('\nTotal staff roles in DB:', len(r2.json()))

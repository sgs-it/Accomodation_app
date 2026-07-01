import pandas as pd
import requests
import json

SUPABASE_URL = 'https://bhmzebuvksntosaogzet.supabase.co'
KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJobXplYnV2a3NudG9zYW9nemV0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjQ2NTEyNSwiZXhwIjoyMDk4MDQxMTI1fQ.OF7GhwCffvFWMn4TaV8TdIkRz2u6g3AVKP2xgZOxpBs'
AH = {'apikey': KEY, 'Authorization': 'Bearer ' + KEY, 'Content-Type': 'application/json'}

# 1. Read Excel
print("Reading Excel...")
df = pd.read_excel(r'c:\Users\HP\Downloads\Staff_app\Updated staff accomodation.xlsx', sheet_name='Sheet2')

# Map occupant ID (string) to bed ID
# The dataframe columns: 'Bed ID', 'Occupant Name', 'Occupant ID', 'Location', 'Status'
excel_map = {}
for idx, row in df.iterrows():
    occ_id = str(row['Occupant ID']).strip()
    bed_id = str(row['Bed ID']).strip()
    if occ_id and occ_id != 'nan':
        excel_map[occ_id] = bed_id

print(f"Found {len(excel_map)} occupants in Excel.")

# 2. Fetch all staff with auth_user_id from Supabase
print("Fetching staff from Supabase...")
r = requests.get(
    SUPABASE_URL + '/rest/v1/staff',
    headers={**AH, 'Prefer': 'return=representation'},
    params={'select': 'staff_id,name,auth_user_id', 'auth_user_id': 'not.is.null'}
)
staff_list = r.json() if r.ok else []
print(f"Fetched {len(staff_list)} staff with auth accounts.")

# 3. Update passwords
ok = 0
fail = 0
for s in staff_list:
    uid = s.get('auth_user_id')
    sid = str(s.get('staff_id', '')).strip()
    name = s.get('name', '')
    
    # Try exact match
    new_bed_id = excel_map.get(sid)
    
    if not new_bed_id:
        print(f"  SKIP {sid} ({name}): no matching bed ID found in Excel")
        continue

    # Reset password via Supabase Admin API
    r2 = requests.put(
        f'{SUPABASE_URL}/auth/v1/admin/users/{uid}',
        headers=AH,
        json={'password': new_bed_id}
    )

    if r2.ok:
        ok += 1
        print(f"  OK  {sid:15} | updated password to: {new_bed_id}")
    else:
        fail += 1
        print(f"  FAIL {sid} ({name}): {r2.status_code} {r2.text[:100]}")

print(f"\nDone: {ok} updated, {fail} failed")

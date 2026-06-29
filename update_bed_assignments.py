import pandas as pd
import requests
import re

SUPABASE_URL = "https://bhmzebuvksntosaogzet.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJobXplYnV2a3NudG9zYW9nemV0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjQ2NTEyNSwiZXhwIjoyMDk4MDQxMTI1fQ.OF7GhwCffvFWMn4TaV8TdIkRz2u6g3AVKP2xgZOxpBs"
AH = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

LOC_MAP = {'R1': 'AQZ', 'R2': 'SNP', 'R3': 'JBL', 'R4': 'MSF', 'R5': 'AJB'}
def to_bed_code(raw):
    raw = str(raw).strip()
    if '-' not in raw: return None
    room_part, bed_part = raw.split('-')
    loc_prefix = room_part[:2]
    room_num = room_part[1:]
    return f'{LOC_MAP.get(loc_prefix)}-{room_num}-B{bed_part.zfill(3)}'

print("Reading Excel...")
df = pd.read_excel(r'c:\Users\HP\Downloads\Staff_app\Updated staff accomodation.xlsx', sheet_name='Sheet2')

excel_map = {}
for idx, row in df.iterrows():
    occ_id = str(row['Occupant ID']).strip()
    bed_id = str(row['Bed ID']).strip()
    if occ_id and occ_id != 'nan':
        bcode = to_bed_code(bed_id)
        if bcode:
            excel_map[occ_id] = bcode

# 1. Fetch beds
r = requests.get(SUPABASE_URL + '/rest/v1/beds?select=id,bed_code', headers=AH)
beds = r.json()
bed_uuid_map = {b['bed_code']: b['id'] for b in beds}

# 2. Fetch staff
r2 = requests.get(SUPABASE_URL + '/rest/v1/staff?select=id,staff_id', headers=AH)
staff = r2.json()
staff_uuid_map = {s['staff_id']: s['id'] for s in staff}

# 3. Fetch bed_assignments
r3 = requests.get(SUPABASE_URL + '/rest/v1/bed_assignments?select=id,staff_id,bed_id', headers=AH)
assignments = r3.json()
assignment_by_staff = {a['staff_id']: a for a in assignments}

print("Updating bed assignments...")
ok = 0
fail = 0

for staff_id_str, new_bed_code in excel_map.items():
    staff_uuid = staff_uuid_map.get(staff_id_str)
    bed_uuid = bed_uuid_map.get(new_bed_code)
    
    if not staff_uuid or not bed_uuid:
        print(f"  SKIP {staff_id_str} -> {new_bed_code} (Staff UUID missing? {not staff_uuid}, Bed UUID missing? {not bed_uuid})")
        continue
        
    existing = assignment_by_staff.get(staff_uuid)
    if existing:
        if existing['bed_id'] == bed_uuid:
            continue
        r4 = requests.patch(
            f"{SUPABASE_URL}/rest/v1/bed_assignments?id=eq.{existing['id']}",
            headers=AH,
            json={"bed_id": bed_uuid}
        )
        if r4.ok: ok += 1
        else: fail += 1
    else:
        r4 = requests.post(
            f"{SUPABASE_URL}/rest/v1/bed_assignments",
            headers=AH,
            json={"staff_id": staff_uuid, "bed_id": bed_uuid}
        )
        if r4.ok: ok += 1
        else: fail += 1

print(f"Done. Updated {ok}, failed {fail}")

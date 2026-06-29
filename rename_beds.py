import requests
import re

SUPABASE_URL = "https://bhmzebuvksntosaogzet.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJobXplYnV2a3NudG9zYW9nemV0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjQ2NTEyNSwiZXhwIjoyMDk4MDQxMTI1fQ.OF7GhwCffvFWMn4TaV8TdIkRz2u6g3AVKP2xgZOxpBs"
AH = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

REV_MAP = {'AQZ': 'R1', 'SNP': 'R2', 'JBL': 'R3', 'MSF': 'R4', 'AJB': 'R5'}
def reverse_bed_code(bcode):
    m = re.match(r'^([A-Z]{3})-(\d{4})-B(\d{3})$', bcode)
    if not m: return bcode
    loc, rnum, bnum = m.groups()
    prefix = REV_MAP.get(loc)
    if not prefix: return bcode
    return f'{prefix}{rnum[1:]}-{bnum}'

print("Fetching all beds...")
r = requests.get(f"{SUPABASE_URL}/rest/v1/beds?select=id,bed_code", headers=AH)
beds = r.json()
print(f"Found {len(beds)} beds.")

ok = 0
fail = 0

for bed in beds:
    old_code = bed['bed_code']
    new_code = reverse_bed_code(old_code)
    
    if old_code == new_code:
        continue # Already formatted or unable to format
        
    r2 = requests.patch(
        f"{SUPABASE_URL}/rest/v1/beds?id=eq.{bed['id']}",
        headers=AH,
        json={"bed_code": new_code}
    )
    if r2.ok:
        ok += 1
    else:
        fail += 1
        print(f"FAIL updating {old_code} to {new_code}: {r2.text}")

print(f"Done. Updated {ok}, failed {fail}")

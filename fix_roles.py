"""
Fix-up script:
1. Creates auth accounts for staff whose IDs had spaces (e.g. LS 6073)
2. Inserts user_roles=staff for ALL staff who have auth_user_id set
3. Re-runs user_roles insert for all existing auth users missing a role
"""
import sys
import re
import requests

SUPABASE_URL = "https://bhmzebuvksntosaogzet.supabase.co"
SERVICE_KEY  = sys.argv[1].strip()

AH = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

def upsert(table, data, on_conflict):
    h = {**AH, "Prefer": "resolution=merge-duplicates,return=representation"}
    r = requests.post(f"{SUPABASE_URL}/rest/v1/{table}", headers=h,
                      json=data, params={"on_conflict": on_conflict})
    if not r.ok:
        print(f"  WARN upsert {table}: {r.status_code} {r.text[:150]}")
        return None
    rows = r.json()
    return rows[0] if rows else None

def create_auth_user(email, password, display_name):
    r = requests.post(f"{SUPABASE_URL}/auth/v1/admin/users", headers=AH,
        json={"email": email, "password": password, "email_confirm": True,
              "user_metadata": {"display_name": display_name}})
    if r.ok:
        return r.json().get("id")
    if r.status_code in (400, 422):
        r2 = requests.get(f"{SUPABASE_URL}/auth/v1/admin/users",
                          headers=AH, params={"email": email})
        if r2.ok:
            for u in r2.json().get("users", []):
                if u.get("email", "").lower() == email.lower():
                    return u["id"]
    print(f"  WARN auth {email}: {r.status_code} {r.text[:100]}")
    return None

def sanitize_email_prefix(staff_id):
    """Convert 'LS 6073' -> 'LS6073', '1325' -> '1325'"""
    return re.sub(r'\s+', '', staff_id)

# 1. Fetch ALL staff from DB
print("Fetching all staff...")
r = requests.get(f"{SUPABASE_URL}/rest/v1/staff",
    headers={**AH, "Prefer": "return=representation"},
    params={"select": "id,staff_id,name,auth_user_id"})
staff_list = r.json() if r.ok else []
print(f"  Found {len(staff_list)} staff records")

fixed_auth = 0
fixed_roles = 0

for s in staff_list:
    staff_uuid = s["id"]
    staff_id   = s.get("staff_id", "")
    name       = s.get("name", "")
    auth_uid   = s.get("auth_user_id")

    # 2. If no auth_user_id, create the account now (sanitize email)
    if not auth_uid:
        safe_id  = sanitize_email_prefix(staff_id)
        email    = f"{safe_id}@staff.sgs.com"
        # We need the bed_id as password — use staff_id as fallback
        password = staff_id  # staff can reset via admin
        auth_uid = create_auth_user(email, password, name)
        if auth_uid:
            # Update staff record
            requests.patch(
                f"{SUPABASE_URL}/rest/v1/staff",
                headers={**AH, "Prefer": "return=representation"},
                params={"id": f"eq.{staff_uuid}"},
                json={"auth_user_id": auth_uid}
            )
            print(f"  Created auth: {email}")
            fixed_auth += 1

    # 3. Ensure user_roles row exists
    if auth_uid:
        row = upsert("user_roles", {"user_id": auth_uid, "role": "staff"}, "user_id")
        if row:
            fixed_roles += 1

print(f"\nFix complete:")
print(f"  Auth accounts created : {fixed_auth}")
print(f"  Roles assigned        : {fixed_roles}")

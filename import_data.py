"""
Staff Accommodation Excel -> Supabase Import Script (FINAL)
============================================================
Actual DB schema:
  locations:       id (text=code), name, manager_name
  rooms:           id, room_code (text, UNIQUE NOT NULL e.g. 'AQZ-006'),
                   location_id (text), room_number (text, UNIQUE), capacity,
                   contract_expiry, contract_room_no, managed_by, emirate
  beds:            id, room_id (uuid), bed_code (text UNIQUE e.g. 'AQZ-006-B001'),
                   bed_number (int), position (LB/UB/MB/SB), status
  staff:           id, staff_id (text, UNIQUE), name, status, phone, nationality, auth_user_id
  bed_assignments: id, bed_id (UNIQUE), staff_id, assigned_at
  user_roles:      user_id, role
"""

import re
import sys
import requests
import pandas as pd

# ─── CONFIG ──────────────────────────────────────────────────────────────────
SUPABASE_URL = "https://bhmzebuvksntosaogzet.supabase.co"
if len(sys.argv) < 2:
    print("Usage: python import_data.py <SERVICE_ROLE_KEY>")
    sys.exit(1)
SERVICE_KEY = sys.argv[1].strip()
EXCEL_PATH  = r"c:\Users\HP\Downloads\Staff_app\Staff Accomodation Plan.xlsx"

AH = {  # auth headers
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

# ─── LOCATION MAP ────────────────────────────────────────────────────────────
LOC_MAP = {
    "R1": {"code": "AQZ", "name": "Al Quoz",   "emirate": "Dubai"},
    "R2": {"code": "SNP", "name": "Sonapur",   "emirate": "Dubai"},
    "R3": {"code": "JBL", "name": "Jebel Ali", "emirate": "Dubai"},
    "R4": {"code": "MSF", "name": "Musaffah",  "emirate": "Abu Dhabi"},
    "R5": {"code": "AJB", "name": "Ajbaan",    "emirate": "Abu Dhabi"},
}

# ─── HELPERS ─────────────────────────────────────────────────────────────────
def upsert(table, data, on_conflict):
    h = {**AH, "Prefer": "resolution=merge-duplicates,return=representation"}
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/{table}",
        headers=h, json=data,
        params={"on_conflict": on_conflict},
    )
    if not r.ok:
        print(f"  WARN upsert {table}: {r.status_code} {r.text[:200]}")
        return None
    rows = r.json()
    return rows[0] if rows else None

def patch(table, filter_qs, data):
    r = requests.patch(
        f"{SUPABASE_URL}/rest/v1/{table}",
        headers={**AH, "Prefer": "return=representation"},
        params=filter_qs, json=data,
    )
    return r.ok

def create_auth_user(email, password, display_name):
    r = requests.post(
        f"{SUPABASE_URL}/auth/v1/admin/users",
        headers=AH,
        json={"email": email, "password": password,
              "email_confirm": True,
              "user_metadata": {"display_name": display_name}},
    )
    if r.ok:
        return r.json().get("id")
    # Already exists - find by listing users
    if r.status_code in (400, 422):
        r2 = requests.get(f"{SUPABASE_URL}/auth/v1/admin/users",
                          headers=AH, params={"email": email})
        if r2.ok:
            for u in r2.json().get("users", []):
                if u.get("email", "").lower() == email.lower():
                    return u["id"]
    print(f"  WARN auth user {email}: {r.status_code} {r.text[:150]}")
    return None

def parse_position(loc_str):
    u = (loc_str or "").upper()
    if u.endswith("-UB") or "-UB-" in u: return "UB"
    if u.endswith("-MB") or "-MB-" in u: return "MB"
    if u.endswith("-SB") or "-SB-" in u: return "SB"
    return "LB"

def norm_status(s):
    s = (s or "").strip().upper()
    if s in ("FULL", "OCCUPIED"):          return "FULL"
    if s in ("VACATION", "LEAVE"):         return "VACATION"
    if s == "MAINTENANCE":                 return "MAINTENANCE"
    return "VACANT"

def safe_int(v):
    try: return int(str(v).strip())
    except: return None

def room_code_from(loc_code, room_id_raw):
    """Generate room_code like AQZ-006 from loc_code=AQZ and room_id=R1006"""
    # Extract last 3 digits of room_id_raw e.g. R1006 -> 006
    m = re.search(r'(\d+)$', room_id_raw)
    num = m.group(1).zfill(3) if m else "000"
    return f"{loc_code}-{num}"

def bed_code_from(room_code, bed_num_int):
    """Generate bed_code like AQZ-006-B001"""
    return f"{room_code}-B{str(bed_num_int).zfill(3)}"

# ─── LOAD EXCEL ──────────────────────────────────────────────────────────────
print("\nLoading Excel...")
xl = pd.ExcelFile(EXCEL_PATH)

# Parse Summary for metadata
summary_df = xl.parse("Summary", header=None)
room_meta = {}
for _, row in summary_df.iterrows():
    rid = str(row.iloc[0]).strip()
    if not re.match(r'^R\d{4}$', rid):
        continue
    expiry = None
    raw_e = row.iloc[4]
    if not pd.isna(raw_e) and hasattr(raw_e, 'date'):
        expiry = raw_e.date().isoformat()
    room_meta[rid] = {
        "contract_room_no": str(row.iloc[2]).strip() if not pd.isna(row.iloc[2]) else None,
        "emirate":          str(row.iloc[3]).strip() if not pd.isna(row.iloc[3]) else None,
        "capacity":         safe_int(row.iloc[6]) or 4,
        "managed_by":       str(row.iloc[9]).strip() if not pd.isna(row.iloc[9]) else None,
        "contract_expiry":  expiry,
    }
print(f"  Summary: {len(room_meta)} rooms")

# ─── STEP 1: LOCATIONS ───────────────────────────────────────────────────────
print("\nUpserting locations...")
loc_uuid_map = {}  # code -> id (which is same as code for locations)
for prefix, info in LOC_MAP.items():
    row = upsert("locations", {"id": info["code"], "name": info["name"]}, "id")
    if row:
        loc_uuid_map[info["code"]] = row["id"]
        print(f"  OK {info['code']} -> {info['name']}")

# ─── STEP 2: ROOM SHEETS ─────────────────────────────────────────────────────
room_sheets = [s for s in xl.sheet_names if s.lower().startswith("room ")]
print(f"\nProcessing {len(room_sheets)} room sheets...")

total_beds = total_staff = 0
errors = []

for sheet_name in room_sheets:
    df = xl.parse(sheet_name, header=None)
    if df.shape[0] < 3:
        continue

    # Detect room_id from Bed IDs (e.g. R2026-053 -> R2026)
    room_id_raw = None
    for i in range(len(df)):
        val = str(df.iloc[i, 0]).strip()
        m = re.match(r'^(R\d{4})-\d+', val)
        if m:
            room_id_raw = m.group(1)
            break
    if not room_id_raw:
        print(f"  SKIP {sheet_name}: no room ID found")
        continue

    loc_prefix = room_id_raw[:2]
    loc_info   = LOC_MAP.get(loc_prefix)
    if not loc_info:
        print(f"  SKIP {sheet_name}: unknown prefix {loc_prefix}")
        continue

    loc_code = loc_info["code"]
    if loc_code not in loc_uuid_map:
        print(f"  SKIP {sheet_name}: location {loc_code} not upserted")
        continue

    meta             = room_meta.get(room_id_raw, {})
    contract_room_no = meta.get("contract_room_no")
    capacity         = meta.get("capacity", 4)
    managed_by       = meta.get("managed_by")
    emirate          = meta.get("emirate") or loc_info["emirate"]
    contract_expiry  = meta.get("contract_expiry")
    rcode            = room_code_from(loc_code, room_id_raw)  # e.g. AQZ-001

    # Fallback: parse contract_room_no from sheet header
    if not contract_room_no:
        for cell in df.iloc[0].tolist():
            if isinstance(cell, str):
                m2 = re.search(r'room\s*no[.:\s]+([A-Za-z0-9\-]+)', cell, re.IGNORECASE)
                if m2:
                    contract_room_no = m2.group(1).strip()
                    break

    room_payload = {
        "room_code":        rcode,
        "location_id":      loc_code,
        "room_number":      room_id_raw,
        "capacity":         capacity,
        "contract_room_no": contract_room_no,
        "managed_by":       managed_by,
        "emirate":          emirate,
    }
    if contract_expiry:
        room_payload["contract_expiry"] = contract_expiry

    room_row = upsert("rooms", room_payload, "room_number")
    if not room_row:
        print(f"  FAIL {sheet_name}: room upsert failed")
        continue
    room_uuid = room_row["id"]

    # Find first data row
    data_start = None
    for idx in range(len(df)):
        if re.match(r'^R\d{4}-\d+', str(df.iloc[idx, 0]).strip()):
            data_start = idx
            break
    if data_start is None:
        continue

    for idx in range(data_start, len(df)):
        row       = df.iloc[idx]
        bid_str   = str(row.iloc[0]).strip() if not pd.isna(row.iloc[0]) else ""
        if not re.match(r'^R\d{4}-', bid_str):
            continue

        occ_name  = str(row.iloc[1]).strip() if not pd.isna(row.iloc[1]) else ""
        occ_id    = str(row.iloc[2]).strip() if not pd.isna(row.iloc[2]) else ""
        loc_str   = str(row.iloc[3]).strip() if not pd.isna(row.iloc[3]) else ""
        stat_str  = str(row.iloc[4]).strip() if not pd.isna(row.iloc[4]) else ""
        col5      = str(row.iloc[5]).strip() if df.shape[1] > 5 and not pd.isna(row.iloc[5]) else ""

        bed_status   = norm_status(stat_str)
        bed_position = parse_position(loc_str)

        m_bed       = re.search(r'-(\d+)$', bid_str)
        bed_num_int = safe_int(m_bed.group(1)) if m_bed else 1
        bcode       = bed_code_from(rcode, bed_num_int)

        bed_row = upsert("beds", {
            "room_id":    room_uuid,
            "bed_code":   bcode,
            "bed_number": bed_num_int,
            "position":   bed_position,
            "status":     bed_status,
        }, "bed_code")

        if not bed_row:
            errors.append(f"Bed fail: {bid_str}")
            continue
        bed_uuid = bed_row["id"]
        total_beds += 1

        # Skip if vacant or no occupant
        if (bed_status == "VACANT"
                or not occ_name or occ_name.lower() in ("nan","none","")
                or not occ_id   or occ_id.lower()   in ("nan","none","")):
            continue

        staff_status = "On Leave" if (bed_status == "VACATION" or col5.upper() == "VACATION") else "Active"

        staff_row = upsert("staff", {
            "staff_id":    occ_id,
            "name":        occ_name,
            "status":      staff_status,
            "nationality": "Unknown",
        }, "staff_id")

        if not staff_row:
            errors.append(f"Staff fail: {occ_name} ({occ_id})")
            continue
        staff_uuid = staff_row["id"]
        total_staff += 1

        # Create auth account
        email    = f"{occ_id}@staff.sgs.com"
        password = bid_str
        auth_uid = create_auth_user(email, password, occ_name)
        if auth_uid:
            upsert("user_roles", {"user_id": auth_uid, "role": "staff"}, "user_id")
            patch("staff", {"id": f"eq.{staff_uuid}"}, {"auth_user_id": auth_uid})

        # Bed assignment (bed_id is unique — one staff per bed)
        upsert("bed_assignments", {
            "bed_id":   bed_uuid,
            "staff_id": staff_uuid,
        }, "bed_id")

    print(f"  OK {sheet_name} -> {room_id_raw} / {rcode} (Room {contract_room_no}, {managed_by})")

# ─── SUMMARY ─────────────────────────────────────────────────────────────────
print(f"\n{'='*55}")
print(f"IMPORT COMPLETE")
print(f"{'='*55}")
print(f"  Room sheets : {len(room_sheets)}")
print(f"  Beds        : {total_beds}")
print(f"  Staff       : {total_staff}")
if errors:
    print(f"\n  Errors ({len(errors)}):")
    for e in errors: print(f"    - {e}")
print(f"\nStaff login: occupant_id as username / bed_id as password")
print(f"  e.g.  1325  /  R2026-053")

# 🏠 Staff Accommodation Management App

> A Flutter + Supabase mobile application to fully automate staff accommodation planning — replacing manual CSV spreadsheets with a real-time, role-based digital system.

---

## 📱 App Overview

The **Staff Accommodation App** manages accommodation for staff across multiple locations (Sonapur, Al Quoz, Jebel Ali, DIP, etc.). It tracks every room, every bed, and every staff member — with live status updates, leave tracking, and a full shift-transfer log.

---

## ✨ Key Features

| Module | Description |
|---|---|
| 📊 **Admin Dashboard** | Live summary — Total Beds, Occupied, Vacant, On Leave per location with occupancy bar charts |
| 🏠 **Room Management** | Add/view rooms per location. Contract expiry warnings highlighted in amber |
| 🛏️ **Bed Management** | Visual 2-column bed grid (Lower Bed / Upper Bed / Single Bed). Color-coded by status |
| 👷 **Staff Directory** | Searchable list with tabs (All / Active / On Leave). Add staff with ID, name, nationality, phone |
| 👤 **Staff Profile** | View current bed assignment, full shift history, and status |
| ✈️ **Leave Tracker** | See all staff currently on leave. Admin can mark them as Returned (auto-restores bed) |
| 🔄 **Shift History** | Full chronological log of every room transfer — staff, from-bed, to-bed, date, reason |
| 👥 **User Management** | Admin creates Viewer accounts (email + password) from within the app |

---

## 🔐 Role System

| Action | Admin | Viewer |
|---|---|---|
| View all data | ✅ | ✅ |
| Add locations | ✅ | ✅ |
| Add rooms & beds | ✅ | ✅ |
| Add staff members | ✅ | ✅ |
| Assign staff to beds | ✅ | ✅ |
| Log room shifts | ✅ | ✅ |
| Edit / Update any record | ✅ | ❌ |
| Delete any record | ✅ | ❌ |
| Mark on leave / returned | ✅ | ❌ |
| Create Viewer accounts | ✅ | ❌ |

> **Rule:** Viewers can enter data for the first time. Only Admins can change or delete existing data.

---

## 🗄️ Database Schema (Supabase)

**Project URL:** `https://bhmzebuvksntosaogzet.supabase.co`

| Table | Purpose |
|---|---|
| `locations` | Camps — Al Quoz (AQZ), Sonapur (SNP), Jebel Ali (JBL), etc. |
| `rooms` | Rooms per location with capacity and contract expiry date |
| `beds` | Individual beds (LB = Lower Bed, UB = Upper Bed, SB = Single Bed) |
| `staff` | Staff members with ID, name, nationality, phone, status |
| `bed_assignments` | Current occupant per bed (one active assignment per bed) |
| `shift_history` | Log of every room/bed transfer |
| `user_roles` | Admin / Viewer role per authenticated user |

---

## 🔧 Tech Stack

| Layer | Technology |
|---|---|
| Mobile Framework | Flutter 3.x (Android + iOS) |
| Backend | Supabase (PostgreSQL + Auth + Row-Level Security) |
| Navigation | go_router |
| State Management | Provider |
| UI / Typography | Google Fonts — Inter |
| Charts | fl_chart |
| Loading Skeletons | shimmer |

---

## 🚀 How to Run the App

### Prerequisites

Make sure you have the following installed:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.12 or later)
- Android Studio or VS Code with Flutter extension
- Android device with **USB Debugging enabled**, or an emulator

---

### Step 1 — Open the Project

```bash
cd C:\Users\HP\Downloads\Staff_app
```

---

### Step 2 — Install Dependencies

```bash
flutter pub get
```

---

### Step 3 — Connect Your Android Device

1. Enable **Developer Options** on your phone:
   - Go to `Settings → About Phone`
   - Tap **Build Number** 7 times
2. Enable **USB Debugging**:
   - Go to `Settings → Developer Options → USB Debugging` → ON
3. Connect via USB cable
4. Verify connection:
   ```bash
   flutter devices
   ```
   You should see your device listed (e.g. `SM G781B`)

---

### Step 4 — Run in Debug Mode (USB required)

```bash
flutter run
```

Or target your specific device:

```bash
flutter run -d RFCRA17HJNH
```

**Useful hot-reload commands while the app is running:**

| Key | Action |
|---|---|
| `r` | Hot reload (instant UI refresh) |
| `R` | Hot restart (full restart) |
| `q` | Quit / stop the app |
| `d` | Detach (leave app running, free terminal) |

---

### Step 5 — Build a Standalone APK (install without PC)

```bash
flutter build apk --release
```

The APK will be saved at:
```
build\app\outputs\flutter-apk\app-release.apk
```

**Install directly on connected device:**
```bash
flutter install
```

Or copy the APK file to your phone and tap it to install manually.

---

### Step 6 — Build for iOS (Mac required)

```bash
flutter build ios --release
```

---

## 🔑 First-Time Admin Setup (Do This Before Logging In)

The app requires at least one **Admin account** in Supabase before you can log in.

### Step 1 — Create a User in Supabase

1. Open: `https://supabase.com/dashboard/project/bhmzebuvksntosaogzet/auth/users`
2. Click **"Add user"** → **"Create new user"**
3. Enter your **Email** and **Password**
4. ✅ Check **"Auto Confirm User"**
5. Click **"Create User"**

### Step 2 — Copy the User UUID

- Click on the newly created user in the list
- Copy their **UUID** (format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)

### Step 3 — Grant Admin Role via SQL

1. Open: `https://supabase.com/dashboard/project/bhmzebuvksntosaogzet/sql/new`
2. Paste and run this SQL (replace with your actual UUID):

```sql
INSERT INTO public.user_roles (user_id, role)
VALUES ('YOUR-USER-UUID-HERE', 'admin');
```

3. Click **"Run"** ✅

### Step 4 — Log In to the App

Open the app → enter your email and password → tap **Sign In**.
You will see the **"Admin — Full Access"** badge on the Dashboard.

---

## 📲 First Use — How to Add Data

Once logged in as Admin, follow this order:

```
1. Dashboard  →  tap "Add"  →  create a Location (e.g. Code: AQZ, Name: Al Quoz)
2. Tap location card  →  tap "+"  →  add a Room (number, capacity, contract expiry)
3. Tap room  →  tap "+"  →  add Beds (bed number + position: LB / UB / SB)
4. Staff tab  →  tap "+"  →  add Staff (ID, name, nationality, phone)
5. Go back to Room Detail  →  tap a VACANT bed  →  "Assign Staff"  →  select staff
```

---

## 📁 Project File Structure

```
Staff_app/
├── lib/
│   ├── main.dart                    # Entry point — Supabase init + runApp
│   ├── app.dart                     # GoRouter routes + ChangeNotifierProvider
│   │
│   ├── core/
│   │   ├── constants.dart           # Supabase URL, anon key, bed positions, statuses
│   │   └── theme.dart               # Premium dark theme, color palette, Inter font
│   │
│   ├── models/                      # Data models (fromJson / toJson)
│   │   ├── location.dart
│   │   ├── room.dart
│   │   ├── bed.dart
│   │   ├── staff.dart
│   │   └── shift_history.dart
│   │
│   ├── services/                    # All Supabase CRUD operations
│   │   ├── auth_service.dart        # Sign in, sign out, create viewer, get role
│   │   ├── location_service.dart    # Location CRUD + bed stats aggregation
│   │   ├── room_service.dart        # Room CRUD + occupancy count
│   │   ├── bed_service.dart         # Bed CRUD + assign/remove staff
│   │   ├── staff_service.dart       # Staff CRUD + mark on leave/returned
│   │   └── shift_service.dart       # Shift history CRUD + log shift
│   │
│   ├── providers/
│   │   └── app_provider.dart        # Global state — all services, role, summaries
│   │
│   ├── widgets/                     # Shared reusable UI components
│   │   ├── stat_card.dart           # Dashboard stat number card
│   │   ├── bed_tile.dart            # Color-coded bed card for the grid
│   │   └── loading_skeleton.dart    # Shimmer skeleton loaders
│   │
│   └── screens/
│       ├── splash/                  # Animated logo splash + auth routing
│       ├── auth/                    # Email/password login screen
│       ├── dashboard/               # Stats grid + per-location cards
│       ├── rooms/                   # Room list + room detail with bed grid
│       ├── staff/                   # Staff directory + staff profile
│       ├── leave/                   # Staff on leave + mark returned
│       ├── shifts/                  # Shift history log + add shift
│       ├── users/                   # Admin creates viewer accounts
│       └── shell/                   # Bottom navigation bar shell
│
├── assets/
│   └── images/                      # App image assets
│
├── pubspec.yaml                     # Dependencies
└── README.md                        # This file
```

---

## 🐛 Troubleshooting

| Problem | Solution |
|---|---|
| `flutter devices` shows nothing | Enable USB Debugging; try a different USB cable |
| App crashes on launch | Verify Supabase URL and key in `lib/core/constants.dart` |
| Login fails with error | Make sure admin user was created AND UUID inserted into `user_roles` table |
| Cannot edit data | Only Admins can edit — log in with your admin account |
| Beds show wrong status | Pull down to refresh on any screen |
| `flutter pub get` fails | Run `flutter doctor` and fix any issues shown |
| APK won't install on phone | Enable "Install from unknown sources" in phone settings |

---

## 🌐 Supabase Dashboard Links

| Page | URL |
|---|---|
| Auth Users | `https://supabase.com/dashboard/project/bhmzebuvksntosaogzet/auth/users` |
| SQL Editor | `https://supabase.com/dashboard/project/bhmzebuvksntosaogzet/sql/new` |
| Table Editor | `https://supabase.com/dashboard/project/bhmzebuvksntosaogzet/editor` |
| Logs | `https://supabase.com/dashboard/project/bhmzebuvksntosaogzet/logs/edge-logs` |

---

*Staff Accommodation Management System — Built with Flutter & Supabase*

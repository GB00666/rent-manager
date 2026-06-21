# Rent Manager (Flutter + Supabase — Android, iOS, Web)

A landlord rent-collection app — dashboard, tenant list with dues, reports, and profile/settings. One shared Supabase backend across all three platforms, so a landlord's data is the same and stays in sync whether they're on their phone, an iPhone, or the web.

## What's included

```
lib/
  main.dart                     # App entry, Supabase init (put your URL/key here)
  models/
    landlord.dart
    tenant.dart
    rent_payment.dart
  services/
    rent_service.dart           # All Supabase queries (CRUD, auth, summaries)
  screens/
    auth_gate.dart               # Routes to sign-in or app based on session
    sign_in_screen.dart          # Email/password + "Continue as Guest"
    root_shell.dart              # Bottom nav (Home / Tenants / Reports / Profile)
    home_screen.dart             # Collection card, quick actions, recent logs
    tenants_screen.dart          # Search, All/Paid/Pending filters, Remind/Collect
    add_tenant_screen.dart       # Add tenant form
    reports_screen.dart          # Collection ratio donut + tenant summary
    profile_screen.dart          # Landlord account + automation toggles + sign out
  theme/
    app_theme.dart               # Teal/white theme matching your screenshots
  widgets/
    rent_app_bar.dart
    formatters.dart              # ₹ currency + date formatting helpers
web/
  index.html, manifest.json     # Web shell (run `flutter create .` once to finish setup)
supabase_schema.sql              # Run this in the Supabase SQL editor, once
```

## One-time setup

### 1. Generate native platform folders
The native `android/`, `ios/`, `web/` scaffolding (icons, manifests, build config) needs to come from the Flutter CLI itself — it won't touch your `lib/` code:
```bash
flutter create . --platforms=android,ios,web
flutter pub get
```

### 2. Create a Supabase project
Go to [supabase.com](https://supabase.com) → New Project.

### 3. Run the schema
Open **SQL Editor** in your Supabase dashboard, paste the contents of `supabase_schema.sql`, and run it. This creates:
- `landlords`, `tenants`, `rent_payments` tables
- Row Level Security policies (each landlord only sees their own data)
- A trigger that auto-creates a landlord profile row on signup

### 4. (Optional) Enable Anonymous Sign-ins
The "Continue as Guest" button on the sign-in screen uses Supabase anonymous auth.
In your dashboard: **Authentication → Providers → Anonymous Sign-Ins → Enable**.
If you skip this, people can still sign up with email/password instead.

### 5. Add your credentials
Open `lib/main.dart` and fill in:
```dart
const String supabaseUrl = 'https://YOUR_PROJECT_REF.supabase.co';
const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```
Both values are in your Supabase dashboard under **Project Settings → API**.

## Running

```bash
flutter run -d chrome    # web
flutter run -d <ios-device-or-simulator-id>
flutter run -d <android-device-or-emulator-id>
```

## Building for release

**Android:**
```bash
flutter build apk --release
# or for Play Store:
flutter build appbundle --release
```

**iOS** (requires a Mac + Xcode):
```bash
flutter build ios --release
```
Then open `ios/Runner.xcworkspace` in Xcode to archive and upload to App Store Connect.

**Web:**
```bash
flutter build web --release
```
Output: a static site in `build/web/`. Deploy that folder to any static host:
- **Firebase Hosting**: `firebase init hosting` → public dir = `build/web` → `firebase deploy`
- **Netlify**: drag-and-drop `build/web`, or connect repo with build command `flutter build web`, publish dir `build/web`
- **Vercel**: same — publish dir `build/web`

The Supabase project itself needs no separate deployment — it's already a hosted backend once you've created it.

## How the data model works

- **Tenants** are people you rent to (name, phone, room/complex, monthly rent, due day).
- **rent_payments** has one row per tenant per calendar month. Adding a tenant auto-creates a `pending` payment row for the current month with `amount_due = monthly_rent`.
- **Collect** updates that row: `amount_paid`, `status = 'paid'`, `payment_method`, `paid_at`.
- **Send Reminder / Remind** uses the native share sheet (`share_plus`) — no backend SMS/WhatsApp API is wired up; that needs a paid provider (Twilio, WhatsApp Business API) and separate setup.
- **Reports** and the **Home** collection card are computed live from `rent_payments` for the current month.
- Row Level Security means each signed-in landlord only ever sees their own tenants and payments — Supabase enforces this at the database level, not just in the app.

## Notes
- Currently only the *current calendar month* is shown; extending to historical months means changing the `period_month`/`period_year` filters in `rent_service.dart` and adding a month picker.
- "WhatsApp Automation Sync" and "Payment Success Sound" toggles persist to Supabase but don't yet trigger real WhatsApp automation.

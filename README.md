# PAVILION – Customer Loyalty App

Flutter iOS & Android app for PAVILION member loyalty, bookings, and digital wallet.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x (iOS + Android) |
| State Management | Riverpod 2 |
| Navigation | GoRouter 13 |
| Database | Supabase (PostgreSQL + Realtime) |
| Auth | Supabase Auth (OTP, Google, Apple, Facebook) |
| Payments | Stripe (flutter_stripe) |
| QR Codes | qr_flutter |
| Anti-Fraud | 1:1 Device Binding + Dynamic QR (60s HMAC refresh) |

---

## Project Structure

```
lib/
├── main.dart                  # App entry, Supabase init
├── app.dart                   # GoRouter + MaterialApp
├── core/
│   ├── constants/             # Colors, routes, strings
│   ├── theme/                 # Light/dark theme
│   ├── utils/                 # QR timer, device binding
│   └── errors/                # Exception + failure types
├── data/
│   ├── models/                # UserModel, BookingModel, etc.
│   ├── repositories/          # Supabase + Stripe data access
│   └── services/              # (notification, calendar, email)
├── features/
│   ├── auth/                  # Login, OTP, Register, Splash
│   ├── home/                  # Feed, hero banner, newsfeed
│   ├── menu/                  # Food / Drinks / Shisha
│   ├── loyalty/               # Wallet, QR, transactions, redeem
│   ├── bookings/              # Date picker, confirm, my bookings
│   └── profile/               # Settings, edit profile, notifications
└── shared/
    └── widgets/               # MainShell (bottom nav), shared UI
migrations/                    # Supabase SQL (run in order 01→07)
supabase/functions/            # Edge Functions (Deno / TypeScript)
```

---

## Setup

### 1. Flutter dependencies

```bash
flutter pub get
```

### 2. Environment variables

Copy `.env` and fill in your values:

```bash
cp .env .env.local
```

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
STRIPE_PUBLISHABLE_KEY=pk_test_...
```

### 3. Supabase database

Run migrations in order in the Supabase SQL editor:

```
migrations/01_users.sql
migrations/02_loyalty.sql
migrations/03_bookings.sql
migrations/04_menus.sql
migrations/05_branches.sql
migrations/06_newsfeeds.sql
migrations/07_rls_policies.sql
```

### 4. Supabase Edge Functions

```bash
supabase functions deploy create-booking
supabase functions deploy cancel-booking
supabase functions deploy refund-deposit
supabase functions deploy delete-account
```

Set Edge Function secrets:

```bash
supabase secrets set STRIPE_SECRET_KEY=sk_test_...
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

### 5. Google Sign-In

- Create an OAuth 2.0 client in Google Cloud Console
- Download `GoogleService-Info.plist` → place in `ios/Runner/`
- Download `google-services.json` → place in `android/app/`
- Add the reversed client ID to `ios/Runner/Info.plist`

### 6. Apple Sign-In

- Enable "Sign In with Apple" in Xcode → Signing & Capabilities
- Enable in Supabase Dashboard → Auth → Providers → Apple

### 7. Stripe

- Add your publishable key to `.env`
- Add your secret key to Supabase Edge Function secrets
- For production: configure Stripe webhook to handle `payment_intent.succeeded`

### 8. iOS deep link

Add to your `ios/Runner/Info.plist` (already included):
```xml
<string>io.pavilion.app</string>
```

### 9. Run the app

```bash
flutter run
```

---

## Key Features

| Feature | Implementation |
|---|---|
| Multi-channel auth | Supabase Auth: OTP SMS, Google, Apple, Facebook |
| 1:1 Device binding | `device_bindings` table + `DeviceBinding` util |
| Dynamic QR (60s) | `QrTimer` HMAC-SHA256 signed, refreshes every 60s |
| Loyalty points | 1 pt per £1 · staff manual input via RPC |
| Physical card link | `link_physical_card()` Supabase function |
| Table booking | 3-step flow · Stripe deposit · auto email + calendar |
| Refund on cancel | Edge Function triggers Stripe refund if >24h notice |
| Branch newsfeeds | Per-branch content in `newsfeeds` table |
| Dynamic menus | Food / Drinks / Shisha from `menu_items` table |
| RLS security | Every table protected — users see only their data |

---

## Loyalty Tier Thresholds

| Tier | Lifetime Points |
|---|---|
| Bronze | 0 – 999 |
| Silver | 1,000 – 4,999 |
| Gold | 5,000 – 9,999 |
| Platinum | 10,000+ |

---

## Notes

- Replace `00000000-0000-0000-0000-000000000001` branch IDs in SQL with real UUIDs after first insert
- `payment_repository.dart` imports `flutter_stripe` — the `Color`/`ThemeMode` stubs at the bottom of that file should be removed once Flutter material imports are in scope
- Add `crypto` to `pubspec.yaml` for `QrTimer` HMAC signing: `crypto: ^3.0.3`

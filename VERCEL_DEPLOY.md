# Deploying TigerBay to Vercel

The Flutter web bundle is served by Vercel as a static SPA. `vercel.json` drives
everything: the build command, the output directory, the SPA rewrite, and all
response headers.

---

## 1. Environment variables (do this first)

Set these in **Vercel → Project → Settings → Environment Variables** for
*Production*, *Preview* and *Development*:

| Variable | Required | Notes |
| --- | --- | --- |
| `SUPABASE_URL` | recommended | e.g. `https://<ref>.supabase.co` |
| `SUPABASE_ANON_KEY` | recommended | Public anon key — safe in the browser |
| `STRIPE_PUBLISHABLE_KEY` | recommended | `pk_live_…` / `pk_test_…` — safe in the browser |
| `GOOGLE_WEB_CLIENT_ID` | required for Google sign-in | `….apps.googleusercontent.com` |
| `APP_SCHEME` | optional | Defaults to `io.tigerbay.app` |
| `APP_ENV` | optional | Set to `production` |

`ci/vercel_build.sh` bakes only the variables above into the bundle via
`--dart-define`. Anything left unset silently falls back to the compiled-in
default in `lib/core/config/env_config.dart` rather than failing the build, so
check the build log for `- VAR (unset …)` lines.

> **Never** add `STRIPE_SECRET_KEY` or `TWILIO_AUTH_TOKEN` here. A
> `--dart-define` value is readable by anyone who downloads `main.dart.js`.

### Supabase auth redirects

Google/Apple sign-in on the web redirects out to the provider and back, so add
your Vercel URLs to **Supabase → Authentication → URL Configuration**:

- Site URL: `https://<your-domain>`
- Redirect URLs: `https://<your-domain>/**` and every preview domain

Add the same origins as **Authorized JS origins** in Google Cloud Console
(APIs & Services → Credentials → your Web OAuth client).

---

## 2. Deploy

### Option A — Git integration (recommended)

1. Push this branch to GitHub.
2. In Vercel: **Add New → Project → Import** the repo.
3. Framework preset is forced to **Other** by `vercel.json` — leave it.
4. Add the environment variables from step 1, then **Deploy**.

Every subsequent push redeploys automatically.

### Option B — Vercel CLI

```bash
npm i -g vercel
vercel          # first run links the project and creates a preview
vercel --prod   # production
```

The CLI uploads only what `.vercelignore` allows and runs `ci/vercel_build.sh`
in Vercel's build environment.

---

## 3. What the build does

`ci/vercel_build.sh` (also runnable locally via `tool/build_web.ps1`):

1. Downloads the pinned Flutter **3.41.6** SDK (~1.4 GB) — Vercel has no
   Flutter preinstalled, so expect **3–6 minutes** on the first build.
2. `flutter pub get`
3. `flutter build web --release --base-href=/ --no-wasm-dry-run` with the
   public `--dart-define`s.
4. Deletes `canvaskit/*.symbols` — ~7 MB of debug symbol tables that are never
   requested by a browser.

Subsequent builds are faster thanks to Vercel's build cache.

### Local preview

```powershell
.\tool\build_web.ps1 -Serve     # builds, then serves on http://localhost:8080
```

---

## 4. Web-specific changes that were required

`webview_flutter` and `local_auth` ship **no web implementation**, so the app
would have thrown `MissingPluginException` in the browser.

- `lib/core/platform/webview_shim.dart` is a conditional barrel: it re-exports
  the real `webview_flutter` on `dart:io` platforms and
  `webview_shim_web.dart` on the web. `booking_screen.dart` imports the shim,
  so **no call site changed and mobile behaviour is untouched**.
- On the web the booking screen renders a branded panel that opens the venue
  booking page in a new tab. This is deliberate — most booking providers send
  `X-Frame-Options: DENY`, so an iframe embed would be blocked anyway.
- `BiometricService` returns "unavailable" on the web. Without this,
  `splash_screen.dart` treated the failed check as a rejected login and
  stranded members on the login screen.
- `web/index.html` gained the required viewport meta tag and a boot splash that
  is dismissed on Flutter's `flutter-first-frame` event (with a 15 s failsafe).
- `web/manifest.json` was still the stock Flutter one; it is now branded.

## 5. Header behaviour

| Path | `Cache-Control` |
| --- | --- |
| `/index.html`, `/version.json`, `/flutter_service_worker.js` | `no-cache, no-store, must-revalidate` |
| `/main.dart.js`, `/flutter.js`, `/flutter_bootstrap.js` | `max-age=0, must-revalidate` |
| `/assets/*` | `max-age=31536000, immutable` (content-hashed) |
| `/canvaskit/*` | `max-age=604800, must-revalidate` |

`/canvaskit/*.wasm` is pinned to `Content-Type: application/wasm`; CanvasKit
will not stream-compile under any other type. All paths fall through to
`/index.html` so `go_router` deep links work on refresh.

---

## 6. ⚠️ Pre-existing issue: secrets are compiled into the bundle

`main.dart.js` currently contains a **live Stripe secret key** and a **Twilio
auth token**. They are *not* coming from `--dart-define` (the build script never
passes them) — they are hardcoded string literals in
`lib/core/config/env_config.dart`, and `payment_repository.dart` calls
`api.stripe.com` directly with the secret from the client.

This was tolerable inside a mobile APK. **On the public web it is a plain-text
credential leak** — `view-source:main.dart.js` is enough to read them.

Recommended fix, in order:

1. Move PaymentIntent creation/verification into the existing
   `supabase/functions/create-payment-intent` Edge Function and return only the
   client secret.
2. Set the key via `supabase secrets set STRIPE_SECRET_KEY=…` — never in
   client code.
3. Replace the hardcoded `defaultValue:` fallbacks in `EnvConfig` for
   `stripeSecretKey` and `twilioAuthToken` with `''`, and rotate both
   credentials (they are also in git history).

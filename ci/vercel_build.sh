#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# TigerBay International — Vercel production build for Flutter Web
# ═══════════════════════════════════════════════════════════════════════════
# Vercel's build image has no Flutter SDK, so we install a pinned version,
# restore dependencies, compile the web bundle, and strip the debug symbol
# files that are never fetched at runtime.
#
# Secrets are NEVER passed in as --dart-define: they would be readable by any
# visitor in the compiled main.dart.js. Only the browser-safe, public values
# below are baked into the bundle. Server-side secrets (Stripe secret key,
# Twilio auth token) must live in the Supabase Edge Function environment.
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.41.6}"
FLUTTER_ROOT="${FLUTTER_ROOT:-/tmp/flutter}"
export PATH="${FLUTTER_ROOT}/bin:${PATH}"

# Vercel only passes production env vars when this is explicitly requested.
export PUB_CACHE="${PUB_CACHE:-/tmp/pub-cache}"
export FLUTTER_SUPPRESS_ANALYTICS=true
export CI=true

# ── 1. Install Flutter ───────────────────────────────────────────────────────
if [ ! -x "${FLUTTER_ROOT}/bin/flutter" ]; then
  echo "▸ Downloading Flutter ${FLUTTER_VERSION}..."
  ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${ARCHIVE}"
  DOWNLOAD_DIR="$(mktemp -d)"

  curl -fsSL --retry 3 --retry-delay 2 -o "${DOWNLOAD_DIR}/${ARCHIVE}" "${URL}"

  # The archive contains a single top-level `flutter/` directory, so it must be
  # unpacked into the PARENT of FLUTTER_ROOT and then moved into place.
  # Unpacking straight into FLUTTER_ROOT would yield FLUTTER_ROOT/flutter/bin/flutter
  # and every later `flutter` call would fail with "command not found".
  EXTRACT_DIR="$(mktemp -d)"
  tar -xf "${DOWNLOAD_DIR}/${ARCHIVE}" -C "${EXTRACT_DIR}"

  if [ ! -x "${EXTRACT_DIR}/flutter/bin/flutter" ]; then
    echo "ERROR: unexpected archive layout, no flutter/bin/flutter at the top level" >&2
    exit 1
  fi

  mkdir -p "$(dirname "${FLUTTER_ROOT}")"
  rm -rf "${FLUTTER_ROOT}"
  mv "${EXTRACT_DIR}/flutter" "${FLUTTER_ROOT}"

  rm -rf "${EXTRACT_DIR}" "${DOWNLOAD_DIR}"
fi

if [ ! -x "${FLUTTER_ROOT}/bin/flutter" ]; then
  echo "ERROR: Flutter is not executable at ${FLUTTER_ROOT}/bin/flutter" >&2
  exit 1
fi

# The SDK is a git checkout owned by a different uid inside the build sandbox.
git config --global --add safe.directory "${FLUTTER_ROOT}" || true

echo "▸ Flutter version: $(flutter --version --machine 2>/dev/null | head -c 200)"
flutter config --no-analytics >/dev/null 2>&1 || true

# ── 2. Restore dependencies ──────────────────────────────────────────────────
echo "▸ flutter pub get"
flutter pub get

# ── 3. Collect browser-safe configuration ────────────────────────────────────
# Reads a value from the environment, tolerating unset/empty so that a missing
# Vercel variable degrades to the app's compiled-in defaults instead of failing
# the build.
env_or_empty() {
  printf '%s' "${!1:-}"
}

DART_DEFINES=()
add_define() {
  local key="$1" value
  value="$(env_or_empty "${key}")"
  if [ -n "${value}" ]; then
    DART_DEFINES+=("--dart-define=${key}=${value}")
    echo "  ✓ ${key}"
  else
    echo "  – ${key} (unset — using compiled default)"
  fi
}

echo "▸ Public build configuration:"
add_define SUPABASE_URL
add_define SUPABASE_ANON_KEY
add_define STRIPE_PUBLISHABLE_KEY
add_define GOOGLE_WEB_CLIENT_ID
add_define APP_SCHEME
add_define APP_ENV

# Demo mode is opt-in per environment: set DEMO_MODE=true on a Vercel environment
# to accept the master OTP (000000) in place of a real SMS code. It is unset by
# default, so a production deploy stays demo-off unless you deliberately enable it.
add_define DEMO_MODE

# ── 4. Build ─────────────────────────────────────────────────────────────────
# --no-web-resources-cdn makes the app serve CanvasKit from build/web/canvaskit
# instead of fetching it from www.gstatic.com at runtime. A blocked or slow
# gstatic request means the app never paints its first frame and the user is
# left staring at the boot splash — a self-hosted demo must not depend on a
# third-party CDN being reachable from the venue's network.
echo "▸ flutter build web --release"
flutter build web \
  --release \
  --base-href=/ \
  --no-web-resources-cdn \
  --no-wasm-dry-run \
  "${DART_DEFINES[@]}"

# ── 5. Trim artifacts that are never served ──────────────────────────────────
# CanvasKit ships DWARF symbol tables alongside every variant. They are only
# useful for debugging native crashes and add ~7 MB to every upload.
echo "▸ Stripping CanvasKit symbol files"
find build/web/canvaskit -name '*.symbols' -type f -delete 2>/dev/null || true

echo "▸ Build complete:"
du -sh build/web
echo "▸ Output directory: build/web"

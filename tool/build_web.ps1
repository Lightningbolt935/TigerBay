<#
.SYNOPSIS
    Builds the TigerBay Flutter Web bundle exactly the way Vercel does.

.DESCRIPTION
    Mirrors ci/vercel_build.sh so that a local preview is byte-for-byte
    equivalent to the deployed bundle. Only browser-safe (public) values are
    passed as --dart-define; server secrets are never embedded.

.PARAMETER Serve
    Start a local static server on the built output for quick verification.

.PARAMETER DemoMode
    Accept the master OTP (000000) in place of a real SMS code, and downgrade
    SMS delivery failures to non-blocking warnings. OFF by default. NEVER use
    this for a published build — ci/vercel_build.sh never passes it.

.EXAMPLE
    .\tool\build_web.ps1
    .\tool\build_web.ps1 -Serve
    .\tool\build_web.ps1 -DemoMode -Serve
#>
[CmdletBinding()]
param([switch]$Serve, [switch]$DemoMode)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot

try {
    # ── 1. Load .env (optional — the app falls back to compiled defaults) ─────
    $envMap = @{}
    if (Test-Path -LiteralPath '.env') {
        Get-Content -LiteralPath '.env' | ForEach-Object {
            if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
                $envMap[$matches[1].Trim()] = $matches[2].Trim()
            }
        }
        Write-Host "Loaded $($envMap.Count) values from .env" -ForegroundColor DarkGray
    } else {
        Write-Warning ".env not found - relying on compiled-in defaults."
    }

    # ── 2. Public configuration only ──────────────────────────────────────────
    # Never add STRIPE_SECRET_KEY / TWILIO_* to this list: a --dart-define
    # value is readable by anyone who downloads main.dart.js.
    $publicKeys = @(
        'SUPABASE_URL',
        'SUPABASE_ANON_KEY',
        'STRIPE_PUBLISHABLE_KEY',
        'GOOGLE_WEB_CLIENT_ID',
        'APP_SCHEME'
    )

    $flutterArgs = @('build', 'web', '--release', '--base-href=/', '--no-wasm-dry-run')
    foreach ($key in $publicKeys) {
        $value = $envMap[$key]
        if ($value) {
            $flutterArgs += "--dart-define=$key=$value"
            Write-Host "  + $key" -ForegroundColor DarkGray
        } else {
            Write-Host "  - $key (using compiled default)" -ForegroundColor DarkGray
        }
    }
    $flutterArgs += '--dart-define=APP_ENV=production'

    if ($DemoMode) {
        $flutterArgs += '--dart-define=DEMO_MODE=true'
        Write-Host "  ! DEMO_MODE=true - master OTP 000000 is accepted. Demo build only." -ForegroundColor Yellow
    } else {
        $flutterArgs += '--dart-define=DEMO_MODE=false'
        Write-Host "  - DEMO_MODE=false (master OTP rejected)" -ForegroundColor DarkGray
    }

    # ── 3. Build ──────────────────────────────────────────────────────────────
    Write-Host "`nBuilding Flutter Web release..." -ForegroundColor Cyan
    & flutter @flutterArgs
    if ($LASTEXITCODE -ne 0) { throw "flutter build web failed (exit $LASTEXITCODE)" }

    # ── 4. Strip CanvasKit debug symbol tables (never fetched at runtime) ─────
    Get-ChildItem -Path 'build\web\canvaskit' -Filter '*.symbols' -Recurse -ErrorAction SilentlyContinue |
        Remove-Item -Force
    Write-Host "Stripped CanvasKit symbol files." -ForegroundColor DarkGray

    $size = (Get-ChildItem -Path 'build\web' -Recurse -File | Measure-Object -Property Length -Sum).Sum
    Write-Host ("`nBuilt build\web ({0:N1} MB)" -f ($size / 1MB)) -ForegroundColor Green

    # ── 5. Optional local preview ─────────────────────────────────────────────
    if ($Serve) {
        Write-Host "`nServing http://localhost:8080 (Ctrl+C to stop)..." -ForegroundColor Cyan
        python -m http.server 8080 --directory build/web
    }
}
finally {
    Pop-Location
}
